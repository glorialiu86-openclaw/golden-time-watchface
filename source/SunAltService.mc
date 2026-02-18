import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

class SunAltService {
    const DEBUG_LOG = false;
    const LOC_CHANGE_THRESHOLD_DEG = 0.01;
    const COARSE_STEP_SEC = 1800;
    const BISECT_TOLERANCE_SEC = 1;
    const ALT_ZERO_EPS_DEG = 0.01;

    var _hasFix as Boolean;
    var _lastFix as Lang.Dictionary or Null;
    var _lastComputeSlotKey as String or Null;
    var _cachedEvents as Array<Lang.Dictionary>;
    var _todayHasGoldenStart as Boolean;
    var _todayHasBlueStart as Boolean;
    var _warnedInRecompute as Boolean;

    function initialize() {
        _hasFix = false;
        _lastFix = null;
        _lastComputeSlotKey = null;
        _cachedEvents = [];
        _todayHasGoldenStart = false;
        _todayHasBlueStart = false;
        _warnedInRecompute = false;
    }

    function updateIfNeeded(nowTs as Number, fix as Lang.Dictionary or Null) as Void {
        if (fix == null || fix[:lat] == null || fix[:lon] == null) {
            _hasFix = false;
            _lastFix = null;
            _cachedEvents = [];
            _todayHasGoldenStart = false;
            _todayHasBlueStart = false;
            return;
        }

        _hasFix = true;

        var needRecompute = false;
        var slotKey = _getLocalSlotKey();

        if (_lastComputeSlotKey == null) {
            needRecompute = true;
        } else if (_lastComputeSlotKey != slotKey) {
            needRecompute = true;
        } else if (_lastFix == null) {
            needRecompute = true;
        } else {
            var dLat = _abs((fix[:lat] as Number) - (_lastFix[:lat] as Number));
            var dLon = _abs((fix[:lon] as Number) - (_lastFix[:lon] as Number));
            if (dLat > LOC_CHANGE_THRESHOLD_DEG || dLon > LOC_CHANGE_THRESHOLD_DEG) {
                needRecompute = true;
            }
        }

        if (!needRecompute) {
            return;
        }

        _lastFix = {
            :lat => fix[:lat],
            :lon => fix[:lon],
            :ts => fix[:ts]
        };
        _lastComputeSlotKey = slotKey;

        var lat = fix[:lat] as Number;
        var lon = fix[:lon] as Number;
        _warnedInRecompute = false;
        var windowStartTs = _getSlotStartTs(nowTs);

        var eventData = _computeWindowEvents(windowStartTs, lat, lon);
        _cachedEvents = eventData[:events] as Array<Lang.Dictionary>;
        _todayHasGoldenStart = _hasEventType(_cachedEvents, "GOLDEN_START");
        _todayHasBlueStart = _hasEventType(_cachedEvents, "BLUE_START");

        var nextGoldenStart = _findNextEventTs(_cachedEvents, nowTs, "GOLDEN_START");
        var nextBlueStart = _findNextEventTs(_cachedEvents, nowTs, "BLUE_START");
        var dMinText = "--";
        if (nextGoldenStart != null && nextBlueStart != null) {
            dMinText = (((((nextGoldenStart as Number) - (nextBlueStart as Number)) / 60).toNumber())).toString();
        }

        if (DEBUG_LOG) {
            System.println(Lang.format(
                "[SunAltService] day=$1$ lat=$2$ lon=$3$ nextG=$4$ nextB=$5$ dMin=$6$ todayG=$7$ todayB=$8$",
                [
                    slotKey,
                    _fmt1(lat),
                    _fmt1(lon),
                    _fmtTs(nextGoldenStart),
                    _fmtTs(nextBlueStart),
                    dMinText,
                    (_todayHasGoldenStart ? "1" : "0"),
                    (_todayHasBlueStart ? "1" : "0")
                ]
            ));
            var altNow = _solarAltitudeDeg(nowTs, lat, lon);
            var altPlus5 = _solarAltitudeDeg(nowTs + COARSE_STEP_SEC, lat, lon);
            var dAlt = (altNow == null || altPlus5 == null) ? null : ((altPlus5 as Number) - (altNow as Number));
            System.println(Lang.format(
                "[AltDelta] altNow=$1$ alt+5m=$2$ dAlt=$3$deg",
                [_fmtAlt(altNow), _fmtAlt(altPlus5), _fmtAlt(dAlt)]
            ));
        }
    }

    function getSnapshot(nowTs as Number) as Lang.Dictionary {
        if (!_hasFix || _lastFix == null) {
            return {
                :hasFix => false,
                :mode => "--",
                :altDeg => null,
                :nextGoldenStartTs => null,
                :nextBlueStartTs => null,
                :todayHasGoldenStart => false,
                :todayHasBlueStart => false
            };
        }

        var lat = _lastFix[:lat] as Number;
        var lon = _lastFix[:lon] as Number;
        var alt = _solarAltitudeDeg(nowTs, lat, lon);
        var mode = _modeFromAltitude(alt);

        var nextGolden = _findNextEventTs(_cachedEvents, nowTs, "GOLDEN_START");
        var nextBlue = _findNextEventTs(_cachedEvents, nowTs, "BLUE_START");

        return {
            :hasFix => true,
            :mode => mode,
            :altDeg => alt,
            :nextGoldenStartTs => nextGolden,
            :nextBlueStartTs => nextBlue,
            :todayHasGoldenStart => _todayHasGoldenStart,
            :todayHasBlueStart => _todayHasBlueStart,
            :dbgDeltaMin => ((nextGolden != null && nextBlue != null) ? (((nextGolden as Number) - (nextBlue as Number)) / 60).toNumber() : null)
        };
    }

    function _computeWindowEvents(startTs as Number, lat as Number, lon as Number) as Lang.Dictionary {
        var dayEndTs = startTs + 86400;
        var events = [] as Array<Lang.Dictionary>;
        var morningBlueStart = null;
        var morningGoldenStart = null;
        var morningGoldenEnd = null;
        var eveningGoldenStart = null;
        var eveningGoldenEnd = null;
        var eveningBlueEnd = null;

        var t0 = startTs;
        var alt0 = _solarAltitudeDeg(t0, lat, lon);
        while (t0 < dayEndTs) {
            var t1 = t0 + COARSE_STEP_SEC;
            if (t1 > dayEndTs) {
                t1 = dayEndTs;
            }

            var alt1 = _solarAltitudeDeg(t1, lat, lon);
            if (alt0 != null && alt1 != null && !_isNaN(alt0) && !_isNaN(alt1)) {
                if (morningBlueStart == null && _isCrossing(alt0, alt1, -6.0, true)) {
                    morningBlueStart = _bisectRoot(t0, t1, lat, lon, -6.0);
                }
                if (morningGoldenStart == null && _isCrossing(alt0, alt1, 0.0, true)) {
                    morningGoldenStart = _bisectRoot(t0, t1, lat, lon, 0.0);
                }
                if (morningGoldenEnd == null && _isCrossing(alt0, alt1, 6.0, true)) {
                    morningGoldenEnd = _bisectRoot(t0, t1, lat, lon, 6.0);
                }
                if (eveningGoldenStart == null && _isCrossing(alt0, alt1, 6.0, false)) {
                    eveningGoldenStart = _bisectRoot(t0, t1, lat, lon, 6.0);
                }
                if (eveningGoldenEnd == null && _isCrossing(alt0, alt1, 0.0, false)) {
                    eveningGoldenEnd = _bisectRoot(t0, t1, lat, lon, 0.0);
                }
                if (eveningBlueEnd == null && _isCrossing(alt0, alt1, -6.0, false)) {
                    eveningBlueEnd = _bisectRoot(t0, t1, lat, lon, -6.0);
                }
            }

            if (morningBlueStart != null
                && morningGoldenStart != null
                && morningGoldenEnd != null
                && eveningGoldenStart != null
                && eveningGoldenEnd != null
                && eveningBlueEnd != null) {
                break;
            }

            t0 = t1;
            alt0 = alt1;
        }

        if (morningBlueStart != null) {
            events.add({ :ts => morningBlueStart, :type => "BLUE_START" });
        }
        if (morningGoldenStart != null) {
            events.add({ :ts => morningGoldenStart, :type => "GOLDEN_START" });
        }
        if (morningGoldenEnd != null) {
            events.add({ :ts => morningGoldenEnd, :type => "GOLDEN_END" });
        }
        if (eveningGoldenStart != null) {
            events.add({ :ts => eveningGoldenStart, :type => "GOLDEN_START" });
        }
        if (eveningGoldenEnd != null) {
            events.add({ :ts => eveningGoldenEnd, :type => "GOLDEN_END" });
        }
        if (eveningBlueEnd != null) {
            events.add({ :ts => eveningBlueEnd, :type => "BLUE_END" });
        }

        return {
            :events => _sortEventsByTs(events)
        };
    }

    function _findNextEventTs(events as Array<Lang.Dictionary>, nowTs as Number, typeName as String) as Number or Null {
        for (var i = 0; i < events.size(); i += 1) {
            var e = events[i];
            if (e[:type] == typeName && (e[:ts] as Number) > nowTs) {
                return e[:ts] as Number;
            }
        }
        return null;
    }

    function _hasEventType(events as Array<Lang.Dictionary>, typeName as String) as Boolean {
        for (var i = 0; i < events.size(); i += 1) {
            if (events[i][:type] == typeName) {
                return true;
            }
        }
        return false;
    }

    function _sortEventsByTs(events as Array<Lang.Dictionary>) as Array<Lang.Dictionary> {
        var out = [] as Array<Lang.Dictionary>;
        for (var i = 0; i < events.size(); i += 1) {
            out.add(events[i]);
        }

        var n = out.size();
        for (var p = 0; p < n; p += 1) {
            for (var q = 0; q < (n - 1 - p); q += 1) {
                var tA = out[q][:ts] as Number;
                var tB = out[q + 1][:ts] as Number;
                if (tA > tB) {
                    var tmp = out[q];
                    out[q] = out[q + 1];
                    out[q + 1] = tmp;
                }
            }
        }
        return out;
    }


    function _isCrossing(alt0, alt1, thresholdAltDeg, rising) {
        if (rising) {
            return alt0 < thresholdAltDeg && alt1 >= thresholdAltDeg;
        }
        return alt0 > thresholdAltDeg && alt1 <= thresholdAltDeg;
    }

    function _bisectRoot(loTs, hiTs, lat, lon, threshold) {
        var lo = loTs;
        var hi = hiTs;
        var altLo = _solarAltitudeDeg(lo, lat, lon);
        var altHi = _solarAltitudeDeg(hi, lat, lon);
        if (altLo == null || altHi == null || _isNaN(altLo) || _isNaN(altHi)) {
            return null;
        }
        var fLo = (altLo as Number) - threshold;
        var fHi = (altHi as Number) - threshold;
        if (fLo == null || fHi == null || _isNaN(fLo) || _isNaN(fHi)) {
            return null;
        }

        if (fLo == 0) {
            return lo;
        }
        if (fHi == 0) {
            return hi;
        }
        if ((fLo > 0 && fHi > 0) || (fLo < 0 && fHi < 0)) {
            return null;
        }

        while ((hi - lo) > BISECT_TOLERANCE_SEC) {
            var mid = (lo + hi) / 2;
            var altMid = _solarAltitudeDeg(mid, lat, lon);
            if (altMid == null || _isNaN(altMid)) {
                return null;
            }
            var fMid = (altMid as Number) - threshold;
            if (_isNaN(fMid)) {
                return null;
            }
            if (fMid == 0) {
                return mid;
            }

            if ((fLo < 0 && fMid > 0) || (fLo > 0 && fMid < 0)) {
                hi = mid;
                fHi = fMid;
            } else {
                lo = mid;
                fLo = fMid;
            }
        }

        return hi;
    }

    function _solarAltitudeDeg(ts, latDeg, lonDeg) {
        // NOAA-style approximate solar position for solar-center altitude.
        var jd = (ts / 86400.0) + 2440587.5;
        var jc = (jd - 2451545.0) / 36525.0;

        var meanLong = _normalizeDeg(280.46646 + jc * (36000.76983 + jc * 0.0003032));
        var meanAnom = _normalizeDeg(357.52911 + jc * (35999.05029 - 0.0001537 * jc));
        var omega = 125.04 - 1934.136 * jc;

        var mRad = _degToRad(meanAnom);
        var center = Math.sin(mRad) * (1.914602 - jc * (0.004817 + 0.000014 * jc))
            + Math.sin(2.0 * mRad) * (0.019993 - 0.000101 * jc)
            + Math.sin(3.0 * mRad) * 0.000289;

        var trueLong = meanLong + center;
        var eclipLong = trueLong - 0.00569 - 0.00478 * Math.sin(_degToRad(omega));

        var obliqMean = 23.0 + (26.0 + ((21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))) / 60.0)) / 60.0;
        var obliqCorr = obliqMean + 0.00256 * Math.cos(_degToRad(omega));

        var eclipRad = _degToRad(eclipLong);
        var obliqRad = _degToRad(obliqCorr);

        var declRad = Math.asin(Math.sin(obliqRad) * Math.sin(eclipRad));
        var raDeg = _normalizeDeg(_radToDeg(Math.atan2(Math.cos(obliqRad) * Math.sin(eclipRad), Math.cos(eclipRad))));

        var gmst = _normalizeDeg(
            280.46061837
            + 360.98564736629 * (jd - 2451545.0)
            + 0.000387933 * jc * jc
            - (jc * jc * jc) / 38710000.0
        );

        var hourAngleDeg = _normalizeSignedDeg(gmst + lonDeg - raDeg);

        var latRad = _degToRad(latDeg);
        var haRad = _degToRad(hourAngleDeg);

        var sinAlt = Math.sin(latRad) * Math.sin(declRad)
            + Math.cos(latRad) * Math.cos(declRad) * Math.cos(haRad);
        var sinAltClamped = sinAlt;
        if (sinAltClamped > 1.0) {
            _warnSolarOnce(Lang.format("[SolarWarn] sinAlt clamp high=$1$", [sinAlt]));
            sinAltClamped = 1.0;
        } else if (sinAltClamped < -1.0) {
            _warnSolarOnce(Lang.format("[SolarWarn] sinAlt clamp low=$1$", [sinAlt]));
            sinAltClamped = -1.0;
        }

        var alt = _radToDeg(Math.asin(sinAltClamped));
        if (_isNaN(declRad) || _isNaN(raDeg) || _isNaN(gmst) || _isNaN(hourAngleDeg) || _isNaN(sinAlt) || _isNaN(alt)) {
            _warnSolarOnce(Lang.format(
                "[SolarWarn] NaN decl=$1$ ra=$2$ gmst=$3$ ha=$4$ sinAlt=$5$ alt=$6$",
                [declRad, raDeg, gmst, hourAngleDeg, sinAlt, alt]
            ));
            return null;
        }

        return alt;
    }

    function _modeFromAltitude(altDeg) {
        if (_abs(altDeg) < ALT_ZERO_EPS_DEG) {
            return "GOLDEN";
        }
        if (altDeg > 6.0) {
            return "DAY";
        }
        if (altDeg >= 0.0) {
            return "GOLDEN";
        }
        if (altDeg >= -6.0) {
            return "BLUE";
        }
        return "NIGHT";
    }

    function _getTodayWindow(nowTs) {
        var clock = System.getClockTime();
        var secondsSinceMidnight = (clock.hour * 3600) + (clock.min * 60) + clock.sec;
        var startTs = nowTs - secondsSinceMidnight;
        return {
            :startTs => startTs,
            :nextDayTs => startTs + 86400
        };
    }

    function _getLocalSlotKey() as String {
        var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var slot = ((info[:hour] as Number) < 12) ? "AM" : "PM";
        return Lang.format("$1$-$2$-$3$-$4$", [
            (info[:year] as Number).format("%04d"),
            (info[:month] as Number).format("%02d"),
            (info[:day] as Number).format("%02d"),
            slot
        ]);
    }

    function _getSlotStartTs(nowTs as Number) as Number {
        var dayWindow = _getTodayWindow(nowTs);
        var startTs = dayWindow[:startTs] as Number;
        var clock = System.getClockTime();
        if ((clock.hour as Number) >= 12) {
            return startTs + 43200;
        }
        return startTs;
    }

    function _degToRad(v) {
        return v * Math.PI / 180.0;
    }

    function _radToDeg(v) {
        return v * 180.0 / Math.PI;
    }

    function _normalizeDeg(v) {
        // Normalize degrees to [0, 360)
        // IMPORTANT: must use floor(v/360) to avoid collapsing to ~0.
        var turns = Math.floor(v / 360.0);
        var out = v - (turns * 360.0);
        while (out < 0) {
            out += 360.0;
        }
        while (out >= 360.0) {
            out -= 360.0;
        }
        return out;
    }

    function _normalizeSignedDeg(v) {
        var out = _normalizeDeg(v);
        if (out > 180.0) {
            out -= 360.0;
        }
        return out;
    }

    function _abs(v) {
        return (v < 0) ? -v : v;
    }

    function _fmt1(v) as String {
        return v.format("%.1f");
    }

    function _fmt2(v) as String {
        return v.format("%.2f");
    }

    function _fmtAlt(v) as String {
        if (v == null || _isNaN(v)) {
            return "--";
        }
        return _fmt1(v);
    }

    function _fmtTs(ts) as String {
        if (ts == null) {
            return "--";
        }
        var m = new Time.Moment(ts as Number);
        var info = Time.Gregorian.info(m, Time.FORMAT_SHORT);
        return Lang.format(
            "$1$ ($2$:$3$)",
            [
                ts,
                (info[:hour] as Number).format("%02d"),
                (info[:min] as Number).format("%02d")
            ]
        );
    }

    function _isNaN(x) {
        return x != x;
    }

    function _warnSolarOnce(msg as String) as Void {
        if (DEBUG_LOG && !_warnedInRecompute) {
            _warnedInRecompute = true;
            System.println(msg);
        }
    }

    function _logCross(kind as String, dir as String, threshold, t0, alt0, t1, alt1, rootTs, lat, lon) as Void {
        if (!DEBUG_LOG) {
            return;
        }
        var altAtRoot = _solarAltitudeDeg(rootTs, lat, lon);
        var errDeg = (altAtRoot == null || _isNaN(altAtRoot)) ? "--" : _fmt2((altAtRoot as Number) - threshold);
        System.println(Lang.format(
            "[Cross] kind=$1$ dir=$2$ thr=$3$ t0=$4$ alt0=$5$ t1=$6$ alt1=$7$ root=$8$ errDeg=$9$",
            [kind, dir, threshold, t0, _fmt1(alt0), t1, _fmt1(alt1), _fmtTs(rootTs), errDeg]
        ));
    }
}
