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

        Rectangle {
            id: workspacesBg
            z:  -1
            readonly property int padding: 4
            x: {
                workspaces.x
                return workspaces.mapToItem(taskbar.contentItem, 0, 0).x - padding
            }
            y: {
                workspaces.y
                return workspaces.mapToItem(taskbar.contentItem, 0, 0).y -padding
            }
            width:        workspaces.width  + padding * 2
            height:       workspaces.height + padding * 2
            color:        Config.colors.shadow
            border.width: 1
            border.color: Config.colors.outline
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
            Workspaces {
                id: workspaces
                anchors.leftMargin: 2
                anchors.rightMargin: 0
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

        // system tray background - independent layer tracking the real SysTray
        // geometry directly, same pattern as workspacesBg above
        Rectangle {
            id: trayBg
            z:  -1
            readonly property int padding: 4
            x: {
                sysTray.x
                return sysTray.x - padding
            }
            y: {
                sysTray.y
                return sysTray.y - padding
            }
            width:        sysTray.width  + padding * 2
            height:       sysTray.height + padding * 2
            color:        Config.colors.shadow
            border.width: 1
            border.color: Config.colors.outline
        }  

        SysTray {
            id: sysTray
        }
      }
    }
  }
}
