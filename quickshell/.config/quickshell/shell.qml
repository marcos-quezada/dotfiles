import QtQuick
import Quickshell
import Quickshell.Io

import "taskbar" as Taskbar
import "threatwatch" as ThreatWatch

Scope {
    id: root

    Taskbar.Bar {}

    // must live at root scope — WlrLayershell surfaces cannot nest inside another PanelWindow
    ThreatWatch.ThreatWatchPopup {}

    // IPC handler — allows manual reload from the terminal via:
    //   qs ipc call shell reload       (soft: reuses existing windows)
    //   qs ipc call shell hardReload   (hard: destroys and recreates all windows)
    // useful when watchFiles is disabled or for scripted workflows.
    IpcHandler {
        target: "shell"
        function reload(): void     { Quickshell.reload(false) }
        function hardReload(): void { Quickshell.reload(true)  }
    }
}
