# Sonos Integration

This document covers Sonos speaker discovery, casting, and multi-room grouping in NullPlayer.

## Quick Start

1. Right-click anywhere in NullPlayer → **Output Devices → Sonos**
2. Check the rooms you want to cast to (checkboxes stay open for multi-select)
3. Click **🟢 Start Casting** to begin playback
4. Click **🔴 Stop Casting** to end the session

## Discovery Methods

NullPlayer uses two methods to discover Sonos devices:

### 1. SSDP (Simple Service Discovery Protocol)
- UDP multicast to `239.255.255.250:1900`
- Search target: `urn:schemas-upnp-org:device:ZonePlayer:1`
- Works on most networks but can be blocked by firewalls/routers

### 2. mDNS/Bonjour (Fallback)
- Service type: `_sonos._tcp.local.`
- Uses Apple's NWBrowser API
- More reliable on networks that block UDP multicast
- Added as fallback due to Sonos app changes in 2024-2025

## Requirements

### UPnP Must Be Enabled
Sonos added a UPnP toggle in their app settings. **Discovery will fail if disabled.**

To enable:
1. Open Sonos app (iOS/Android)
2. Go to **Account → Privacy & Security → Connection Security**
3. Ensure **UPnP** is **ON** (default)

If UPnP is disabled:
- SSDP discovery won't find devices
- mDNS discovery may still work but SOAP control won't
- The macOS/Windows Sonos app also won't work

### Connection Security (Firmware 85.0+, July 2025)

Sonos firmware 85.0-66270 added optional security settings:

| Setting | Default | Effect if Changed |
|---------|---------|-------------------|
| Authentication | OFF | Blocks SOAP commands from NullPlayer |
| UPnP | ON | Disables ALL local SOAP control |
| Guest Access | ON | Prevents same-network playback control |

NullPlayer detects 401/403 SOAP errors and shows a specific message directing users to:
Sonos app → Settings → Account → Privacy & Security → Connection Security

## Architecture

### Zone vs Group vs Room
- **Zone**: Individual Sonos speaker hardware (e.g., a single Sonos One)
- **Room**: A named location that may contain one or more zones (e.g., "Living Room" with stereo pair)
- **Group**: Multiple rooms playing in sync (e.g., "Living Room + Kitchen")

When casting, NullPlayer targets the **group coordinator** - the speaker that controls playback for the group.

### Discovery Flow
1. SSDP/mDNS finds Sonos devices on network
2. Fetch device description XML from each device (port 1400)
3. Extract room name, UDN (unique device name), and AVTransport URL
4. After 3 seconds, fetch group topology from any zone
5. Create cast devices based on groups (showing coordinator only)

### Group Topology
Fetched via SOAP request to `/ZoneGroupTopology/Control`:
```xml
<u:GetZoneGroupState xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1"/>
```

Response contains all groups and their member zones.

---

## User Interface

### Accessing the Sonos Menu
1. Right-click anywhere in NullPlayer
2. Go to **Output Devices → Sonos**

### Menu Structure

```
Sonos                          ▸
├── ☐ Dining Room                 (checkbox - selectable room)
├── ☐ Living Room                 (checkbox - selectable room)  
├── ☐ Kitchen                     (checkbox - selectable room)
├── ─────────────────
├── 🟢 Start Casting              (when NOT casting)
│   OR
├── 🔴 Stop Casting               (when casting)
└── Refresh
```

### Checkbox Behavior

The checkbox meaning depends on whether you're currently casting:

**When NOT casting:**
| State | Meaning |
|-------|---------|
| ☐ Unchecked | Room is not selected for casting |
| ☑ Checked | Room is selected for future casting |

**When casting:**
| State | Meaning |
|-------|---------|
| ☐ Unchecked | Room is NOT receiving audio from the app |
| ☑ Checked | Room IS receiving audio from the app |

### Multi-Select Feature

The room checkboxes use a custom view that **keeps the menu open** when clicked. This allows you to:
- Select multiple rooms without the menu closing
- Quickly configure your cast targets
- Click "Start Casting" when ready

### Visual Indicators

| Indicator | Meaning |
|-----------|---------|
| 🟢 Start Casting | Green circle - ready to begin casting |
| 🔴 Stop Casting | Red circle - casting is active, click to stop |

---

## Casting Workflow

### Starting a Cast

1. **Load music** - Play or load a track from Plex, Subsonic, local files, or internet radio
2. **Open Sonos menu** - Right-click → Output Devices → Sonos
3. **Select rooms** - Check one or more room checkboxes
4. **Start casting** - Click "🟢 Start Casting"

The app will:
- Cast to the first selected room
- Join additional rooms to that group
- Update checkboxes to show which rooms are receiving audio

**Internet Radio Note:** Radio streams are live and don't support seeking. When you cast a radio station that's already playing locally, playback on Sonos starts fresh from the live stream (time resets to 0:00).

### Managing Rooms While Casting

While casting is active:
- **Check a room** → Room joins the cast group and starts playing
- **Uncheck a non-coordinator room** → Room leaves the group and stops playing
- **Uncheck the coordinator room** → Casting stops entirely (user must restart with a different room selected)

**Note:** The coordinator is the first room you started casting to. Other rooms join its group. If you want to switch to a different primary room, stop casting and restart with the new room selected.

### Stopping a Cast

Click **🔴 Stop Casting** to:
- Stop playback on all Sonos rooms
- Clear all room selections
- Return to local playback (if audio was playing)

### Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| "No Music" | No track loaded | Load/play a track first |
| "No Room Selected" | No rooms checked | Select at least one room |
| "No Device Found" | Discovery incomplete | Click Refresh, wait 10 seconds |

---

## Implementation Details

### State Management

**CastManager.swift** maintains:
```swift
/// Rooms selected for Sonos casting (UDNs) - used before casting starts
var selectedSonosRooms: Set<String> = []
```

This set stores room UDNs that the user has checked but hasn't started casting to yet.

### Checkbox State Logic

**ContextMenuBuilder.swift** determines checkbox state:

```swift
if isCastingToSonos {
    // WHILE CASTING: checked = receiving audio from cast session
    // Check if this room is the cast target or in the cast group
    isChecked = (room.id == castTargetUDN) ||
                (room.groupCoordinatorUDN == castTargetUDN) ||
                (room is coordinator and target is in its group)
} else {
    // NOT CASTING: checked = room is selected for future cast
    isChecked = castManager.selectedSonosRooms.contains(room.id)
}
```

### Custom Checkbox View

**SonosRoomCheckboxView** is an `NSView` subclass that:
- Renders a checkbox with the room name
- Handles clicks without closing the menu
- Updates `selectedSonosRooms` when not casting
- Joins/unjoins rooms when casting is active

```swift
class SonosRoomCheckboxView: NSView {
    private let checkbox: NSButton
    private let info: SonosRoomToggle
    
    @objc private func checkboxClicked(_ sender: NSButton) {
        if isCastingToSonos {
            // Toggle actual Sonos group membership
            if isNowChecked {
                joinSonosToGroup(...)
            } else {
                unjoinSonos(...)
            }
        } else {
            // Just update local selection state
            if isNowChecked {
                selectedSonosRooms.insert(roomUDN)
            } else {
                selectedSonosRooms.remove(roomUDN)
            }
        }
    }
}
```

### Device Matching

**Challenge**: `sonosRooms` returns room UDNs, but `sonosDevices` only contains group coordinators.

**Solution** in `castToSonosRoom`:
1. Try direct ID match (room is a coordinator)
2. Fall back to matching by room name
3. Use first available device as last resort

```swift
// Find device that matches selected room
for udn in selectedUDNs {
    // Direct match
    if let device = devices.first(where: { $0.id == udn }) { ... }
    // Name match
    if let room = rooms.first(where: { $0.id == udn }),
       let device = devices.first(where: { $0.name.hasPrefix(room.name) }) { ... }
}
```

### Group Management

**Join a group** - `SetAVTransportURI` with `x-rincon:{coordinator_uid}`:
```xml
<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
  <InstanceID>0</InstanceID>
  <CurrentURI>x-rincon:RINCON_xxxx</CurrentURI>
  <CurrentURIMetaData></CurrentURIMetaData>
</u:SetAVTransportURI>
```

**Leave a group** - `BecomeCoordinatorOfStandaloneGroup`:
```xml
<u:BecomeCoordinatorOfStandaloneGroup xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
  <InstanceID>0</InstanceID>
</u:BecomeCoordinatorOfStandaloneGroup>
```

---

## Casting Protocol

### AVTransport Control
Sonos uses UPnP AVTransport service for playback:
- Control URL: `http://{ip}:1400/MediaRenderer/AVTransport/Control`
- Service type: `urn:schemas-upnp-org:service:AVTransport:1`

Key actions:
- `SetAVTransportURI` - Set media URL with DIDL-Lite metadata
- `Play` - Start playback
- `Pause` - Pause playback
- `Stop` - Stop playback
- `Seek` - Seek to position (REL_TIME format: HH:MM:SS)
- `GetTransportInfo` - Get transport state (PLAYING, STOPPED, PAUSED_PLAYBACK, etc.)
- `GetPositionInfo` - Get current position and track duration

### Fire-and-Forget Commands

For Sonos audio casting, playback control commands use a **fire-and-forget** pattern:

| Command | Behavior |
|---------|----------|
| `Pause` | Sends SOAP request, returns immediately |
| `Resume` | Sends SOAP request, returns immediately |
| `Seek` | Sends SOAP request, returns immediately |

**Why fire-and-forget?**
- Sonos SOAP requests can take 5-10 seconds due to network latency
- Blocking on responses makes the UI unresponsive
- The commands succeed even without waiting for acknowledgment

**Implementation:**
- Commands spawn a background `Task` to send the SOAP request
- UI updates immediately (optimistic update)
- Errors are logged but don't block the user
- TV/DLNA casting still uses blocking behavior (needed for video sync)

**Error detection:**
- Consecutive failures are tracked (threshold: 3)
- After 3 failures, a user-facing error notification is posted
- Counter resets on any successful command
- This detects when the Sonos speaker becomes unreachable

This differs from track changes (`SetAVTransportURI` + `Play`) which use the generation counter pattern to handle rapid clicking - see the loading overlay in `MainWindowView`.

### Volume Control
Via RenderingControl service:
- Control URL: `http://{ip}:1400/MediaRenderer/RenderingControl/Control`
- `SetVolume` - Set volume (0-100)
- `GetVolume` - Get current volume
- `SetMute` / `GetMute` - Mute control

### Playback State Monitoring

NullPlayer polls Sonos every 5 seconds during casting using two SOAP actions:

- `GetTransportInfo` - Returns transport state: PLAYING, PAUSED_PLAYBACK, STOPPED, TRANSITIONING, NO_MEDIA_PRESENT
- `GetPositionInfo` - Returns RelTime (current position) and TrackDuration

**Why polling instead of UPnP events:**
- Polling is simpler (no callback server, no subscription management)
- 5-second interval is sufficient for detecting disconnections
- UPnP event subscriptions require a local HTTP server, subscription renewal (at 85% of timeout per SoCo), and LastChange XML parsing

**What polling detects:**
- Sonos stopped externally (user paused via Sonos app, speaker went to sleep)
- Track position drift (syncs local timer with actual Sonos position)
- Device unreachable (SOAP timeout indicates speaker offline)

**Polling lifecycle:**
- Started when Sonos casting begins (in CastManager)
- Stopped when casting ends (stopCasting)
- Also runs a post-wake check after Mac sleep

### Resilience and Recovery

**Network change detection:**
- LocalMediaServer monitors network changes via NWPathMonitor
- IP address refreshed automatically when Wi-Fi changes
- New file registrations use the updated IP

**Mac sleep/wake handling:**
- CastManager observes NSWorkspace.willSleepNotification and didWakeNotification
- On wake: waits 2s for network, polls Sonos state, updates UI if playback stopped

**Server health checks:**
- LocalMediaServer pings itself every 30 seconds
- Auto-restarts if the ping fails

**Fire-and-forget error detection:**
- Tracks consecutive failures for pause/resume/seek commands
- Posts CastManager.errorNotification after 3 consecutive failures
- Counter resets on any successful command

**Group topology refresh:**
- During Sonos casting, group topology is refreshed every 60 seconds
- Detects external group changes made via the Sonos app

---

## Limitations

### Bonded Speakers
Bonded speakers are handled automatically:
- **Stereo pairs** (two speakers as L/R) act as one room
- **Surround systems** (soundbar + sub + rears) act as one room
- You group/ungroup the entire room, not individual bonded speakers

### Menu Refresh Behavior
During device refresh, the menu preserves existing zone and group data to avoid UI flicker. The `resetDiscoveryState()` function keeps `sonosZones` and `lastFetchedGroups` intact while only resetting the discovery flags.

### Local File Casting

Local files are supported via an embedded HTTP server (LocalMediaServer):

- **Automatic startup**: Server starts automatically when casting local files
- **Port**: Files are served on port 8765
- **Seeking**: Supports HTTP Range requests for seeking
- **Network binding**: Server binds to local network interface (en0/en1), not localhost
- **HEAD requests**: Server handles HEAD requests (Sonos may send HEAD before GET to check Content-Length)

**Supported content:**
- ✅ Plex streaming (with token in URL)
- ✅ Subsonic/Navidrome streaming (via proxy)
- ✅ Local files (via embedded HTTP server)
- ✅ Internet radio (Shoutcast/Icecast streams)

**Subsonic/Navidrome Casting:**
Subsonic streams are proxied through LocalMediaServer for Sonos casting. This is necessary because:
1. Sonos has issues with URLs containing query parameters (authentication tokens)
2. Navidrome may be bound to localhost only, unreachable by Sonos speakers

The proxy flow:
1. NullPlayer registers the Subsonic stream URL with LocalMediaServer
2. LocalMediaServer provides a simple URL: `http://{mac-ip}:8765/stream/{token}`
3. When Sonos requests this URL, LocalMediaServer fetches from Navidrome and streams to Sonos
4. Content-Type is passed through (e.g., `audio/flac`) - no transcoding occurs

**Concurrent stream limitation:**
Navidrome and most Subsonic servers limit concurrent streams per user (often to 1). When casting starts, NullPlayer fully stops local streaming playback to release the connection, allowing the proxy to stream without conflict. This is handled automatically by `AudioEngine.stopLocalForCasting()`.

**Requirements for local file casting:**
- Mac must be on the same network as Sonos speakers
- Firewall must allow incoming connections on port 8765
- Local network interface (en0 or en1) must have an IP address

### Artwork Display

NullPlayer sends artwork URLs to Sonos via DIDL-Lite metadata so album art appears in the Sonos app during playback.

**How artwork URLs are determined:**

| Source | Artwork URL |
|--------|-------------|
| Plex | `PlexManager.artworkURL(thumb:)` - Uses Plex's `/photo/:/transcode` endpoint |
| Subsonic | `SubsonicManager.coverArtURL(coverArtId:)` - Uses Subsonic's `/rest/getCoverArt` endpoint |
| Local files | LocalMediaServer extracts embedded artwork and serves via `http://{ip}:8765/artwork/{token}.jpg` |

**Requirements:**
- Sonos speakers must be able to reach the artwork URL (same network)
- Local file artwork requires embedded ID3/iTunes artwork tags
- Artwork is served as JPEG regardless of original format

**Troubleshooting:**
- If artwork doesn't appear, check that the Plex/Subsonic server is reachable from Sonos
- For local files, verify artwork is embedded (check in Finder "Get Info" or a tag editor)
- Check Console.app for "LocalMediaServer: Registered artwork" log messages

### Sonos Protocol Quirks

**Content-Type matching:** The content type in DIDL-Lite `protocolInfo` must match the actual HTTP Content-Type header. NullPlayer detects format from file extension via `CastManager.detectAudioContentType(for:)`.

**Content-Length for MP3/OGG:** Sonos closes the connection if Content-Length is missing for MP3 and OGG streams. Chunked transfer encoding only works for WAV/FLAC.

**HEAD requests:** Sonos may send HTTP HEAD before GET to check file size. LocalMediaServer handles both methods.

**Radio streams:** MP3 radio streams use `x-rincon-mp3radio://` URI scheme for better Sonos buffering behavior.

**Error 701:** "Transition Not Available" - the most common Sonos error. Occurs when the speaker is busy (e.g., processing a group change). NullPlayer waits for transport ready state before retrying.

**Redirect limitation:** Sonos does not follow HTTP 30x redirects with relative URLs - only absolute URLs work.

**Supported formats:** MP3 (320kbps), AAC/HE-AAC (320kbps), FLAC (24-bit, 48kHz), ALAC (24-bit), WAV/AIFF (16-bit), OGG Vorbis (320kbps). Opus has known UPnP issues despite being listed.

---

## Troubleshooting

### Devices Not Found
1. Check UPnP is enabled in Sonos app settings
2. Ensure devices are on same network/VLAN as computer
3. Check firewall allows UDP 1900 (SSDP) and mDNS (5353)
4. Click "Refresh" and wait 10 seconds

### Devices Found But Won't Play
1. Verify AVTransport URL is accessible: `curl http://{ip}:1400/xml/device_description.xml`
2. Check Sonos isn't in "TV" mode (some soundbars)
3. Ensure media URL is accessible from Sonos (not localhost)

### Group Topology Issues
- Groups take 3+ seconds to resolve after initial discovery
- Reopen the Sonos menu after waiting
- If groups show incorrectly, click Refresh

### Grouping Not Working
If you can't change room groups:
1. **UPnP must be enabled** in Sonos app settings
2. Ensure rooms are discovered (wait for discovery to complete)
3. Try clicking "Refresh" and wait 10 seconds
4. Check Sonos app to verify groups actually changed
5. **SOAP error 500/1023**: This usually means you're trying to ungroup a bonded speaker

### Checkbox Changes Don't Persist
This is expected behavior:
- When NOT casting: selections are stored locally in memory
- When casting STOPS: selections are cleared
- Refresh always shows the actual Sonos state

### Local Files Won't Cast
If local files fail to cast:
1. Check that your Mac has a local network IP address (not just 127.0.0.1)
2. Ensure firewall allows incoming connections on port 8765
3. Verify Sonos speakers are on the same network as your Mac
4. Check Console.app for "LocalMediaServer" log messages

### Casting Stops Unexpectedly
1. Check if Sonos speaker went to sleep (idle timeout)
2. Check if someone paused via the Sonos app (NullPlayer now detects this)
3. Check if Mac went to sleep (NullPlayer recovers on wake)
4. Check Console.app for "Sonos reported STOPPED" or "consecutive command failures"

### Authentication Errors (401/403)
If you see "Sonos rejected the command":
1. Open Sonos app → Settings → Account → Privacy & Security → Connection Security
2. Ensure **UPnP** is **ON**
3. Ensure **Authentication** is **OFF**
4. These settings were added in Sonos firmware 85.0 (July 2025)

### Content Plays Wrong or Stops Mid-Track
1. Check Console.app for DIDL-Lite content type vs actual Content-Type header
2. Sonos requires matching content types between DIDL metadata and HTTP response
3. NullPlayer auto-detects format from file extension

---

## Network Requirements

### Ports
- **UDP 1900**: SSDP discovery
- **UDP 5353**: mDNS discovery
- **TCP 1400**: Sonos HTTP/SOAP control
- **TCP 8765**: Local media server (for casting local files)
- **Media port**: Whatever port your media is served on (Plex default: 32400)

### Multicast
SSDP requires multicast to work. Some routers/switches block this:
- Enable IGMP snooping
- Allow multicast on WLAN
- Don't isolate wireless clients

---

## Key Source Files

| File | Purpose |
|------|---------|
| `CastManager.swift` | Central casting coordinator, `selectedSonosRooms` state, Sonos polling timer, sleep/wake handling |
| `UPnPManager.swift` | SSDP/mDNS discovery, SOAP control, group topology, `pollSonosPlaybackState()` |
| `ContextMenuBuilder.swift` | Menu UI, `SonosRoomCheckboxView`, casting actions |
| `LocalMediaServer.swift` | Embedded HTTP server for local file casting, HEAD handlers, health checks, network monitoring |

---

## References

- [Sonos UPnP Services (unofficial)](https://github.com/SoCo/SoCo/wiki/Sonos-UPnP-Services-and-Functions)
- [SoCo Python Library](https://github.com/SoCo/SoCo)
- [Sonos Developer Docs](https://docs.sonos.com/)
- [Sonos Connection Security](https://support.sonos.com/en-us/article/adjust-connection-security-settings)
