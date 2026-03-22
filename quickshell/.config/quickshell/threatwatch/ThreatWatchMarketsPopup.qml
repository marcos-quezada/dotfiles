// ThreatWatchMarketsPopup.qml — geopolitical prediction markets panel (right-click).
// must be instantiated at shell.qml root scope — same WlrLayershell constraint as
// ThreatWatchPopup. see docs/architecture.md.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "."

PanelWindow {
    id: popup

    // driven by the singleton — ThreatWatchWidget toggles marketsExpanded
    visible: ThreatWatchModel.marketsExpanded

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // panel sits top-right just below the bar, same as the map popup.
    // width is fixed; height is content-driven via implicitHeight binding.
    implicitWidth:  360
    implicitHeight: panel.implicitHeight

    anchors {
        top:    true
        bottom: false
        left:   false
        right:  true
    }
    margins.top: 35

    color: "transparent"

    // click background to close
    MouseArea {
        anchors.fill: parent
        onClicked:    ThreatWatchModel.marketsExpanded = false
    }

    // ── panel card ────────────────────────────────────────────────────────────

    Rectangle {
        id:     panel
        width:  popup.implicitWidth
        color:  "#f0f0f0"
        radius: 6
        border.color: "#b0b0b0"
        border.width: 1

        // height: header + rows + divider + footer; min so empty state is readable
        implicitHeight: headerRow.implicitHeight
                        + rowList.implicitHeight
                        + 1              // divider
                        + footer.implicitHeight
                        + 24             // top/bottom padding (12 each)

        // ── header ────────────────────────────────────────────────────────────

        RowLayout {
            id:            headerRow
            width:         parent.width - 24
            x:             12
            y:             12
            spacing:       8

            Text {
                text:           "Geopolitical markets"
                font.pixelSize: 13
                font.bold:      true
                color:          "#1a1a1a"
                Layout.fillWidth: true
            }

            // close button — small ×
            Text {
                text:           "×"
                font.pixelSize: 16
                color:          "#666666"

                MouseArea {
                    anchors.fill: parent
                    onClicked:    ThreatWatchModel.marketsExpanded = false
                }
            }
        }

        // ── market rows ───────────────────────────────────────────────────────

        ListView {
            id:            rowList
            x:             12
            y:             headerRow.y + headerRow.implicitHeight + 8
            width:         parent.width - 24
            // sum of all delegate heights — no scrolling needed for ≤20 entries
            implicitHeight: contentHeight
            interactive:   false
            model:         ThreatWatchModel.markets

            delegate: Item {
                width:          rowList.width
                implicitHeight: rowLayout.implicitHeight + 6
                height:         implicitHeight

                RowLayout {
                    id:      rowLayout
                    width:   parent.width
                    y:       3
                    spacing: 8

                    // probability bar + percentage
                    Rectangle {
                        width:  60
                        height: 14
                        radius: 3
                        color:  "#e0e0e0"
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width:  Math.max(4, parent.width * (modelData.prob_yes / 100))
                            height: parent.height
                            radius: parent.radius
                            // colour: green below 30%, amber 30–60%, red above
                            color: modelData.prob_yes >= 60 ? "#cc3300"
                                 : modelData.prob_yes >= 30 ? "#cc7700"
                                 : "#336600"
                        }

                        Text {
                            anchors.centerIn: parent
                            text:             Math.round(modelData.prob_yes) + "%"
                            font.pixelSize:   10
                            font.bold:        true
                            color:            "#1a1a1a"
                        }
                    }

                    // market title — wraps to multiple lines if needed
                    Text {
                        text:           modelData.title
                        font.pixelSize: 12
                        color:          "#1a1a1a"
                        wrapMode:       Text.WordWrap
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // ── divider ───────────────────────────────────────────────────────────

        Rectangle {
            id:     divider
            x:      12
            y:      rowList.y + rowList.implicitHeight + 4
            width:  parent.width - 24
            height: 1
            color:  "#cccccc"
        }

        // ── footer: last updated ──────────────────────────────────────────────

        Text {
            id:             footer
            x:              12
            y:              divider.y + divider.height + 6
            width:          parent.width - 24
            text:           ThreatWatchModel.updatedAt !== ""
                                ? "Updated " + ThreatWatchModel.updatedAt
                                : "No data yet — middle-click to fetch."
            font.pixelSize: 11
            color:          "#666666"
            implicitHeight: contentHeight + 12   // +12 accounts for bottom padding
        }
    }
}
