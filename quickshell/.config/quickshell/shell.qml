import QtQuick
import Quickshell
import Quickshell.Io

import "taskbar" as Taskbar
import "threatwatch" as ThreatWatch

Scope {
    id: root

    FontLoader {
        id: iconFont
        source: "fonts/MaterialSymbolsSharp_Filled_36pt-Regular.ttf"
    }
    FontLoader {
        id: fontMonaco
        source: "fonts/Monaco.ttf"
    }
    FontLoader {
        id: fontCharcoal
        source: "fonts/Charcoal.ttf"
    }

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
