// PopupFrame.qml — reusable win95-style chrome for popup windows.
//
// usage:
//   PopupFrame {
//       id: chrome
//       title: "MY PANEL"
//       icon:  "󱡣"          // nerd-font / material symbol codepoint
//       // content goes here as direct children — lands in the inset content area
//       Image { ... }
//       MouseArea { ... }
//   }
//
// callers animate visibility via chrome.open() / chrome.close().
// the content area is inset: top = titleBarHeight + 6px, sides/bottom = 6px.
//
// title bar decoration: 4 × 2px solid strips either side of the icon/title,
// filled with Config.colors.shadow — darker than base, matching the reference.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    anchors.fill: parent
    color: Config.colors.base
    opacity: 0

    // public api
    property string title: "Window"
    property string icon:  ""

    // open/close called by the host PanelWindow's Connections block
    function open() {
        fadeOut.running = false
        fadeIn.running  = true
    }
    function close() {
        fadeIn.running  = false
        fadeOut.running = true
    }

    // content slot — children of PopupFrame land here
    default property alias content: contentArea.data

    // title bar height — also used as the top offset in all NewBorder inset layers
    readonly property int titleBarHeight: 20

    // ── fade animation ────────────────────────────────────────────────────────

    OpacityAnimator on opacity {
        id: fadeIn
        running: false
        from:     0;  to: 1
        duration: 140
        easing.type: Easing.OutCubic
    }

    OpacityAnimator on opacity {
        id: fadeOut
        running: false
        from:     1;  to: 0
        duration: 80
        easing.type: Easing.InOutQuad
    }

    // ── title bar decoration strips ───────────────────────────────────────────
    // 4 × 2px solid horizontal strips, shadow colour (darker than base).

    component DecoStrips: Item {
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight

        ColumnLayout {
            id: col
            anchors.fill: parent
            spacing: 1

            Repeater {
                model: 4
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight:   2
                    color: Config.colors.shadow
                }
            }
        }
    }

    // ── title bar ─────────────────────────────────────────────────────────────

    Item {
        id: titleBar
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        implicitHeight: root.titleBarHeight

        RowLayout {
            anchors.fill: parent
            spacing: 4

            // left strips
            DecoStrips {}

            Text {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                font.family:    iconFont.name
                font.pixelSize: 14
                opacity: 0.8
                text:  root.icon
                color: Config.colors.text
            }

            Text {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                font.family:    fontCharcoal.name
                font.pixelSize: 12
                text:  root.title
                color: Config.colors.text
            }

            // right strips
            DecoStrips {}
        }
    }

    // ── border stack ──────────────────────────────────────────────────────────
    // win95 bevel: asymmetric widths create the raised/lowered 3-d illusion.
    // zValue: 10 on all layers so chrome always renders above content (z default 0).
    // NewBorder uses negative anchors.margins to bleed *outside* the parent rect;
    // negative borderwidth values make it bleed *inside* instead.

    // highlight: thin left, thick right/top/bottom — raised left edge
    NewBorder {
        commonBorder: false
        lBorderwidth: 1;  rBorderwidth: 10
        tBorderwidth: 10; bBorderwidth: 10
        zValue: 10
        borderColor: Config.colors.highlight
    }

    // shadow: thick left/top, thin right/bottom — lowered right edge
    NewBorder {
        commonBorder: false
        lBorderwidth: 10; rBorderwidth: 1
        tBorderwidth: 10; bBorderwidth: 1
        zValue: 10
        borderColor: Config.colors.shadow
    }

    // top-only outline strip
    NewBorder {
        commonBorder: false
        lBorderwidth: 0; rBorderwidth: 0
        tBorderwidth: 10; bBorderwidth: 0
        zValue: 10
        borderColor: Config.colors.outline
    }

    // inner inset halo — 7px inside, 50% opacity
    NewBorder {
        commonBorder: false
        lBorderwidth: -7; rBorderwidth: -7
        tBorderwidth: -7 - root.titleBarHeight; bBorderwidth: -7
        zValue: 10
        opacity: 0.5
        borderColor: Config.colors.outline
    }

    // inner inset halo — 8px inside, 20% opacity (softer second ring)
    NewBorder {
        commonBorder: false
        lBorderwidth: -8; rBorderwidth: -8
        tBorderwidth: -8 - root.titleBarHeight; bBorderwidth: -8
        zValue: 10
        opacity: 0.2
        borderColor: Config.colors.outline
    }

    // innerOutline box — 1px border inset 6px, top also clears the title bar
    Rectangle {
        z: 10
        anchors {
            fill:        parent
            margins:     6
            topMargin:   6 + root.titleBarHeight
        }
        color:        "transparent"
        border.width: 1
        border.color: Config.colors.outline
    }

    // ── content area ──────────────────────────────────────────────────────────
    // children of PopupFrame (via default alias) land here.
    // inset matches the innerOutline box above.

    Item {
        id: contentArea
        anchors {
            top:          titleBar.bottom
            left:         parent.left
            right:        parent.right
            bottom:       parent.bottom
            topMargin:    6
            leftMargin:   6
            rightMargin:  6
            bottomMargin: 6
        }
    }
}
