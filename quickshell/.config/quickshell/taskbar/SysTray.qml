import QtQuick
import QtQuick.Layouts

RowLayout {
    id: sysTrayRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: 12

    ClockWidget {
      id: clockWidget
    }
}
