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
  // popups must live at root scope — WlrLayershell surfaces cannot be nested inside Bar's PanelWindow
  ThreatWatch.ThreatWatchPopup {}
  ThreatWatch.ThreatWatchMarketsPopup {}

}
