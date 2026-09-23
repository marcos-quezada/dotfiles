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
        implicitHeight: Config.settings.bar.height 

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
              color:        "transparent"
              radius:       0
              border.width: 1
              border.color: Config.colors.outline
          }
        }

        RowLayout {
            id:                     leftCluster
            anchors.left:           parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin:     11
            spacing:                Config.settings.bar.spacing 

            Components.TaskbarButton {
                id:            sessionButton
                glyph:         "\uf900"
                isToggled:     Session.expanded
                triggerTarget: Session
                mapTarget:     taskbar.contentItem
                onClicked:     Popups.toggle("session")
            }

            Components.Separator {
                shadowColor:    Config.colors.shadow
                highlightColor: Config.colors.highlight
            }

            // workspaces panel — shadow-backed container for the workspace switcher
            Workspaces {
                id: workspaces
                anchors.leftMargin: 2
                anchors.rightMargin: 0
            }
            
            Components.Separator {
                shadowColor:    Config.colors.shadow
                highlightColor: Config.colors.highlight
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

        Components.TrackedBackground {
            id:           trayBg
            z:            -1
            target:       sysTray
            height:       Config.settings.bar.buttonSize + padding * 2
            y: (Config.settings.bar.height - height) / 2
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
