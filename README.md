# AdAmp

A faithful recreation of the classic Winamp 2.x music player for macOS.

## Features

- Pixel-perfect recreation of the classic Winamp 2.x interface
- Full Winamp skin support (.wsz files)
- Main player, Playlist editor, and 10-band Equalizer windows
- Shade mode for all windows
- Classic window snapping and docking behavior
- Audio playback: MP3, FLAC, AAC, WAV, AIFF, ALAC, OGG
- Video playback: MKV, MP4, MOV, AVI, WebM, HEVC (KSPlayer/FFmpeg)
- Local media library with metadata parsing
- Plex Media Server integration with PIN-based authentication
- Plex music and video streaming
- Casting to Chromecast, Sonos, and DLNA devices
- Real-time spectrum analyzer visualization
- MilkDrop-style visualizations (projectM)
- Double size (2x) scaling mode

## Requirements

- macOS 12.0 (Monterey) or later
- Xcode 14.0+ with Command Line Tools
- Swift 5.9+

## Building

```bash
# Clone the repository
git clone https://github.com/ad-repo/adamp.git
cd adamp

# Download required frameworks
./scripts/bootstrap.sh

# Build and run
./scripts/run.sh
```

The bootstrap script downloads VLCKit and libprojectM from GitHub Releases with checksum verification.

To open in Xcode:

```bash
open Package.swift
```

## Media Library

Library data is stored as JSON at `~/Library/Application Support/AdAmp/library.json`.

**Backup & Restore API** (`MediaLibrary.swift`):

| Function | Description |
|----------|-------------|
| `backupLibrary(customName:)` | Creates timestamped JSON backup, returns URL |
| `restoreLibrary(from:)` | Restores from backup (auto-backs up current first) |
| `listBackups()` | Returns backup URLs sorted newest first |
| `deleteBackup(at:)` | Deletes a backup file |

Backups are stored in `~/Library/Application Support/AdAmp/Backups/`.

## Development

See [AGENTS.md](AGENTS.md) for documentation links and key source files.

## Skins

AdAmp supports classic Winamp 2.x skins (.wsz files). Download skins from [Winamp Skin Museum](https://skins.webamp.org/).

## License

This project is open source and uses the following licensed components:

- **KSPlayer** (GPL-3.0) - Video playback with FFmpeg backend

This project is not affiliated with Winamp LLC or Radionomy Group.

## Acknowledgments

- [Webamp](https://github.com/captbaritone/webamp) - Reference for skin parsing
- [Winamp Skin Museum](https://skins.webamp.org/) - Skin archive
- Original Winamp by Nullsoft
