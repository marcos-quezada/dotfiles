import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import qs.Components as Components
import qs.Services

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
          Components.NewBorder {
            commonBorderWidth: 4
            commonBorder: false
            lBorderwidth: 10
            rBorderwidth: 1 
            tBorderwidth: 10
            bBorderwidth: 1
            borderColor: Config.colors.shadow
          }
          Components.NewBorder {
            commonBorderWidth: 4
            commonBorder: false
            lBorderwidth: 10
            rBorderwidth: 10
            tBorderwidth: 1
            bBorderwidth: 10
            borderColor: Config.colors.highlight
          }

          Rectangle {
              id: barBackground
              anchors {
                  fill: parent
                  margins: 0
                }
              color: "transparent"
              radius: 0
              border.width: 1
              border.color: Config.colors.outline
          }
        }

        RowLayout {
            id:                     leftCluster
            anchors.left:           parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin:     11
            spacing:                11 

            Components.TaskbarButton {
                id:            sessionButton
                glyph:         "\uf900"
                isToggled:     Session.expanded
                triggerTarget: Session
                mapTarget:     taskbar.contentItem
                onClicked:     Popups.toggle("session")
            }

            // workspaces panel — shadow-backed container for the workspace switcher
            Item {
                id:                     workspacesPanel
                Layout.preferredHeight: taskbar.height - 8
                Layout.preferredWidth:  workspaces.width + 5

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

            // threat watch button - toggle button to show the threatwatch map
            Components.TaskbarButton {
                id:            threatWatchButton
                glyph:         "\u{f1863}"
                isToggled:     ThreatWatchModel.mapExpanded
                triggerTarget: ThreatWatchModel
                mapTarget:     taskbar.contentItem
                onClicked:     Popups.toggle("threatwatch")
            }

            Components.TaskbarButton {
                id:            playlistButton
                glyph:         "\ue405"
                isToggled:     Playlist.expanded
                triggerTarget: Playlist
                mapTarget:     taskbar.contentItem
                onClicked:     Popups.toggle("playlist") 
            }

            Components.TaskbarButton {
                id:            soundButton
                glyph:         "\ue050"
                isToggled:     Sound.expanded
                triggerTarget: Sound
                mapTarget:     taskbar.contentItem
                onClicked:     Popups.toggle("sound")
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
