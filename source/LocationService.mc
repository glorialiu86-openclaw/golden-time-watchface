import Toybox.Lang;
import Toybox.Position;
import Toybox.Time;

class LocationService {
    const FIX_REQUEST_MIN_INTERVAL_SEC = 5;
    const TEST_MODE = true;  // 测试模式：硬编码上海位置

    var _lastFix as Lang.Dictionary or Null;
    var _lastRequestTs as Number;

    function initialize() {
        _lastFix = null;
        _lastRequestTs = 0;
        
        // 测试模式：立即设置上海位置
        if (TEST_MODE) {
            _lastFix = {
                :lat => 31.2304,
                :lon => 121.4737,
                :ts => Time.now().value()
            };
        }
    }

    function requestFixIfNeeded(nowTs as Number) as Void {
        // 测试模式：跳过真实 GPS 请求
        if (TEST_MODE) {
            return;
        }
        
        var ageSec = nowTs - _lastRequestTs;
        if (_lastFix != null && ageSec < FIX_REQUEST_MIN_INTERVAL_SEC) {
            return;
        }

        _lastRequestTs = nowTs;

        try {
            var info = Position.getInfo();
            if (info == null || info.position == null) {
                return;
            }

            var coord = info.position.toDegrees();
            if (coord == null) {
                return;
            }

            var lat = coord[0];
            var lon = coord[1];
            if (lat == null || lon == null) {
                return;
            }
            if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                return;
            }
            // Simulators often return (180,180) when no GPS fix is available.
            if (lat == 180 && lon == 180) {
                return;
            }

            var fix = {
                :lat => lat,
                :lon => lon,
                :ts => Time.now().value()
            };

            if (info.accuracy != null) {
                fix[:acc] = info.accuracy;
            }

            _lastFix = fix;
        } catch (ex) {
        }
    }

    function getLastFix() as Lang.Dictionary or Null {
        return _lastFix;
    }
}
