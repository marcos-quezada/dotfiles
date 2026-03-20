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

        // taskbar background — double NewBorder layers produce the shadow/highlight bevel
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

        // workspaces panel — shadow-backed container for the workspace switcher
        Item {
            id: workspacesPanel
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            height: parent.height - 8
            anchors.leftMargin: 11
            width: workspaces.width + 5
            Rectangle {
                id: workspacesBg
                anchors.fill: workspacesPanel

                anchors.bottomMargin: -2
                color: "transparent"
                Rectangle {
                    anchors.fill: workspacesBg
                    border.width: 0
                    color: Config.colors.shadow
                }
                Rectangle {
                    anchors.fill: workspacesBg
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

        // system tray panel — same shadow treatment, anchored right for clock + widgets
        Item {
            id: trayPanel
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12
            height: parent.height - 8
            width: sysTray.width + 18
            Rectangle {
                id: trayBg
                anchors.fill: trayPanel

                anchors.bottomMargin: -2
                color: "transparent"
                Rectangle {
                    anchors.fill: trayBg
                    border.width: 0
                    color: Config.colors.shadow
                }
                Rectangle {
                    anchors.fill: trayBg
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
      }
    }
  }
}
