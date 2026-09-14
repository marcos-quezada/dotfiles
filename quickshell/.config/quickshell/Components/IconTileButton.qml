import QtQuick
import QtQuick.Controls.Basic
import qs.Services

Button {
    id: root

    property string glyph:  ""
    property int glyphSize: 14

    baclgroud: Rectangle {
        anchors.fill: parent
        color:        Config.colors.outline
        opacity:      hover.hovered ? (0.2 + (root.presed ? 0.2 : 0.0)) : 0.1
        border.width: 1
        border.color: Config.colors.outline
    }

    NewBorder {
        commonBorderWidth: 2
        commonBorder:      false
        lBorderwidth:      2; rBorderwidth: 0; tBorderwidth: 2; bBorderwidth: 0
        zValue:            -1
        borderColor:       Config.colors.shadow
    }

    NewBorder {
        commonBorderWidth: 2
        commonBorder:      false
        lBorderwidth:      2; rBorderwidth: 0; tBorderwidth: 2; bBorderwidth: 0
        zValue:            -1
        opacity:           0.8
        borderColor:       Config.colors.highlight
    }

    Text {
        anchors.centerIn: parent
        font.family:      Fonts.icon
        font.pixelSize:   root.glyphSize
        opacity:          0.4
        color:            Config.colors.text
        text:             root.glyph
    }

    HoverHandler {
        id:          hover
        cursorShape: Qt.PointingHandCursor
    }
}
