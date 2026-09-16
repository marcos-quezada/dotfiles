pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool expanded: Popups.current === "session"
    property real trgiggerX:         0

    property bool rebootPending:   false
    property bool shutdownPending: false

    Process { id: rebootProc }
    Process { id: shutdownProc }
    Process { id: suspendProc }

    function reboot(minutes) {
        rebootProc.command = ["shutdown", "-r", "+" + minutes, "reboot requested from quickshell"]
        rebootProc.running = true
        root.rebootPending = true
    }

    function cancelReboot() {
        rebootProc.running = false    // SIGTERM, per shutdown(8)'s own cancellation mechanism
        root.rebootPending = false
    }

    function shutdown(minutes) {
        shutdownProc.command = ["shutdown", "-p", "+" + minutes, "shutdown requested from qucickshell"]
        shutdownProc.running = true
        root.shutdownPending = true
    }

    function cancelShutdown() {
        shutdownProc.running = false
        root.shutdownPending = false
    }

    function suspend() {
        suspendProc.command = ["acpiconf", "-s", "3"]
        suspendProc.running = true
    }
}
