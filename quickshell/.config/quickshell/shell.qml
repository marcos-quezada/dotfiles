import QtQuick
import Quickshell

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
}
