# Changelog

## 1.2

- Fixed release-install alarm audio by preferring bundled WAV playback (`SoundEffect`)
- Kept MP3 playback as fallback for broader runtime compatibility
- Added bundled `beep.wav` asset to improve out-of-the-box alarm reliability

## 1.1

- Fixed settings instability when warning alarms are disabled and re-enabled
- Added explicit Enable/Disable Alarms flow in the configuration UI
- Fixed warning trigger handling at exact threshold boundaries
- Switched runtime countdown clock updates to monotonic uptime-based timing
- Fixed arc rendering `strokeWidth` ReferenceError in main UI

## 1.0

- First stable release (promoted from 1.0-beta)
- No functional changes from the latest beta package

## 1.0-beta

- Initial public beta release
- Configurable timer duration
- Dynamic warning list with configurable beep length
- Boot-aware countdown logic with reboot/shutdown handling
- Transparent timer rendering with auto-sized text
