## Context

The quickshell bar is composed of three QML modules (taskbar, threatwatch, shared utilities) plus a `Config.qml` singleton. The codebase has accumulated dead code from a prototype phase (`Bar.qml`, several unused `Config` settings properties) and hardcodes threat-level colours in `ThreatWatchUtils/Utils.qml` rather than routing them through the theme system.

The linux-antiquity reference project (same author, later iteration) introduces four additional colour slots per theme — `accentDark`, `textLight`, `danger`, `warning` — and uses them to express semantic colours in UI components. Adopting these slots here allows threat-level colours to be theme-aware without introducing new dependencies.

Current state:
- `Bar.qml` exists in the package root but is imported by nothing
- `Config.qml` settings carries `systemProfileImageSource`, `execCommands.*`, `systemDetails.*`, `setWallpaperToThemeWallpaper`, `militaryTimeClockFormat`, `bar.trayIconSize`, `bar.monochromeTrayIcons` — none referenced in any QML file
- Each theme object also carries `defaultWallpaperPath: ""` — a vestige of `setWallpaperToThemeWallpaper`
- `ThreatWatchUtils/Utils.qml` has a `levelColors` map with five hardcoded hex values; all widgets read this via `ThreatWatchModel`
- `ThreatWatchPopup.qml` uses an inline `Rectangle`-based tooltip (correct approach given `Qt.ToolTip` does not work in `PanelWindow`), but event propagation under WlrLayershell on FreeBSD is unverified

Constraints: QML only, no new runtime dependencies, phases 1 and 2 must not break map display or theme switching.

## Goals / Non-Goals

**Goals:**
- Remove `Bar.qml` and all unreferenced `Config` settings properties
- Add `accentDark`, `textLight`, `danger`, `warning` slots to every theme in `Config.qml`
- Replace hardcoded hex values in `Utils.qml`'s `levelColors` with `Config.colors.*` references
- Verify or fix widget left-click popup toggle under WlrLayershell
- Verify or fix pin tooltip hover event propagation in `ThreatWatchPopup.qml`
- Update `docs/architecture.md` to reflect the cleaned structure

**Non-Goals:**
- Adding new themes
- Changing the theme-switching mechanism
- Altering map tile fetching or the Mapbox integration
- Adding new UI features to any module

## Decisions

### D1 — Map `danger`/`warning` directly to threat levels; derive `info`/`low` from base slots

`levelColors` currently has five entries: `critical`, `high`, `medium`, `low`, `info`. The new colour slots provide `danger` and `warning` directly. For the remaining levels:

| Level    | Mapped slot     | Rationale |
|----------|-----------------|-----------|
| critical | `colors.danger` | Semantically matches; all themes define it |
| high     | `colors.urgent` | Already present in all themes; conveys urgency |
| medium   | `colors.warning`| Semantically matches; all themes define it |
| low      | `colors.accent` | Positive/neutral emphasis; theme-appropriate |
| info     | `colors.shadow` | Muted, de-emphasised; readable on bar base |

Alternative considered: keep `levelColors` as a static map but populate it from `Config.colors` at binding time. Rejected — introduces indirection with no benefit; direct `Config.colors.*` references are simpler and automatically reactive to theme changes.

### D2 — Pick theme-appropriate values for new colour slots

The existing five themes (`default`, `yorha`, `cherry`, `indigo`, `gleep`) were designed for a light bar. The reference project themes are dark. Colour values for `danger`, `warning`, `accentDark`, `textLight` must be chosen to read legibly on each theme's `base` colour. Values will be derived by sampling hue from existing theme accents and adjusting lightness to maintain contrast.

### D3 — `defaultWallpaperPath` removal is safe

Every theme already has `defaultWallpaperPath: ""`. Removing the property eliminates the key from the JS object; no QML file accesses it. No migration needed.

### D4 — Phase 3 interaction work is best-effort

The `Item + MouseArea` wrapper pattern for the widget is architecturally correct per commit history. If FreeBSD/WlrLayershell testing cannot be completed in this change, the finding will be documented in `docs/architecture.md` under a known-issues section and the task marked incomplete. The inline `Rectangle` tooltip approach in `ThreatWatchPopup.qml` is the correct workaround for `PanelWindow`; any fix is limited to `z`-ordering, `propagateComposedEvents`, or `containsMouse` binding corrections.

## Risks / Trade-offs

- **Colour contrast on existing themes** — `danger`/`warning` values chosen manually may not meet contrast expectations on all themes. Mitigation: test each theme visually after Phase 2.
- **`Utils.qml` reactive binding** — `levelColors` is declared `readonly property var`. Replacing static hex strings with `Config.colors.*` references requires changing the declaration to a computed `property var` (or a function call). Mitigation: change to `property var levelColors: ({ ... })` binding — QML will re-evaluate when `Config.colors` changes.
- **Phase 3 left incomplete** — tooltip and click behaviour on FreeBSD may require live hardware testing. Mitigation: document findings clearly so the work can be picked up in a follow-on change.

## Open Questions

- None blocking Phase 1 or 2. Phase 3 verification requires a live FreeBSD session with Quickshell running.
