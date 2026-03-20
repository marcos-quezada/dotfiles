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
| parsed state (`level`, `barText`, `pins`) | layout, colours, click handlers |
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

### why _refreshFromSummary uses regex, not JSON.parse

`summary.json` is ~18 KB and `_refreshFromSummary` is called on every file
change. a full `JSON.parse` on 18 KB triggers a V8 GC cycle on each call.
regex extraction of three known keys (`threat_level`, `warn`,
`requests_this_month`) is cheap and deterministic.

`_refreshPins` uses `JSON.parse` because `pins.json` is small (< 1 KB) and the
data is an array that cannot be safely extracted with a regex.

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

### secrets handling

`MAPBOX_TOKEN` must never be committed. the script sources
`~/.config/threatwatch/config.env` immediately after variable declarations,
overriding the default empty string. the stow package includes
`config.env.template` — copy, fill in, chmod 600. `config.env` is in
`.gitignore`.

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
