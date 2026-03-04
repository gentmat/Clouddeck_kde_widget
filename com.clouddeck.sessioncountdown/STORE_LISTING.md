# KDE Store Listing (Draft)

## Title

clouddeck session countdown

## Version

1.2

## Short Description

Configurable Plasma 6 countdown widget with boot-aware timing and warning beeps.

## Long Description

clouddeck session countdown is a KDE Plasma 6 widget that shows a large, panel-friendly countdown timer.

Features:

- Configurable duration (hours + minutes)
- Dynamic warning list (`+` / `-`) in minutes before end
- Warning alarms can be enabled/disabled
- Boot-aware countdown anchoring
- Transparent display with responsive auto-sized text

Plugin ID: `com.clouddeck.sessioncountdown`

## Release Notes (1.2)

- Fixed alarm playback in user installs by preferring bundled WAV playback
- Kept MP3 playback as fallback for runtime compatibility
- Added bundled `beep.wav` to improve alarm reliability across systems
