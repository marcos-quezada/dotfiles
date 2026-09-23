import QtQuick
import QtQuick.Layouts

RowLayout {
    id:                     sysTrayRow
    anchors.right:          parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin:    12
    spacing:                8

    NowPlaying {}

    ClockWidget {
      id: clockWidget
    }
}
