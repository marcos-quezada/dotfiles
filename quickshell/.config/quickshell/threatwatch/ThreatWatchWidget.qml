// ThreatWatchWidget.qml
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURAL DECISION: pure view component, zero logic
//
// This file contains *only* UI elements. All state lives in ThreatWatchModel
// (the Singleton). This mirrors how ClockWidget.qml works in the retroism
// taskbar — it is a thin presentation layer that slots into SysTray.qml's
// RowLayout next to the clock, with the same font and sizing API.
//
// Wiring:
//   Bar.qml  →  SysTray.qml RowLayout  →  ThreatWatchWidget (here)
//
// The widget shows:
//   - a Nerd Font icon  (always visible)
//   - the threat label  (hidden when cache is cold / blank)
//   - a Mapbox warn badge when approaching the free tier limit
//
// Interactions:
//   left-click    → toggle map overlay   (sets ThreatWatchModel.mapExpanded)
//   middle-click  → force update now     (calls ThreatWatchModel.triggerUpdate)
//   right-click   → dump data to stdout  (calls ThreatWatchModel.dumpData)
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import QtQuick.Layouts
import Quickshell

import ".."
import "."

// RowLayout child — implicitWidth drives how much space we take in the bar row.
// We do NOT anchor to parent; let the parent RowLayout handle positioning.
RowLayout {
    id: widget
    spacing: 3

    // icon — always visible, coloured by current threat level.
    // using the nerd font radar/shield icon to signal "threat monitor active".
    // colour comes from ThreatWatchModel so it matches the text label exactly.
    Text {
        id: icon
        text: "󱡣"    // nf-md-radar — persistent even when cache is cold
        color: ThreatWatchModel.levelColors[ThreatWatchModel.level] ?? Config.colors.text
        font.pixelSize: Config.settings.bar.fontSize
        font.family:    fontMonaco.name
        verticalAlignment: Text.AlignVCenter

        HoverHandler {
            id: iconHover
            cursorShape: Qt.PointingHandCursor
        }

        ToolTip {
            visible: iconHover.hovered
            delay:   600
            timeout: 8000
            text: ThreatWatchModel.barText !== ""
                ? ThreatWatchModel.barText
                : "threatwatch — no data yet.\nmiddle-click to fetch."
        }
    }

    // threat label — hidden when barText is empty (cold cache / first boot).
    // colour tracks ThreatWatchModel.level reactively via QML binding.
    Text {
        id: label
        visible: ThreatWatchModel.barText !== ""
        text:    ThreatWatchModel.barText
        color:   ThreatWatchModel.levelColors[ThreatWatchModel.level] ?? Config.colors.text
        font.pixelSize: Config.settings.bar.fontSize
        font.family:    fontMonaco.name
        verticalAlignment: Text.AlignVCenter
    }

    // mapbox usage warning badge — only appears when approaching the free tier.
    // icons: 󰋮 = no-map (hard limit), 󰴱 = warning (soft limit)
    Text {
        id: mapWarnBadge
        visible: ThreatWatchModel.mapWarn
        text:    ThreatWatchModel.mapHardLimit ? "󰋮" : "󰴱"
        color:   ThreatWatchModel.mapHardLimit ? "#ff4444" : "#ff8800"
        font.pixelSize: Config.settings.bar.fontSize
        font.family:    fontMonaco.name
        verticalAlignment: Text.AlignVCenter

        HoverHandler { id: warnHover }

        ToolTip {
            visible: warnHover.hovered
            delay:   400
            timeout: 12000
            text: ThreatWatchModel.mapHardLimit
                ? "Mapbox hard limit reached (" + ThreatWatchModel.mapRequests + "/50,000).\n" +
                  "Map fetches paused until next month.\n" +
                  "To keep maps updating, increase MAP_MIN_INTERVAL in config.env\n" +
                  "or rotate to a fresh free token."
                : "Mapbox approaching free tier (" + ThreatWatchModel.mapRequests + "/50,000 this month).\n" +
                  "Default: 6h interval = ~120 req/month (well within limits).\n" +
                  "If you see this, you may have run many manual tests.\n\n" +
                  "To reduce usage, set in config.env:\n" +
                  "  MAP_MIN_INTERVAL=86400   # daily = ~30 req/month\n\n" +
                  "To check usage:  threatwatch mapbox\n" +
                  "To force a map:  threatwatch map --force"
        }
    }

    // ── click handling ────────────────────────────────────────────────────────
    // MouseArea covers the whole widget row. individual HoverHandlers above
    // handle per-element cursors and tooltips independently.

    MouseArea {
        // fill the parent RowLayout bounding box
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        // do not consume hover so HoverHandlers on children still fire
        propagateComposedEvents: true

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                ThreatWatchModel.mapExpanded = !ThreatWatchModel.mapExpanded
            } else if (mouse.button === Qt.MiddleButton) {
                ThreatWatchModel.triggerUpdate()
            } else if (mouse.button === Qt.RightButton) {
                ThreatWatchModel.dumpData()
            }
            mouse.accepted = true
        }
    }
}
