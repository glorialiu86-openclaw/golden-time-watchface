import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Time;

class LocationService {
    const FIX_REQUEST_MIN_INTERVAL_SEC_NO_FIX = 5;
    const FIX_REQUEST_MIN_INTERVAL_SEC_HAS_FIX = 1800;
    const TEST_MODE = false;  // 测试模式：硬编码上海位置
    const KEY_LASTFIX_LAT = "gt_lastfix_lat";
    const KEY_LASTFIX_LON = "gt_lastfix_lon";
    const KEY_LASTFIX_TS = "gt_lastfix_ts";
    const KEY_LASTFIX_ACC = "gt_lastfix_acc";
    const KEY_LASTFIX_VER = "gt_lastfix_ver";

    var _lastFix as Lang.Dictionary or Null;
    var _lastRequestTs as Number;

    function initialize() {
        _lastFix = null;
        _lastRequestTs = 0;
        _loadPersistedFix();
        
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
        var minInterval = (_lastFix == null) ? FIX_REQUEST_MIN_INTERVAL_SEC_NO_FIX : FIX_REQUEST_MIN_INTERVAL_SEC_HAS_FIX;
        if (ageSec < minInterval) {
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
            _persistFix(fix);
        } catch (ex) {
        }
    }

    function getLastFix() as Lang.Dictionary or Null {
        return _lastFix;
    }

    function _loadPersistedFix() as Void {
        var app = Application.getApp();
        if (app == null) {
            return;
        }

        var lat = app.getProperty(KEY_LASTFIX_LAT) as Number or Null;
        var lon = app.getProperty(KEY_LASTFIX_LON) as Number or Null;
        var ts = app.getProperty(KEY_LASTFIX_TS) as Number or Null;
        var acc = app.getProperty(KEY_LASTFIX_ACC) as Number or Null;
        if (lat == null || lon == null || ts == null) {
            return;
        }
        if ((lat as Number) < -90 || (lat as Number) > 90 || (lon as Number) < -180 || (lon as Number) > 180) {
            return;
        }

        _lastFix = {
            :lat => lat,
            :lon => lon,
            :ts => ts
        };
        if (acc != null) {
            _lastFix[:acc] = acc;
        }
    }

    function _persistFix(fix as Lang.Dictionary) as Void {
        var app = Application.getApp();
        if (app == null) {
            return;
        }

        app.setProperty(KEY_LASTFIX_LAT, fix[:lat]);
        app.setProperty(KEY_LASTFIX_LON, fix[:lon]);
        app.setProperty(KEY_LASTFIX_TS, fix[:ts]);
        app.setProperty(KEY_LASTFIX_VER, 1);
        if (fix[:acc] != null) {
            app.setProperty(KEY_LASTFIX_ACC, fix[:acc]);
        } else {
            app.setProperty(KEY_LASTFIX_ACC, null);
        }
    }
}
