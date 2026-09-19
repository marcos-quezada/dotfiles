pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.Components as Components
import qs.Services

PanelWindow {
    id:      popup
    visible: Session.rebootPending || Session.shutdownPending

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth:  280
    implicitHeight: 140
    anchors { top: true; left: true }
    margins.top:    50 
    margins.left:   25
    color:          "transparent"

    Components.PopupFrame {
        id:    chrome
        showTitleBar: false

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 8
            spacing:         10

            RowLayout {
                Layout.fillWidth: true
                spacing:          10

                Text {
                  text:           "\ue8b2"
                  font.family:    Fonts.icon
                  font.pixelSize: 32
                  color:          Config.colors.warning
                }

                Text{
                    Layout.fillWidth: true
                    text:             (Session.rebootPending ? "Rebooting" : "Shutting down") +  " in ~1 minute\u2026"
                    color:            Config.colors.text
                    font.family:      Fonts.body
                    font.pixelSize:   12
                    wrapMode:         Text.WordWrap
                }
            }

            Item { Layout.fillHeight: true }    // pushes the button to the bottom

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight

                Components.IconTileButton {
                    id:               cancelButton
                    glyph:            "Cancel"
                    glyphFont:        Fonts.body
                    glyphSize:        12
                    implicitWidth:    70
                    implicitHeight:   26
                    onClicked:        Session.rebootPending ? Session.cancelReboot() : Session.cancelShutdown()
                }
            }
        }
    }

    Connections {
        target: Session
        function onRebootPendingChanged()  { (Session.rebootPending || Session.shutdownPending) ? chrome.open() : chrome.close() }
        function onShutdownPendingChanged(){ (Session.rebootPending || Session.shutdownPending) ? chrome.open() : chrome.close() }
    }
}
