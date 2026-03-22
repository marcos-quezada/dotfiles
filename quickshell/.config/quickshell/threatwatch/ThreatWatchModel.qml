// ThreatWatchModel.qml — singleton data layer: all processes, timers, file watchers, shared state.
// no visual items live here. see docs/architecture.md for the full design rationale.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── configuration ─────────────────────────────────────────────────────────

    // full path to the threatwatch shell script — stow places it at ~/.local/bin/threatwatch
    property string scriptPath: Quickshell.env("HOME") + "/.local/bin/threatwatch"

    // auto-refresh interval — default 6h keeps mapbox usage at ~120 req/month
    //   21600000 = 6h (default) · 3600000 = 1h · 86400000 = daily
    property int refreshInterval: 6 * 60 * 60 * 1000

    // ── derived paths ─────────────────────────────────────────────────────────

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/threatwatch"

    // ── threat state — consumed by ThreatWatchWidget and ThreatWatchPopup ─────

    // one-line bar string, e.g. "󰒙 󰈌3 ✈2"
    property string barText: ""

    // current level: "info" | "low" | "medium" | "high" | "critical"
    property string level: "info"

    // full tooltip summary shown on bar hover — built by _refreshFromSummary()
    // sections: level · quakes · flights · gdacs · markets · updated
    property string tooltipText: "threatwatch — no data yet.\nmiddle-click to fetch."

    // last update timestamp from summary.json — "YYYY-MM-DD HH:MM UTC"
    property string updatedAt: ""

    // level → colour map — all widgets read this; never hardcode colours elsewhere
    // colours chosen for legibility on the light (#d8d8d8) default bar base
    readonly property var levelColors: ({
        "critical": "#cc0000",
        "high":     "#cc5500",
        "medium":   "#997700",
        "low":      "#336600",
        "info":     "#444444",
    })

    property bool mapWarn:      false   // usage >= 40,000 this month
    property bool mapHardLimit: false   // usage >= 48,000; fetches paused
    property int  mapRequests:  0       // raw monthly count for tooltip

    // pre-computed Web Mercator pin coords — [{type,lon,lat,title,x,y}, ...]
    property var pins: []

    // popup visibility — widget writes, popup reads
    property bool mapExpanded: false

    // ── processes ─────────────────────────────────────────────────────────────

    // fast path — reads cache, emits one bar text line
    Process {
        id: tobarProc
        command: [root.scriptPath]

        stdout: SplitParser {
            onRead: data => {
                root.barText = data.trim()
            }
        }
    }

    // full fetch — all APIs + map render; re-runs tobarProc on exit
    Process {
        id: updateProc
        command: [root.scriptPath, "update"]

        onExited: (code, signal) => {
            tobarProc.running = true
        }
    }

    // debug dump — prints full summary JSON to stdout (right-click)
    Process {
        id: dataProc
        command: [root.scriptPath, "data"]

        stdout: SplitParser {
            onRead: data => {
                console.log("[ThreatWatch data]", data)
            }
        }
    }

    // ── file watchers ─────────────────────────────────────────────────────────
    // inotify/kqueue — no busy-polling. see docs/architecture.md for watcher rationale.

    // .updated is touched by the script after every run — master trigger
    FileView {
        id: updatedWatcher
        path: root.cacheDir + "/.updated"
        onTextChanged: {
            if (!tobarProc.running) tobarProc.running = true
            root._refreshFromSummary()
            root._refreshPins()
        }
    }

    // summary.json — direct watcher so manual edits also refresh level/badge
    FileView {
        id: summaryWatcher
        path: root.cacheDir + "/summary.json"
        onTextChanged: root._refreshFromSummary()
    }

    // pins.json — written by build_pins_json() after every update
    FileView {
        id: pinsWatcher
        path: root.cacheDir + "/pins.json"
        onTextChanged: root._refreshPins()
    }

    // ── auto-refresh timer ────────────────────────────────────────────────────

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        repeat:   true
        running:  true
        onTriggered: root.triggerUpdate()
    }

    // ── public functions ──────────────────────────────────────────────────────

    // start a full update — no-op if one is already running
    function triggerUpdate() {
        if (!updateProc.running) {
            updateProc.running = true
        }
    }

    // dump full summary JSON to stdout (right-click / debug)
    function dumpData() {
        dataProc.running = true
    }

    // human-readable pin category — used by ThreatWatchPopup tooltips
    function pinTypeLabel(type) {
        if (type === "quake")     return "Earthquake"
        if (type === "military")  return "Military aircraft"
        if (type === "emergency") return "Emergency squawk"
        if (type === "gdacs")     return "GDACS disaster alert"
        return ""
    }

    // ── private helpers ───────────────────────────────────────────────────────

    function _refreshFromSummary() {
        var raw = String(summaryWatcher.text)
        if (!raw) return
        var s
        try { s = JSON.parse(raw) } catch(e) { return }

        if (s.threat_level) root.level = s.threat_level

        // format "2025-01-15T14:32:00Z" → "2025-01-15 14:32 UTC"
        if (s.updated_at) {
            var ts = s.updated_at.replace("T", " ").replace("Z", "")
            root.updatedAt = ts.substring(0, 16) + " UTC"
        }

        var mb = s.mapbox || {}
        root.mapRequests  = mb.requests_this_month || 0
        root.mapWarn      = mb.warn || false
        root.mapHardLimit = root.mapRequests >= 48000

        // ── build tooltip body ─────────────────────────────────────────────────
        var parts = []

        // level line
        parts.push("Level: " + (s.threat_level || "info").toUpperCase())

        // earthquakes — top quake + total count
        var qcount = s.quake_count || 0
        var tq = s.top_quake
        if (qcount > 0 && tq) {
            parts.push("Quakes: " + qcount + " — top M" + tq.mag + " " + tq.place)
        } else if (qcount > 0) {
            parts.push("Quakes: " + qcount)
        }

        // flights
        var mil   = s.mil_count   || 0
        var emerg = s.emerg_count || 0
        if (emerg > 0) {
            parts.push("Flights: " + mil + " military, " + emerg + " EMERGENCY squawk")
        } else if (mil > 0) {
            parts.push("Flights: " + mil + " military")
        }

        // GDACS in-region alerts
        var gdacs = s.gdacs_alerts || []
        var gdacsInRegion = gdacs.filter(function(a) {
            return a.in_region && (a.level === "red" || a.level === "orange")
        })
        if (gdacsInRegion.length > 0) {
            var gdacsLines = ["GDACS alerts in region:"]
            for (var g = 0; g < Math.min(3, gdacsInRegion.length); g++) {
                var a = gdacsInRegion[g]
                gdacsLines.push("  [" + a.level.toUpperCase() + "] " + a.title)
            }
            parts.push(gdacsLines.join("\n"))
        }

        // geopolitical markets — top 5
        var markets = s.poly_markets || []
        if (markets.length > 0) {
            var mktLines = ["Prediction markets:"]
            for (var i = 0; i < Math.min(5, markets.length); i++) {
                var m = markets[i]
                mktLines.push("  " + Math.round(m.prob_yes) + "%  " + m.title)
            }
            parts.push(mktLines.join("\n"))
        }

        // updated timestamp
        if (root.updatedAt !== "") {
            parts.push("Updated: " + root.updatedAt)
        }

        root.tooltipText = parts.join("\n")
    }

    function _refreshPins() {
        try {
            var parsed = JSON.parse(pinsWatcher.text)
            if (Array.isArray(parsed)) root.pins = parsed
        } catch (e) {
            // partial write in progress — keep previous pins, retry next cycle
        }
    }

    // ── init ──────────────────────────────────────────────────────────────────

    Component.onCompleted: {
        // seed from cache immediately; timer handles first real update at refreshInterval
        tobarProc.running = true
        root._refreshFromSummary()
        root._refreshPins()
    }
}
