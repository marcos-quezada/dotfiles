pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property string current: ""   // "" | "threatwatch" | "playlist" | "sound"

    function toggle(name) {
        root.current = (root.current === name) ? "" : name
    }
}
