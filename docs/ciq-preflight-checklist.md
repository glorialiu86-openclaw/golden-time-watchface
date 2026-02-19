# Connect IQ 开发前检查清单

**快速参考**：开始开发前 5 分钟检查

---

## 环境检查（5 项）

- [ ] SDK 已安装：`~/Library/Application Support/Garmin/ConnectIQ/Sdks/`
- [ ] 开发者密钥存在：`developer_key` 文件在项目根目录
- [ ] VS Code + Monkey C 扩展已安装
- [ ] 模拟器可启动：`monkeydo --help` 有输出
- [ ] 截图目录已创建：`screenshots/`

---

## 配置检查（5 项）

- [ ] `monkey.jungle` 列出了目标设备
- [ ] `manifest.xml` 权限与实际需求一致
- [ ] 资源文件存在：`resources/drawables/`, `resources/layouts/`
- [ ] 启动图标准备好（建议多尺寸：24x24, 40x40, 80x80）
- [ ] `.gitignore` 包含 `bin/`, `.DS_Store`

---

## 代码检查（8 项）

- [ ] 所有时间戳使用 UTC 基准
- [ ] 时区修正只在一处完成（NOAA 公式）
- [ ] 关键变量独立声明，避免 `var a = b;`
- [ ] 涉及精度的计算使用浮点数：`/ 2.0`
- [ ] 添加了日志输出：`System.println("[TAG] message")`
- [ ] 或添加了 UI debug 信息（版本号、状态码）
- [ ] 使用了语义明确的变量名
- [ ] 避免了魔法数字（用常量或注释说明）

---

## 验证准备（5 项）

- [ ] 算法先用 Python 验证通过
- [ ] 准备了测试用固定经纬度（如上海 31.2°N, 121.5°E）
- [ ] 准备了测试用固定时间戳
- [ ] 知道如何截图（系统快捷键或脚本）
- [ ] 知道如何查看日志（monkeydo 输出）

---

## 文档准备（2 项）

- [ ] README 中记录了构建命令
- [ ] 已知问题记录在 PRD 或 AGENTS.md

---

## 快速构建测试

```bash
# 1. 构建
monkeyc --jungles monkey.jungle --device fenix7s --output bin/test.prg --warn

# 2. 部署
monkeydo bin/test.prg fenix7s

# 3. 检查日志
# 查找 [SNAPSHOT] 或 [DEBUG] 标记

# 4. 截图
# Cmd + Shift + 4 + 空格 → 点击模拟器窗口
```

---

## 遇到问题时

1. **编译失败** → 检查 SDK 路径、语法、资源
2. **运行时错误** → 检查日志、截图、变量值
3. **日志为空** → 切换到 UI 验证（显示版本号）
4. **问题复杂** → 使用二分法缩小范围

详细排障手册：`docs/ciq-embedded-postmortem.md`

---

**版本**：v1.0  
**更新**：2026-02-20
