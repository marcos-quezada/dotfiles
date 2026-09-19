pragma ComponentBehavior: Bound

// PowerPopup.qml - suspend/reboot/shutdown, with a cancelable delay for the
// latter two (shutdown(8)'s own native scheduling, not custom countown logic).
// must be instantiated at shell.qml root scope - cannot nest inside Bar's PanelWindow

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.Components as Components
import qs.Services

PanelWindow {
    id: popup

    visible: Session.expanded

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth:  220
    implicitHeight: 100
    anchors {
        top:  true
        left: true
    }
    margins.top:  35
    margins.left: Session.triggerX
    
    color: "transparent"

    Components.PopupFrame {
        id:    chrome
        title: "SESSION"
        icon:  "\uf900"

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 6
            spacing:         8

            RowLayout {
                Layout.fillWidth:  true
                Layout.alignment: Qt.AlignHCenter
                spacing:           10

                Components.IconTileButton {
                    glyph:          "\u23fe"    // power sleep symbol
                    glyphFont:      Fonts.body
                    glyphSize:      28
                    implicitWidth:  50
                    implicitHeight: 50
                    onClicked:      Session.suspend()
                }
                Components.IconTileButton {
                    glyph:          "\ue028"    // clockwise open circle arrow
                    glyphFont:      Fonts.body
                    glyphSize:      28
                    implicitWidth:  50
                    implicitHeight: 50
                    onClicked:      Session.reboot(1)
                }
                Components.IconTileButton {
                    glyph:          "\u23fb"    // power symbol
                    glyphFont:      Fonts.body
                    glyphSize:      20
                    implicitWidth:  50
                    implicitHeight: 50
                    onClicked:      Session.shutdown(1)
                }
            }
       }

        MouseArea {
            anchors.fill: parent
            z:            -1
            onClicked:    Popups.current = ""
        }
    }

    Connections {
        target:Session 
        function onExpandedChanged() {
            if (Session.expanded) chrome.open()
            else chrome.close()
        }
    }
}
