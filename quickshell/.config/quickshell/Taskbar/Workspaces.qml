// Workspaces.qml - workspace switcher. must be instantiated inline inside
// Bar.qml - relies on an ancestor `id: taskbar`being in scope.

import Quickshell.I3
import QtQuick
import QtQuick.Layouts

import qs.Components as Components
import qs.Services

RowLayout {
    id: workspaces
    spacing: 3
    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

    property var currentWorkspaces: I3.workspaces.values.filter(w => w.monitor.name == taskbar.screen.name)


    Repeater { 
        model: parent.currentWorkspaces
        Components.TaskbarButton {
            Layout.alignment: Qt.AlignVCenter
            label:            String(modelData.number)
            isToggled:        modelData.active
            isUrgent:         modelData.urgent
            onClicked:        I3.dispatch(`workspace ` + modelData.number)
        }
    }
}
