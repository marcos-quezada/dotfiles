import Quickshell
import Quickshell.I3
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

import ".."

RowLayout {
    id: workspaces
    spacing: 3
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter

    property var currentWorkspaces: I3.workspaces.values.filter(w => w.monitor.name == taskbar.screen.name)


    Repeater { 
        model: parent.currentWorkspaces
        Button {
            id: control

            anchors.centerIn: parent.centerIn
            contentItem: Text {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.number
                font.family: fontMonaco.name
                width: 10
                height: 10
                font.pixelSize: Config.settings.bar.fontSize
                color: Config.colors.text
            }
            onPressed: I3.dispatch(`workspace ` + modelData.number)
            NewBorder {
                commonBorderWidth: 2
                commonBorder: false
                lBorderwidth: -2
                rBorderwidth: 0
                tBorderwidth: -4
                bBorderwidth: -1
                borderColor: Config.colors.outline
                zValue: -1
            }

            background: Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                border.width: 1
                border.color: Config.colors.outline
                width: 22
                height: 22
                color: (modelData.active || mouse.hovered) ? Config.colors.shadow : (modelData.urgent ? Config.colors.urgent : Config.colors.base)
            }

            HoverHandler {
                id: mouse
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
