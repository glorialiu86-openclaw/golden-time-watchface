import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class GoldenTimeView extends WatchUi.WatchFace {
    const DEBUG_ENABLED = true;

    var _locationService as LocationService;
    var _sunAltService as SunAltService;

    function initialize() {
        WatchFace.initialize();
        _locationService = new LocationService();
        _sunAltService = new SunAltService();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var nowMoment = Time.now();
        var nowTs = nowMoment.value();
        var w = dc.getWidth();
        var h = dc.getHeight();

        _locationService.requestFixIfNeeded(nowTs);
        var fix = _locationService.getLastFix();

        _sunAltService.updateIfNeeded(nowTs, fix);
        var snap = _sunAltService.getSnapshot(nowTs);

        _drawBackground(dc);
        _drawTime(dc, w, h);
        _drawDate(dc, nowMoment, w, h);
        _drawDualCountdown(dc, snap, nowTs, w, h);

        if (DEBUG_ENABLED) {
            _drawDebug(dc, snap, fix);
        }
    }

    function _drawBackground(dc as Dc) as Void {
        dc.setColor(0xFFFFFF, 0x000000);
        dc.clear();
    }

    function _drawTime(dc as Dc, w as Number, h as Number) as Void {
        var clock = System.getClockTime();
        var hh = clock.hour.format("%02d");
        var mm = clock.min.format("%02d");
        var text = Lang.format("$1$:$2$", [hh, mm]);
        var insets = _getSafeInsets(dc);
        var safeTop = (insets[:top] as Number) + 6;
        var safeBottom = h - (insets[:bottom] as Number) - 6;
        var safeH = safeBottom - safeTop;

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, safeTop + (safeH * 0.37), Graphics.FONT_LARGE, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawDate(dc as Dc, nowMoment as Time.Moment, w as Number, h as Number) as Void {
        var info = Time.Gregorian.info(nowMoment, Time.FORMAT_SHORT);
        var dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        var monthNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        var dowIdx = (info[:day_of_week] as Number);
        var monthIdx = (info[:month] as Number) - 1;
        var dateText = Lang.format("$1$ | $2$ $3$", [
            dayNames[dowIdx],
            monthNames[monthIdx],
            (info[:day] as Number).format("%02d")
        ]);
        var insets = _getSafeInsets(dc);
        var safeTop = (insets[:top] as Number) + 6;

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, safeTop + 16, Graphics.FONT_TINY, dateText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawDualCountdown(dc as Dc, snap as Lang.Dictionary, nowTs as Number, w as Number, h as Number) as Void {
        var hasFix = snap[:hasFix] as Boolean;
        var pad = 6;
        var fontLabel = Graphics.FONT_TINY;
        var fontValue = Graphics.FONT_SMALL;
        var insets = _getSafeInsets(dc);
        var safeLeft = (insets[:left] as Number) + pad;
        var safeRight = w - (insets[:right] as Number) - pad;
        var safeTop = (insets[:top] as Number) + pad;
        var safeBottom = h - (insets[:bottom] as Number) - pad;
        var safeW = safeRight - safeLeft;
        var safeH = safeBottom - safeTop;

        var blueTs = hasFix ? (snap[:nextBlueStartTs] as Number or Null) : null;
        var goldenTs = hasFix ? (snap[:nextGoldenStartTs] as Number or Null) : null;

        if (!((snap[:todayHasBlueStart] as Boolean) || false)) {
            blueTs = null;
        }
        if (!((snap[:todayHasGoldenStart] as Boolean) || false)) {
            goldenTs = null;
        }

        var blueText = _formatRemaining(nowTs, blueTs);
        var goldenText = _formatRemaining(nowTs, goldenTs);

        var yLabel = safeBottom - 42;
        var yValue = safeBottom - 20;
        var leftCenterX = safeLeft + (safeW * 0.30);
        var rightCenterX = safeLeft + (safeW * 0.70);

        var blueLabel = "Blue";
        var goldLabel = "Golden";
        var blueLabelW = dc.getTextWidthInPixels(blueLabel, fontLabel);
        var goldLabelW = dc.getTextWidthInPixels(goldLabel, fontLabel);
        var blueValueW = dc.getTextWidthInPixels(blueText, fontValue);
        var goldValueW = dc.getTextWidthInPixels(goldenText, fontValue);

        var blueX = _clamp(leftCenterX, safeLeft + (blueLabelW / 2), safeRight - (blueLabelW / 2));
        var goldX = _clamp(rightCenterX, safeLeft + (goldLabelW / 2), safeRight - (goldLabelW / 2));
        var blueValueX = _clamp(leftCenterX, safeLeft + (blueValueW / 2), safeRight - (blueValueW / 2));
        var goldValueX = _clamp(rightCenterX, safeLeft + (goldValueW / 2), safeRight - (goldValueW / 2));

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(blueX, yLabel, fontLabel, blueLabel, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(blueValueX, yValue, fontValue, blueText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(goldX, yLabel, fontLabel, goldLabel, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(goldValueX, yValue, fontValue, goldenText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((w / 2) - 1, yLabel - 2, 2, 26);
        
        // L2 验证：显示版本号
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 5, h - 15, Graphics.FONT_XTINY, "v1.1", Graphics.TEXT_JUSTIFY_RIGHT);

        if (DEBUG_ENABLED) {
            System.println(Lang.format(
                "[Layout] w=$1$ h=$2$ safeL=$3$ safeR=$4$ safeB=$5$ blueW=$6$ goldW=$7$ blueX=$8$ goldX=$9$",
                [w, h, safeLeft, safeRight, safeBottom, blueLabelW, goldLabelW, blueX, goldX]
            ));
        }
    }

    function _formatRemaining(nowTs as Number, targetTs as Number or Null) as String {
        if (targetTs == null) {
            return "--:--";
        }

        var remainingSec = (targetTs as Number) - nowTs;
        if (remainingSec <= 0) {
            return "00:00";
        }

        var totalMin = Math.floor(remainingSec / 60.0);
        var hh = Math.floor(totalMin / 60.0);
        var mm = totalMin - (hh * 60);
        return Lang.format("$1$:$2$", [(hh.toNumber()).format("%02d"), (mm.toNumber()).format("%02d")]);
    }

    function _drawDebug(dc as Dc, snap as Lang.Dictionary, fix as Lang.Dictionary or Null) as Void {
        var mode = snap[:mode] as String;
        var altText = "alt=--";
        if (snap[:altDeg] != null) {
            altText = Lang.format("alt=$1$", [_round1(snap[:altDeg] as Number)]);
        }

        var gText = Lang.format("g=$1$", [_fmtDbgTs(snap[:nextGoldenStartTs] as Number or Null)]);
        var bText = Lang.format("b=$1$", [_fmtDbgTs(snap[:nextBlueStartTs] as Number or Null)]);
        var dText = (snap[:dbgDeltaMin] == null)
            ? "d=--m"
            : Lang.format("d=$1$m", [snap[:dbgDeltaMin]]);
        var locText = (fix == null) ? "loc=0" : "loc=1";
        var pad = 6;
        var w = dc.getWidth();
        var h = dc.getHeight();
        var insets = _getSafeInsets(dc);
        var safeLeft = (insets[:left] as Number) + pad;
        var safeRight = w - (insets[:right] as Number) - pad;
        var safeBottom = h - (insets[:bottom] as Number) - pad;
        var safeW = safeRight - safeLeft;
        var rightCenterX = safeLeft + (safeW * 0.70);
        var goldLabelW = dc.getTextWidthInPixels("GOLDEN", Graphics.FONT_TINY);
        var goldX = _clamp(rightCenterX, safeLeft + (goldLabelW / 2), safeRight - (goldLabelW / 2));

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 4, Graphics.FONT_XTINY, mode, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 18, Graphics.FONT_XTINY, altText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 32, Graphics.FONT_XTINY, gText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 46, Graphics.FONT_XTINY, bText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 60, Graphics.FONT_XTINY, dText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 74, Graphics.FONT_XTINY, locText, Graphics.TEXT_JUSTIFY_LEFT);
        System.println(Lang.format(
            "[DebugSafe] safeL=$1$ safeR=$2$ safeB=$3$ goldW=$4$ goldX=$5$",
            [safeLeft, safeRight, safeBottom, goldLabelW, goldX]
        ));
        
        // 🔍 状态快照（用于自动验证）
        System.println(Lang.format(
            "[SNAPSHOT] buildId=v1.1 blueCountdown=$1$ goldenCountdown=$2$ blueTs=$3$ goldenTs=$4$",
            [bText, gText, snap[:nextBlueStartTs], snap[:nextGoldenStartTs]]
        ));
    }

    function _fmtDbgTs(ts as Number or Null) as String {
        if (ts == null) {
            return "--:--";
        }
        var info = Time.Gregorian.info(new Time.Moment(ts as Number), Time.FORMAT_SHORT);
        return Lang.format(
            "$1$:$2$",
            [
                (info[:hour] as Number).format("%02d"),
                (info[:min] as Number).format("%02d")
            ]
        );
    }

    function _getSafeInsets(dc as Dc) as Lang.Dictionary {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var settings = System.getDeviceSettings();
        if (settings != null && settings.screenShape == System.SCREEN_SHAPE_ROUND) {
            var inset = ((w - (w * 0.70710678)) / 2).toNumber();
            return {
                :left => inset,
                :top => inset,
                :right => inset,
                :bottom => inset
            };
        }
        return {
            :left => 0,
            :top => 0,
            :right => 0,
            :bottom => 0
        };
    }

    function _clamp(x, minV, maxV) {
        if (x < minV) {
            return minV;
        }
        if (x > maxV) {
            return maxV;
        }
        return x;
    }

    function _round1(v as Number) as String {
        return v.format("%.1f");
    }
}
