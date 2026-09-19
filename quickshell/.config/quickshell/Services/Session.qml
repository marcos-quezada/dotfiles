pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool expanded: Popups.current === "session"
    property real triggerX:         0

    property bool rebootPending:   false
    property bool shutdownPending: false

    Process { id: rebootProc }
    Process { id: shutdownProc }
    Process { id: suspendProc }
    Process { id: cancelProc }

    function reboot(minutes) {
        rebootProc.command = ["shutdown", "-r", "+" + minutes, "reboot requested from quickshell"]
        rebootProc.running = true
        root.rebootPending = true
        Popups.current     = ""
    }

    function cancelReboot() {
        cancelProc.command = ["pkill", "shutdown"]
        cancelProc.running = true 
        root.rebootPending = false
    }

    function shutdown(minutes) {
        shutdownProc.command = ["shutdown", "-p", "+" + minutes, "shutdown requested from quickshell"]
        shutdownProc.running = true
        root.shutdownPending = true
        Popups.current       = ""
    }

    function cancelShutdown() {
        cancelProc.command = ["pkill", "shutdown"]
        cancelProc.running = true
        root.shutdownPending = false
    }

    function suspend() {
        suspendProc.command = ["acpiconf", "-s", "3"]
        suspendProc.running = true
        Popups.current      = ""
    }
}
