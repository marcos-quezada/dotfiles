// ThreatWatchWidget.qml — bar button: icon + threat label + mapbox warn badge.
// pure view — all state comes from ThreatWatchModel. see docs/architecture.md.
// slots into SysTray.qml RowLayout before ClockWidget.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import ".."
import "."

// outer Item owns the geometry the parent RowLayout allocates; the MouseArea
// fills it freely without being a layout-managed sibling of the Text items.
Item {
    id: widget
    implicitWidth:  row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 3

        // radar icon — always visible, coloured by threat level
        Text {
            id: icon
            text: "󱡣"
            color: ThreatWatchModel.levelColors[ThreatWatchModel.level] ?? Config.colors.text
            font.pixelSize: Config.settings.bar.fontSize
            font.family:    fontMonaco.name
            verticalAlignment: Text.AlignVCenter

            ToolTip.visible: iconHover.hovered
            ToolTip.delay:   600
            ToolTip.timeout: 12000
            ToolTip.text:    ThreatWatchModel.headlines !== ""
                ? ThreatWatchModel.headlines
                : (ThreatWatchModel.barText !== ""
                    ? ThreatWatchModel.barText
                    : "threatwatch — no data yet.\nmiddle-click to fetch.")

            HoverHandler {
                id: iconHover
                cursorShape: Qt.PointingHandCursor
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

            ToolTip.visible: warnHover.hovered
            ToolTip.delay:   400
            ToolTip.timeout: 12000
            ToolTip.text:    ThreatWatchModel.mapHardLimit
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

            HoverHandler { id: warnHover }
        }
    }

    // click handler — fills the outer Item, not a layout sibling, so it gets
    // the correct geometry. propagateComposedEvents lets child HoverHandlers fire.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        propagateComposedEvents: true

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                console.log("[ThreatWatch] left click — toggling mapExpanded:", !ThreatWatchModel.mapExpanded)
                ThreatWatchModel.mapExpanded = !ThreatWatchModel.mapExpanded
            } else if (mouse.button === Qt.MiddleButton) {
                console.log("[ThreatWatch] middle click — triggering update")
                ThreatWatchModel.triggerUpdate()
            } else if (mouse.button === Qt.RightButton) {
                console.log("[ThreatWatch] right click — dumping data")
                ThreatWatchModel.dumpData()
            }
            mouse.accepted = true
        }
    }
}
