# architecture

design decisions for the quickshell + threatwatch configuration.

---

## standing convention: prefer a native Quickshell service over a shell-out

whenever a native Quickshell service exists for something, use it instead of
shelling out to (or wrapping) an external CLI tool. surfaced independently
twice during an explore session, for two different concerns:

- **media playback**: `Quickshell.Services.Mpris` instead of parsing
  `playerctl` output (see "music playback" below)
- **audio output**: considered `Quickshell.Services.Pipewire` instead of
  `pactl`/`jq` while evaluating `BreadOnPenguins/scripts`' `audioswitch`.
  in practice this system runs PulseAudio over FreeBSD's OSS bridge, not
  PipeWire — there's no native Quickshell service for that stack, so
  `Services/Sound.qml` shells out to `pactl`/a small `bin/` script
  deliberately, the same kind of accepted exception as `yt-dlp` staying
  outside `pkg`. the *principle* still generalizes; it just doesn't apply
  to this specific machine's audio stack. (`Taskbar/NowPlayingWidget.qml`'s
  scroll-to-adjust-volume handler briefly violated this convention by
  itself — a leftover `Quickshell.execDetached(["pactl", ...])` call from
  before `Sound.qml` existed, duplicating the command *and* never calling
  `Sound.refresh()` afterward. fixed to call `Sound.volumeUp()`/
  `Sound.volumeDown()` directly.)

the reasoning generalizes: a native service is reactive by construction (no
polling, no subprocess spawned per update), and Quickshell's own type system
can describe it (unlike a `Process` wrapping a CLI tool's text output, which
is opaque to `qmllint`/`qmlls`). before reaching for a shell-out when adding
a new bar feature, check whether `Quickshell.Services.*` already covers it.

---

## standing convention: the bar-residency filter

when a new bar feature comes up, decide *where* it belongs before writing
any QML — not everything that could go in the bar should. three buckets,
in order of how much bar space they cost:

- **popup** (a `Components.TaskbarButton` + a popup): the feature needs
  user input, or has more than one possible action. `Playlist`, `Sound`,
  `Session`, `ThreatWatch` all fit here — each needs clicking, selecting,
  or choosing between several actions.
- **always-visible, no popup**: the feature is glanceable status someone
  wants to see continuously, and interacting with it (if at all) is a
  single, obvious action. `NowPlayingWidget` fits here — click toggles
  play/pause, scroll adjusts volume, no popup needed for either.
- **shortcut-only, not bar-resident at all**: the feature is used
  rarely enough, or is simple enough, that a keybinding covers it without
  spending any bar space. brightness/volume media keys fit here even
  though `Sound` also exists as a popup — the common case (nudge volume
  up or down) doesn't need to open anything.

this is also why some things were deliberately *not* added: an app
launcher and a timer widget were both considered and dropped — shortcuts
already cover launching, and a timer has no real use case here. the
"disks"/USB indicator sat unimplemented for a long time specifically
because a single indicator didn't justify a shared status strip on its
own — it only became worth doing once a second concrete need (embedded-dev
USB mass-storage devices) showed up.

when scoping a new addition, ask: does this need input or a choice between
actions (popup), does it need to always be visible (informative, no
popup), or does neither apply (shortcut, not bar-resident at all)? if none
of the three fit comfortably, that's a sign the feature needs more thought
before it becomes a bar widget at all.

---

## quickshell bar

### bar structure


[1119 more lines in file. Use offset=11 to continue.]
the bar runs on sway (wlroots compositor) using Quickshell's `PanelWindow` +
`WlrLayershell`. `Bar.qml` wraps its content in `Scope > Variants { model:
Quickshell.screens }` so one `Bar` instance is spawned per monitor.

```
shell.qml
├── Bar                             — PanelWindow, WlrLayer.Bottom
│   │                                (Bar.qml wraps this in Scope > Variants { model:
│   │                                 Quickshell.screens } so one instance spawns per monitor)
│   ├── leftCluster                — RowLayout: Session, Workspaces, ThreatWatch,
│   │                                Playlist, Sound TaskbarButtons, left-anchored
│   └── trayPanel                  — right side: system tray row (SysTray.qml, tray icons + ClockWidget)
├── ThreatWatchPopup                — PanelWindow, WlrLayer.Overlay
├── PlaylistPopup                   — PanelWindow, WlrLayer.Overlay
├── SoundPopup                      — PanelWindow, WlrLayer.Overlay
├── SessionPopup                    — PanelWindow, WlrLayer.Overlay
└── SessionActionPopup              — PanelWindow, WlrLayer.Overlay (pending reboot/
                                       shutdown notice — not gated by Popups.current)
```

all four toggleable popups (`ThreatWatch`/`Playlist`/`Sound`/`Session`) share
`Components/TriggeredPopup.qml` for their window/chrome boilerplate — see
"Components/TriggeredPopup" below.

### widget interactions

`ThreatWatch`, `Playlist`, `Sound`, and `Session` are each triggered from their
own `Components.TaskbarButton` in `leftCluster`, in that visual order (Session
leftmost, before the workspace switcher — a deliberate placement choice, not
following any one reference repo's convention, since precedent varies:
caelestia/retroism/BreadOnPenguins each do something different here, and
BreadOnPenguins doesn't even put it in the bar).

| action | result |
|---|---|
| left click any of the four buttons | `Popups.toggle(name)` — opens that popup, closing whichever else was open (mutual exclusivity, see `Services/Popups.qml` below); button bevel inverts (raised → sunken) while its popup is open |

### why ThreatWatchPopup lives in shell.qml, not Bar.qml

Wayland protocol forbids nesting `WlrLayershell` surfaces. a `PanelWindow` is a
layershell surface; you cannot place one inside another. attempting it parses
without error in Quickshell but produces undefined compositor behaviour.

the popup also needs a different layer (`WlrLayer.Overlay`) than the bar
(`WlrLayer.Bottom`). these are compositor-level concepts — they cannot share a
parent object.

solution: instantiate `ThreatWatchPopup` once at root scope in `shell.qml`,
alongside `Bar`. visibility is driven by `ThreatWatchModel.mapExpanded`
so the widget in the bar can toggle it with a single property write.

### popup position: tracks the trigger button, just below the bar

none of the four popups anchor to a fixed screen corner. each tracks the
horizontal position of the `TaskbarButton` that triggers it:

```qml
anchors { top: true; left: true }
margins.top:  35
margins.left: triggerX   // passed through to Components.TriggeredPopup
```

`triggerX` is a plain property on each popup's own singleton (`Session`,
`ThreatWatchModel`, `Playlist`, `Sound` — all named `triggerX` consistently;
this used to be `mapTriggerX` on `ThreatWatchModel` specifically, renamed for
consistency when this mechanism was generalized). the popup and the taskbar
are separate top-level `PanelWindow`s — they can't share layout directly — so
the singleton is the coordination point, same role `Config` plays for colours
and `Fonts` plays for typefaces.

the write side lives in `Components/TaskbarButton.qml` itself, not per-button
in `Bar.qml` (see "Components/TaskbarButton" below for how that binding is
structured and the bug it took to get right).

`margins` is a grouped property on `PanelWindow` (sub-properties `left`, `top`,
`right`, `bottom`). per the Quickshell docs, **margins only apply to anchored
edges** — `margins.top` is effective because `top: true` is set, and
`margins.left` is effective because `left: true` is set.

`ExclusionMode.Ignore` means the compositor does not shift the popup's top anchor
down for the bar's exclusive zone — the bar occupies the top 35 px, and the popup
must add that offset manually via `margins.top: 35` (matching `Taskbar/Bar.qml`'s
`implicitHeight`).

**pin coordinate safety**: `margins.top` shifts the window surface on screen but
does not affect the coordinate space inside the surface. the map image fills
`contentArea` (the inset child of `PopupFrame`) via `anchors.fill: parent`.
`PopupFrame` uses `default property alias content: contentArea.data`, so the
`Repeater` pin delegates and the `pinTooltip` Rectangle are also children of
`contentArea` — all three share the same coordinate space. `modelData.x/y` pixel
values from `pins.json` map correctly to `contentArea`-relative positions without
any offset adjustment.

---

## threatwatch MVC split

### why a Singleton model

`ThreatWatchModel` is `pragma Singleton`. this means one instance exists for the
entire Quickshell process, regardless of how many UI files import the module.

without Singleton: every `ThreatWatchWidget` instantiation would create its own
`Process` and `Timer` objects. the threatwatch script would run in parallel N
times, each writing to the same cache files and racing each other.

with Singleton: one timer, one update cycle, one set of file watchers. all UI
components reading from it (currently `ThreatWatchPopup`, previously also
`ThreatWatchWidget` before it was deleted as dead code) read shared reactive
properties — a change propagates to all of them instantly via QML bindings.

this is the same pattern used by every other file in `Services/`
(`Config`, `Fonts`, `Time`). see
https://quickshell.org/docs/v0.2.1/guide/qml-language/#singletons

### what belongs in the model vs the view

| model (`Services/ThreatWatchModel.qml`) | view (`ThreatWatch/ThreatWatchPopup.qml`) |
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

### why ImageMagick, not Ghostscript

Ghostscript was evaluated as a lighter alternative for the map overlay step.
it was rejected for three reasons:

1. **no raster compositing** — Ghostscript is a PostScript/PDF interpreter. it
   has no equivalent of ImageMagick's `composite` command. overlaying a
   semi-transparent PNG panel onto a JPEG map requires raster blending, which
   Ghostscript cannot do.

2. **no `-annotate`** — the HUD text is drawn with `magick -annotate` using a
   TTF font at a given point size. Ghostscript has `show` for PostScript text,
   but there is no command-line interface for placing text at pixel coordinates
   on a raster image.

3. **no `-draw rectangle`** — the accent bar and legend borders use
   `magick -draw 'rectangle x1,y1 x2,y2'`. Ghostscript's `rectfill` operator
   works in PostScript coordinate space on a PostScript canvas, not on a PNG.

ImageMagick stays. the `magick` binary (v7) or `convert` (v6 fallback) is the
only tool with the full compositing, annotation, and drawing surface needed.

### Fonts.qml — centralized font resources

`Fonts.qml` is the single source of truth for font resources, mirroring
`Config.qml`'s role for colours. It owns the three `FontLoader` instances
(`body` → Monaco, `icon` → Material Symbols Nerd variant, `title` → Charcoal)
and exposes semantic roles: `Fonts.body`, `Fonts.icon`, `Fonts.title`, and
`Fonts.iconBody` (a `[icon, body]` reference array — not a native fallback
chain; this Qt build doesn't support list-valued `font.families`).

no widget should reference a `FontLoader` id directly — always go through
`Fonts.*`. this is what prevents the class of bug where two widgets render
the same icon codepoint against different fonts and silently diverge (see
the `ThreatWatchWidget` vs `PopupFrame` icon-font mismatch, fixed in
dotfiles-quickshell-cleanup).

### patching a glyph into the bundled icon font

no FreeBSD logo exists anywhere in the bundled
`fonts/MaterialSymbolsSharp_Filled_36pt-Regular.ttf` — confirmed by scanning
its full glyph-name table *and* checking known nerd-font FreeBSD codepoint
candidates directly, not just a name search (patched nerd-font glyphs are
sometimes named generically, e.g. `uniF30C`, so a name-only search alone
can miss a glyph that's actually present).

[font-logos](https://github.com/Lukas-W/font-logos) has a proper FreeBSD
"Beastie" glyph, built at the right stroke weight for icon-font use. the
official [Nerd Fonts patcher](https://github.com/ryanoasis/nerd-fonts) ships
a self-contained `FontPatcher.zip` release bundling `font-logos.ttf` as one
of its glyph sources — didn't need the full nerd-fonts repo, just that one
release asset.

**important**: `font-logos` maps FreeBSD to its own `0xf30c` — that
codepoint is already used in *this* font (`battery_android_1`). copying a
glyph between fonts means picking a genuinely free codepoint in the
*destination* font, not reusing the source's own numbering. `0xf900` (just
past this font's existing `0xd`–`0xf8ff` range) was free and is what's
actually used here.

the glyph was copied via a small, surgical `fontTools`-only script — no
`FontForge`. **the first attempt used `fontforge -lang=py` to copy the
glyph and call `generate()`, and it broke other, unrelated glyphs on the
real machine** (reverted immediately). checking glyph count and rendering
the one new codepoint wasn't enough verification to catch it. the actual
cause: this font has a `GSUB` table (glyph substitution, referencing
glyphs by internal ID, not name/codepoint), and FontForge's full
open/edit/`generate()` cycle appears to rebuild/reorder more than just the
targeted glyph, silently shifting IDs that `GSUB` rules pointed at — Qt's
text shaping applies `GSUB` during rendering, so this broke glyphs at
display time in a way a plain codepoint→glyph check never would have
revealed.

the working approach: edit only the tables that actually need to change
(`glyf`, `hmtx`, `cmap`, glyph order) directly via `fontTools`, leaving
everything else — especially `GSUB` — completely untouched. verified this
time with checks that would have caught the FontForge issue: `GSUB` bytes
identical before/after, every pre-existing glyph's outline *and* metrics
unchanged (not just glyph count), original glyph order an exact prefix of
the new order (append-only, nothing reordered), plus a rendered PNG of the
new glyph and a few pre-existing ones to confirm visually.

incidental discovery made while verifying: this font's `cmap` only has
format-4 (BMP-only) subtables, no format-12 for the supplementary plane —
meaning a codepoint like `\uf1863` (used elsewhere for the `ThreatWatch`
radar icon, requiring a surrogate pair since it's above `0xffff`) could
never actually resolve through this font's own `cmap` at all. it must be
rendering via Qt's own font-fallback to some other system font, not
`MaterialSymbolsSharp` itself — pre-existing behavior, not something this
patch changed, but worth knowing before adding another glyph above `0xffff`
to this specific font.

**second correction, found after the first fontTools patch actually
shipped**: the new glyph rendered noticeably smaller and misaligned versus
every other icon. cause: `font-logos.ttf` and this font use different
`unitsPerEm` (512 vs 960) — the first pass copied the source glyph's raw
outline coordinates directly, silently assuming both fonts shared the same
coordinate scale. fix: draw the source glyph through a
`fontTools.pens.transformPen.TransformPen` scaling by the `unitsPerEm`
ratio (`dst_upm / src_upm`) into a fresh `TTGlyphPen`, and scale the
advance width/left-side-bearing by the same factor, rather than copying
raw numbers across. verified visually this time by rendering the new glyph
alongside two existing ones at the same point size to directly compare
scale and baseline, not just checking that *something* renders.

**third correction**: even at the right scale, the glyph still sat visibly
lower than the others. measured actual bounding boxes to confirm rather
than re-guess: `freebsd_logo` spanned `yMin -154` to `yMax 701` (partly
*below* baseline), while `power_settings_new`/`music_note` both spanned
roughly `80`–`880`/`120`–`840`, centered at `y=480`. `font-logos` simply uses
a different vertical placement convention than Material Symbols, which
uniform scaling alone can't fix — it needed an additional vertical
translation (added directly to the `TransformPen` matrix's `dy` term) to
recentre it on the same `y=480` the other icons share. verified by
checking the new glyph's bounding-box center numerically before shipping,
not just re-rendering and eyeballing it again.

use it via `font.family: Fonts.icon`, `text: "\uf900"`.

### Services/ — every singleton, one place

`Services/` holds every process-wide singleton: `Config` (colours +
settings), `Fonts` (font resources), `Time` (clock), `ThreatWatchModel`
(threat feed data layer), `Players` (MPRIS now-playing + transport control),
`Playlist` (downloaded/local track library + download queue), `Sound`
(volume/mute/output-switching state), `Session` (suspend/reboot/shutdown,
with cancelable delayed actions), and `Popups` (which popup, if any, is
currently open — see below). this replaced an earlier, inconsistent split —
`Config`/`Fonts`/`Time` used to sit at the project root ("global"), while
`ThreatWatchModel.qml` sat *with* `ThreatWatchPopup.qml` in `ThreatWatch/`
("feature-grouped"). caelestia's actual convention (our architecture
reference) splits by **layer** — `services/` for state/logic, `modules/`
for the UI that consumes it — not by feature or by "how global is this,"
so `Services/` now matches that: `ThreatWatch/`, `Playlist/`, and `Sound/`
are all view-only (a popup + `qmldir` each), their data layers live in
`Services/` alongside everything else.

consumers import it the same way as any other `qs.<Path>` module:
```qml
import qs.Services
...
color: Config.colors.base
text: Time.time
```
no `as Namespace` — bare, matching how root-level singletons were always
referenced before this move.

note: `Sound` is named `Sound`, not `Audio` — `Audio` collides with a real
built-in QML type from `QtMultimedia`; naming our own singleton `Audio`
produces a confusing "not allowed" error rather than a clean redefinition
error.

**gotcha hit during the migration, worth remembering**: relative paths
inside a moved singleton resolve from the *file's own location*, not the
project root. `Fonts.qml`'s `FontLoader` sources (`"fonts/Monaco.ttf"`) and
`Config.qml`'s `settings.json` path both needed a `../` prefix added after
moving one directory deeper — the `settings.json` case was the more
dangerous one, since it didn't error, it silently wrote a fresh,
defaults-only file in the wrong place instead of failing loudly.

### popup exclusivity: `Services/Popups.qml`

with four independent popups (`ThreatWatch`, `Playlist`, `Sound`, `Session`),
nothing stopped more than one from being open and overlapping at once — each
tracked its own `expanded`/`mapExpanded` boolean with no awareness of the
others. both reference repos solve this the same way, just with different
names: retroism's `Bar.qml` tracks a single `currentPopup` value + a
`closeAllPopups()` call; caelestia's `PopoutState`/`popouts.hasCurrent` does
the equivalent. `Popups.qml` matches that pattern here — one shared
`current: string` (`""` | `"threatwatch"` | `"playlist"` | `"sound"` |
`"session"`) and a `toggle(name)` function. each popup's own `expanded`-style
property became a read-only computed value (`Popups.current === "sound"`)
instead of a plain settable boolean; only each `TaskbarButton.onClicked`
handler writes to `Popups.current`, via `toggle()`, never the popups
themselves.

`Session/SessionActionPopup.qml` (the persistent "reboot/shutdown pending,
cancel?" notice) deliberately does **not** go through `Popups.current` — it's
not mutually exclusive with anything; it can and should stay visible
regardless of whatever other popup is open, since dismissing a pending
shutdown is a real decision, not routine bar navigation.

### Components/TriggeredPopup.qml — shared popup chrome + open/close wiring

all four `Popups.current`-gated popups (`ThreatWatchPopup`, `PlaylistPopup`,
`SoundPopup`, `SessionPopup`) were each independently hand-rolling the same
boilerplate: a `PanelWindow` + `WlrLayershell` setup, a `Components.PopupFrame`
for the win95 chrome, a background `MouseArea` to dismiss on outside-click, and
a `Connections`/`onExpandedChanged` block calling `chrome.open()`/`chrome.close()`.
`TriggeredPopup.qml` extracts all of that into one reusable base:

```qml
Components.TriggeredPopup {
    expanded:       Sound.expanded
    triggerX:       Sound.triggerX
    title:          "AUDIO"
    icon:           "\ue050"
    implicitWidth:  260
    implicitHeight: 180

    // popup-specific content goes here, as default children
}
```

each popup file now only needs its own content and an `expanded`/`triggerX`
binding back to its own singleton — no `PanelWindow`, no `WlrLayershell`
properties, no manual open/close wiring.

this is a deliberately simpler base than caelestia's own `Wrapper.qml` — that
component adds Hyprland-specific focus-grab, animated-detach, and queued-open
behavior this project has no use for. `TriggeredPopup` is scoped to exactly
what these four popups actually need, the same judgment call applied
throughout rather than porting caelestia's abstractions wholesale.

**a background-dismiss click assigning straight to a popup's own `readonly
expanded` property is a silent no-op** — `Playlist`/`Sound`'s pre-conversion
code did exactly this (`onClicked: Sound.expanded = false`, where `expanded`
is computed from `Popups.current`, not settable). always dismiss via
`Popups.current = ""`, which `TriggeredPopup`'s shared background `MouseArea`
now does correctly for all four.

### Components/TaskbarButton.qml — owns its own trigger-position binding

each of the four toggle buttons (`Session`, `ThreatWatch`, `Playlist`,
`Sound`) needs to report its own screen-space `x` onto its popup's singleton,
so the popup can position itself underneath. this used to be four
hand-copied `Binding { target: X; property: "triggerX"; value: {...} }`
blocks in `Bar.qml`, one per button — folded into `TaskbarButton` itself via
two properties:

```qml
Components.TaskbarButton {
    glyph:         "\ue050"
    isToggled:     Sound.expanded
    triggerTarget: Sound
    mapTarget:     taskbar.contentItem
    onClicked:     Popups.toggle("sound")
}
```

internally:

```qml
Binding {
    target:   root.triggerTarget
    property: "triggerX"
    when:     root.triggerTarget !== null && root.mapTarget !== null
    value: {
        root.x
        root.mapTarget ? root.mapToItem(root.mapTarget, 0, 0).x : 0
    }
}
```

two real bugs surfaced getting this right, worth remembering if this pattern
is ever copied again:

1. **`mapToItem`'s own internal reads aren't tracked as reactive
   dependencies** — referencing `root.x` first, as a bare statement, forces a
   real tracked dependency so the binding actually re-evaluates when the
   button moves (e.g. a preceding `RowLayout` sibling changing width). without
   it, the binding only evaluates once, at creation.
2. **a plain `mapItem` vs. `mapToItem` typo** produced the exact same visible
   symptom as a bug in the reactivity model would have (all four popups
   landing at `x=0`) — caught by checking the file directly, not by more
   reasoning about QML binding semantics.

### Components/ — shared, generic UI atoms

`Components/` holds QML types with no feature-specific knowledge:
`NewBorder`, `PopupFrame`, `TaskbarButton`, `IconTileButton`, and `ListRow`.
it has its own `qmldir` (`module Components`), same convention as `Taskbar/`
and `ThreatWatch/`, so consumers import it via Quickshell's own module
scheme:

```qml
import qs.Components
...
NewBorder { ... }
```

the bar you're reading about above the fold — `Bar.qml`, `Workspaces.qml`,
`ThreatWatchPopup.qml` — all import `Components/` this way. `Config` and
`Fonts` are not in `Components/`: they live in `Services/` (see above), a
different category from stateless, reusable view chrome.

`IconTileButton` and `ListRow` were added while porting retroism's actual
popup-content style into `PlaylistPopup`/`SoundPopup` — the popups were
using plain, unstyled `QtQuick.Controls.Basic` `Button`/`ListView` delegates,
which looked flat next to `PopupFrame`'s beveled win95 chrome. `IconTileButton`
replicates retroism's `StartMenu` tile style (double `NewBorder` bevel,
translucent icon); `ListRow` replicates its `AppLauncher` flat-row style, but
as a *selectable* container rather than an immediate-action button, since our
rows need both "select" and a separate "remove" action. `IconTileButton`'s
glyph font is a property (`glyphFont`, defaults to `Fonts.icon`), not
hardcoded — several glyphs used with it (transport controls, remove) are
plain Unicode symbols, not Material Symbols codepoints, and forcing the icon
font on those would likely have broken them, same lesson as `NowPlayingWidget`'s
music-note glyph.

`TaskbarButton` separately got the same `NewBorder` bevel treatment, with the
toggled state inverting which corner is raised (raised → sunken) — real
win95 pressed-button behavior, and it removes any need for a glyph swap
(a chevron, etc.) to signal a popup is open, though `toggledGlyph` still
works if you want one anyway. note `TaskbarButton` and `IconTileButton` look
deliberately different (no fill + full-opacity icon vs. translucent fill +
dimmed icon) — retroism does the same thing, distinguishing "chrome-level"
controls (the bar itself) from "content-level" controls (inside a popup),
not an inconsistency we introduced by accident.

**gotcha discovered moving `PopupFrame.qml` here:** a file can depend on a
sibling in the same directory with zero import statement — QML resolves
same-directory types automatically, `qmldir` or not. `PopupFrame.qml`
references `NewBorder` this way. that dependency is real but invisible to a
`grep` of its imports: if `NewBorder.qml` is ever moved to a different
subdirectory of `Components/`, `PopupFrame.qml` breaks silently at load time,
in a file nobody touched. QML has no way to declare "depends on this sibling"
explicitly — the only mitigation is a comment at the point of use.

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

### prefer NumberAnimation over the Animator family for popup/UI-transition fades

`Components/PopupFrame.qml`'s open/close fade originally used `OpacityAnimator`
(Qt Quick's render-thread-animated family — `OpacityAnimator`, `XAnimator`,
`ScaleAnimator`, etc.), inherited unchanged from before this project had a
shared popup base. once `PopupFrame` moved from being declared inline in each
popup's own file into one reusable component (`TriggeredPopup.qml`)
instantiated across multiple independent `wlr-layer-shell` surfaces, every
popup after the first one opened started visibly flickering on reopen (never
on the very first open).

confirmed step by step, not guessed:

- disabling the fade animation entirely removed the flicker — confirmed it
  was animation-specific, not a window-visibility or content-reload issue
- logging directly inside `PopupFrame.open()`/`close()` showed exactly one
  call per real transition — ruled out a double-invocation/duplicate-handler
  theory (a real, separate bug of that shape *was* found and fixed along the
  way — a debug handler that should only ever have lived in
  `TriggeredPopup.qml` had been added to `ThreatWatchPopup.qml` instead,
  throwing a `ReferenceError` on every transition since `chrome` isn't in that
  file's scope — but fixing it didn't resolve the flicker)
- swapping `OpacityAnimator` → plain `NumberAnimation` (identical `from`/`to`/
  `duration`/`easing`, only the type changed) fixed it while keeping the fade

`OpacityAnimator`'s render-thread execution is an optimization for staying
smooth while the GUI thread is under heavy, unrelated load — not something a
simple popup fade triggered by a user click actually needs. validated against
real precedent afterward: neither caelestia's own shared animation components
(`components/Anim.qml`, `components/CAnim.qml` — used for every UI transition
in that whole shell) nor Quickshell's own `ReloadPopup.qml` use the `Animator`
family anywhere for this kind of fade; both use plain `NumberAnimation`/
`ColorAnimation`.

**lesson**: default to plain `NumberAnimation`/`ColorAnimation` for popup and
UI-transition animations in this project, matching both reference
implementations. reach for the `Animator` family only if a specific, real
GUI-thread-contention symptom shows up — not preemptively.

### a colour slot must be checked against every background it can render over, not just colors.base

`ThreatWatchUtils/Utils.qml`'s `levelColors` mapped the idle (`"info"`) level
to `Config.colors.shadow`, reasoned as "muted, readable on the bar base." it
was readable on `colors.base` — but `Taskbar/Bar.qml`'s `trayBg` rectangle,
the panel sitting directly behind the tray icons, is *also* filled with
`colors.shadow`. the idle-state icon rendered in a colour identical to the
surface behind it: invisible by exact colour match, not a font or rendering
bug, and only discoverable by actually looking at the running bar — nothing
about the code was wrong in isolation.

fix: remapped to `colors.text`, which nothing else in the tray area uses as a
background fill. lesson: when choosing a `Config.colors.*` slot for a
foreground element, check every background layer it can appear over in situ,
not just the outermost bar colour.

---

## music playback (mpv + yt-dlp + mpv-mpris)

### why not shellbeats

an explore session considered `shellbeats` (a full C/ncurses YouTube client)
for ad-free YouTube audio. the actual requirement — ads live in the web
player UI, not the raw stream `yt-dlp` extracts — doesn't need a dedicated
client at all. plain `mpv` bundles `ytdl_hook.lua` as a built-in script
(compiled in, not a separate installed file — it won't show up in
`pkg info -l mpv`'s file listing, which is expected, not a sign it's missing).
adding `mpv-mpris` (a small Lua script) makes that `mpv` instance visible to
`Quickshell.Services.Mpris`, the same native-service pattern already used for
everything else in this project (see the "prefer a native Quickshell service
over a shell-out" convention below).

`shellbeats` would have built on FreeBSD (its includes are standard POSIX/BSD,
nothing Linux-specific) but its dependency shape — a self-updating binary
fetched from GitHub at runtime outside `pkg`, a JS runtime (`deno`/`node`)
solely to defeat YouTube's anti-bot checks, an optional third-party cloud
sync feature baked into the binary — conflicts with this project's
pkg-managed, minimal-dependency-chain preference.

### `yt-dlp` is deliberately not `pkg`-managed

unlike `mpv`/`mpv-mpris`/`python3` (all installed via `pkg`, checked by
`install.sh`), `yt-dlp` is installed per the
[official wiki instructions](https://github.com/yt-dlp/yt-dlp/wiki/Installation)
and kept current via its own `yt-dlp -U` self-update, independent of `pkg`'s
release cadence. this is a deliberate exception, not an inconsistency:
YouTube changes frequently enough that `yt-dlp` needs to update far more
often than a quarterly `pkg` release cycle supports. `install.sh` only checks
for its presence (`command -v yt-dlp`) and points at the wiki if missing —
it does not try to install or manage it.

**caveat**: `yt-dlp -U` checks GitHub's API for the latest release, which is
rate-limited per IP (unauthenticated) — on a shared or frequently-checking
connection this can silently fail rather than update. per
[yt-dlp#8175](https://github.com/yt-dlp/yt-dlp/issues/8175), the workaround
is bypassing the API lookup entirely and updating to a specific known tag:
```sh
yt-dlp --update-to stable@2023.09.24   # pin to a specific release directly
```
no general fix exists upstream beyond this — worth remembering if `-U`
starts reporting failures without an obvious cause.

### gotcha: `env: python3: No such file or directory`

`yt-dlp`'s generic release asset (the one both the official installer and
`shellbeats`' own bundled copy use — there is no FreeBSD-specific standalone
build) is a Python script with a `#!/usr/bin/env python3` shebang. FreeBSD
ports commonly install versioned binaries (`python3.12`, etc.) without a bare
`python3` symlink unless the generic meta-port is also installed. this
surfaces as `mpv`/`ytdl_hook` failing to run `yt-dlp` at all, which can look
like a much more exotic problem (YouTube anti-bot detection, a stale `yt-dlp`
version, `player_client` extractor-arg mismatches — all real, documented
issues in general, all ruled out here) before the actual, mundane cause is
found.

fix: `doas pkg install -y python3` (FreeBSD's meta-port for the
default-version symlink) — not a manual `ln -s`, which would be unmanaged
and untracked by `pkg`. `install.sh` checks for this alongside `mpv`/
`mpv-mpris`.

### audio output: why `mpv` needed rebuilding from ports

MPRIS control (`Services/Players.qml`) works regardless of which audio
backend `mpv` uses underneath — that's a separate protocol. actual audio
routing (volume, switching between speakers/headphones) is not, and getting
that working surfaced three independent, stacked findings:

1. the HDA codec genuinely supports hardware jack-sensing (`UNSOL` capability
   on a distinct `Headphones` pin, confirmed via `sysctl dev.hdaa`) — the
   hardware was never the limitation.
2. PulseAudio's FreeBSD backend, `module-oss.c`, has no port abstraction at
   all (`pactl list sinks` shows flat, portless sinks — one per detected PCM
   device, via `module-devd-detect`). `module-switch-on-port-available` has
   nothing to attach to here, so automatic switching on plug/unplug can't
   work no matter how `default.pa` is configured — this is an architectural
   limit of the backend, not a config gap.
3. the pkg-built `mpv` itself has PulseAudio (and PipeWire) disabled at
   compile time (`-Dpulse=disabled -Dpipewire=disabled` in its build
   configuration) — it was talking directly to `/dev/dsp` (OSS), bypassing
   PulseAudio entirely. `pactl list sink-inputs` staying empty while audio
   plays is the tell — nothing was ever registered with PulseAudio to
   switch in the first place.

given (2), automatic switching isn't achievable without a much larger,
unverified change (migrating the whole system to PipeWire, on the chance its
FreeBSD backend handles HDA port-switching better — never confirmed). manual
switching was the pragmatic target instead, which only needed (3) fixed.

**fix**: rebuilt `mpv` from ports with the PulseAudio option enabled
(`cd /usr/ports/multimedia/mpv && doas make config` — enable PulseAudio in
the options menu — `doas make install clean`), then locked it against `pkg`
overwriting the custom build:

```sh
doas pkg lock mpv
```

with `ao=pulse` set in `mpv.conf` (see the `mpv` stow package below), manual
switching now works reliably in both directions regardless of playback
state:

```sh
pactl set-default-sink oss_output.dsp1   # headphones
pactl set-default-sink oss_output.dsp0   # speakers
```

**updating this custom `mpv` build later**: `pkg upgrade` will skip it
entirely while locked (that's the point), so updates have to go back through
ports:

```sh
cd /usr/ports && doas git pull
cd /usr/ports/multimedia/mpv && doas make deinstall reinstall clean
doas pkg lock mpv   # re-confirm the lock survived the reinstall; re-apply if not
```

**why not pursue automatic switching further**: it would require PipeWire,
a materially heavier system change than anything else in this project, to
fix a problem manual switching already solves — worth revisiting only if
automatic switching becomes a real, recurring annoyance rather than a nice-
to-have. binding the manual `pactl` commands to sway keybindings is the
more proportionate next step (not yet implemented).

### `FileView.watchChanges` can't be trusted for externally-written files

`Services/Playlist.qml` watches an inbox file (`playlist-inbox.txt`) that
`bin/.local/bin/queue-track` appends a URL to on every bookmarklet click.
This never triggered `onTextChanged` reliably — confirmed via three
separate tests (waiting several minutes in case of a slow poll interval;
rewriting the file via a temp-file-plus-`mv` atomic replace, the same
pattern editors use on save) — all disproven by direct evidence, not just
assumption.

the root cause, per `FileView`'s actual C++ source
(`quickshell-mirror/quickshell`, `src/io/fileview.cpp`): it uses Qt's
`QFileSystemWatcher`, which only has native, event-driven backends on Linux
(`inotify`) and macOS (`fsevents`) — FreeBSD falls back to Qt's generic
polling watcher. quickshell's own config-file hot-reload
(`src/core/generation.cpp`) uses the *identical* watcher class, which is
why it reliably works on save in an editor while `FileView.watchChanges`
didn't work here — the exact mechanism for that asymmetry was never fully
pinned down (the atomic-replace test was meant to confirm it and didn't),
and it wasn't worth chasing further once a fix that sidesteps the question
entirely was available.

**fix**: don't rely on file-watching for externally-written files at all —
have the writer notify quickshell directly over IPC instead. `queue-track`
calls `qs ipc call playlist processInbox` immediately after its append,
hitting a `playlist`-targeted `IpcHandler` in `shell.qml` that calls
`Playlist._processInbox()` directly. instant, and doesn't depend on
whatever FreeBSD's Qt build does or doesn't support for file watching.

**lesson for next time**: `FileView.watchChanges` is fine for files
quickshell itself writes (`Config.qml`'s `settings.json`,
`Playlist.qml`'s own `playlist.json` via `writeAdapter()` — both confirmed
working throughout this project) since those changes happen from within
the same process. for anything written by an external script or process,
prefer an explicit `IpcHandler` notification over hoping the watcher
notices.

---

## script placement

a script goes in a thematic package (like `threatwatch/.local/bin/threatwatch`)
only when it's genuinely coupled to that package's other files — the
threatwatch script and its `config.env.template` are a cohesive unit,
meaningfully paired. everything else general-purpose goes in `bin`, so
`.local/bin/` doesn't end up fragmented across whichever unrelated package a
tool happened to be added alongside when it was written. `new_script` moved
out of `git` for exactly this reason — it's a general script generator with
nothing to do with git, it just historically landed there.

---

## stow layout

every top-level directory (except `docs/`) is a stow package. `install.sh`
handles all stow invocations interactively — you do not need to run `stow`
manually.

| package | stow target | platform | contents |
|---|---|---|---|
| `bin` | `$HOME` | all | `.local/bin/new_script`, `.local/bin/queue-track`, `.local/bin/switch-audio-output`, `.local/bin/sound-status`, `.local/share/applications/quickshell-add.desktop` — the canonical home for standalone tools not tightly coupled to another package's own files (`queue-track`/`switch-audio-output`/`sound-status` are used by `quickshell`'s `Playlist`/`Sound` services, but the scripts themselves have no quickshell-specific knowledge, so they stay here rather than moving to the `quickshell` package) |
| `cheatsheets` | `$HOME` | all | `.config/cheatsheets/` |
| `curl` | `$HOME` | all | `.curlrc` — silent, follow redirects, fail-on-error, 30s timeout |
| `foot` | `$HOME` | FreeBSD + Linux | `.config/foot/` |
| `git` | `$HOME` | all | `.gitconfig`, `.color.gitconfig`, `.gitignore`, `.local/bin/git-clone-bare-for-worktrees` |
| `inputrc` | `$HOME` | all | `.inputrc` |
| `mpv` | `$HOME` | FreeBSD | `.config/mpv/mpv.conf` — `ao=pulse`; requires `mpv` rebuilt from ports with PulseAudio enabled, see `docs/architecture.md`'s "audio output" section |
| `nvim` | `$HOME` | macOS | `.config/nvim/init.lua` — minimal single-file config, treesitter only |
| `pulseaudio` | `$HOME` | FreeBSD | `.config/pulse/daemon.conf` — `exit-idle-time = -1`, keeps the daemon persistent instead of autospawning-and-exiting on idle (that cycle cost ~6s per cold start, confirmed via `time pactl`) |
| `quickshell` | `$HOME` | FreeBSD | `.config/quickshell/` (bar + threatwatch QML, fonts) |
| `sh` | `$HOME` | FreeBSD | `.profile`, `.shrc` |
| `sketchybar` | `$HOME` | macOS | `.config/sketchybar/` |
| `ssh` | `$HOME` | all | `.ssh/config.template` — port-443 GitHub alias, ControlMaster, ServerAlive; FreeBSD also wants `keychain` for a persistent agent (see `docs/freebsd-setup/user-setup.md`) — the activation line in `sh/.profile` ships commented out until you've installed it |
| `sway` | `$HOME` | FreeBSD + Linux | `.config/sway/config`, `walls/freebsd-kilmynda-wide.png`, `walls/metropolis.png` |
| `threatwatch` | `$HOME` | all | `.local/bin/threatwatch`, `.config/threatwatch/config.env.template` |
| `tmux` | `$HOME` | all | `.tmux.conf` — C-a prefix, vim keys, true colour, split/nav bindings |
| `vim` | `$HOME` | all | `.vimrc`, `.config/vim/` |
| `vt` | `/` | FreeBSD | `boot/fonts/12x22.fnt.gz`, `boot/fonts/INDEX.fonts` |
| `zsh` | `$HOME` | macOS | `.zshrc`, `.git-worktree-functions.zsh` |

`vt` is the only package with a non-`$HOME` target. `install.sh` runs
`stow --target=/ vt` under `doas`/`sudo` — console font files must land in
`/boot/fonts/` for the FreeBSD loader to find them.

### why early-boot system config files aren't stowed

`/boot/loader.conf`, `/etc/rc.conf`, `/etc/sysctl.conf`, `/etc/fstab`, and
`/usr/local/etc/devd/automount_devd.conf` are all tracked as plain reference
copies under `docs/freebsd-setup/` — not stow-managed symlinks. this wasn't
the original plan; it's a correction made after a real, disruptive failure.

the first attempt symlinked `/etc/rc.conf` via `stow --adopt`, reasoning
(wrongly) that it was "read well after full multi-dataset mount, unlike
`loader.conf`." on the next reboot, `ly` failed with "failed to get active
tty"/"failed to crawl session directories" — `seatd`/`dbus` hadn't started at
all. root cause, confirmed by reading FreeBSD's actual `/etc/rc` source
(`libexec/rc/rc`, `cgit.freebsd.org`): `load_rc_config` (which sources
`/etc/rc.conf`) runs essentially as the *first* thing `/etc/rc` does, before
any mount-related `rc.d` script has run at all. this machine's home
directory lives on its own ZFS dataset (`zroot/home/mquezada`, separate from
`zroot/ROOT/default`, FreeBSD's own installer default — specifically so a
`bectl` rollback doesn't touch home directories). a symlink from
`/etc/rc.conf` into `~/git/dotfiles/...` pointed across that exact boundary,
and failed silently at the one moment it's read.

after that failure, every other early-boot candidate was checked against
FreeBSD's real `rc.d` `REQUIRE`/`BEFORE` chains before assuming anything —
not re-guessed the same way twice:

| file | reader | ordering vs. `/home`'s mount (`zfs`/`zfsbe`) |
|---|---|---|
| `/etc/rc.conf` | `/etc/rc` directly | confirmed before — the failure above |
| `/etc/sysctl.conf` | `rc.d/sysctl` | no `REQUIRE` line at all — unordered |
| `/etc/fstab` | `rc.d/mountcritlocal` | `mountcritlocal` REQUIREs only `root hostid_save mdconfig`; `zfsbe`/`zfs` REQUIRE `mountcritlocal` — fstab is read *before* `/home` mounts |
| `/usr/local/etc/devd/automount_devd.conf` | `rc.d/devd` | `REQUIRE: netif ldconfig`, `BEFORE: NETWORKING mountcritremote` — no ordering relative to `zfs`/`zfsbe` either |

every one of these is either confirmed-early or unordered/unproven — none
are things this project calls safe to symlink across a separate-home-dataset
boundary. the general rule that came out of this: **don't assume a
boot-time config file is safe to symlink just because it "feels" late in
boot — check the actual `rc.d` dependency chain, or default to a plain
tracked copy.**

each reference copy is synced by hand after editing:

```sh
doas cp ~/git/dotfiles/docs/freebsd-setup/loader.conf   /boot/loader.conf
doas cp ~/git/dotfiles/docs/freebsd-setup/rc.conf        /etc/rc.conf
doas cp ~/git/dotfiles/docs/freebsd-setup/sysctl.conf    /etc/sysctl.conf
doas cp ~/git/dotfiles/docs/freebsd-setup/fstab          /etc/fstab
doas cp ~/git/dotfiles/docs/freebsd-setup/automount_devd.conf /usr/local/etc/devd/automount_devd.conf
```

this is genuinely less convenient than a live symlink, but a stale userspace
dotfile is a minor annoyance; a boot-time config file that silently fails to
read is a machine that won't come up correctly — not a trade worth making
for convenience alone.

### manual stow

`install.sh` is the normal entry point, but individual packages can be stowed or
unstowed at any time without re-running the full installer.

stow a single package:

```sh
stow --dir=~/dotfiles --target="$HOME" --restow <package>
```

unstow (remove symlinks for) a package:

```sh
stow --dir=~/dotfiles --target="$HOME" --delete <package>
```

`--restow` is equivalent to `--delete` followed by `--stow` — it cleans up any
stale symlinks before creating fresh ones. safe to run repeatedly.

`vt` requires a root target and privilege escalation:

```sh
doas stow --dir=~/dotfiles --target=/ --restow vt
```

to preview what stow would do without changing anything, add `--simulate` (or `-n`):

```sh
stow --dir=~/dotfiles --target="$HOME" --simulate --restow <package>
```

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

the lint gate (`tests/lint.bats`) runs ShellCheck on all target shell scripts
and all `.bats` files and is the CI entry point — it must pass before any
other suite is run.

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
├── common.sh             shared helpers: tmp dir setup/teardown, tw_funcs_strip
├── lint.bats             ShellCheck gate — run this first; 19 tests covering all scripts + all .bats files
├── install.bats          install.sh OS detection and pkg_name / install_pkg unit tests
├── vim.bats              headless vim sourcing tests for .vimrc, theme.vim, lsp.vim
├── qml.bats              Qt Quick Test gate — Utils.qml pure-logic tests (qmltestrunner)
├── new_script.bats       unit tests for new_script (flags, generated content, output ShellCheck)
├── threatwatch.bats      unit tests for threatwatch against fixture JSON (no network)
├── git-clone-bare.bats   integration tests using a local bare repo
├── gwt.bats              tests sourcing gwt.sh against a local bare-worktree hub
└── fixtures/
    ├── quakes.json           2 EMSC events (M4.8 AUSTRIA, M3.7 BAVARIA)
    ├── flights.json          OpenSky state vectors (GAF001, REACH42, DLH123)
    ├── summary.json          full summary output with threat_level=high
    ├── gdacs.xml             Red alert Prague (in-region) + Orange Canary Islands (out-of-region)
    ├── polymarket.json       3 keyword-matching markets (Russia/NATO 45%, Ukraine 22%, Germany 8%)
    └── mapbox_count.json     stale month 2025-01 / count 42 (for rollover test)
```

run all suites:

```sh
bats tests/
```

run a single suite:

```sh
bats tests/lint.bats
```

all tests are network-free. `threatwatch.bats` uses the `TW_FUNCS` pattern:
`awk '/^# ── main/{exit}'` strips the case dispatcher from the script before
sourcing, so individual functions can be tested without the top-level
`tobar()` call polluting stdout. the sentinel `# ── main` is the existing
comment that precedes the dispatcher block.

`qml.bats` skips gracefully when `qmltestrunner` is not installed — the
availability test emits a `skip` rather than failing.

**hermetic mock strategy in install.bats** — `install.sh` calls `install_pkg`
which checks `command -v sudo` and `command -v doas`. on macOS the real
`/usr/bin/sudo` is in `PATH` and will prompt for a password if found.
`install.bats`'s `setup()` writes no-op `sudo` and `doas` stubs into `$MOCK_BIN`
alongside the existing `brew`, `pkg`, and `apt-get` mocks. `PATH="$MOCK_BIN:$PATH"`
ensures the stubs shadow the real binaries for every test in the file. the
pattern must be followed for any new system command that install.sh might invoke.

### vim quality

no linter is used for Vimscript. vint (the canonical Vimscript linter) is not in
FreeBSD ports, crashes on Vim 9 `#{key: val}` dict literal syntax (upstream issue
#339, unfixed), hangs on `:vim9script`, and has been abandoned since 2018 with 79
open issues. style conventions are enforced by convention, not tooling.

style conventions applied to all `.vim` files in this repo:

- `scriptencoding utf-8` as the first line of every file (multibyte chars present)
- single-quoted strings where no escape sequences are needed
- full option names (`tabstop` not `ts`, `autoindent` not `ai`)

**testing approach** — headless `vim -es` sourcing via `tests/vim.bats`:

```sh
vim --clean -es -u NONE \
    --cmd "set packpath=$TMPDIR" \
    --cmd "set cpoptions-=C" \
    -c "source <file>" \
    -c 'qa!'
```

`-es` is silent ex mode — no UI, no startup files, exits non-zero if any E-series
error fires during sourcing. each test checks `$status -eq 0`.

two `--cmd` flags are always required:

| flag | why |
|---|---|
| `set packpath=$TMPDIR` | points vim at a stub plugin directory so `packadd lsp` succeeds |
| `set cpoptions-=C` | in `-es` mode the C cpoption treats `\`-continuation lines as new commands, breaking the multiline `#{...}` dict literal in `lsp.vim` |

the lsp stub (`$TMPDIR/pack/plugins/opt/lsp/plugin/lsp.vim`) defines a no-op
`LspAddServer()` function so `lsp.vim`'s `call LspAddServer([…])` succeeds without
a real plugin checkout.

`.vimrc` sources `~/.config/vim/theme.vim` and `~/.config/vim/lsp.vim` via
hardcoded `~` paths. tests point `$HOME` at a tmpdir containing symlinks to the
repo files: `--cmd "let $HOME='$TMPDIR/home'"`.

### generated scripts

`new_script -q <path>` generates a POSIX sh script skeleton. the generated
output is itself ShellCheck-clean — verified by `tests/new_script.bats` test 9.
the `signal_exit` function in the generated code carries `# shellcheck
disable=SC2329` because it is only ever called via `trap "signal_exit …"` and
ShellCheck's direct-call analysis flags it as unused without the directive.

---

## QML quality

### tools

| tool | package (FreeBSD) | role |
|---|---|---|
| `qmllint` | `qt6-declarative` | batch linter — unqualified access, bad signal handlers, unused imports, type errors, JS anti-patterns |
| `qmlformat` | `qt6-declarative` | formatter only — no semantic checks. use `-i` for in-place edit |
| `qmlls6` | `qt6-declarative` | LSP server — completions, go-to-definition, hover in Vim |

all three binaries ship in the same package, but FreeBSD only symlinks a
subset into `/usr/local/bin/` with a `6` suffix (`qml6`, `qmlls6`,
`qmlscene6`, ...) — `qmllint` and `qmlformat` are **not** among them.
their real (unsuffixed) location is `/usr/local/lib/qt6/bin/`, which is not
on `PATH` by default:

```sh
/usr/local/lib/qt6/bin/qmllint
/usr/local/lib/qt6/bin/qmlformat
```

`lsp.vim` resolves this the same way `tests/qml.bats` resolves
`qmltestrunner`: check `PATH` first, fall back to the known FreeBSD path.
don't assume `qmllint` is bare-callable on FreeBSD — verify with
`pkg info -l qt6-declarative | grep bin` rather than guessing at a naming
convention (the `6`-suffix pattern that applies to `qmlls6` does **not**
apply to `qmllint`/`qmlformat`).

`qmllint` exits non-zero on any `error`-level finding. strictness is
per-category (e.g. `--unused-imports=error`) — there is no global `--strict`
flag.

### vim integration

live diagnostics come from `qmlls` (the LSP server, wired up via `yegappan/lsp`
in `lsp.vim`) — `<leader>df` shows diagnostics for the current file, `[d`/`]d`
jump between them, `K` shows hover info (though `K` specifically has a known
issue, see below).

an earlier version of this file wired `qmllint` into Vim's quickfix list via
`:make`/`<leader>lq`, separate from `qmlls`'s live diagnostics. it was removed:
`:make`'s implicit jump-to-first-error was creating a second, unloaded buffer
for the file already open instead of reusing it (diagnostic signs appeared,
the window went blank). replacing `:make` with `setqflist()` fixed that but
surfaced a second Vim quirk — `E282: Cannot read from` — tied to `system()`'s
temp-file capture mechanism. workarounds existed for both, but `qmllint` run
this way never added anything `qmlls`'s live diagnostics didn't already cover,
so the whole mechanism was dropped rather than kept working through Vim
internals for no real benefit. run `qmllint` directly from a terminal instead
when you want a full-tree batch report (see below).

**known issue:** mapping `K` (or any key) to `:LspHover`/`<Cmd>LspHover` does
not reliably show the popup — it flashes and the cursor may jump, even though
typing `:LspHover<CR>` manually works every time. cause unknown; use the
manual command instead of a keybinding for hover.

formatting is manual: `:!qmlformat -i %` rewrites the current file in place.
there is no autoformat-on-save — qmlformat is a separate concern from the LSP.

### qmlls and .qmlls.ini

`--build-dir build` (the original arg) was wrong for a pure-QML Quickshell
project — it pointed at a nonexistent CMake build directory and suppressed
valid completions. the correct approach is an empty `.qmlls.ini` in
`~/.config/quickshell/`. Quickshell auto-populates it with its module import
paths on first run. the file is committed as a placeholder so the stow package
creates it — Quickshell fills it in on startup.

per Quickshell's own changelog: *"LSP support for Singletons and Root-Relative
imports can be enabled by creating a file named `.qmlls.ini` in the shell root
directory... The generated configuration also includes QML import paths
available to Quickshell, meaning QMLLS no longer requires the `-E` flag."*
this is why `.qmlls.ini` exists and why `-E`/`QML_IMPORT_PATH` are not needed
in `lsp.vim`'s `qmlls` config on current Quickshell versions.

a real `.qmlls.ini` looks like:
```ini
[General]
no-cmake-calls=true
buildDir="/var/run/xdg/<user>/quickshell/vfs/<hash>"
importPaths="/usr/local/bin:/usr/local/lib/qt6/qml"
```
`buildDir` points at an ephemeral, per-process VFS directory Quickshell
materializes at runtime — it contains real symlinks mirroring the project
(`qs/Services/Config.qml -> .../Services/Config.qml`, etc.), confirmed by
direct inspection. it does **not** contain a `qmldir` for that mirror, which is why external
tooling (see below) can't fully resolve `import qs` even when pointed at it.

### `import qs` vs `import ".."` — a deliberate trade-off, not an oversight

this project uses `import qs` (Quickshell's own module scheme, `qs.<path>`
imports the shell root, available since Quickshell v0.2.0) for root singleton
access (`Config`, `Fonts`, `Time`), **not** relative-path imports
(`import ".."`) — even though `qs` cannot currently be resolved by standalone
`qmllint`/`qmlls` on this Quickshell/Qt version, producing `Unqualified
access`/`Failed to import qs` warnings across every consumer file.

this was verified exhaustively, not assumed:
- confirmed via a minimal, from-scratch repro (one singleton, one consumer
  one directory down, a proper `qmldir`, a fresh `.qmlls.ini`) that `import qs`
  from a subdirectory to a root singleton fails identically in both `qmllint`
  and `qmlls`, ruling out anything project-specific
- confirmed `import ".."` for the *same* singleton, *same* file, resolves
  cleanly — the only variable was the import style
- confirmed the VFS mirror Quickshell generates for `qs` lacks a `qmldir`,
  which is why no combination of `-I`/`-E`/`QML_IMPORT_PATH`/working directory
  changes anything — there's nothing for standard QML tooling to find
- ruled out caelestia-shell's approach as a model to copy: their `qs.services`
  imports rely on a real CMake-generated `build/qml` (via a C++ plugin this
  project deliberately doesn't have), not on Quickshell's VFS mirror

**the decision:** `qs` is the correct, documented, future-facing mechanism
(*"much more LSP friendly"* per Quickshell's own docs) and the noise is fully
understood and traced to specific upstream gaps, not ambiguity about our code.
accepting known, explained noise was judged better than reverting to a
mechanism that works today but isn't the one Quickshell's own tooling is
moving toward.

**subdirectory `qs.<path>` imports** (`qs.Taskbar`, `qs.Components`,
`qs.ThreatWatch`, `qs.ThreatWatchUtils`) are now fully adopted. `components/`,
`taskbar/`, and `threatwatch/` were renamed to `Components/`, `Taskbar/`, and
`ThreatWatch/` — `qs.<path>` requires an uppercase first letter, and those
were the last lowercase directories blocking it. every consumer now imports
`qs.<Path>` directly (no `as Namespace`, matching how root singletons are
accessed) instead of a relative path + namespace alias.

### known, accepted qmllint/qmlls warnings

four warning categories are structural — real Quickshell/Qt types, used
correctly, with incomplete external type metadata. each was confirmed by
directly inspecting Quickshell's own `.qmltypes` files, not assumed:

| warning | type | evidence |
|---|---|---|
| `Type PanelWindow is not creatable` | `PanelWindow` | `isCreatable: false` in `quickshell-window.qmltypes` — deliberate, `PanelWindow` requires a live compositor |
| `Property "adapter" has incomplete type "FileViewAdapter"` | `FileViewAdapter` | `isCreatable: false` — abstract base class; `JsonAdapter` (`prototype: "qs::io::FileViewAdapter"`) is the real, creatable subclass we correctly use |
| `unknown grouped property scope margins` / `Type margins is used but it is not resolved` | `Margins` | referenced as a property type (`type: "Margins"`) but never given its own exported `Component` declaration anywhere in Quickshell's `.qmltypes` |
| `Type QProcess::ExitStatus ... was not found` | `QProcess::ExitStatus` | same shape as `Margins` — referenced, never exported; no import can ever resolve it |

plus every `import qs`-related `Unqualified access` warning, per the section
above.

worth reporting upstream (two independent repro cases ready to file):
type-export gaps for `Margins`/`QProcess::ExitStatus`, and `qs`-from-
subdirectory resolution failing in standalone `qmllint`/`qmlls`.

### testing approach

Quickshell types (`PanelWindow`, `WlrLayershell`, `FileView`, `Process`) cannot
be tested headlessly — they require a live Wayland compositor or Quickshell's
C++ plugin loaded. only pure-logic QML (no `import Quickshell`) is exercisable
with `qmltestrunner`.

**Utils.qml** — extracted from `ThreatWatchModel.qml` specifically to enable
testing. it is a plain `QtObject` with `import QtQuick` only. it exposes:

| function / property | purpose |
|---|---|
| `levelColors` | level → `#rrggbb` colour map |
| `parseSummary(raw)` | JSON parse + field extraction from summary.json |
| `formatTimestamp(iso)` | `"2025-01-15T14:32:00Z"` → `"2025-01-15 14:32 UTC"` |
| `parsePins(raw)` | JSON parse + array validation from pins.json |
| `pinTypeLabel(type)` | string mapping for pin type → human label |

`ThreatWatchModel.qml` instantiates `Utils { id: utils }` as a child object and
delegates to it. `levelColors` is re-exposed on the model so downstream widgets
don't need to import Utils directly.

**tst_threatwatch.qml** in `tests/` is the Qt Quick Test file. it covers ~20
cases across all five Utils functions including data-driven table tests for
`pinTypeLabel`.

run headlessly:

```sh
QT_QPA_PLATFORM=offscreen /usr/local/lib/qt6/bin/qmltestrunner \
    -import quickshell/.config/quickshell/threatwatch \
    -input  tests/tst_threatwatch.qml
```

or via bats:

```sh
bats tests/qml.bats
```

`tests/qml.bats` resolves `qmltestrunner` from `$QML_TEST_RUNNER`, `$PATH`, or
the FreeBSD install path `/usr/local/lib/qt6/bin/qmltestrunner`. on machines
without Qt installed the availability test fails fast and the suite is skipped.

### dev workflow

`watchFiles = true` is the Quickshell default — any `.qml` file save triggers an
automatic sub-second reload. no command is needed for the basic edit loop.

for explicit reloads, `IpcHandler { target: "shell" }` in `shell.qml` exposes
two functions over the `qs` CLI:

```sh
qs ipc call shell reload       # soft reload — reuses windows
qs ipc call shell hardReload   # hard reload — destroys and recreates all windows
```

`qs log` shows runtime output and errors from the running Quickshell instance.

`swaymsg reload` does not restart `exec` processes — Quickshell keeps running
across sway config reloads.
