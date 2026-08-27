pragma Singleton
import QtQuick
import Quickshell

// Fonts.qml - single source of truth for font resources, mirroring how
// Config.qml centralizes colours. Widgets reference semantic role here
// instead of reaching for a raw FontLoader id directly.
Singleton {
    id: root

    FontLoader {
      id:     bodyLoader
      source: "fonts/Monaco.ttf"
    }
    FontLoader {
      id:     iconLoader
      source: "fonts/MaterialSymbolsSharp_Filled_36pt-Regular.ttf"
    }
    FontLoader {
      id:     titleLoader
      source: "fonts/Charcoal.ttf"
    }

    readonly property string body:  bodyLoader.name
    readonly property string icon:  iconLoader.name
    readonly property string title: titleLoader.name

    // convenience array - pick a single entry per call site; this build's
    // Qt/QML does not support the list-valued font.families property, so
    // this is not a native fallback chain, just [icon, body] for reference
    readonly property var iconBody: [iconLoader.name, bodyLoader.name]
}
