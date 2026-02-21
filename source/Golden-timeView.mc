import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class GoldenTimeView extends WatchUi.WatchFace {
    const DEBUG_ENABLED = false;
    const SOFT_STALE_MAX_AGE_SEC = 259200;
    const HARD_STALE_MAX_AGE_SEC = 604800;
    const POSITION_LOST_Y_OFFSET = 24;
    const COLOR_WHITE = 0xFFFFFF;
    const COLOR_BLACK = 0x000000;
    const COLOR_BLUE  = 0x8094B5;
    const COLOR_GOLD  = 0xFFAA00;

    var _locationService as LocationService;
    var _sunAltService as SunAltService;
    var _phase as String;
    var _bgGolden as WatchUi.BitmapResource;
    var _bgNight as WatchUi.BitmapResource;
    var _bgDay as WatchUi.BitmapResource;
    var _moonNight as WatchUi.BitmapResource;
    var _sunGolden as WatchUi.BitmapResource;
    var _sunDay as WatchUi.BitmapResource;

    function initialize() {
        WatchFace.initialize();
        _locationService = new LocationService();
        _sunAltService = new SunAltService();
        _phase = "DAY";
        _bgGolden = WatchUi.loadResource(Rez.Drawables.bg_golden) as WatchUi.BitmapResource;
        _bgNight = WatchUi.loadResource(Rez.Drawables.bg_night) as WatchUi.BitmapResource;
        _bgDay = WatchUi.loadResource(Rez.Drawables.bg_day) as WatchUi.BitmapResource;
        _moonNight = WatchUi.loadResource(Rez.Drawables.moon_night) as WatchUi.BitmapResource;
        _sunGolden = WatchUi.loadResource(Rez.Drawables.sun_golden) as WatchUi.BitmapResource;
        _sunDay = WatchUi.loadResource(Rez.Drawables.sun_day) as WatchUi.BitmapResource;
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
        var hardStale = _isHardStale(nowTs);
        var softStale = (!hardStale) && _isSoftStale(nowTs);

        _sunAltService.updateIfNeeded(nowTs, hardStale ? null : fix);
        var snap = _sunAltService.getSnapshot(nowTs);
        var phase = _getPhase(nowTs, snap);
        if (hardStale) {
            phase = "DAY";
        }
        _phase = phase;

        if (DEBUG_ENABLED) {
            System.println(Lang.format("[PHASE_BYTES] phaseText=$1$", [Lang.format("$1$", [_phase])]));
            System.println(Lang.format("[PHASE_TOSTR] phaseToString=$1$", [_phase.toString()]));
            System.println("[SNAP_KEYS] [:mode, :hasFix, :altDeg, :nextGoldenStartTs, :nextBlueStartTs, :todayHasGoldenStart, :todayHasBlueStart, :dayStartUtc, :windowStartTs, :windowEndTs, :dbgDeltaMin, :morningBlueStartTs, :morningBlueEndTs, :morningGoldenStartTs, :morningGoldenEndTs, :eveningGoldenStartTs, :eveningGoldenEndTs, :eveningBlueStartTs, :eveningBlueEndTs]");
            System.println(Lang.format("[SNAP_FULL] $1$", [snap.toString()]));
            System.println(Lang.format(
                "[SNAP_MAP] phase=$1$ mode=$2$ hasFix=$3$ altDeg=$4$ nextGoldenStartTs=$5$ nextBlueStartTs=$6$ todayHasGoldenStart=$7$ todayHasBlueStart=$8$ dayStartUtc=$9$ windowStartTs=$10$ windowEndTs=$11$ dbgDeltaMin=$12$ morningBlueStartTs=$13$ morningBlueEndTs=$14$ morningGoldenStartTs=$15$ morningGoldenEndTs=$16$ eveningGoldenStartTs=$17$ eveningGoldenEndTs=$18$ eveningBlueStartTs=$19$ eveningBlueEndTs=$20$",
                [
                    phase,
                    snap[:mode],
                    snap[:hasFix],
                    snap[:altDeg],
                    snap[:nextGoldenStartTs],
                    snap[:nextBlueStartTs],
                    snap[:todayHasGoldenStart],
                    snap[:todayHasBlueStart],
                    snap[:dayStartUtc],
                    snap[:windowStartTs],
                    snap[:windowEndTs],
                    snap[:dbgDeltaMin],
                    snap[:morningBlueStartTs],
                    snap[:morningBlueEndTs],
                    snap[:morningGoldenStartTs],
                    snap[:morningGoldenEndTs],
                    snap[:eveningGoldenStartTs],
                    snap[:eveningGoldenEndTs],
                    snap[:eveningBlueStartTs],
                    snap[:eveningBlueEndTs]
                ]
            ));
            var morningBlueStartTs = snap[:morningBlueStartTs] as Number or Null;
            var morningGoldenEndTs = snap[:morningGoldenEndTs] as Number or Null;
            var eveningGoldenStartTs = snap[:eveningGoldenStartTs] as Number or Null;
            var eveningBlueEndTs = snap[:eveningBlueEndTs] as Number or Null;
            if (morningBlueStartTs != null && morningGoldenEndTs != null && eveningGoldenStartTs != null && eveningBlueEndTs != null) {
                var morningProbe = ((morningBlueStartTs as Number) + (((morningGoldenEndTs as Number) - (morningBlueStartTs as Number)) / 2.0)).toNumber();
                var dayProbe = ((morningGoldenEndTs as Number) + (((eveningGoldenStartTs as Number) - (morningGoldenEndTs as Number)) / 2.0)).toNumber();
                var eveningProbe = ((eveningGoldenStartTs as Number) + (((eveningBlueEndTs as Number) - (eveningGoldenStartTs as Number)) / 2.0)).toNumber();
                var nightProbe = (morningBlueStartTs as Number) - 60;
                System.println(Lang.format(
                    "[PHASE_TEST] morningProbe=$1$=>$2$ dayProbe=$3$=>$4$ eveningProbe=$5$=>$6$ nightProbe=$7$=>$8$",
                    [
                        morningProbe,
                        _getPhase(morningProbe, snap),
                        dayProbe,
                        _getPhase(dayProbe, snap),
                        eveningProbe,
                        _getPhase(eveningProbe, snap),
                        nightProbe,
                        _getPhase(nightProbe, snap)
                    ]
                ));
            }
            var phaseTestSnap = {
                :hasFix => true,
                :mode => "DAY",
                :morningBlueStartTs => 100,
                :morningGoldenEndTs => 200,
                :eveningGoldenStartTs => 500,
                :eveningBlueEndTs => 600
            };
            System.println(Lang.format(
                "[PHASE_TEST_MOCK] morning=$1$ day=$2$ evening=$3$ night=$4$",
                [
                    _getPhase(150, phaseTestSnap),
                    _getPhase(300, phaseTestSnap),
                    _getPhase(550, phaseTestSnap),
                    _getPhase(50, phaseTestSnap)
                ]
            ));
        }

        _drawBackground(dc);
        _drawTime(dc, w, h);
        _drawDate(dc, nowMoment, w, h);
        _drawDualCountdown(dc, snap, nowTs, w, h, hardStale, softStale);
        _drawCelestial(dc);

        var hasFix = snap[:hasFix] as Boolean;
        var blueTs = hasFix ? (snap[:nextBlueStartTs] as Number or Null) : null;
        var goldenTs = hasFix ? (snap[:nextGoldenStartTs] as Number or Null) : null;
        if (!((snap[:todayHasBlueStart] as Boolean) || false)) {
            blueTs = null;
        }
        if (!((snap[:todayHasGoldenStart] as Boolean) || false)) {
            goldenTs = null;
        }
        var blueText = Lang.format("b=$1$", [_formatStartTime(blueTs)]);
        var goldenText = Lang.format("g=$1$", [_formatStartTime(goldenTs)]);
        if (DEBUG_ENABLED) {
            System.println(Lang.format("[BG_PICK] phase=$1$", [_phase]));
            System.println(Lang.format(
                "[SNAPSHOT] buildId=v1.1 phase=$1$ dayStartUtc=$2$ windowStartTs=$3$ windowEndTs=$4$ blueCountdown=$5$ goldenCountdown=$6$ blueTs=$7$ goldenTs=$8$",
                [phase, snap[:dayStartUtc], snap[:windowStartTs], snap[:windowEndTs], blueText, goldenText, snap[:nextBlueStartTs], snap[:nextGoldenStartTs]]
            ));
        }

    }

    function _drawBackground(dc as Dc) as Void {
        var bmp = _getBackgroundBitmap(_phase);
        dc.drawBitmap(0, 0, bmp);
    }

    function _getBackgroundBitmap(phase as String) as WatchUi.BitmapResource {
        if (phase != null && phase.equals("TWILIGHT")) {
            return _bgGolden;
        }
        if (phase != null && phase.equals("NIGHT")) {
            return _bgNight;
        }
        return _bgDay;
    }

    function _drawTime(dc as Dc, w as Number, h as Number) as Void {
        var clock = System.getClockTime();
        var hh = clock.hour.format("%02d");
        var mm = clock.min.format("%02d");
        var text = Lang.format("$1$:$2$", [hh, mm]);

        var isDay = (_phase != null) && (_phase as String).equals("DAY");
        var mainColor;
        if (isDay) {
            mainColor = 0x000000;
        } else {
            mainColor = 0xFFFFFF;
        }
        if (DEBUG_ENABLED) {
            System.println(Lang.format("[COLOR_MAIN] func=_drawTime phase=$1$ mainColor=$2$ cond=$3$", [_phase, mainColor, isDay]));
        }
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            73,
            Graphics.FONT_NUMBER_HOT,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function _drawDate(dc as Dc, nowMoment as Time.Moment, w as Number, h as Number) as Void {
        var info = Time.Gregorian.info(nowMoment, Time.FORMAT_SHORT);
        var dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        var monthNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        var dowRaw = info[:day_of_week] as Number;
        var dowIdx = ((dowRaw - 1) % 7).toNumber();
        if (dowIdx < 0) {
            dowIdx += 7;
        }
        var monthIdx = (info[:month] as Number) - 1;
        var dateText = Lang.format("$1$ | $2$ $3$", [
            dayNames[dowIdx],
            monthNames[monthIdx],
            (info[:day] as Number).format("%02d")
        ]);
        var isDay = (_phase != null) && (_phase as String).equals("DAY");
        var mainColor;
        if (isDay) {
            mainColor = 0x000000;
        } else {
            mainColor = 0xFFFFFF;
        }
        if (DEBUG_ENABLED) {
            System.println(Lang.format("[COLOR_MAIN] func=_drawDate phase=$1$ mainColor=$2$ cond=$3$", [_phase, mainColor, isDay]));
        }
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            31,
            Graphics.FONT_TINY,
            dateText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function _getCelestialBitmap(phase as String) as WatchUi.BitmapResource {
        if (phase != null && phase.equals("NIGHT")) {
            return _moonNight;
        }
        if (phase != null && phase.equals("TWILIGHT")) {
            return _sunGolden;
        }
        return _sunDay;
    }

    function _drawCelestial(dc as Dc) as Void {
        var bmp = _getCelestialBitmap(_phase);
        dc.drawBitmap(0, 0, bmp);
    }

    function _drawDualCountdown(dc as Dc, snap as Lang.Dictionary, nowTs as Number, w as Number, h as Number, hardStale as Boolean, softStale as Boolean) as Void {
        var hasFix = snap[:hasFix] as Boolean;
        var pad = 6;
        var fontLabel = Graphics.FONT_XTINY;
        var fontValue = Graphics.FONT_MEDIUM;
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

        var morningBlueStartTs = snap[:morningBlueStartTs] as Number or Null;
        var morningBlueEndTs = snap[:morningBlueEndTs] as Number or Null;
        var eveningBlueStartTs = snap[:eveningBlueStartTs] as Number or Null;
        var eveningBlueEndTs = snap[:eveningBlueEndTs] as Number or Null;
        var morningGoldenStartTs = snap[:morningGoldenStartTs] as Number or Null;
        var morningGoldenEndTs = snap[:morningGoldenEndTs] as Number or Null;
        var eveningGoldenStartTs = snap[:eveningGoldenStartTs] as Number or Null;
        var eveningGoldenEndTs = snap[:eveningGoldenEndTs] as Number or Null;

        var isBlueNow =
            (morningBlueStartTs != null && morningBlueEndTs != null
                && nowTs >= (morningBlueStartTs as Number) && nowTs < (morningBlueEndTs as Number))
            || (eveningBlueStartTs != null && eveningBlueEndTs != null
                && nowTs >= (eveningBlueStartTs as Number) && nowTs < (eveningBlueEndTs as Number));

        var isGoldenNow =
            (morningGoldenStartTs != null && morningGoldenEndTs != null
                && nowTs >= (morningGoldenStartTs as Number) && nowTs < (morningGoldenEndTs as Number))
            || (eveningGoldenStartTs != null && eveningGoldenEndTs != null
                && nowTs >= (eveningGoldenStartTs as Number) && nowTs < (eveningGoldenEndTs as Number));
        isBlueNow = isBlueNow && (blueTs != null);
        isGoldenNow = isGoldenNow && (goldenTs != null);

        // Shared boundary uses left-closed/right-open, but keep a hard rule for abnormal data.
        if (isBlueNow && isGoldenNow) {
            isBlueNow = false;
        }

        var blueText = _formatStartTime(blueTs);
        var goldenText = _formatStartTime(goldenTs);
        if (isBlueNow) {
            blueText = "NOW";
        }
        if (isGoldenNow) {
            goldenText = "NOW";
        }
        if (hardStale) {
            blueText = "--:--";
            goldenText = "--:--";
        }

        var blockCenterY = 180;
        var yLabel = blockCenterY - 12;
        var yValue = blockCenterY + 12;
        var leftCenterX = 80;
        var rightCenterX = 160;

        var blueLabel = "BLUE";
        var goldLabel = "GOLDEN";
        var blueLabelW = dc.getTextWidthInPixels(blueLabel, fontLabel);
        var goldLabelW = dc.getTextWidthInPixels(goldLabel, fontLabel);
        var blueValueW = dc.getTextWidthInPixels(blueText, fontValue);
        var goldValueW = dc.getTextWidthInPixels(goldenText, fontValue);

        var blueX = _clamp(leftCenterX, safeLeft + (blueLabelW / 2), safeRight - (blueLabelW / 2));
        var goldX = _clamp(rightCenterX, safeLeft + (goldLabelW / 2), safeRight - (goldLabelW / 2));
        var blueValueX = _clamp(leftCenterX, safeLeft + (blueValueW / 2), safeRight - (blueValueW / 2));
        var goldValueX = _clamp(rightCenterX, safeLeft + (goldValueW / 2), safeRight - (goldValueW / 2));

        dc.setColor(COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(blueX, yLabel, fontLabel, blueLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(blueValueX, yValue, fontValue, blueText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(COLOR_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(goldX, yLabel, fontLabel, goldLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(goldValueX, yValue, fontValue, goldenText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (hardStale) {
            dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, yValue + POSITION_LOST_Y_OFFSET, Graphics.FONT_XTINY, "Enable GPS Once", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (softStale) {
            dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, yValue + POSITION_LOST_Y_OFFSET, Graphics.FONT_XTINY, "Update GPS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

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

    function _isHardStale(nowTs as Number) as Boolean {
        var fix = _locationService.getLastFix();
        var fixTs = null;
        var ageSec = null;
        var hardStale = true;

        if (fix != null && fix[:ts] != null) {
            fixTs = fix[:ts] as Number;
            ageSec = nowTs - (fixTs as Number);
            hardStale = (ageSec as Number) > HARD_STALE_MAX_AGE_SEC;
        }

        if (DEBUG_ENABLED) {
            System.println(Lang.format("[POS_HARD_STALE] nowTs=$1$ hardStale=$2$ fixTs=$3$ ageSec=$4$", [nowTs, hardStale, fixTs, ageSec]));
        }

        return hardStale;
    }

    function _isSoftStale(nowTs as Number) as Boolean {
        var fix = _locationService.getLastFix();
        if (fix == null || fix[:ts] == null) {
            return false;
        }

        var ageSec = nowTs - (fix[:ts] as Number);
        var softStale = (ageSec > SOFT_STALE_MAX_AGE_SEC) && (ageSec <= HARD_STALE_MAX_AGE_SEC);
        if (DEBUG_ENABLED) {
            System.println(Lang.format("[POS_SOFT_STALE] nowTs=$1$ softStale=$2$ ageSec=$3$", [nowTs, softStale, ageSec]));
        }
        return softStale;
    }

    function _formatStartTime(targetTs as Number or Null) as String {
        if (targetTs == null) {
            return "--:--";
        }

        var info = Time.Gregorian.info(new Time.Moment(targetTs as Number), Time.FORMAT_SHORT);
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

    function _getPhase(nowTs as Number, snap as Lang.Dictionary) as String {
        var hasFix = ((snap[:hasFix] as Boolean) || false);
        if (!hasFix) {
            return "DAY";
        }

        var morningBlueStartTs = snap[:morningBlueStartTs] as Number or Null;
        var morningGoldenEndTs = snap[:morningGoldenEndTs] as Number or Null;
        var eveningGoldenStartTs = snap[:eveningGoldenStartTs] as Number or Null;
        var eveningBlueEndTs = snap[:eveningBlueEndTs] as Number or Null;
        if (morningBlueStartTs == null || morningGoldenEndTs == null || eveningGoldenStartTs == null || eveningBlueEndTs == null) {
            return _phaseFromMode(snap[:mode] as String or Null);
        }

        if ((nowTs >= (morningBlueStartTs as Number) && nowTs < (morningGoldenEndTs as Number))
            || (nowTs >= (eveningGoldenStartTs as Number) && nowTs < (eveningBlueEndTs as Number))) {
            return "TWILIGHT";
        }
        if (nowTs >= (morningGoldenEndTs as Number) && nowTs < (eveningGoldenStartTs as Number)) {
            return "DAY";
        }
        return "NIGHT";
    }

    function _phaseFromMode(mode as String or Null) as String {
        if (mode != null && mode.equals("--")) {
            return "NIGHT";
        }
        if (mode != null && (mode.equals("GOLDEN") || mode.equals("BLUE"))) {
            return "TWILIGHT";
        }
        if (mode != null && mode.equals("NIGHT")) {
            return "NIGHT";
        }
        return "DAY";
    }

}
