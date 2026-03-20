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

    // one-line bar string, e.g. "󰒙 HIGH M4.2 ✈3"
    property string barText: ""

    // current level: "info" | "low" | "medium" | "high" | "critical"
    property string level: "info"

    // level → colour map — all widgets read this; never hardcode colours elsewhere
    readonly property var levelColors: ({
        "critical": "#ff4444",
        "high":     "#ff8800",
        "medium":   "#ffcc00",
        "low":      "#88cc44",
        "info":     "#aaaaaa",
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

    // regex on raw JSON text — cheaper than JSON.parse on an 18 KB file called frequently
    function _refreshFromSummary() {
        var raw = summaryWatcher.text
        if (!raw) return

        var ml = raw.match(/"threat_level"\s*:\s*"([^"]+)"/)
        if (ml) root.level = ml[1]

        var mw = raw.match(/"warn"\s*:\s*(true|false)/)
        if (mw) root.mapWarn = (mw[1] === "true")

        var mr = raw.match(/"requests_this_month"\s*:\s*(\d+)/)
        if (mr) root.mapRequests = parseInt(mr[1])

        root.mapHardLimit = (root.mapRequests >= 48000)
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
