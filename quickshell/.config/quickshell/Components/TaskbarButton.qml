import QtQuick
import QtQuick.Controls.Basic

import qs.Services

Button {
  id: root

  property bool isToggled: false
  property string glyph: ""
  property string toggledGlyph: glyph

  // when set, this button reports its own screen space x (mapped into
  // mapTarget) onto triggerTarget.triggerX - the position popups read to
  // anchor themselves under whichever button opened them.
  property var triggerTarget: null
  property var mapTarget:     null

  implicitWidth:  Config.settings.bar.buttonSize
  implicitHeight: Config.settings.bar.buttonSize

  Binding {
        target:   root.triggerTarget
        property: "triggerX"
        when:     root.triggerTarget !== null && root.mapTarget !== null
        value:    {
            root.x
            root.mapTarget ? root.mapToItem(root.mapTarget, 0, 0).x : 0
        }
  }

  background: Rectangle {
    anchors.fill: parent
    color: "transparent"
    opacity: hover.hovered ? 0.6 : 1
    
    // full outline - shadow normally, swaps when toggled
    NewBorder {
        commonBorderWidth: 1
        commonBorder:      false
        lBorderwidth:      1; rBorderwidth: 1; tBorderwidth: 1; bBorderwidth: 1
        zValue:            -1
        borderColor:       root.isToggled ? Config.colors.highlight : Config.colors.shadow
    }

    NewBorder {
        commonBorderWidth: 1
        commonBorder:      false
        lBorderwidth:      root.isToggled ? 0 : 1
        rBorderwidth:      root.isToggled ? 1 : 0
        tBorderwidth:      root.isToggled ? 0 : 1
        bBorderwidth:      root.isToggled ? 1 : 0
        zValue:            -1
        opacity:           0.8
        borderColor:       root.isToggled ? Config.colors.shadow : Config.colors.highlight
    }

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
