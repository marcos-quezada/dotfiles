# architecture

design decisions for the quickshell + threatwatch configuration.

---

## quickshell bar

### bar structure

the bar runs on sway (wlroots compositor) using Quickshell's `PanelWindow` +
`WlrLayershell`. one `Bar` instance is spawned per monitor via `Variants { model:
Quickshell.screens }`.

```
shell.qml
├── Taskbar.Bar          — PanelWindow, WlrLayer.Bottom, spans all monitors
│   ├── workspacesPanel  — left side: sway workspace switcher
│   └── trayPanel        — right side: SysTray row
│       ├── ThreatWatchWidget
│       └── ClockWidget
└── ThreatWatch.ThreatWatchPopup  — PanelWindow, WlrLayer.Overlay (see below)
```

### why ThreatWatchPopup lives in shell.qml, not Bar.qml

Wayland protocol forbids nesting `WlrLayershell` surfaces. a `PanelWindow` is a
layershell surface; you cannot place one inside another. attempting it parses
without error in Quickshell but produces undefined compositor behaviour.

the popup also needs a different layer (`WlrLayer.Overlay`) than the bar
(`WlrLayer.Bottom`). these are compositor-level concepts — they cannot share a
parent object.

solution: instantiate `ThreatWatchPopup` once at root scope in `shell.qml`,
alongside `Taskbar.Bar`. visibility is driven by `ThreatWatchModel.mapExpanded`
so the widget in the bar can still toggle it with a single property write.

### popup position: top-right, just below the bar

the popup is anchored to the top-right corner of the screen using:

```qml
anchors { top: true; right: true }
margins.top: 35
```

`margins` is a grouped property on `PanelWindow` (sub-properties `left`, `top`,
`right`, `bottom`). per the Quickshell docs, **margins only apply to anchored
edges** — `margins.top` is effective because `top: true` is set.

`ExclusionMode.Ignore` means the compositor does not shift the popup's top anchor
down for the bar's exclusive zone — the bar occupies the top 35 px, and the popup
must add that offset manually via `margins.top: 35` (matching `Bar.qml`'s
`implicitHeight`).

**pin coordinate safety**: `margins.top` shifts the window surface on screen but
does not affect the coordinate space inside the surface. the map image fills the
full 800×780 surface via `anchors.fill: parent`, so all pin hitbox `x`/`y`
values from `pins.json` remain pixel-accurate relative to the image.

---

## threatwatch MVC split

### why a Singleton model

`ThreatWatchModel` is `pragma Singleton`. this means one instance exists for the
entire Quickshell process, regardless of how many UI files import the module.

without Singleton: every `ThreatWatchWidget` instantiation would create its own
`Process` and `Timer` objects. the threatwatch script would run in parallel N
times, each writing to the same cache files and racing each other.

with Singleton: one timer, one update cycle, one set of file watchers. all UI
components (`ThreatWatchWidget`, `ThreatWatchPopup`) read shared reactive
properties — a change propagates to both instantly via QML bindings.

this is the same pattern used by `Config.qml` and `Time.qml` in the retroism
base config. see https://quickshell.org/docs/v0.2.1/guide/qml-language/#singletons

### what belongs in the model vs the view

| model (`ThreatWatchModel`) | view (`ThreatWatchWidget`, `ThreatWatchPopup`) |
|---|---|
| `Process`, `Timer`, `FileView` | `Text`, `Rectangle`, `Image` |
| parsed state (`level`, `barText`, `pins`, `headlines`, `updatedAt`) | layout, colours, click handlers |
| `triggerUpdate()`, `dumpData()` | reads model properties via QML binding |
| no visual items whatsoever | no network/process/timer logic |

### file watchers vs polling

`FileView` uses `inotify` (Linux) or `kqueue` (FreeBSD/macOS) under the hood —
no busy-polling. three files are watched:

| file | why |
|---|---|
| `.updated` | zero-byte sentinel, `touch`-ed after every script run. master trigger. |
| `summary.json` | direct watcher so manual edits also refresh level + mapbox badge |
| `pins.json` | written by `build_pins_json()` after each update |

`.updated` is the primary trigger. the other two exist so external tools or
manual `threatwatch update` calls also drive a UI refresh without the QML timer.

### _refreshFromSummary and _refreshPins

both helpers use `JSON.parse`. a single parse call is simpler, handles nested
objects (`mapbox.*`) correctly, and avoids the class of bugs where regex silently
misses a key when the JSON is pretty-printed or field order changes.

`_refreshFromSummary` extracts:

| field | target property | notes |
|---|---|---|
| `threat_level` | `root.level` | |
| `updated_at` | `root.updatedAt` | ISO `"2025-01-15T14:32:00Z"` → `"2025-01-15 14:32 UTC"` (16 chars + suffix) |
| `mapbox.requests_this_month` | `root.mapRequests` | |
| `mapbox.warn` | `root.mapWarn` | |
| `poly_markets` (top 5) | `root.headlines` | formatted as `"<prob>%  <title>"`, joined with `\n`, prefixed `"Geopolitical markets:\n"` |

`mapHardLimit` is derived: `root.mapRequests >= 48000` (no field in JSON —
computed locally to avoid a stale value if the script resets the counter).

`_refreshPins` uses `JSON.parse` on `pins.json` (< 1 KB) and replaces
`root.pins` only when the result is a valid array — partial writes during a
script run silently keep the previous value.

### levelColors centralisation

all level-to-colour mappings live in `ThreatWatchModel.levelColors`. both
`ThreatWatchWidget` and `ThreatWatchPopup` (and any future widget) read from
this one object. changing a colour requires editing exactly one line.

---

## threatwatch script

### data flow

```
every 6h (or on middle-click):

  threatwatch update
  ├── fetch_earthquakes()   EMSC primary → USGS supplementary → merge/dedup → quakes.json
  ├── fetch_gdacs()         GDACS RSS → gdacs.xml
  ├── fetch_flights()       OpenSky state vectors → flights.json
  ├── fetch_polymarket()    Polymarket politics tag → polymarket.json
  ├── fetch_map()           Mapbox Static Image → germany_raw.png
  │   └── _map_overlay()   ImageMagick HUD + legend composite → germany.png
  ├── build_summary()       all sources → summary.json + touch .updated
  └── build_pins_json()     quakes + flights + gdacs → Web Mercator pixel coords → pins.json

on .updated change (FileView):
  threatwatch (no args) → tobar() → one-line bar string
```

### earthquake source priority

EMSC (seismicportal.eu) is primary — better sensitivity for Central Europe than
USGS. USGS is only fetched when EMSC returns fewer than 5 events (quiet period or
outage). results are merged and deduplicated within a 0.4° proximity radius.

bounding box: `45.0°N – 55.5°N, 5.5°E – 16.0°E`. the 45° south edge captures
Como (45.81°N), Dizzasco (45.95°N), Lombardia, and the Slovenian seismic zone.

### mapbox rate limiting

| threshold | value | action |
|---|---|---|
| `MAP_MIN_INTERVAL` | 21600s (6h) | skip if cached map is younger |
| `MAP_WARN_THRESHOLD` | 40,000 req | `mapbox.warn: true` in summary → QML shows badge |
| `MAP_SKIP_THRESHOLD` | 48,000 req | hard stop, use cached map |
| free tier | 50,000 req/month | resets on calendar month rollover |

default 6h interval = ~120 req/month. counter stored in `mapbox_count.json` as
`{ month: "2026-03", count: 42 }` and auto-resets when the month changes.

### threat level logic

levels are monotonically upgraded (never downgraded) within a single run:

| signal | condition | upgrades to |
|---|---|---|
| earthquake | top magnitude ≥ 5.5 | critical |
| earthquake | top magnitude ≥ 4.5 | high |
| earthquake | top magnitude ≥ 3.5 | medium |
| GDACS | red alert in region | critical |
| GDACS | orange alert in region | high |
| GDACS | red alert globally | medium |
| aircraft | emergency squawk 7700/7600/7500 | critical |
| Polymarket | keyword market ≥ 40% yes | high |
| Polymarket | keyword market ≥ 20% yes | medium |

military callsigns alone do not upgrade level — they are monitoring data, not a
threat signal.

### map viewport calibration

| parameter | value | rationale |
|---|---|---|
| `MAP_ZOOM` | 5 | zoom 6 cut off Flensburg and Como entirely |
| `MAP_CENTER_LAT` | 50.609°N | empirical center — not the bbox midpoint |
| `MAP_CENTER_LON` | 10.45°E | geographic center of Germany |
| `MAP_SIZE` | 800×780 → 1600×1560 @2x | |
| Flensburg (54.79°N) | 4.9% from top | comfortable margin |
| Como (45.81°N) | 88.6% from top | fully visible |

calibrated by fetching three maps with `pin-l` markers at exact target
coordinates and measuring Y positions with ImageMagick pixel scanning.

### interactive pins

`build_pins_json()` projects each pin's lon/lat into pixel coordinates on the
800×780 image using Web Mercator (512 px base tile, zoom 5):

```
global_x = ((lon + 180) / 360) * 512 * 2^zoom
global_y = (1 - ln(tan(lat_rad) + 1/cos(lat_rad)) / pi) * 256 * 2^zoom
image_x  = 400 + (global_x - center_global_x)
image_y  = 390 + (global_y - center_global_y)
```

result written to `pins.json`. `ThreatWatchPopup` places invisible hitboxes at
these coordinates for hover tooltips without requiring an interactive map.

### mapbox pin slot budget

Mapbox caps static image overlays at 10 pins. slots are pre-reserved:

| type | slots | colour |
|---|---|---|
| emergency squawk | 2 | cyan `#00ffff` |
| military aircraft | 3 | purple `#aa44ff` |
| GDACS in-region | 1 | red/orange star |
| earthquakes | remaining (up to 4) | magnitude-keyed red→yellow |

### map overlay font

`_find_font()` resolves a TTF path for ImageMagick's `-font` argument. the
bundled Monaco font is checked first:

```
${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/fonts/Monaco.ttf
```

this ensures the map HUD uses the same typeface as the bar text. fallbacks cover
JetBrains Mono (Nerd Font), DejaVu Sans Mono, Liberation Mono, and SF Mono — in
that order. if none are found, ImageMagick uses its built-in default font and
the overlay is still applied.

### secrets handling

`MAPBOX_TOKEN` must never be committed. the script sources
`~/.config/threatwatch/config.env` immediately after variable declarations,
overriding the default empty string. the stow package includes
`config.env.template` — copy, fill in, chmod 600. `config.env` is in
`.gitignore`.

---

## QML / Quickshell gotchas

hard-won lessons from debugging the bar. recorded here so we never re-discover
them the slow way.

### ToolTip: attached property form required on non-Control items

`ToolTip { }` as a **child element** only works inside `Control`-derived types
(Button, ComboBox, etc.). `Text` and `Item` are plain `QtQuick` items — placing
a `ToolTip {}` child inside them silently does nothing.

correct form for `Text`, `Item`, `Rectangle`:

```qml
import QtQuick.Controls

Text {
    ToolTip.visible: someHover.hovered
    ToolTip.delay:   600
    ToolTip.timeout: 12000
    ToolTip.text:    "..."
}
```

`QtQuick.Controls` must be imported for the attached properties to resolve.

### MouseArea inside a RowLayout sibling gets zero geometry

a `MouseArea` placed as a **sibling** to other children inside a `RowLayout`
gets zero width and height from the layout — clicks never register.

correct pattern: wrap the `RowLayout` in a plain `Item`, mirror the layout's
`implicitWidth`/`implicitHeight` on the `Item`, and put the `MouseArea` as a
sibling to the `RowLayout` inside that `Item`:

```qml
Item {
    id: widget
    implicitWidth:  row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout { id: row; anchors.fill: parent; ... }

    MouseArea { anchors.fill: parent; ... }   // gets correct geometry
}
```

### TapHandler on a PanelWindow is unreliable on Wayland

`TapHandler` placed on the root `PanelWindow` does not receive pointer events
reliably on Wayland layer surfaces. `MouseArea { anchors.fill: parent }` works.
the `anchors` layout warning Qt emits is a false positive — `PanelWindow` is not
a layout manager.

### anchors.* on RowLayout-managed items is undefined

setting `anchors.left`, `anchors.centerIn`, etc. on a direct child of a
`RowLayout` is undefined behaviour in Qt (the layout and the anchor system fight
over geometry). use `Layout.alignment` instead:

```qml
RowLayout {
    Text { Layout.alignment: Qt.AlignVCenter }
}
```

### PanelWindow: use implicitHeight / implicitWidth, not height / width

Quickshell deprecates setting `height` and `width` directly on `PanelWindow`.
use `implicitHeight` and `implicitWidth` — the compositor reads these to size
the surface correctly.

### qmldir comment syntax

`qmldir` files use `#` for comments. `//` causes a "too many parameters" parse
error in the Quickshell module loader. all other `.qml` files use `//`.

---

## stow layout

each top-level directory in this repo is a stow package. `stow <package>` from
the repo root creates symlinks under `$HOME` that mirror the package's directory
tree.

```
dotfiles/
├── quickshell/          stow package — sway bar (FreeBSD only)
│   └── .config/quickshell/
├── threatwatch/         stow package — all platforms
│   ├── .local/bin/threatwatch
│   └── .config/threatwatch/config.env.template
├── docs/                not stowed — repo documentation
├── install.sh           not stowed — bootstrap script
├── .stow-local-ignore   tells stow what to skip
└── .gitignore
```
