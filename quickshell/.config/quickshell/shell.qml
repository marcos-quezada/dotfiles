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
  // ThreatWatchPopup is a PanelWindow — must live here at root scope.
  // Wayland protocol forbids nesting WlrLayershell surfaces inside another
  // PanelWindow, so it cannot go inside Bar.qml or SysTray.qml.
  ThreatWatch.ThreatWatchPopup {}

}
