# Release Notes

## 1.2

Alarm audio compatibility update for released packages.

- Fixed alarm playback in user installs by preferring bundled WAV playback
- Kept MP3 fallback path for environments where WAV path is unavailable
- Added bundled `beep.wav` to improve compatibility across systems

## 1.1

Stability and timing update focused on alarm configuration and countdown accuracy.

- Added explicit Enable/Disable Alarms controls in settings
- Fixed alarm list instability when toggling alarms off and back on
- Fixed warning triggers at exact time thresholds
- Switched runtime countdown updates to monotonic uptime-based timing
- Fixed arc rendering `strokeWidth` errors

## 1.0

First stable release (promoted from 1.0-beta).

- Configurable timer duration
- Dynamic warning points with beep notifications
- Shutdown/reboot-aware boot anchor logic
- Transparent style and responsive text scaling
