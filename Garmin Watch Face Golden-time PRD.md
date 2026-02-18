# Garmin Watch Face Golden-time PRD

**产品需求文档**  
**版本：** v1.1  
**日期：** 2026-02-18

---

## 一、产品概述

### 1.1 产品定义

Golden-time 是一款为摄影师和户外爱好者设计的 Garmin 表盘，实时显示下一次蓝调（Blue Hour）和金调（Golden Hour）的倒计时，帮助用户捕捉最佳光线时刻。

### 1.2 目标用户

- 摄影师（风光、人像、城市摄影）
- 户外爱好者
- 对日出日落时间敏感的用户

### 1.3 支持设备

- Garmin Fenix 7S（主要测试设备）
- 其他支持 Connect IQ SDK 5.2+ 的设备

---

## 二、功能需求

### 2.1 核心功能

#### 2.1.1 时间显示
- **主时间：** 大字号显示当前时间（HH:MM）
- **日期：** 小字号显示星期和日期（WED | FEB 18）

#### 2.1.2 蓝调倒计时（Blue Hour）
- **定义：** 太阳高度角从 -10° 到 -4°
- **显示位置：** 表盘左下角
- **标签：** "Blue"（白色）
- **倒计时格式：** HH:MM
- **当时间处于蓝调区间内，则显示：** NOW
- **无数据显示：** --:--

#### 2.1.3 金调倒计时（Golden Hour）
- **定义：** 太阳高度角从 -4° 到 +6°
- **显示位置：** 表盘右下角
- **标签：** "Golden"（金色 #FFAA00）
- **倒计时格式：** HH:MM
- **当时间处于金调区间内，则显示：** NOW
- **无数据显示：** --:--

#### 2.1.4 GPS 定位与倒计时计算
- **自动获取：** 使用设备 GPS 获取当前位置
- **更新频率：** 每日凌晨零点请求一次，计算当日晨与当日夜的数据。每日中午十二点请求一次，计算当日夜与次日晨的数据。缓存并使用。
- **跨越时区 or 经纬度更新：** 首次定位后，或者，单小时内经度变化 ≥ 2.5°（≈10分钟）时，进行一次重算。
- **测试模式：** 可硬编码上海位置（31.2304, 121.4737）

---

## 三、技术架构

### 3.1 技术栈

- **开发语言：** Monkey C
- **SDK 版本：** Connect IQ SDK 8.4.1
- **开发工具：** VS Code + Monkey C 扩展
- **构建工具：** monkeyc + monkeydo

### 3.2 核心模块

#### 3.2.1 LocationService
- **职责：** GPS 定位管理
- **功能：**
  - 请求 GPS 定位
  - 缓存最近一次定位
  - 测试模式支持

#### 3.2.2 SunAltService
- **职责：** 太阳高度角计算和事件扫描
- **功能：**
  - 计算太阳高度角（NOAA 算法）
  - 扫描蓝调/金调事件
  - 缓存 24 小时内的事件
  - 查找下一次事件

#### 3.2.3 Golden-timeView
- **职责：** 表盘 UI 渲染
- **功能：**
  - 绘制时间和日期
  - 绘制蓝调/金调倒计时
  - 处理安全区域（圆形表盘）

### 3.3 算法实现

#### 3.3.1 太阳高度角计算
- **算法：** NOAA Solar Position Algorithm
- **输入：** 时间戳、纬度、经度
- **输出：** 太阳高度角（度）
- **精度：** 约 0.01°

#### 3.3.2 事件扫描算法

**当前实现（v1.1）：解析解方法（NOAA 标准公式）**

```
1. 计算太阳赤纬 δ
2. 计算时间方程（equation of time）
3. 对于每个阈值角度 θ（-10°、-4°、+6°）：
   - 解时角方程：cos(H) = (sin(θ) - sin(φ)sin(δ)) / (cos(φ)cos(δ))
   - 计算太阳正午：solarNoon = 720 - 4*lon - eqTime + tz*60 (分钟)
   - 计算事件时间：T = solarNoon ± H/15 (本地时间)
   - 转换为 UTC 时间戳
4. 返回时间戳
```

---

## 四、当前唯一活跃问题

**问题：** Monkey C 实现返回 null，导致表盘显示 `--:--`

**完成判定：**
```
[SNAPSHOT] 输出中 blueTs != null && goldenTs != null
且 blueCountdown 和 goldenCountdown 显示不同的时间（格式 HH:MM）
```

**证据来源：**
```
[SNAPSHOT] buildId=v1.1 blueCountdown=b=--:-- goldenCountdown=g=--:-- blueTs=null goldenTs=null
```

---

## 五、已证实事实（Verified Facts）

### 5.1 变量绑定错误已修复
**证据：** 代码改动 `source/SunAltService.mc` 行 230-310  
**时间：** 2026-02-18 22:17  
**问题：** `var goldenStart = blueEnd;` 导致两个变量共享同一个值  
**修复：** 改为 6 个独立变量（`morningBlueStart`, `morningBlueGoldenBoundary`, `morningGoldenEnd`, `eveningGoldenStart`, `eveningGoldenBlueBoundary`, `eveningBlueEnd`）

### 5.2 Python 算法正确
**证据：** Python 单测输出
```
蓝调开始（-10°）：✅ 时间: 05:49:57
金调开始（-4°）：✅ 时间: 06:18:23
时间差: 28 分钟
✅ 测试通过：时间在早晨范围内
```
**对比数据：** 巧摄专业版（2026-02-18）
- 晨蓝调起点：05:59（误差 -9 分钟，预期，因为 -10° vs -8°）
- 晨蓝调结束/晨金调起点：06:18（误差 +1 分钟）
- 晨金调结束：07:06（误差 +1 分钟）
- 夜金调起点：17:11（误差 0 分钟）
- 夜蓝调结束：18:18（误差 +10 分钟）

### 5.3 NOAA 标准公式修复了时间基准问题
**证据：** Python 诊断输出
```
方法 A（错误）：solar_noon_hour = 12 + (RA - GMST - lon) / 15 = 16.13（凌晨）
方法 B（NOAA 标准）：solarNoon = 720 - 4*lon - eqTime + tz*60 = 12.16（中午）
早晨时间：05:50，傍晚时间：18:28
```

---

## 六、已证伪假设（Rejected Hypotheses）

### 6.1 "模拟器日志丢失"
**假设：** System.println() 输出被模拟器丢失  
**证据：** 代码未执行到 System.println() 行（因为算法提前返回 null）  
**结论：** 不是日志丢失，是代码逻辑问题

### 6.2 "Monkey C 整数除法导致时间戳相同"
**假设：** `(hi - lo) / 2` 的整数截断导致二分查找失败  
**证据：** 改用 `/ 2.0` 后问题依然存在  
**结论：** 不是整数除法问题，是变量绑定错误（`goldenStart = blueEnd`）

---

## 七、修复闭环规则

**强制执行顺序：**

1. **Python 单测全绿**
   - 运行 `python3 test_algorithm.py`
   - 所有断言通过
   - 时间在早晨范围内（4:00-10:00）

2. **同步到 Monkey C**
   - 将 Python 验证通过的算法移植到 Monkey C
   - 编译成功：`monkeyc -d fenix7s -f monkey.jungle -o bin/Golden-time.prg`

3. **验证 SNAPSHOT**
   - 运行 `monkeydo bin/Golden-time.prg fenix7s`
   - 捕获 `[SNAPSHOT]` 输出
   - 验证 `blueTs != null && goldenTs != null`
   - 验证 `blueCountdown != goldenCountdown`

4. **未通过不得进入 UI 层**
   - 禁止在算法未验证通过时修改 UI 代码
   - 禁止在 SNAPSHOT 未通过时进行手动验证

---

## 八、变量结构约束

### 8.1 六个时间点变量
**强制命名：**
- `morningBlueStart` - 晨蓝调起点（-10°，上升）
- `morningBlueGoldenBoundary` - 晨蓝调结束 = 晨金调起点（-4°，上升）
- `morningGoldenEnd` - 晨金调结束（+6°，上升）
- `eveningGoldenStart` - 夜金调起点（+6°，下降）
- `eveningGoldenBlueBoundary` - 夜金调结束 = 夜蓝调起点（-4°，下降）
- `eveningBlueEnd` - 夜蓝调结束（-10°，下降）

**禁止：**
- 变量之间互相引用（如 `goldenStart = blueEnd`）
- 重复计算同一阈值（如同时计算 `blueEnd` 和 `goldenStart` 都用 -4°）

### 8.2 时间基准声明

**UTC 统一：**
- 所有时间戳（`dayStartTs`, `eventTs`）必须是 UTC 时间
- 所有儒略日计算基于 UTC 时间戳

**时区修正只能一次：**
- 在 NOAA 公式中修正：`solarNoon = 720 - 4*lon - eqTime + tz*60`
- 在转换为时间戳时修正：`eventTs = dayStartTs + (eventHourLocal - tz) * 3600`
- 禁止在多处重复加减时区偏移

**经度方向：**
- 东经为正（如上海 121.4737）
- 西经为负（如纽约 -74.0060）

---

## 九、技术债务

### 9.1 代码质量

- **冗余代码：** 旧的二分查找函数未删除（_isCrossing, _bisectRoot）
- **魔法数字：** 扫描窗口时间（4:00-10:00）硬编码

### 9.2 测试覆盖

- ✅ **Python 单元测试：** 已完成（test_algorithm.py）
- ✅ **状态快照输出：** 已完成（[SNAPSHOT] 日志）
- ❌ **Monkey C 验证：** 待完成

---

## 十、验收标准

### 10.1 功能验收

- [ ] `[SNAPSHOT]` 输出 `blueTs != null`
- [ ] `[SNAPSHOT]` 输出 `goldenTs != null`
- [ ] `blueCountdown` 和 `goldenCountdown` 不同
- [ ] 时间精度误差 < 15 分钟（对比巧摄专业版）

---

## 十一、参考资料

### 11.1 算法参考

- NOAA Solar Position Algorithm
- 巧摄专业版（对比数据）
- 时角方程：cos(H) = (sin(θ) - sin(φ)sin(δ)) / (cos(φ)cos(δ))
- NOAA 太阳正午公式：solarNoon = 720 - 4*longitude - equationOfTime + timezone*60

### 11.2 开发文档

- Garmin Connect IQ SDK 文档
- Monkey C API 参考
- AGENTS.md（工作空间规则）

---

**变更记录：**
- 2026-02-18 21:21 - 初始版本
- 2026-02-18 22:20 - 更新进度
- 2026-02-18 22:48 - 结构修正：删除猜测性判断，新增已证实事实和已证伪假设，明确修复闭环规则和变量结构约束
