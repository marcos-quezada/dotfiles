// ThreatWatchModel.qml — singleton data layer: all processes, timers, file watchers, shared state.
// no visual items live here. see docs/architecture.md for the full design rationale.
// pure logic (JSON parsing, formatters, label helpers) lives in Utils.qml so it
// can be tested headlessly with qmltestrunner without Quickshell imports.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../utils" as Utils

Singleton {
    id: root

    // ── pure-logic helpers ────────────────────────────────────────────────────
    // Utils has no Quickshell imports — instantiated as a plain child object.
    Utils.Utils { id: utils }

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

    // last update timestamp from summary.json — "YYYY-MM-DD HH:MM UTC"
    property string updatedAt: ""

    // level → colour map — all widgets read this; never hardcode colours elsewhere
    readonly property var levelColors: utils.levelColors

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

    // delegates to Utils — exposed here so callers don't need to import Utils
    function pinTypeLabel(type) { return utils.pinTypeLabel(type) }

    // ── private helpers ───────────────────────────────────────────────────────

    function _refreshFromSummary() {
        var result = utils.parseSummary(String(summaryWatcher.text))
        if (!result) return
        if (result.level)     root.level     = result.level
        if (result.updatedAt) root.updatedAt = result.updatedAt
        root.mapRequests  = result.mapRequests
        root.mapWarn      = result.mapWarn
        root.mapHardLimit = result.mapRequests >= 48000
    }

    function _refreshPins() {
        var result = utils.parsePins(pinsWatcher.text)
        if (result !== null) root.pins = result
        // null means partial write in progress — keep previous pins, retry next cycle
    }

    // ── init ──────────────────────────────────────────────────────────────────

    Component.onCompleted: {
        // seed from cache immediately, then kick a full update — script skips
        // the map fetch if cache is still fresh (MAP_MIN_INTERVAL check)
        root._refreshFromSummary()
        root._refreshPins()
        root.triggerUpdate()
    }
}
