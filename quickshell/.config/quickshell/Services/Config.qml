pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  component ThemePalette: QtObject {
      property color base
      property color shadow
      property color highlight
      property color urgent
      property color accent
      property color accentDark
      property color text
      property color textLight
      property color outline
      property color outlineGradientFade
      property color danger
      property color warning
  }

  ThemePalette {
      id:                  themeDefault
      base:                "#d8d8d8"
      shadow:              "#9b9b9b"
      highlight:           "#efefef"
      urgent:              "#ff723e"
      accent:              "#207874"
      accentDark:          "#14514d"
      text:                "#000000"
      textLight:           "#f8f8f8"
      danger:              "#c63b30"
      warning:             "#d08a2f"
      outline:             "#000000"
      outlineGradientFade: "#161616"
  }

  ThemePalette {
      id:                  themeYorha
      base:                "#d9caba"
      shadow:              "#baafa1"
      highlight:           "#f0e2d3"
      urgent:              "#ff854c"
      accent:              "#626335"
      accentDark:          "#494a25"
      text:                "#3e3d38"
      textLight:           "#f5ede2"
      danger:              "#b84a3a"
      warning:             "#b68d43"
      outline:             "#3d3d39"
      outlineGradientFade: "#5b5b45"
  }
  
  ThemePalette {
      id:                  themeCherry
      base:                "#f4c9ef"
      shadow:              "#c7a4cc"
      highlight:           "#f9d0f7"
      urgent:              "#ff936c"
      accent:              "#c950bb"
      accentDark:          "#98348c"
      text:                "#321d32"
      textLight:           "#fff5ff"
      danger:              "#cf4f6a"
      warning:             "#d58a3a"
      outline:             "#20091d"
      outlineGradientFade: "#3e233e"
  }
  
  ThemePalette {
      id:                  themeIndigo
      base:                "#bac4e6"
      shadow:              "#7e8bad"
      highlight:           "#d0def9"
      urgent:              "#e83939"
      accent:              "#3e7c99"
      accentDark:          "#2b5a73"
      text:                "#0d0d19"
      textLight:           "#f3f6ff"
      danger:              "#c33434"
      warning:             "#c28a2c"
      outline:             "#1a2135"
      outlineGradientFade: "#223143"
  }

  ThemePalette {
      id:                  themeGleep
      base:                "#bae6c5"
      shadow:              "#93c48c"
      highlight:           "#ccf9e7"
      urgent:              "#ff7559"
      accent:              "#3e9949"
      accentDark:          "#2b7034"
      text:                "#0d1913"
      textLight:           "#f3fff7"
      danger:              "#c94f45"
      warning:             "#b08a2f"
      outline:             "#21351a"
      outlineGradientFade: "#284223"
    }

  function paletteFor(name: string): ThemePalette {
      switch (name) {
      case "yorha":   return themeYorha
      case "cherry":  return themeCherry
      case "indigo":  return themeIndigo
      case "gleep":   return themeGleep
      default:        return themeDefault
      }
  }

  property ThemePalette colors: paletteFor(settings.currentTheme)
  
  property alias settings: settingsJsonAdapter.settings
  FileView {
    path: Qt.resolvedUrl("./settings.json")
    // when changes are made on disk, reload the file's content
    watchChanges: true
    onFileChanged: reload()
    // when changes are made to properties in the adapter, save them
    onAdapterUpdated: writeAdapter()

    onLoadFailed: error => {
        if (error == FileViewError.FileNotFound) {
            writeAdapter();
        }
    }

    JsonAdapter {
        id: settingsJsonAdapter
        property AppSettings settings: AppSettings{}
    }
  }

  component AppSettings: JsonObject {
      property string version: "0.1"
    property string currentTheme: "default"
    property BarSettings bar: BarSettings{}

    onCurrentThemeChanged: {
        console.info("Updated theme to: " + currentTheme);
    }

  }

  component BarSettings: JsonObject {
      property int fontSize: 12

  }
}
