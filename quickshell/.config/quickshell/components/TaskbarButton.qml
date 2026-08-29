import QtQuick
import QtQuick.Controls.Basic

import qs 

Button {
  id: root

  property bool isToggled: false
  property string glyph: ""
  property string toggledGlyph: glyph

  implicitWidth: 22
  implicitHeight: 22

  background: Rectangle {
    anchors.fill: parent
    border.width: 1
    border.color: root.isToggled ? Config.colors.accent : Config.colors.outline
    color: "transparent"
    opacity: hover.hovered ? 0.6 : 1

    Text {
      anchors.centerIn: parent
      font.family: Fonts.icon
      font.pixelSize: root.isToggled ? 18 : 14
      text: root.isToggled ? root.toggledGlyph : root.glyph
      color: root.isToggled ? Config.colors.accent : Config.colors.text
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }
}
