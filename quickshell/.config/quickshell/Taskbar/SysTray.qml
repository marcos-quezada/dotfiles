import QtQuick
import QtQuick.Layouts

RowLayout {
    id:                     sysTrayRow
    anchors.right:          parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin:    12
    spacing:                8

    Rectangle { anchors.fill: parent; color: "#ff00ff"; z: -1 }

    NowPlaying {}

    ClockWidget {
      id: clockWidget
    }
}
