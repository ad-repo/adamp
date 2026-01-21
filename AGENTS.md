# Agent Guide

## Documentation

- [docs/UI_GUIDE.md](docs/UI_GUIDE.md) - Coordinate systems, scaling, skin sprites, hit testing
- [docs/AUDIO_SYSTEM.md](docs/AUDIO_SYSTEM.md) - Audio engine, EQ, spectrum, Plex playback

## Key Source Files

| Area | Files |
|------|-------|
| Skin | `Skin/SkinElements.swift`, `Skin/SkinRenderer.swift`, `Skin/SkinLoader.swift` |
| Audio | `Audio/AudioEngine.swift`, `Audio/StreamingAudioPlayer.swift` |
| Windows | `Windows/MainWindow/`, `Windows/Playlist/`, `Windows/Equalizer/` |
| Plex | `Plex/PlexManager.swift`, `Plex/PlexServerClient.swift` |
| App | `App/WindowManager.swift`, `App/ContextMenuBuilder.swift` |

## Before Making UI Changes

1. Read [docs/UI_GUIDE.md](docs/UI_GUIDE.md)
2. Check `SkinElements.swift` for sprite coordinates
3. Follow existing patterns in `MainWindowView` or `EQView`
4. Test at different window sizes (scaling bugs)
5. Test with multiple skins
