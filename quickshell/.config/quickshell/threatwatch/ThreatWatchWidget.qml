// ThreatWatchWidget.qml — bar button: icon + threat label + mapbox warn badge.
// pure view — all state comes from ThreatWatchModel. see docs/architecture.md.
// slots into SysTray.qml RowLayout before ClockWidget.
//
// interactions:
//   left click — toggle ThreatWatchPopup (map overlay)

import QtQuick
import QtQuick.Layouts
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
        }
    }

    MouseArea {
        anchors.fill:    parent
        acceptedButtons: Qt.LeftButton

        onClicked: {
            ThreatWatchModel.mapExpanded = !ThreatWatchModel.mapExpanded
        }
    }
}
