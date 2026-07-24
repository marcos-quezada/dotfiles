## Why

The quickshell bar has accumulated dead code from an earlier prototype phase and hardcoded hex colour values that bypass the theme system. Cleaning this up reduces noise in code review, makes theme switching reliable for threat-level colours, and aligns the codebase with the improvements made in the linux-antiquity reference project.

## What Changes

- **Remove** `Bar.qml` — prototype file, never imported, predates the current modular structure
- **Strip** unused properties from `Config.qml`: `systemProfileImageSource`, `execCommands.*`, `systemDetails.*`, `setWallpaperToThemeWallpaper`, `militaryTimeClockFormat`, `bar.trayIconSize`, `bar.monochromeTrayIcons`
- **Add** missing colour slots to all themes in `Config.qml`: `accentDark`, `textLight`, `danger`, `warning`
- **Move** hardcoded threat-level hex colours out of `ThreatWatchUtils/Utils.qml` and into `Config.colors` per-theme
- **Remove** `setWallpaperToThemeWallpaper` default wallpaper path from all theme objects
- **Verify** widget left-click popup toggle works correctly under WlrLayershell on FreeBSD
- **Fix** pin tooltip hover event propagation in `ThreatWatchPopup.qml` if broken
- **Update** `docs/architecture.md` to reflect the cleaned state

## Capabilities

### New Capabilities

- `quickshell-theme-colours`: Extend `Config.colors` with `accentDark`, `textLight`, `danger`, and `warning` slots across all themes, and wire threat-level colours through them

### Modified Capabilities

*(none — no existing specs exist; no spec-level requirement changes apply)*

## Impact

- `quickshell/.config/quickshell/Bar.qml` — deleted
- `quickshell/.config/quickshell/Config.qml` — properties removed, colour slots added per theme
- `quickshell/.config/quickshell/ThreatWatchUtils/Utils.qml` — hardcoded hex values replaced with `Config.colors.*` references
- `quickshell/.config/quickshell/threatwatch/ThreatWatchPopup.qml` — tooltip event propagation reviewed and fixed if needed
- `docs/architecture.md` — updated to reflect current structure
- No new QML dependencies introduced
