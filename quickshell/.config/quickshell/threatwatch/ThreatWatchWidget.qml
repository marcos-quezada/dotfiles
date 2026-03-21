// ThreatWatchWidget.qml — bar button: icon + threat label + mapbox warn badge.
// pure view — all state comes from ThreatWatchModel. see docs/architecture.md.
// slots into SysTray.qml RowLayout before ClockWidget.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import ".."
import "."

RowLayout {
    id: widget
    spacing: 3

    // radar icon — always visible, coloured by threat level
    Text {
        id: icon
        text: "󱡣"
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

    // threat label — hidden when cache is cold; colour tracks level via binding
    Text {
        id: label
        visible: ThreatWatchModel.barText !== ""
        text:    ThreatWatchModel.barText
        color:   ThreatWatchModel.levelColors[ThreatWatchModel.level] ?? Config.colors.text
        font.pixelSize: Config.settings.bar.fontSize
        font.family:    fontMonaco.name
        verticalAlignment: Text.AlignVCenter
    }

    // mapbox usage badge — only shown when approaching/at the free tier limit
    // 󰋮 = hard limit (red), 󰴱 = soft warn (orange)
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

    // click handler — covers the full widget row
    // propagateComposedEvents keeps child HoverHandlers firing for tooltips/cursors
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        propagateComposedEvents: true

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                // left: toggle map overlay
                ThreatWatchModel.mapExpanded = !ThreatWatchModel.mapExpanded
            } else if (mouse.button === Qt.MiddleButton) {
                // middle: force update now
                ThreatWatchModel.triggerUpdate()
            } else if (mouse.button === Qt.RightButton) {
                // right: dump summary to stdout for debugging
                ThreatWatchModel.dumpData()
            }
            mouse.accepted = true
        }
    }
}
