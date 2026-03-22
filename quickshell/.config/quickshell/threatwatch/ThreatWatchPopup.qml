// ThreatWatchPopup.qml — map overlay panel with retroism win95 chrome.
// must be instantiated at shell.qml root scope — cannot nest inside Bar's PanelWindow.
// see docs/architecture.md for the Wayland layer constraint explanation.
//
// chrome modelled directly on PopupWindowFrame.qml from diinki/linux-retroism:
//   - title bar: ColumnLayout of 4× horizontal 2px gradient lines flanking icon + label
//   - border stack: 6 NewBorder/Rectangle layers replicating the win95 raised bevel
//   - title bar height: 20px (matching retroism's hard-coded 20 offset throughout)
//   - no accent-colour title bar — frame stays Config.colors.base throughout

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
    // anchored top-right so the popup sits flush to the right edge just below the bar.
    // topMargin: 35 matches Bar.qml implicitHeight so it clears the bar surface.
    // ExclusionMode.Ignore means we must add the bar height manually.
    implicitWidth:  800
    implicitHeight: 820
    anchors {
        top:    true
        bottom: false
        left:   false
        right:  true
    }
    margins.top: 35

    color: "transparent"

    // ── retroism frame ────────────────────────────────────────────────────────
    // modelled on PopupWindowFrame.qml. titleBarHeight matches the 20px offset
    // used throughout that file's NewBorder stack.

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

        // title bar height — must match the '20' literal in NewBorder top offsets below
        readonly property int titleBarHeight: 20

        // ── title bar ─────────────────────────────────────────────────────────
        // direct port of PopupWindowFrame.qml top-bar section.
        // horizontal gradient lines (ColumnLayout of 4 rows) flank icon + label.

        Item {
            id: titleBar
            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   parent.top
            implicitHeight: frame.titleBarHeight

            RowLayout {
                id: panelName
                anchors.centerIn: parent

                // left decorative column — 4× horizontal 2px lines with gradient
                ColumnLayout {
                    spacing: 1
                    Repeater {
                        model: 4
                        Rectangle {
                            implicitHeight: 2
                            implicitWidth:  100
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Config.colors.highlight }
                                GradientStop { position: 0.5; color: Config.colors.highlight }
                                GradientStop { position: 1.0; color: Config.colors.outline   }
                            }
                        }
                    }
                }

                // radar icon
                Text {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                    font.family:    fontMonaco.name
                    font.pixelSize: 18
                    opacity: 0.8
                    text:  "󱡣"
                    color: Config.colors.text
                }

                // title label
                Text {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                    font.family:    fontCharcoal.name
                    font.pixelSize: 12
                    text:  "THREATWATCH"
                    color: Config.colors.text
                }

                // right decorative column — mirror of left
                ColumnLayout {
                    spacing: 1
                    Repeater {
                        model: 4
                        Rectangle {
                            implicitHeight: 2
                            implicitWidth:  100
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Config.colors.highlight }
                                GradientStop { position: 0.5; color: Config.colors.highlight }
                                GradientStop { position: 1.0; color: Config.colors.outline   }
                            }
                        }
                    }
                }
            }
        }

        // ── border stack (exact retroism NewBorder pattern) ───────────────────
        // see PopupWindowFrame.qml "Window Frame" section.
        // the thick sides (10) bleed outside the frame rectangle via negative anchors.
        // the inner outlines use negative borderwidth values to inset instead of bleed.

        // highlight: left thin, right+top+bottom thick — raised left edge
        NewBorder {
            commonBorder: false
            lBorderwidth: 1
            rBorderwidth: 10
            tBorderwidth: 10
            bBorderwidth: 10
            zValue: 0
            borderColor: Config.colors.highlight
        }

        // shadow: left+top thick, right+bottom thin — lowered right edge
        NewBorder {
            commonBorder: false
            lBorderwidth: 10
            rBorderwidth: 1
            tBorderwidth: 10
            bBorderwidth: 1
            zValue: 0
            borderColor: Config.colors.shadow
        }

        // top-only outline strip — solid outline across the top
        NewBorder {
            commonBorder: false
            lBorderwidth: 0
            rBorderwidth: 0
            tBorderwidth: 10
            bBorderwidth: 0
            zValue: 0
            borderColor: Config.colors.outline
        }

        // inner inset outline — bleeds inside by 7px + titleBarHeight on top, 50% opacity
        NewBorder {
            commonBorder: false
            lBorderwidth: -7
            rBorderwidth: -7
            tBorderwidth: -7 - frame.titleBarHeight
            bBorderwidth: -7
            zValue: 0
            opacity: 0.5
            borderColor: Config.colors.outline
        }

        // inner inset outline — slightly further, 20% opacity (softer halo)
        NewBorder {
            commonBorder: false
            lBorderwidth: -8
            rBorderwidth: -8
            tBorderwidth: -8 - frame.titleBarHeight
            bBorderwidth: -8
            zValue: 0
            opacity: 0.2
            borderColor: Config.colors.outline
        }

        // innerOutline box — solid 1px border inset 6px + titleBarHeight on top
        Rectangle {
            anchors {
                fill:        parent
                margins:     6
                topMargin:   6 + frame.titleBarHeight
            }
            color:        "transparent"
            border.width: 1
            border.color: Config.colors.outline
        }

        // ── map content area ──────────────────────────────────────────────────

        Item {
            id: contentArea
            anchors {
                top:         titleBar.bottom
                left:        parent.left
                right:       parent.right
                bottom:      parent.bottom
                topMargin:   6
                leftMargin:  6
                rightMargin: 6
                bottomMargin: 6
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
                                pinTooltip.tipText = modelData.title + "\n" + ThreatWatchModel.pinTypeLabel(modelData.type)
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
