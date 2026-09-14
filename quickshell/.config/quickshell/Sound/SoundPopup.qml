pragma ComponentBehavior: Bound

// SoundPopup.qml - volume, mute, and output switching.
// must be instantiated at shell.qml root scope - cannot nest inside Bar's PanelWindow

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.Components as Components
import qs.Services

PanelWindow {
    id: popup

    visible: Sound.expanded

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth:  260
    implicitHeight: 180
    anchors {
        top:  true
        left: true
    }
    margins.top:  35
    margins.left: Sound.triggerX

    color: "transparent"

    Components.PopupFrame {
        id:    chrome
        title: "AUDIO"
        icon:  "\ue050"

        ColumnLayout {
            anchors.fill: parent
            spacing:      8

            // ── volume row ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing:          4

                Components.IconTileButton {
                    glyph:          "-"
                    glyphFont:      Fonts.body
                    implicitWidth:   22
                    implicitHeight: 22
                    onClicked:      Sound.volumeDown()
                }

                Text {
                    Layout.fillWidth:    true
                    horizontalAlignment: Text.AlignHCenter
                    text:                Sound.muted ? "muted" : Sound.volume + "%"
                    color:               Config.colors.text
                    font.family:         Fonts.body
                    font.pixelSize:      12
                }

                Components.IconTileButton {
                    glyph:          "+"
                    glyphFont:      Fonts.body
                    implicitWidth:  22
                    implicitHeight: 22
                    onClicked:      Sound.volumeUp()
                }

                Components.IconTileButton {
                    glyph:          Sound.muted ? "\ue04f" : "\ue050"
                    glyphFont:      Fonts.icon
                    implicitWidth:  22
                    implicitHeight: 22
                    onClicked:      Sound.toggleMute()
                }
            }
      
            // ── output switcher ─────────────────────────────────────────────
            Repeater {
                model: Sound.outputs

                delegate: Components.ListRow {
                    id:               row
                    required property var modelData
                    Layout.fillWidth: true
                    height:           26
                    selected:         Sound.currentSink === modelData.sink
                    onClicked:        Sound.switchOutput(modelData.sink)
                

                    Text {
                        anchors.fill:      parent
                        anchors.margins:   4
                        text:              row.modelData.label
                        color:             Config.colors.text
                        font.family:       Fonts.body
                        font.pixelSize:    12
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z:            -1
            onClicked:    Sound.expanded = false
        }
    }

    Connections {
        target: Sound
        function onExpandedChanged() {
            if (Sound.expanded) chrome.open()
            else chrome.close()
        }
    }
}
