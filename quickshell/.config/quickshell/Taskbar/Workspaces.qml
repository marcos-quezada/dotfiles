// Workspaces.qml - workspace switcher. must be instantiated inline inside
// Bar.qml - relies on an ancestor `id: taskbar`being in scope.

import Quickshell.I3
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

import qs.Services

RowLayout {
    id: workspaces
    spacing: 3
    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

    property var currentWorkspaces: I3.workspaces.values.filter(w => w.monitor.name == taskbar.screen.name)


    Repeater { 
        model: parent.currentWorkspaces
        Button {
            id:               control
            Layout.alignment: Qt.AlignVCenter
            contentItem: Text {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.number
                font.family: Fonts.body
                width: 10
                height: 10
                font.pixelSize: Config.settings.bar.fontSize
                color: Config.colors.text

                Rectangle { anchors.fill: parent; color: "#00ff00"; opacity: 0.5; z: -1 }
            }
            onPressed: I3.dispatch(`workspace ` + modelData.number)

            background: Rectangle {
                anchors.verticalCenter:   parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                border.width:             1
                border.color:             Config.colors.outline
                width:                    22
                height:                   22
                color:                    (modelData.active || mouse.hovered) ? Config.colors.shadow : (modelData.urgent ? Config.colors.urgent : Config.colors.base)
                
                Rectangle { anchors.fill: parent; color: "#ff00ff"; opacity: 0.3; z: -1 }
            }

            HoverHandler {
                id: mouse
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
