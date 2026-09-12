pragma ComponentBehavior: Bound

// PlaylistPopup.qml - view/play/remove saved tracks, add a local file manually.
// must be instantiated at shell.qml root scope - cannot nest inside Bar's PanelWindow

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Wayland

import qs.Components as Components
import qs.Services

PanelWindow {
    id: popup

    visible: Playlist.expanded

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth:  400
    implicitHeight: 420
    anchors {
        top:  true
        left: true
    }
    margins.top:  35
    margins.left: Playlist.triggerX

    color: "transparent"

    property int selectedIndex: -1
   
    Components.PopupFrame {
        id:    chrome
        title: "PLAYLIST"
        icon:  "\ue405"

        ColumnLayout {
            anchors.fill: parent
            spacing:      6

            // ── status line ─ visible only while a download is in progress ──
            Text {
                Layout.fillWidth: true
                visible:          Playlist._downloading
                text:             "downloading: " + Playlist._currentUrl
                color:            Config.colors.text
                font.family:      Fonts.body
                font.pixelSize:   11
                elide:            Text.ElideMiddle
            }

            // ── transport controls ──────────────────────────────────────────   
            RowLayout {
                Layout.fillWidth: true
                spacing:          4

                Button {
                    text:           "\u23ee"
                    enabled:        Players.active !== null
                    implicitWidth:  22
                    implicitHeight: 22
                    onClicked:      Players.previous()
                }
                Button {
                    text:           Players.isPlaying ? "\u23f8" : "\u25b6"
                    enabled:        Players.active !==null || popup.selectedIndex !== -1
                    implicitWidth:  22
                    implicitHeight: 22
                    onClicked:      {
                        if (Players.active !== null) Players.togglePlaying()
                        else if (popup.selectedIndex !== -1) Playlist.playAll(popup.selectedIndex)
                    }
                }
                Button {
                    text:           "\u23ed"
                    enabled:        Players.active !== null
                    implicitWidth:  22
                    implicitHeight: 22
                    onClicked:      Players.next()
                }
                Button {
                    text:           "shuffle"
                    checkable:      true
                    checked:        Players.shuffle
                    enabled:        Players.shuffleSupported
                    onClicked:      Players.toggleShuffle()
                }
                Button {
                    text:           Players.loopLabel
                    enabled:        Players.loopSupported
                    onClicked:      Players.cycleLoop()
                }
            }            


            // ── track list ──────────────────────────────────────────────────
            ListView {
                id:                trackList
                Layout.fillWidth:  true
                Layout.fillHeight: true
                clip:              true
                model:             Playlist.tracks

                delegate: Rectangle {
                    id:     row
                    required property var modelData
                    required property int index
                    width:  trackList.width
                    height: 26
                    color:  popup.selectedIndex === index ? Config.colors.highlight : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        spacing:      6

                        Text {
                            Layout.fillWidth: true
                            text:             row.modelData.title
                            color:            Config.colors.text
                            font.family:      Fonts.body
                            font.pixelSize:   12
                            elide:            Text.ElideRight
                        }

                        Button {
                            text:           "\u2715"    // remove glyph
                            implicitWidth:  22
                            implicitHeight: 22
                            onClicked:      Playlist.removeAt(row.index)
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        z:            -1    // behind the remove button, so  it doesn't steal its clicks
                        onClicked:     popup.selectedIndex = row.index
                    }
                }
            }

            //── manual add: paste a local file path ─────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing:          4

                TextField {
                    id:               pathInput
                    Layout.fillWidth: true
                    placeholderText:  "/path/to/local/file.m4a"
                    font.family:      Fonts.body
                    font.pixelSize:   11
                }

                Button {
                    text:      "add"
                    onClicked: {
                        if (pathInput.text !== "") {
                            Playlist.addLocalFile(pathInput.text)
                            pathInput.text = ""
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z:            -1
            onClicked:    Playlist.expanded = false
        }
    }
    
    Connections {
        target: Playlist
        function onExpandedChanged() {
            if (Playlist.expanded) chrome.open()
            else chrome.close()
        }
    }
}
