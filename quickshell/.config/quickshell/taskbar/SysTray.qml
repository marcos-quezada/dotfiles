import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import QtQuick.Effects

import ".."
import "../threatwatch" as ThreatWatch

RowLayout {
    id: sysTrayRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: 12

    // threatwatch bar button — sits left of the clock, same row.
    // ThreatWatchModel (singleton) is instantiated automatically by Quickshell
    // when ThreatWatchWidget is first used — no manual registration needed.
    ThreatWatch.ThreatWatchWidget {
        id: threatWatchWidget
    }

    ClockWidget {
      id: clockWidget
    }
}
