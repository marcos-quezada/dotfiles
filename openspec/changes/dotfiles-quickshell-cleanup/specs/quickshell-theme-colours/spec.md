## ADDED Requirements

### Requirement: Config.colors exposes accentDark, textLight, danger, and warning slots for all themes
Every theme object in `Config.qml` SHALL include the four colour slots `accentDark`, `textLight`, `danger`, and `warning`. Each value SHALL be a CSS hex colour string chosen for legibility against that theme's `base` colour.

#### Scenario: All five themes include the new slots
- **WHEN** `Config.colors` is read for any of the themes `default`, `yorha`, `cherry`, `indigo`, or `gleep`
- **THEN** the resulting object contains non-empty string values for `accentDark`, `textLight`, `danger`, and `warning`

#### Scenario: Theme switch updates semantic colour bindings
- **WHEN** `Config.settings.currentTheme` is changed to a different valid theme
- **THEN** all bindings to `Config.colors.danger`, `Config.colors.warning`, `Config.colors.accentDark`, and `Config.colors.textLight` update to the new theme's values

### Requirement: Threat-level colours are resolved through Config.colors
`ThreatWatchUtils/Utils.qml` SHALL NOT contain hardcoded hex colour values for threat levels. The `levelColors` property SHALL resolve each level's colour from `Config.colors` slots according to the mapping: `critical` → `danger`, `high` → `urgent`, `medium` → `warning`, `low` → `accent`, `info` → `shadow`.

#### Scenario: levelColors reflects the active theme
- **WHEN** the active theme is changed
- **THEN** `ThreatWatchModel.levelColors` values update to match the new theme's corresponding colour slots

#### Scenario: All five threat levels have a colour
- **WHEN** `levelColors` is evaluated for any valid theme
- **THEN** entries for `critical`, `high`, `medium`, `low`, and `info` are all non-empty strings

### Requirement: Dead Config settings properties are removed
`Config.qml` SHALL NOT declare the following settings properties: `systemProfileImageSource`, `execCommands` (the full object), `systemDetails` (the full object), `setWallpaperToThemeWallpaper`, `militaryTimeClockFormat`, `bar.trayIconSize`, `bar.monochromeTrayIcons`. Theme objects SHALL NOT include a `defaultWallpaperPath` key.

#### Scenario: Removed properties are absent from the settings object
- **WHEN** `Config.settings` is inspected at runtime
- **THEN** accessing any of the removed property names returns `undefined`

#### Scenario: Remaining bar settings are intact
- **WHEN** `Config.settings` is inspected after the cleanup
- **THEN** `bar.fontSize` is present and retains its default value of `12`

### Requirement: Bar.qml prototype file is deleted
The file `quickshell/.config/quickshell/Bar.qml` SHALL NOT exist in the repository.

#### Scenario: File is absent
- **WHEN** the repository is checked after the change
- **THEN** `quickshell/.config/quickshell/Bar.qml` does not exist and no QML import references it
