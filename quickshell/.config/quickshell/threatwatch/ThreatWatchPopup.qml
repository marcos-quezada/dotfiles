// ThreatWatchPopup.qml — map overlay panel (800×780 px, WlrLayer.Overlay).
// must be instantiated at shell.qml root scope — cannot nest inside Bar's PanelWindow.
// see docs/architecture.md for the Wayland layer constraint explanation.

import QtQuick
import QtQuick.Controls
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

    // germany.png is rendered at 1600×1560 @2x — display at half size.
    // anchored top-right so the popup sits flush to the right edge just below the bar.
    // topMargin: 35 matches Bar.qml's implicitHeight so it clears the bar surface.
    // ExclusionMode.Ignore means the compositor does not adjust our top anchor for the
    // bar's exclusive zone — we must add the bar height manually.
    implicitWidth:  800
    implicitHeight: 780
    anchors {
        top:    true
        bottom: false
        left:   false
        right:  true
    }
    margins.top: 35

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

            // absorb click so background MouseArea does not close the popup;
            // explicit width/height instead of anchors.fill avoids layout warning
            MouseArea {
                width:  parent.width
                height: parent.height
                onClicked: mouse => { mouse.accepted = true }
            }

            HoverHandler { id: pinHover }

            ToolTip.visible: pinHover.hovered
            ToolTip.delay:   200
            ToolTip.timeout: 15000
            ToolTip.text:    modelData.title + "\n" + ThreatWatchModel.pinTypeLabel(modelData.type)
        }
    }
}
