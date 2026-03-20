// ThreatWatchPopup.qml — map overlay panel (800×780 px, WlrLayer.Overlay).
// must be instantiated at shell.qml root scope — cannot nest inside Bar's PanelWindow.
// see docs/architecture.md for the Wayland layer constraint explanation.

import QtQuick
import Quickshell
import Quickshell.Wayland

import "."

PanelWindow {
    id: popup

    // driven by the singleton — ThreatWatchWidget toggles mapExpanded
    visible: ThreatWatchModel.mapExpanded

    // overlay: above sway windows, below lockscreen; no exclusive zone, no keyboard steal
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // germany.png is rendered at 1600×1560 @2x — display at half size, bottom-left
    width:  800
    height: 780
    anchors {
        top:    false
        bottom: true
        left:   true
        right:  false
    }

    color: "transparent"

    // ── map image ─────────────────────────────────────────────────────────────

    Image {
        id: mapImage
        anchors.fill: parent
        source:       ThreatWatchModel.cacheDir + "/germany.png"
        cache:        false     // never use Qt image cache — file changes without URL change
        fillMode:     Image.PreserveAspectFit
        smooth:       true
    }

    // bust Qt image cache on each open so the latest map is always shown
    Connections {
        target: ThreatWatchModel
        function onMapExpandedChanged() {
            if (ThreatWatchModel.mapExpanded) {
                mapImage.source = ""
                mapImage.source = ThreatWatchModel.cacheDir + "/germany.png"
            }
        }
    }

    // click background to close; pin hitboxes below absorb their own clicks
    MouseArea {
        anchors.fill: parent
        onClicked: ThreatWatchModel.mapExpanded = false
    }

    // ── interactive pin overlay ───────────────────────────────────────────────
    // invisible hitboxes at pre-computed Web Mercator pixel positions from pins.json.
    // offset: left = x-12, top = y-30 so the hitbox bottom-centre sits on the pin tip.

    Repeater {
        model: ThreatWatchModel.pins

        delegate: Item {
            id:     pinZone
            x:      modelData.x - 12
            y:      modelData.y - 30
            width:  24
            height: 30
            z:      10

            // absorb click so background MouseArea does not close the popup
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => { mouse.accepted = true }
            }

            HoverHandler { id: pinHover }

            ToolTip {
                visible: pinHover.hovered
                delay:   200
                timeout: 15000
                text:    modelData.title + "\n" + ThreatWatchModel.pinTypeLabel(modelData.type)
            }
        }
    }
}
