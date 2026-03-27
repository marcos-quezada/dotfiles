# architecture

design decisions for the quickshell + threatwatch configuration.

---

## quickshell bar

### bar structure

the bar runs on sway (wlroots compositor) using Quickshell's `PanelWindow` +
`WlrLayershell`. `Bar.qml` wraps its content in `Scope > Variants { model:
Quickshell.screens }` so one `Bar` instance is spawned per monitor.

```
shell.qml
├── Taskbar.Bar                    — PanelWindow, WlrLayer.Bottom
│   │                                (Bar.qml wraps this in Scope > Variants { model: Quickshell.screens }
│   │                                 so one instance spawns per monitor)
│   ├── workspacesPanel            — left side: sway workspace switcher (Workspaces.qml)
│   └── trayPanel                  — right side: system tray row
│       └── SysTray                — SysTray.qml (contains ThreatWatchWidget + ClockWidget internally)
└── ThreatWatch.ThreatWatchPopup   — PanelWindow, WlrLayer.Overlay (see below)
```

### widget interactions

| action | result |
|---|---|
| left click | toggle `ThreatWatchPopup` (map overlay with HUD) |

### why ThreatWatchPopup lives in shell.qml, not Bar.qml

Wayland protocol forbids nesting `WlrLayershell` surfaces. a `PanelWindow` is a
layershell surface; you cannot place one inside another. attempting it parses
without error in Quickshell but produces undefined compositor behaviour.

the popup also needs a different layer (`WlrLayer.Overlay`) than the bar
(`WlrLayer.Bottom`). these are compositor-level concepts — they cannot share a
parent object.

solution: instantiate `ThreatWatchPopup` once at root scope in `shell.qml`,
alongside `Taskbar.Bar`. visibility is driven by `ThreatWatchModel.mapExpanded`
so the widget in the bar can toggle it with a single property write.

### popup position: top-right, just below the bar

the popup is anchored to the top-right corner of the screen:

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
| parsed state (`level`, `barText`, `pins`, `updatedAt`) | layout, colours, click handlers |
| `triggerUpdate()` | reads model properties via QML binding |
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

## threatwatch themes

### how themes work

`_resolve_theme()` runs once at startup, after `config.env` is sourced. it sets
every `TH_*` variable for the current session and resolves `MAPBOX_STYLE`.

```
config.env sourced
    └── THREATWATCH_THEME="vintage"   (or "neon", or unset → defaults to vintage)

_resolve_theme()
    ├── case branch sets all TH_* variables
    ├── sets _TH_MAPBOX_STYLE  (internal — the style paired with this theme)
    └── MAPBOX_STYLE resolution:
            if MAPBOX_STYLE already set in config.env → keep it (explicit override)
            else → MAPBOX_STYLE = _TH_MAPBOX_STYLE
        then: MAPBOX_BASE = https://api.mapbox.com/styles/v1/${MAPBOX_STYLE}/static
```

the `vintage|*` branch is the fallback — any unrecognised theme name silently
uses vintage rather than crashing. keep this as the last branch when adding
new themes.

### variable contract

all `TH_*` variables must be set in every theme branch. missing a variable
produces a silent empty string, which ImageMagick renders as black — not an
error, but visually broken.

**HUD panel**

| variable | format | controls |
|---|---|---|
| `TH_PANEL_FILL` | `rgba(r,g,b,a)` | background fill of HUD + legend panels |
| `TH_BORDER_COL` | `#rrggbb` | border stroke of HUD + legend panels |

**text hierarchy** — four levels, dark→faint, used top-to-bottom in the HUD

| variable | format | used for |
|---|---|---|
| `TH_TEXT_DARK` | `#rrggbb` | primary data lines (quake count, flight count) |
| `TH_TEXT_MID` | `#rrggbb` | secondary data (Polymarket line, Mapbox usage) |
| `TH_TEXT_SOFT` | `#rrggbb` | timestamps and low-priority lines |
| `TH_TEXT_FAINT` | `#rrggbb` | de-emphasised text; on dark themes set equal to `TH_TEXT_MID` — faint-on-dark is unreadable |
| `TH_LEG_TEXT` | `#rrggbb` | legend labels |

**threat level accent** — drives the left accent bar and the top HUD line colour

| variable | format | level |
|---|---|---|
| `TH_LEVEL_CRITICAL` | `#rrggbb` | critical |
| `TH_LEVEL_HIGH` | `#rrggbb` | high |
| `TH_LEVEL_MEDIUM` | `#rrggbb` | medium |
| `TH_LEVEL_LOW` | `#rrggbb` | low |
| `TH_LEVEL_INFO` | `#rrggbb` | info (default / no events) |

**pin colours** — bare hex, no `#` prefix. passed directly into Mapbox Static
Images pin URL syntax: `pin-s-icon+rrggbb(lon,lat)`. the `#` form is rejected
by the API.

| variable | pin type | slots |
|---|---|---|
| `TH_PIN_EMERG` | emergency squawk aircraft | up to 2 |
| `TH_PIN_MIL` | military callsign aircraft | up to 3 |
| `TH_PIN_GDACS_RED` | GDACS red alert in region | 1 |
| `TH_PIN_GDACS_ORG` | GDACS orange alert in region | 1 |
| `TH_PIN_Q_CRIT` | earthquake M5.5+ (`pin-l`) | up to 4 (fills remaining slots) |
| `TH_PIN_Q_HIGH` | earthquake M4.5+ (`pin-m`) | ↑ |
| `TH_PIN_Q_MED` | earthquake M4.0+ (`pin-s`) | ↑ |
| `TH_PIN_Q_LOW` | earthquake M3.5+ (`pin-s`) | ↑ |

**Mapbox style**

| variable | format | notes |
|---|---|---|
| `_TH_MAPBOX_STYLE` | `{username}/{style_id}` | internal — set inside the `case` branch, unset after `_resolve_theme` returns |

### pin colour selection guide

the map has its own dominant colours. pins must stand out from both the map
background **and** from each other. before choosing pin colours, sample the
map histogram to find the dominant hues.

method: fetch the map with `threatwatch map --force`, then run:
```sh
magick ~/.cache/threatwatch/germany_raw.png \
    -format %c -depth 8 histogram:info:- \
    | sort -rn | head -20
```

this gives the top 20 pixel colours by count. build a palette of those
dominant hues, then choose each pin colour to maximise distance from all of
them and from the other pins.

the inline comments in `_resolve_theme()` document this for both existing
themes — preserve that pattern when adding a new one.

### adding a theme

1. pick a Mapbox style. studio styles live at
   `https://studio.mapbox.com` — the style ID is the last path segment of
   the style URL. user-owned styles use `{username}/{style_id}`.

2. fetch the map and sample the histogram (see above). note the dominant
   colours so you can choose pin colours that contrast with the map.

3. add a `case` branch in `_resolve_theme()`, **before** the `vintage|*)`
   fallback:

   ```sh
   mytheme)
       _TH_MAPBOX_STYLE="{username}/{style_id}"
       TH_PANEL_FILL="rgba(...)"
       TH_BORDER_COL="#..."
       TH_TEXT_DARK="#..."
       TH_TEXT_MID="#..."
       TH_TEXT_SOFT="#..."
       TH_TEXT_FAINT="#..."
       TH_LEVEL_CRITICAL="#..."
       TH_LEVEL_HIGH="#..."
       TH_LEVEL_MEDIUM="#..."
       TH_LEVEL_LOW="#..."
       TH_LEVEL_INFO="#..."
       TH_PIN_EMERG="rrggbb"    # bare hex — note the contrast rationale
       TH_PIN_MIL="rrggbb"
       TH_PIN_GDACS_RED="rrggbb"
       TH_PIN_GDACS_ORG="rrggbb"
       TH_PIN_Q_CRIT="rrggbb"
       TH_PIN_Q_HIGH="rrggbb"
       TH_PIN_Q_MED="rrggbb"
       TH_PIN_Q_LOW="rrggbb"
       TH_LEG_TEXT="#..."
       ;;
   ```

4. add the theme name to the `THREATWATCH_THEME` comment block in
   `config.env.template` with a one-line description and the paired style ID.

5. test: set `THREATWATCH_THEME="mytheme"` in `config.env`, run
   `threatwatch map --force && threatwatch overlay`, then inspect
   `~/.cache/threatwatch/germany.png`.

---

## threatwatch script

### data flow

```
every 6h (or on demand via triggerUpdate()):

  threatwatch update
  ├── fetch_earthquakes()   EMSC primary → USGS supplementary → merge/dedup → quakes.json
  ├── fetch_gdacs()         GDACS RSS → gdacs.xml
  ├── fetch_flights()       OpenSky state vectors → flights.json
  ├── fetch_polymarket()    Polymarket politics tag → polymarket.json
  ├── fetch_map()           Mapbox Static Image → germany_raw.png   (raw only)
  ├── build_summary()       all sources → summary.json + touch .updated
  ├── apply_map_overlay()   ImageMagick HUD + legend composite → germany.png
  └── build_pins_json()     quakes + flights + gdacs → Web Mercator pixel coords → pins.json

on .updated change (FileView):
  threatwatch (no args) → tobar() → one-line bar string
```

`threatwatch update` is the single atomic command used by both the Quickshell
auto-refresh timer and any future manual trigger. it always runs the full sequence:
fetch → summary → overlay → pins.

### tobar format

`tobar()` emits a single line consumed by `ThreatWatchModel` as `barText`:

```
<level-icon> <quake-icon><count> <flight-icon><count> <gdacs-icon><count>
```

each category token is only included when its count is > 0. emergency squawks
prefix the flight token with `!` (e.g. `✈!2`). when level is `info` and all
counts are zero, an empty string is emitted so the widget hides the label.

icons (Nerd Font md- set):

| category | icon | notes |
|---|---|---|
| level critical | `󱡶` | |
| level high | `󰒙` | |
| level medium/low/info | `󱇎` / `󰒘` | |
| earthquake | `󰈌` | seismograph waveform |
| flight | `✈` | U+2708, universally present |
| GDACS in-region alert | `󱠕` | alert triangle outline |

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
these coordinates. hovering a hitbox shows an inline `Rectangle` tooltip (the
`pinTooltip` at `z:20`) with the event title and type. clicking absorbs the event
to prevent accidental map dismissal on pin areas.

### mapbox pin slot budget

Mapbox caps static image overlays at 10 pins. slots are pre-reserved:

| type | slots | colour |
|---|---|---|
| emergency squawk | 2 | white `#ffffff` (neon) / teal `#1a5f5a` (vintage) |
| military aircraft | 3 | hot pink `#ff00cc` (neon) / slate `#2b3a5c` (vintage) |
| GDACS in-region | 1 | red/orange star (theme `TH_PIN_GDACS_*`) |
| earthquakes | remaining (up to 4) | magnitude-keyed, theme `TH_PIN_Q_*` |

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

### ToolTip attached properties don't render inside PanelWindow

`ToolTip.visible` / `ToolTip.text` attached properties rely on
`ApplicationWindow`'s overlay layer to render the floating tooltip surface.
`PanelWindow` has no `ApplicationWindow` — the overlay layer does not exist, so
the tooltip is silently never drawn.

fix: use an inline `Rectangle` + `Text` as a shared tooltip, positioned manually
near the hovered item. `ThreatWatchPopup` uses a single `pinTooltip` Rectangle at
`z: 20` shared by all pin hitboxes via `onContainsMouseChanged`.

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

### HoverHandler blocked by sibling MouseArea

a `HoverHandler` nested inside an `Item` that also has a sibling `MouseArea`
never fires — `MouseArea` swallows all pointer events including hover by default.

fix: set `hoverEnabled: true` on the `MouseArea` and drive visibility from
`containsMouse`. do not use a separate `HoverHandler`.

---

## stow layout

every top-level directory (except `docs/`) is a stow package. `install.sh`
handles all stow invocations interactively — you do not need to run `stow`
manually.

| package | stow target | platform | contents |
|---|---|---|---|
| `cheatsheets` | `$HOME` | all | `.config/cheatsheets/` |
| `foot` | `$HOME` | FreeBSD + Linux | `.config/foot/` |
| `git` | `$HOME` | all | `.gitconfig`, `.color.gitconfig`, `.gitignore`, `.local/bin/git-clone-bare-for-worktrees`, `.local/bin/new_script` |
| `inputrc` | `$HOME` | all | `.inputrc` |
| `nvim` | `$HOME` | macOS | `.config/nvim/` |
| `quickshell` | `$HOME` | FreeBSD | `.config/quickshell/` (bar + threatwatch QML, fonts) |
| `sh` | `$HOME` | FreeBSD | `.profile`, `.shrc` |
| `sketchybar` | `$HOME` | macOS | `.config/sketchybar/` |
| `sway` | `$HOME` | FreeBSD + Linux | `.config/sway/config`, `walls/freebsd-kilmynda-wide.png` |
| `threatwatch` | `$HOME` | all | `.local/bin/threatwatch`, `.config/threatwatch/config.env.template` |
| `vim` | `$HOME` | all | `.vimrc`, `.config/vim/` |
| `vt` | `/` | FreeBSD | `boot/fonts/12x22.fnt.gz`, `boot/fonts/INDEX.fonts` |
| `zsh` | `$HOME` | macOS | `.zshrc`, `.git-worktree-functions.zsh` |

`vt` is the only package with a non-`$HOME` target. `install.sh` runs
`stow --target=/ vt` under `doas`/`sudo` — console font files must land in
`/boot/fonts/` for the FreeBSD loader to find them.

---

## shell quality

### target shell

all scripts not under `sketchybar/` target FreeBSD `/bin/sh` (POSIX sh, no bash
extensions). forbidden constructs:

- `[[ ]]` — use `[ ]`
- `(( ))` — use `expr` or `[ $((…)) -eq … ]`
- `declare -a` / `declare -A` — no arrays; use newline-delimited strings
- `echo -e` — use `printf`
- `$REPLY` from bare `read` — always name the variable: `read -r var`
- `local` — not POSIX; use a unique `_prefix` naming convention instead and
  `unset` after use

sketchybar plugins are macOS-only and may use bash — they carry `#!/bin/bash`.

### shellcheck

run against every script before committing:

```sh
shellcheck <file>
```

the lint gate (`tests/lint.bats`) runs ShellCheck on all nine target files and
is the CI entry point — it must pass before any other suite is run.

**suppression rules** — only suppress with an inline comment explaining why:

```sh
# shellcheck disable=SC2329  # called via trap string, not directly
signal_exit() { … }
```

never suppress without a comment. never use a file-level `# shellcheck disable`
directive — suppressions must be as narrow as possible.

common legitimate suppressions in this repo:

| code | reason |
|---|---|
| SC2329 | `signal_exit` called only via `trap "…"` string — ShellCheck can't see the indirect call |
| SC2016 | help text intentionally prints `$EDITOR` as a literal string |
| SC1090 | `bats` tests source gwt.sh at a dynamic path — no static path for ShellCheck |
| SC1091 | sketchybar plugins source icon map at a dynamic install path |

### shfmt

format check for consistent style:

```sh
shfmt -ln posix <file>   # POSIX sh scripts
shfmt -ln bash  <file>   # bash scripts (sketchybar plugins)
```

`shfmt` is installed by the dev tools section of `install.sh` alongside
ShellCheck and bats-core.

### bats test suite

```
tests/
├── lint.bats             ShellCheck gate — run this first; all 9 scripts must pass
├── new_script.bats       unit tests for new_script (flags, generated content, output ShellCheck)
├── threatwatch.bats      unit tests for threatwatch against fixture JSON (no network)
├── git-clone-bare.bats   integration tests using a local bare repo
├── gwt.bats              tests sourcing gwt.sh against a local bare-worktree hub
└── fixtures/
    ├── quakes.json       2 EMSC events (M4.8 AUSTRIA, M3.7 BAVARIA)
    ├── flights.json      OpenSky state vectors (GAF001, REACH42, DLH123)
    └── summary.json      full summary output with threat_level=high
```

run all suites:

```sh
bats tests/
```

run a single suite:

```sh
bats tests/lint.bats
```

all tests are network-free. `threatwatch.bats` mocks the cache directory with
`$TMPDIR` and points `THREATWATCH_CACHE` at the fixtures directory so the
script reads fixture JSON instead of live data.

### generated scripts

`new_script -q <path>` generates a POSIX sh script skeleton. the generated
output is itself ShellCheck-clean — verified by `tests/new_script.bats` test 9.
the `signal_exit` function in the generated code carries `# shellcheck
disable=SC2329` because it is only ever called via `trap "signal_exit …"` and
ShellCheck's direct-call analysis flags it as unused without the directive.
