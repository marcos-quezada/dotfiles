// tst_threatwatch.qml — Qt Quick Test suite for threatwatch pure logic (Utils.qml).
// run: QT_QPA_PLATFORM=offscreen qmltestrunner -import <path>/utils -input tst_threatwatch.qml
//
// all tests exercise Utils.qml only — no Quickshell imports, no Wayland, no display required.

import QtQuick
import QtTest
import Utils

TestCase {
    name: "ThreatWatchUtils"

    // ── formatTimestamp ───────────────────────────────────────────────────────

    property Utils utils: Utils {}

    function test_formatTimestamp_basic() {
        compare(utils.formatTimestamp("2025-01-15T14:32:00Z"), "2025-01-15 14:32 UTC")
    }

    function test_formatTimestamp_empty() {
        compare(utils.formatTimestamp(""), "")
    }

    function test_formatTimestamp_midnight() {
        compare(utils.formatTimestamp("2025-06-01T00:00:00Z"), "2025-06-01 00:00 UTC")
    }

    // ── parseSummary ──────────────────────────────────────────────────────────

    function test_parseSummary_full() {
        var json = JSON.stringify({
            threat_level: "high",
            updated_at:   "2025-03-01T12:00:00Z",
            mapbox: { requests_this_month: 42, warn: true }
        })
        var r = utils.parseSummary(json)
        verify(r !== null,          "result should not be null")
        compare(r.level,            "high")
        compare(r.updatedAt,        "2025-03-01 12:00 UTC")
        compare(r.mapRequests,      42)
        compare(r.mapWarn,          true)
    }

    function test_parseSummary_minimal() {
        var r = utils.parseSummary('{"threat_level":"info"}')
        verify(r !== null)
        compare(r.level,       "info")
        compare(r.updatedAt,   "")
        compare(r.mapRequests, 0)
        compare(r.mapWarn,     false)
    }

    function test_parseSummary_invalid_json() {
        compare(utils.parseSummary("not json"), null)
    }

    function test_parseSummary_empty_string() {
        compare(utils.parseSummary(""), null)
    }

    function test_parseSummary_no_mapbox_key() {
        var r = utils.parseSummary('{"threat_level":"low"}')
        verify(r !== null)
        compare(r.mapRequests, 0)
        compare(r.mapWarn,     false)
    }

    // ── parsePins ─────────────────────────────────────────────────────────────

    function test_parsePins_valid_array() {
        var json = JSON.stringify([{type:"quake",x:100,y:200}])
        var result = utils.parsePins(json)
        verify(Array.isArray(result))
        compare(result.length, 1)
        compare(result[0].type, "quake")
    }

    function test_parsePins_empty_array() {
        var result = utils.parsePins("[]")
        verify(Array.isArray(result))
        compare(result.length, 0)
    }

    function test_parsePins_invalid_json() {
        compare(utils.parsePins("{partial"), null)
    }

    function test_parsePins_object_rejected() {
        // a JSON object (not array) should return null — partial write guard
        compare(utils.parsePins('{"type":"quake"}'), null)
    }

    // ── pinTypeLabel ──────────────────────────────────────────────────────────

    function test_pinTypeLabel_data() {
        return [
            { tag: "quake",     input: "quake",     expected: "Earthquake"           },
            { tag: "military",  input: "military",  expected: "Military aircraft"    },
            { tag: "emergency", input: "emergency", expected: "Emergency squawk"     },
            { tag: "gdacs",     input: "gdacs",     expected: "GDACS disaster alert" },
            { tag: "unknown",   input: "unknown",   expected: ""                     },
            { tag: "empty",     input: "",          expected: ""                     },
        ]
    }

    function test_pinTypeLabel(data) {
        compare(utils.pinTypeLabel(data.input), data.expected)
    }

    // ── levelColors ───────────────────────────────────────────────────────────

    function test_levelColors_all_levels_present() {
        var levels = ["critical", "high", "medium", "low", "info"]
        for (var i = 0; i < levels.length; i++) {
            var col = utils.levelColors[levels[i]]
            verify(col !== undefined, levels[i] + " must have a colour")
            verify(col !== "",        levels[i] + " colour must not be empty")
        }
    }

    function test_levelColors_format() {
        // every value must be a #rrggbb hex string
        var levels = ["critical", "high", "medium", "low", "info"]
        var hexRe  = /^#[0-9a-fA-F]{6}$/
        for (var i = 0; i < levels.length; i++) {
            var col = utils.levelColors[levels[i]]
            verify(hexRe.test(col), levels[i] + " colour '" + col + "' is not #rrggbb")
        }
    }
}
