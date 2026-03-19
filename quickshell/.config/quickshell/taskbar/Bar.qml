import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

import ".."

Scope {
  Variants {
    model: Quickshell.screens
    Item {
      id: root
      required property var modelData

      PanelWindow {
        id: taskbar
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
          top: true
          left: true
          right: true
        }
        implicitHeight: 35

        /*=== Taskbar Background (colors & shading) ===*/
        color: Config.colors.base
        Item {
          id: taskbarBackground
          anchors.fill: parent
          NewBorder {
            commonBorderWidth: 4
            commonBorder: false
            lBorderwidth: 10
            rBorderwidth: 1
            tBorderwidth: 10
            bBorderwidth: 1
            borderColor: Config.colors.shadow
          }
          NewBorder {
            commonBorderWidth: 4
            commonBorder: false
            lBorderwidth: 10
            rBorderwidth: 1
            tBorderwidth: 10
            bBorderwidth: 1
            borderColor: Config.colors.highlight
          }
        }

        /*=== ===================================== ===*/

        /*=== Workspaces & Background for it ===*/
        Item {
            id: test2
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            height: parent.height - 8
            anchors.leftMargin: 11
            width: workspaces.width + 5
            Rectangle {
                id: background2
                anchors.fill: test2

                anchors.bottomMargin: -2
                color: "transparent"
                Rectangle {
                    anchors.fill: background2
                    border.width: 0
                    color: Config.colors.shadow
                }
                Rectangle {
                    anchors.fill: background2
                    color: "transparent"
                    border.width: 1
                    z: -5
                    anchors.margins: -1
                    anchors.bottomMargin: 1
                }
            }
            Workspaces {
                id: workspaces
                anchors.leftMargin: 2
                anchors.rightMargin: 0
            }
        }
        /*=== ============================== ===*/

        /*=== System Tray & Background for it ===*/
        Item {
            id: test
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12
            height: parent.height - 8
            width: sysTray.width + 18
            Rectangle {
                id: background
                anchors.fill: test

                anchors.bottomMargin: -2
                color: "transparent"
                Rectangle {
                    anchors.fill: background
                    border.width: 0
                    color: Config.colors.shadow
                }
                Rectangle {
                    anchors.fill: background
                    color: "transparent"
                    border.width: 1
                    z: -5
                    anchors.margins: -1
                    anchors.bottomMargin: 1
                }
            }
            SysTray {
                id: sysTray
            }
        }
        /*=== =============================== ===*/
      }
    }
  }
}
