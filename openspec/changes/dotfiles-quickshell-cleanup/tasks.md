## 1. Phase 1 — Remove dead code

- [x] 1.1 Delete `quickshell/.config/quickshell/Bar.qml`
- [x] 1.2 Remove the `systemProfileImageSource` property from `Config.qml` `JsonObject settings`
- [x] 1.3 Remove the `execCommands` `JsonObject` block from `Config.qml` `JsonObject settings`
- [x] 1.4 Remove the `systemDetails` `JsonObject` block from `Config.qml` `JsonObject settings`
- [x] 1.5 Remove the `setWallpaperToThemeWallpaper` property from `Config.qml` `JsonObject settings`
- [x] 1.6 Remove the `militaryTimeClockFormat` property from `Config.qml` `JsonObject settings`
- [x] 1.7 Remove `bar.trayIconSize` and `bar.monochromeTrayIcons` from the `bar` `JsonObject` in `Config.qml`
- [x] 1.8 Remove the `defaultWallpaperPath` key from every theme object in `Config.qml`
- [x] 1.9 Verify no remaining QML file references any of the removed properties (grep check)

## 2. Phase 2 — Add colour slots to themes

- [ ] 2.1 Add `accentDark`, `textLight`, `danger`, `warning` slots to the `default` theme in `Config.qml` with values appropriate for its `#d8d8d8` base
- [ ] 2.2 Add the same four slots to the `yorha` theme
- [ ] 2.3 Add the same four slots to the `cherry` theme
- [ ] 2.4 Add the same four slots to the `indigo` theme
- [ ] 2.5 Add the same four slots to the `gleep` theme
- [ ] 2.6 Verify all five themes have non-empty values for all four new slots

## 3. Phase 2 — Wire threat-level colours through Config

- [ ] 3.1 Change `levelColors` in `ThreatWatchUtils/Utils.qml` from `readonly property var` to `property var` with a JS object binding that references `Config.colors.danger`, `Config.colors.urgent`, `Config.colors.warning`, `Config.colors.accent`, and `Config.colors.shadow`
- [ ] 3.2 Add `import "../"` (or the appropriate relative path) to `Utils.qml` so `Config` is accessible, if not already imported via `ThreatWatchModel`
- [ ] 3.3 Confirm `ThreatWatchModel.qml` passes `levelColors` through to widgets without caching the values as constants
- [ ] 3.4 Visually verify each threat level colour renders correctly on the `default` theme

## 4. Phase 3 — Interaction verification

- [ ] 4.1 On a live FreeBSD session, left-click the ThreatWatch widget and confirm the map popup toggles open and closed
- [ ] 4.2 If popup toggle is broken, inspect the `Item + MouseArea` wrapper in `ThreatWatchWidget.qml` and fix `z`-ordering or `propagateComposedEvents` as needed
- [ ] 4.3 On the same session, hover over a map pin in `ThreatWatchPopup.qml` and confirm the inline Rectangle tooltip appears
- [ ] 4.4 If tooltip is not visible, check `z` value of the tooltip `Rectangle` and `containsMouse` binding; fix event propagation if needed
- [ ] 4.5 If FreeBSD testing is not possible in this session, document findings (or the gap) in `docs/architecture.md` under a "Known Issues" section

## 5. Documentation

- [ ] 5.1 Update `docs/architecture.md` to remove references to `Bar.qml` and the deleted settings properties
- [ ] 5.2 Add a note in `docs/architecture.md` describing the `Config.colors` semantic slots (`accentDark`, `textLight`, `danger`, `warning`) and their use in the threatwatch module
