// ThreatWatchPopup.qml — map overlay panel with retroism win95 chrome.
// must be instantiated at shell.qml root scope — cannot nest inside Bar's PanelWindow.
// see docs/architecture.md for the Wayland layer constraint explanation.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import ".."
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
    // total height: 18 top margin + 22 title bar + 18 bottom margin + 780 map = 838.
    // total width:  18 left margin + 800 map + 18 right margin = 836.
    // anchored top-right so the popup sits flush to the right edge just below the bar.
    // topMargin: 35 matches Bar.qml implicitHeight so it clears the bar surface.
    // ExclusionMode.Ignore means we must add the bar height manually.
    implicitWidth:  836
    implicitHeight: 838
    anchors {
        top:    true
        bottom: false
        left:   false
        right:  true
    }
    margins.top: 35

    color: "transparent"

    // ── retroism frame ────────────────────────────────────────────────────────

    Rectangle {
        id: frame
        anchors.fill: parent
        color: Config.colors.base

        opacity: 0

        // fade in when popup becomes visible
        OpacityAnimator on opacity {
            id: fadeIn
            running: false
            from:     0
            to:       1
            duration: 140
            easing.type: Easing.OutCubic
        }

        // fade out when popup closes
        OpacityAnimator on opacity {
            id: fadeOut
            running: false
            from:     1
            to:       0
            duration: 80
            easing.type: Easing.InOutQuad
        }

        // outer shadow border — bottom-right dark edge (win95 sunken outer rim)
        NewBorder {
            commonBorderWidth: 1
            borderColor: Config.colors.shadow
            zValue: 2
        }

        // outer highlight border — top-left light edge (win95 raised outer rim)
        NewBorder {
            commonBorder: false
            lBorderwidth: 1
            tBorderwidth: 1
            rBorderwidth: 0
            bBorderwidth: 0
            borderColor: Config.colors.highlight
            zValue: 3
        }

        // inner outline — 1px black rect inset 1px inside the outer bevel
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.color: Config.colors.outline
            border.width: 1
            z: 1
        }

        // ── title bar ─────────────────────────────────────────────────────────

        property int titleBarHeight: 22

        Rectangle {
            id: titleBar
            anchors.top:   parent.top
            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.margins: 4
            height: frame.titleBarHeight
            color: Config.colors.accent

            // inner border on title bar — slight highlight top-left
            NewBorder {
                commonBorder: false
                lBorderwidth: 1
                tBorderwidth: 1
                rBorderwidth: 0
                bBorderwidth: 0
                borderColor: Config.colors.highlight
                zValue: 2
            }
            NewBorder {
                commonBorder: false
                lBorderwidth: 0
                tBorderwidth: 0
                rBorderwidth: 1
                bBorderwidth: 1
                borderColor: Config.colors.shadow
                zValue: 2
            }

            // centred title content
            Item {
                anchors.fill: parent
                anchors.leftMargin:  6
                anchors.rightMargin: 6

                RowLayout {
                    id:      titleRow
                    anchors.centerIn: parent
                    spacing: 4

                    // left decorative bars — 4× 2px vertical lines
                    Repeater {
                        model: 4
                        Rectangle {
                            width:  2
                            height: frame.titleBarHeight - 8
                            color:  index < 2 ? Config.colors.highlight : Config.colors.shadow
                        }
                    }

                    // radar icon
                    Text {
                        text: "󱡣"
                        color: Config.colors.base
                        font.pixelSize: 12
                        font.family:    fontMonaco.name
                        verticalAlignment: Text.AlignVCenter
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // title label
                    Text {
                        text: "THREATWATCH"
                        color: Config.colors.base
                        font.pixelSize: 12
                        font.family:    fontCharcoal.name
                        verticalAlignment: Text.AlignVCenter
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // right decorative bars — 4× 2px vertical lines (mirrored)
                    Repeater {
                        model: 4
                        Rectangle {
                            width:  2
                            height: frame.titleBarHeight - 8
                            color:  index < 2 ? Config.colors.shadow : Config.colors.highlight
                        }
                    }
                }
            }
        }

        // ── map content area ──────────────────────────────────────────────────

        Item {
            id: contentArea
            anchors {
                top:    titleBar.bottom
                left:   parent.left
                right:  parent.right
                bottom: parent.bottom
                topMargin:    4
                leftMargin:   4
                rightMargin:  4
                bottomMargin: 4
            }

            // map image — fills the content area
            Image {
                id: mapImage
                anchors.fill: parent
                source:       ThreatWatchModel.cacheDir + "/germany.png"
                cache:        false     // never use Qt image cache — file changes without URL change
                fillMode:     Image.Stretch
                smooth:       true
            }

            // click background to close; pin hitboxes below absorb their own clicks
            MouseArea {
                anchors.fill: parent
                onClicked: ThreatWatchModel.mapExpanded = false
            }

            // ── interactive pin overlay ───────────────────────────────────────
            // invisible hitboxes at pre-computed Web Mercator pixel positions from pins.json.
            // offset: left = x-12, top = y-30 so the hitbox bottom-centre sits on the pin tip.
            //
            // ToolTip attached properties don't render inside PanelWindow (no ApplicationWindow
            // overlay layer). instead we use a single shared inline Rectangle tooltip that
            // positions itself near whichever pin is currently hovered.

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
                x: Math.min(Math.max(pinX - width / 2, 4), contentArea.width  - width  - 4)
                y: Math.max(pinY - height - 6, 4)

                width:  tipLabel.implicitWidth  + 16
                height: tipLabel.implicitHeight + 10

                Text {
                    id:          tipLabel
                    anchors.centerIn: parent
                    text:        pinTooltip.tipText
                    color:       Config.colors.text
                    font.pixelSize: 12
                    font.family:    fontCharcoal.name
                    wrapMode:    Text.NoWrap
                }
            }

            Repeater {
                model: ThreatWatchModel.pins

                delegate: Item {
                    id:     pinZone
                    x:      modelData.x - 12
                    y:      modelData.y - 30
                    width:  24
                    height: 30
                    z:      10

                    // single MouseArea handles both hover and click absorption.
                    // hoverEnabled is required — without it containsMouse is always false.
                    MouseArea {
                        id:           pinMouse
                        width:        parent.width
                        height:       parent.height
                        hoverEnabled: true

                        onContainsMouseChanged: {
                            if (containsMouse) {
                                pinTooltip.tipText  = modelData.title + "\n" + ThreatWatchModel.pinTypeLabel(modelData.type)
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

        // inner outline at content boundary — subtle inset border below title bar
        Rectangle {
            anchors {
                top:    titleBar.bottom
                left:   parent.left
                right:  parent.right
                bottom: parent.bottom
                margins: 4
            }
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            z: 5
        }
    }

    // ── animation triggers ────────────────────────────────────────────────────

    // bust Qt image cache on each open so the latest map is always shown
    Connections {
        target: ThreatWatchModel
        function onMapExpandedChanged() {
            if (ThreatWatchModel.mapExpanded) {
                mapImage.source = ""
                mapImage.source = ThreatWatchModel.cacheDir + "/germany.png"
                fadeOut.running = false
                fadeIn.running  = true
            } else {
                fadeIn.running  = false
                fadeOut.running = true
            }
        }
    }
}
