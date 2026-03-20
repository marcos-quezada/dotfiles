// ThreatWatchModel.qml
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURAL DECISION: Singleton data layer
//
// This file is the *only* place that runs Processes, Timers, and FileView
// watchers. Making it a Singleton (pragma Singleton) means:
//
//   1. One timer. One set of file watchers. One update cycle — regardless of
//      how many UI components import this module. Without Singleton, every
//      instantiation of ThreatWatchWidget would spawn its own Process objects
//      and the threatwatch script would run N times in parallel.
//
//   2. Shared reactive state. Both ThreatWatchWidget (bar button) and
//      ThreatWatchPopup (map overlay) read the same properties via QML's
//      reactive binding system. Change a property here → both UIs update
//      instantly, zero coordination required.
//
//   3. Follows Quickshell idioms. The Quickshell docs and the linux-retroism
//      reference config (Config.qml, Time.qml) both use pragma Singleton for
//      exactly this pattern — background state that multiple widgets share.
//      See: https://quickshell.org/docs/v0.2.1/guide/qml-language/#singletons
//
//   4. Singleton root must be Quickshell's Singleton type (not plain Item or
//      QtObject) so Quickshell can manage its lifetime correctly inside the
//      Wayland event loop.
//
// What lives here:   Process, Timer, FileView, parsed state, helper functions
// What does NOT live here: any Rectangle, Text, PanelWindow, or visual item
// ─────────────────────────────────────────────────────────────────────────────

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── configuration — public, override from shell.qml if needed ────────────

    // full path to the threatwatch shell script.
    // stow places it at ~/.local/bin/threatwatch.
    // the script sources ~/.config/threatwatch/config.env for secrets at runtime.
    property string scriptPath: Quickshell.env("HOME") + "/.local/bin/threatwatch"

    // auto-refresh interval in milliseconds (default 6 hours).
    // mapbox free tier is 50,000 req/month. at 6h = ~120 req/month — very safe.
    //   21600000  → every 6h  (~120/month)   ← default
    //   3600000   → every 1h  (~720/month)
    //   86400000  → daily     (~30/month)
    property int refreshInterval: 6 * 60 * 60 * 1000

    // ── derived paths — all based on XDG_CACHE_HOME ──────────────────────────

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/threatwatch"

    // ── threat data — consumed by ThreatWatchWidget and ThreatWatchPopup ─────

    // text shown on the bar button (e.g. "DE  M3.8 ●●○  GAF123")
    property string barText: ""

    // current threat level: "info" | "low" | "medium" | "high" | "critical"
    property string level: "info"

    // colour map keyed by level — widgets read this, do not hardcode colours
    // ARCHITECTURAL DECISION: centralising colours here means a single edit
    // propagates to the bar label, the popup border, and any future widget.
    readonly property var levelColors: ({
        "critical": "#ff4444",
        "high":     "#ff8800",
        "medium":   "#ffcc00",
        "low":      "#88cc44",
        "info":     "#aaaaaa",
    })

    // mapbox usage — drives the warning badge in ThreatWatchWidget
    property bool mapWarn:      false   // true when usage >= 40,000 this month
    property bool mapHardLimit: false   // true when usage >= 48,000 (fetches pause)
    property int  mapRequests:  0       // raw count for tooltip display

    // interactive pins for ThreatWatchPopup — [{type,lon,lat,title,x,y}, ...]
    // x/y are Web Mercator pixel coords pre-computed by the shell script.
    // see build_pins_json() in the threatwatch script for the projection math.
    property var pins: []

    // toggle — ThreatWatchWidget sets this; ThreatWatchPopup reads it
    property bool mapExpanded: false

    // ── processes ─────────────────────────────────────────────────────────────

    // "threatwatch" (no args) — fast path: reads cache, emits one line of text
    Process {
        id: tobarProc
        command: [root.scriptPath]

        stdout: SplitParser {
            onRead: data => {
                root.barText = data.trim()
            }
        }
    }

    // "threatwatch update" — full fetch cycle: all APIs + map render
    // onExited re-runs tobarProc so the label reflects the new data immediately
    Process {
        id: updateProc
        command: [root.scriptPath, "update"]

        onExited: (code, signal) => {
            tobarProc.running = true
        }
    }

    // "threatwatch data" — full JSON dump, useful for debugging (middle-click)
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
    //
    // ARCHITECTURAL DECISION: file watchers vs polling
    // FileView in Quickshell uses inotify (Linux) / kqueue (FreeBSD/macOS) to
    // react to file changes without busy-polling. We watch three files:
    //
    //   .updated     — zero-byte sentinel, touched by the script after every run.
    //                  most reliable trigger: catches all update cycles.
    //   summary.json — parsed for level + mapbox usage counts.
    //   pins.json    — parsed for map pin coordinates.
    //
    // .updated is the master trigger. summary.json and pins.json watchers exist
    // so that manual edits or external tools can also drive a UI refresh.

    FileView {
        id: updatedWatcher
        path: root.cacheDir + "/.updated"
        onTextChanged: {
            if (!tobarProc.running) tobarProc.running = true
            root._refreshFromSummary()
            root._refreshPins()
        }
    }

    FileView {
        id: summaryWatcher
        path: root.cacheDir + "/summary.json"
        onTextChanged: root._refreshFromSummary()
    }

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

    // kick off a full update — safe to call any time, guards against overlap
    function triggerUpdate() {
        if (!updateProc.running) {
            updateProc.running = true
        }
    }

    // dump full summary JSON to stdout (right-click / debug)
    function dumpData() {
        dataProc.running = true
    }

    // human-readable label for pin tooltips — called by ThreatWatchPopup
    function pinTypeLabel(type) {
        if (type === "quake")     return "Earthquake"
        if (type === "military")  return "Military aircraft"
        if (type === "emergency") return "Emergency squawk"
        if (type === "gdacs")     return "GDACS disaster alert"
        return ""
    }

    // ── private helpers ───────────────────────────────────────────────────────

    // parse key fields out of summary.json text using lightweight regex.
    // ARCHITECTURAL DECISION: we do not use JSON.parse on the full summary here
    // because summary.json can be ~18 KB and is parsed frequently. Regex on
    // specific known keys is far cheaper than a full parse + GC cycle.
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
            // partial write in progress — keep previous pins, try again next cycle
        }
    }

    // ── init ──────────────────────────────────────────────────────────────────

    Component.onCompleted: {
        // seed bar text and state from whatever is in cache right now.
        // the timer will schedule the first real update at refreshInterval.
        // if cache is cold (fresh install) the bar will be blank until the
        // first update cycle completes — that is expected and acceptable.
        tobarProc.running = true
        root._refreshFromSummary()
        root._refreshPins()
    }
}
