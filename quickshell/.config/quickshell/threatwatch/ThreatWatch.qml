// ThreatWatch.qml
// Drop into your Quickshell bar config as a component.
//
// Reads ~/.cache/threatwatch/summary.json via a FileView watcher,
// calls the threatwatch script for updates. Left-click expands an
// overlay panel showing the germany.png threat map inline.
//
// Sway / wlroots compatible — no Hyprland-specific types used.
//
// Usage in your bar (shell.qml or Bar.qml):
//   import "threatwatch" as ThreatWatch
//   ThreatWatch.ThreatWatch {}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Sys
import Quickshell.Wayland

Item {
    id: root

    // ── Public properties (override in your bar) ─────────────────────────────

    // Full path to the threatwatch script.
    // stow places it at ~/.local/bin/threatwatch — override if your PATH differs.
    property string scriptPath: Quickshell.env("HOME") + "/.local/bin/threatwatch"

    // Auto-refresh interval in milliseconds (default 6 hours).
    // At 6h the map is fetched ~120 times/month — well within the 50,000
    // Mapbox Static Images free tier. Increase if you share a token across
    // machines or run many manual tests:
    //   30 * 60 * 1000   →  every 30 min  (~1,440/month) — still safe
    //   60 * 60 * 1000   →  every hour    (~720/month)
    //   6  * 60 * 60 * 1000  →  every 6h (default, ~120/month)
    //   24 * 60 * 60 * 1000  →  daily     (~30/month)
    property int refreshInterval: 6 * 60 * 60 * 1000

    // Colours keyed by threat level
    property var levelColors: ({
        "critical": "#ff4444",
        "high":     "#ff8800",
        "medium":   "#ffcc00",
        "low":      "#88cc44",
        "info":     "#aaaaaa",
    })

    // Font size for the bar label
    property int fontSize: 13

    // ── Internal state ───────────────────────────────────────────────────────

    property string _barText:       ""
    property string _level:         "info"
    property bool   _running:       false
    property bool   _mapWarn:       false   // true when Mapbox usage ≥ 40,000/month
    property bool   _mapHardLimit:  false   // true when usage ≥ 48,000/month
    property int    _mapRequests:   0
    property string _cacheDir:      Quickshell.env("HOME") + "/.cache/threatwatch"
    property bool   _mapExpanded:   false   // left-click toggles the map overlay panel
    property var    _pins:          []      // parsed from pins.json — drives tooltip overlay

    // ── Size: shrink-wrap the row ─────────────────────────────────────────────

    implicitWidth:  row.implicitWidth + 10
    implicitHeight: row.implicitHeight

    // ── Layout ────────────────────────────────────────────────────────────────

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        // Main threat label
        Text {
            id: label
            text:  root._barText
            color: root.levelColors[root._level] ?? "#aaaaaa"
            font.pixelSize: root.fontSize
            font.family:    "monospace"
            visible: root._barText !== ""
        }

        // Mapbox usage warning badge — only shown when approaching limit
        Text {
            id: mapWarnLabel
            visible: root._mapWarn
            text:    root._mapHardLimit ? "󰋮" : "󰴱"   // Nerd Font: no-map / warning
            color:   root._mapHardLimit ? "#ff4444" : "#ff8800"
            font.pixelSize: root.fontSize
            font.family:    "monospace"

            // Tooltip-style ToolTip (Qt Quick built-in)
            ToolTip {
                id:      mapWarnTip
                visible: mapWarnHover.containsMouse
                delay:   400
                timeout: 12000
                text: root._mapHardLimit
                    ? "Mapbox hard limit reached (" + root._mapRequests + "/50,000).\n" +
                      "Map fetches paused until next month.\n" +
                      "To keep maps updating, increase your MAP_MIN_INTERVAL or\n" +
                      "use a second free token (export MAPBOX_TOKEN=pk.eyJ1...)."
                    : "Mapbox approaching free tier (" + root._mapRequests + "/50,000 this month).\n" +
                      "Default: 6-hour interval ≈ 120 req/month (safe).\n" +
                      "If you're seeing this, you may have run many manual tests.\n\n" +
                      "To reduce usage, set in your shell profile:\n" +
                      "  export MAP_MIN_INTERVAL=86400   # daily (30/month)\n\n" +
                      "To check usage:  threatwatch mapbox\n" +
                      "To force a map:  threatwatch map --force"
            }

            HoverHandler { id: mapWarnHover }
        }
    }

    // ── Click handling ───────────────────────────────────────────────────────

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                // Left click → expand or collapse the map overlay panel
                root._mapExpanded = !root._mapExpanded
            } else if (mouse.button === Qt.MiddleButton) {
                // Middle click → force refresh
                root._triggerUpdate()
            } else if (mouse.button === Qt.RightButton) {
                // Right click → print data to stdout (pipe to terminal/popup)
                dataProc.running = true
            }
        }
    }

    // ── Processes ────────────────────────────────────────────────────────────

    // Runs `threatwatch` (no args) to get tobar text
    Process {
        id: tobarProc
        command: [root.scriptPath]

        stdout: SplitParser {
            onRead: data => {
                root._barText = data.trim()
            }
        }

        onExited: (code, signal) => {
            root._running = false
        }
    }

    // Runs `threatwatch update` — fetches all data sources
    Process {
        id: updateProc
        command: [root.scriptPath, "update"]

        onExited: (code, signal) => {
            // After update finishes, refresh the bar text
            tobarProc.running = true
        }
    }

    // ── Map overlay panel ─────────────────────────────────────────────────────
    // Shown when _mapExpanded is true. Uses WlrLayershell (overlay layer) so it
    // floats above sway windows without stealing focus or exclusive zone space.

    PanelWindow {
        id: mapPanel
        visible: root._mapExpanded

        // overlay layer — sits above normal windows, below lockscreen
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // 800×780 logical px — germany.png is 1600×1560 @2x
        width:  800
        height: 780

        // position relative to where the bar sits — adjust anchors to taste
        anchors {
            top:   false
            bottom: true
            left:  true
            right: false
        }

        color: "transparent"

        // close on click anywhere on the panel background (pins stop propagation)
        MouseArea {
            anchors.fill: parent
            onClicked: root._mapExpanded = false
        }

        Image {
            id: mapImage
            anchors.fill: parent
            source:       root._cacheDir + "/germany.png"
            cache:        false
            fillMode:     Image.PreserveAspectFit
            smooth:       true
        }

        // ── interactive pin overlay ───────────────────────────────────────────
        // one invisible hitbox per pin, positioned at the computed x/y pixel.
        // the pin tip sits at (x, y) — shift the hitbox up by 30px and left by
        // 12px so it centres over the body of the rendered Mapbox marker.
        // clicking a pin shows its tooltip and does NOT close the panel.

        Repeater {
            model: root._pins

            delegate: Item {
                id:     pinZone
                x:      modelData.x - 12
                y:      modelData.y - 30
                width:  24
                height: 30
                z:      10

                // stop the background MouseArea from firing when clicking a pin
                MouseArea {
                    anchors.fill: parent
                    onClicked:    mouse => { mouse.accepted = true }
                }

                HoverHandler { id: pinHover }

                ToolTip {
                    visible: pinHover.hovered
                    delay:   200
                    timeout: 15000
                    text:    modelData.title + "\n" + _pinTypeLabel(modelData.type)
                }
            }
        }
    }

    // Runs `threatwatch data` — prints full summary to stdout
    Process {
        id: dataProc
        command: [root.scriptPath, "data"]

        stdout: SplitParser {
            onRead: data => {
                console.log("[ThreatWatch data]", data)
            }
        }
    }

    // ── File watcher — reacts to cache updates ────────────────────────────────
    // threatwatch touches ~/.cache/threatwatch/.updated after every update.
    // FileView polls / watches it; when content changes we re-read everything.

    FileView {
        id: updatedWatcher
        path: root._cacheDir + "/.updated"
        onTextChanged: {
            if (tobarProc.running) return
            tobarProc.running = true
            root._refreshFromSummary()
            // bust Qt image cache so the panel shows the fresh germany.png
            mapImage.source = ""
            mapImage.source = root._cacheDir + "/germany.png"
        }
    }

    // Watch summary.json directly for colour + usage updates
    FileView {
        id: summaryWatcher
        path: root._cacheDir + "/summary.json"
        onTextChanged: root._refreshFromSummary()
    }

    // Watch pins.json — written by build_pins_json() after every update
    FileView {
        id: pinsWatcher
        path: root._cacheDir + "/pins.json"
        onTextChanged: {
            try {
                var parsed = JSON.parse(pinsWatcher.text)
                if (Array.isArray(parsed)) root._pins = parsed
            } catch (e) {
                // malformed json during write — keep previous pins
            }
        }
    }

    // ── Auto-refresh timer ────────────────────────────────────────────────────

    Timer {
        id: refreshTimer
        interval:  root.refreshInterval
        repeat:    true
        running:   true
        onTriggered: root._triggerUpdate()
    }

    // ── Functions ─────────────────────────────────────────────────────────────

    function _triggerUpdate() {
        if (!updateProc.running) {
            updateProc.running = true
        }
    }

    // human-readable sub-label for the tooltip footer
    function _pinTypeLabel(type) {
        if (type === "quake")     return "Earthquake"
        if (type === "military")  return "Military aircraft"
        if (type === "emergency") return "Emergency squawk"
        if (type === "gdacs")     return "GDACS disaster alert"
        return ""
    }

    // Parse key fields out of summary.json text to update colour and map warn.
    function _refreshFromSummary() {
        var raw = summaryWatcher.text
        if (!raw) return

        // threat_level → label colour
        var ml = raw.match(/"threat_level"\s*:\s*"([^"]+)"/)
        if (ml) root._level = ml[1]

        // mapbox.warn → show badge
        var mw = raw.match(/"warn"\s*:\s*(true|false)/)
        if (mw) root._mapWarn = (mw[1] === "true")

        // mapbox.requests_this_month → counter for tooltip
        var mr = raw.match(/"requests_this_month"\s*:\s*(\d+)/)
        if (mr) root._mapRequests = parseInt(mr[1])

        // hard limit (≥ 48,000)
        root._mapHardLimit = (root._mapRequests >= 48000)
    }

    // ── Init ──────────────────────────────────────────────────────────────────

    Component.onCompleted: {
        tobarProc.running = true
        root._refreshFromSummary()
        // load any cached pins immediately — watcher fires only on change
        try {
            var p = JSON.parse(pinsWatcher.text)
            if (Array.isArray(p)) root._pins = p
        } catch (e) {}
    }
}
