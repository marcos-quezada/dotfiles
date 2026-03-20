// ThreatWatchPopup.qml
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURAL DECISION: popup lives in shell.qml, not Bar.qml
//
// The map overlay is a full-screen-scale PanelWindow (800×780 px). It must
// exist at the shell root scope — not inside the taskbar's PanelWindow — for
// two reasons:
//
//   1. Wayland protocol: a WlrLayershell surface cannot be a child of another
//      WlrLayershell surface. Nesting PanelWindows is not permitted.
//
//   2. Layer ordering: the overlay needs WlrLayer.Overlay (above all windows)
//      while the taskbar uses WlrLayer.Bottom. These are different compositor
//      layers and cannot share a parent object.
//
// The popup is therefore instantiated once in shell.qml alongside Taskbar.Bar.
// Visibility is driven entirely by ThreatWatchModel.mapExpanded (Singleton),
// so ThreatWatchWidget (in the bar) can toggle it with a single property write.
//
// Wiring:
//   shell.qml  →  ThreatWatch.ThreatWatchPopup {}
//   ThreatWatchWidget (left-click) → ThreatWatchModel.mapExpanded = true
//   ThreatWatchPopup (click background) → ThreatWatchModel.mapExpanded = false
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Wayland

import "."

PanelWindow {
    id: popup

    // driven by the Singleton — widget toggles this, we just read it
    visible: ThreatWatchModel.mapExpanded

    // overlay layer: above all normal sway windows, below lockscreen.
    // ExclusionMode.Ignore: we do not push sway windows aside when open.
    // KeyboardFocus.None: do not steal keyboard focus from the active window.
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // 800×780 logical px — germany.png is rendered at 1600×1560 @2x by the
    // shell script (mapbox static image + imagemagick compositing).
    // anchored bottom-left so it appears directly above the bar's left side.
    // adjust anchors to taste if your bar is on a different edge.
    width:  800
    height: 780
    anchors {
        top:    false
        bottom: true
        left:   true
        right:  false
    }

    color: "transparent"

    // ── map image ─────────────────────────────────────────────────────────────

    Image {
        id: mapImage
        anchors.fill: parent
        source:       ThreatWatchModel.cacheDir + "/germany.png"
        cache:        false     // always read from disk — never use Qt image cache
        fillMode:     Image.PreserveAspectFit
        smooth:       true
    }

    // ── image cache buster ────────────────────────────────────────────────────
    // Qt caches images by URL. after a map update the file changes on disk but
    // the URL does not, so Qt would keep showing the stale image.
    // solution: briefly set source to "" then back to the real path whenever
    // ThreatWatchModel signals that the cache was updated (.updated sentinel).
    // we watch mapExpanded as the trigger: the popup is freshest on open.

    Connections {
        target: ThreatWatchModel

        // bust the cache each time the popup opens so the latest map is shown.
        // opening = transition false → true.
        function onMapExpandedChanged() {
            if (ThreatWatchModel.mapExpanded) {
                mapImage.source = ""
                mapImage.source = ThreatWatchModel.cacheDir + "/germany.png"
            }
        }
    }

    // ── background dismiss ────────────────────────────────────────────────────
    // clicking anywhere on the map background closes the popup.
    // pin hitboxes (below) stop click propagation, so clicking a pin tooltip
    // does NOT close the popup.

    MouseArea {
        anchors.fill: parent
        onClicked: ThreatWatchModel.mapExpanded = false
    }

    // ── interactive pin overlay ───────────────────────────────────────────────
    // one invisible hitbox per pin, positioned by pre-computed Web Mercator
    // pixel coordinates from pins.json.
    //
    // pin coordinate system (from build_pins_json in the threatwatch script):
    //   x = Web Mercator pixel X relative to the image's top-left corner
    //   y = Web Mercator pixel Y relative to the image's top-left corner
    //
    // hitbox is offset so its bottom-centre sits on the pin tip:
    //   left edge = x - 12  (half of 24px wide hitbox)
    //   top  edge = y - 30  (30px tall = approx Mapbox default marker height)

    Repeater {
        model: ThreatWatchModel.pins

        delegate: Item {
            id:     pinZone
            x:      modelData.x - 12
            y:      modelData.y - 30
            width:  24
            height: 30
            z:      10

            // absorb click so the background MouseArea does not close the popup
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => { mouse.accepted = true }
            }

            HoverHandler { id: pinHover }

            ToolTip {
                visible: pinHover.hovered
                delay:   200
                timeout: 15000
                text:    modelData.title + "\n" + ThreatWatchModel.pinTypeLabel(modelData.type)
            }
        }
    }
}
