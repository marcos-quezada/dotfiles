pragma ComponentBehavior: Bound

// SoundPopup.qml - volume, mute, and output switching.
// must be instantiated at shell.qml root scope - cannot nest inside Bar's PanelWindow

import QtQuick
import QtQuick.Layouts

import qs.Components as Components
import qs.Services

Components.TriggeredPopup {
    id:             popup
    expanded:       Sound.expanded
    triggerX:       Sound.triggerX
    title:          "AUDIO"
    icon:           "\ue050"
    implicitWidth:  260
    implicitHeight: 180

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: 4
        spacing:         8

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
}
