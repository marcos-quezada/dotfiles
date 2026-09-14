import QtQuick
import qs.Services

Rectangle {
    id : root

    property bool selected: false
    signal clicked()

    default property alias content: contentItem.data

    color:        root.selected ? Config.colors.highlight : "transparent"
    border.width: 1
    border.color: root.selected ? Config.colors.outline : "transparent"
    opacity:      hover.hovered ? 0.75 : 1

    Item {
        id:              contentItem
        anchors.fill:    parent
        anchors.margins: 4
    }

    MouseArea {
        anchors.fill: parent
        z:            -1
        onClicked:    root.clicked()
    }

    HoverHandler {
        id: hover
    }
}
