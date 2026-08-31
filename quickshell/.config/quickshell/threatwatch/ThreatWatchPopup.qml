pragma ComponentBehavior: Bound

// ThreatWatchPopup.qml — map overlay panel.
// must be instantiated at shell.qml root scope — cannot nest inside Bar's PanelWindow.
// chrome (border stack, title bar, fade) lives in components/PopupFrame.qml.

import QtQuick
import Quickshell
import Quickshell.Wayland

import qs 
import "../components" as Components

PanelWindow {
    id: popup

    visible: ThreatWatchModel.mapExpanded

    // overlay: above sway windows, below lockscreen; no exclusive zone, no keyboard steal
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // germany.png is rendered at 1600×1560 @2x — display at half size.
    // topMargin: 35 matches Bar.qml implicitHeight so it clears the bar surface.
    // ExclusionMode.Ignore means we must add the bar height manually.
    implicitWidth:  800
    implicitHeight: 780
    anchors {
        top:    true
        bottom: false
        left:   true 
        right:  false
    }
    margins.top:  35
    margins.left: ThreatWatchModel.mapTriggerX

    color: "transparent"

    Components.PopupFrame {
        id: chrome
        title: "THREATWATCH"
        icon:  "󱡣"

        Image {
            id: mapImage
            anchors.fill: parent
            source:       ThreatWatchModel.cacheDir + "/germany.png"
            cache:        false     // file changes without URL change — never use Qt image cache
            fillMode:     Image.Stretch
            smooth:       true
        }

        // click background to close; pin hitboxes below absorb their own clicks
        MouseArea {
            anchors.fill: parent
            onClicked: ThreatWatchModel.mapExpanded = false
        }

        // invisible hitboxes at pre-computed Web Mercator pixel positions.
        // offset: left = x-12, top = y-30 so the hitbox bottom-centre sits on the pin tip.
        //
        // ToolTip attached properties don't render inside PanelWindow (no ApplicationWindow
        // overlay layer). instead we use a single shared inline Rectangle tooltip.

        // shared pin tooltip — rendered above everything at z:20
        Rectangle {
            id: pinTooltip
            visible: false
            z:       20
            color:   Config.colors.base
            border.color: Config.colors.outline
            border.width: 1

            property string tipText: ""
            property real   pinX:    0
            property real   pinY:    0

            // position: prefer above the pin; clamp to content area bounds
            x: Math.min(Math.max(pinX - width / 2, 4), parent.width  - width  - 4)
            y: Math.max(pinY - height - 6, 4)

            width:  tipLabel.implicitWidth  + 16
            height: tipLabel.implicitHeight + 10

            Text {
                id:          tipLabel
                anchors.centerIn: parent
                text:        pinTooltip.tipText
                color:       Config.colors.text
                font.pixelSize: 12
                font.family: Fonts.title
                wrapMode:    Text.NoWrap
            }
        }

        Repeater {
            model: ThreatWatchModel.pins

            delegate: Item {
                id:     pinZone
                required property var modelData

                x:      modelData.x - 12
                y:      modelData.y - 30
                width:  24
                height: 30
                z:      10

                // hoverEnabled is required — without it containsMouse is always false
                MouseArea {
                    id:           pinMouse
                    width:        parent.width
                    height:       parent.height
                    hoverEnabled: true

                    onContainsMouseChanged: {
                        if (containsMouse) {
                            pinTooltip.tipText = pinZone.modelData.title + "\n" + ThreatWatchModel.pinTypeLabel(pinZone.modelData.type)
                            // tip anchors to pin tip: centre of hitbox bottom, in content area coords
                            pinTooltip.pinX = pinZone.x + pinZone.width  / 2
                            pinTooltip.pinY = pinZone.y + pinZone.height
                            pinTooltip.visible = true
                        } else {
                            pinTooltip.visible = false
                        }
                    }

                    onClicked: mouse => { mouse.accepted = true }
                }
            }
        }
    }

    // ── animation + map reload triggers ──────────────────────────────────────

    // bust Qt image cache on each open so the latest map is always shown
    Connections {
        target: ThreatWatchModel

        function onMapExpandedChanged() {
            if (ThreatWatchModel.mapExpanded) {
                mapImage.source = ""
                mapImage.source = ThreatWatchModel.cacheDir + "/germany.png"
                chrome.open()
            } else {
                chrome.close()
            }
        }

        // reload map if a fresh update lands while the popup is already open
        function onUpdatedAtChanged() {
            if (ThreatWatchModel.mapExpanded) {
                mapImage.source = ""
                mapImage.source = ThreatWatchModel.cacheDir + "/germany.png"
            }
        }
    }
}
