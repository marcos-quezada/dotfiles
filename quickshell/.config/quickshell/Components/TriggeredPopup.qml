// TriggeredPopup.qml - shared chrome+window wrapper for the toggle triggered
// popups (ThreatWatch/Playlist/Sound/Session). Bundles the PanelWindow setup,
// PopupFrame instantiation, open/close wiring, and click outside to dismiss
// in one place instead of copied per popup - each popup file becomes just
// its own content plus a few bound properties.
//
// dismissing always goes through Popups.current = "", matching how every 
// popup's own `expanded` is itself derived from Popups.current - not each
// popups's own (often read-only) expanded property directly.
//
// usage:
//  TriggeredPopup {
//      expanded:       Playlist.expanded
//      triggerX:       Playlist.triggerX
//      title:          "PLAYLIST"
//      icon:           "\ue405"
//      implicitWidth:  400
//      implicitHeight: 420
//      // content goes here as direct children
//  }

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.Services

PanelWindow {
    id: popup

    property bool  expanded: false
    property real  triggerX: 0
    property alias title:    chrome.title
    property alias icon:     chrome.icon
    default property alias content: chrome.content

    visible: expanded

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; left: true }
    margins.top:  35
    margins.left: triggerX
    color:        "transparent"

    PopupFrame {
        id: chrome
    }

    MouseArea {
        anchors.fill: parent
        z:            -1
        onClicked:    Popups.current=""
    }

    onExpandedChanged: {
        if (expanded) chrome.open()
        else chrome.close()
    }
}
