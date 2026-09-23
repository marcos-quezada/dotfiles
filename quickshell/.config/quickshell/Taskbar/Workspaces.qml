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
        Rectangle {
            id:               control
            Layout.alignment: Qt.AlignVCenter
            width:            22
            height:           22
            border.width:     1
            border.color:     Config.colors.outline
            color:            (modelData.active || mouseArea.containsMouse) ? Config.colors.shadow : (modelData.urgent ? Config.colors.urgent : Config.colors.base)

            Text {
                anchors.centerIn: parent
                text: modelData.number
                font.family: Fonts.body
                font.pixelSize: Config.settings.bar.fontSize
                color: Config.colors.text
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: I3.dispatch(`workspace ` + modelData.number)
            }
        }
    }
}
