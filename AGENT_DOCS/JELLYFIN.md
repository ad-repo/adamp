# Jellyfin Integration

NullPlayer supports Jellyfin media servers for music streaming, browsing, and scrobbling.

## Architecture

The Jellyfin integration mirrors the Subsonic integration pattern exactly:

| File | Purpose |
|------|---------|
| `Jellyfin/JellyfinModels.swift` | Domain models (Server, Artist, Album, Song, Playlist) and API DTOs |
| `Jellyfin/JellyfinServerClient.swift` | HTTP client for Jellyfin REST API |
| `Jellyfin/JellyfinManager.swift` | Singleton managing connections, caching, and track conversion |
| `Jellyfin/JellyfinPlaybackReporter.swift` | Scrobbling and "now playing" reporting |
| `Jellyfin/JellyfinLinkSheet.swift` | Server add/edit/manage UI dialogs |

There is also a `Sources/NullPlayerCore/Jellyfin/JellyfinModels.swift` with public model types for the core library target.

## Jellyfin API Reference

All requests include header: `Authorization: MediaBrowser Client="NullPlayer", Device="Mac", DeviceId="{uuid}", Version="1.0"`. After auth, also include `X-Emby-Token: {accessToken}`.

### Authentication

- **Auth**: `POST /Users/AuthenticateByName`
  - Body: `{"Username":"x","Pw":"y"}`
  - Returns JSON with `AccessToken` and `User.Id`
  - The access token is stored in keychain and reused for subsequent requests

- **Ping**: `GET /System/Ping`
  - Returns 200 if server is reachable

### Library Browsing

- **Music libraries**: `GET /Users/{userId}/Views`
  - Filter `Items` where `CollectionType == "music"`
  - Jellyfin can have multiple music libraries

- **Artists**: `GET /Artists/AlbumArtists?parentId={libId}&userId={userId}&Recursive=true&SortBy=SortName&SortOrder=Ascending&Fields=PrimaryImageAspectRatio`
  - Paginated with `Limit` and `StartIndex`

- **Albums**: `GET /Users/{userId}/Items?parentId={libId}&IncludeItemTypes=MusicAlbum&Recursive=true&SortBy=SortName&SortOrder=Ascending`
  - Paginated with `Limit` and `StartIndex`

- **Artist albums**: `GET /Users/{userId}/Items?AlbumArtistIds={artistId}&IncludeItemTypes=MusicAlbum&Recursive=true&SortBy=ProductionYear,SortName`

- **Album tracks**: `GET /Users/{userId}/Items?parentId={albumId}&IncludeItemTypes=Audio&SortBy=ParentIndexNumber,IndexNumber`

- **Single item**: `GET /Users/{userId}/Items/{itemId}`

- **Playlists**: `GET /Users/{userId}/Items?IncludeItemTypes=Playlist&Recursive=true`

- **Playlist items**: `GET /Playlists/{playlistId}/Items?userId={userId}`

- **Search**: `GET /Items?searchTerm={q}&IncludeItemTypes=Audio,MusicAlbum,MusicArtist&Recursive=true&userId={userId}&Limit=50`

### Streaming

- **Stream**: `GET /Audio/{itemId}/stream?static=true&api_key={token}`
  - Returns original audio file (direct stream)

### Images

- **Image**: `GET /Items/{itemId}/Images/Primary?maxHeight={size}&maxWidth={size}&tag={imageTag}`
  - No auth required for images typically
  - `imageTag` is from `ImageTags.Primary` in the item response

### User Actions

- **Favorite**: `POST /Users/{userId}/FavoriteItems/{itemId}` (add), `DELETE /Users/{userId}/FavoriteItems/{itemId}` (remove)

- **Rate**: `POST /Users/{userId}/Items/{itemId}/Rating?likes=true`

- **Scrobble**: `POST /Users/{userId}/PlayedItems/{itemId}`

### Playback Reporting

- **Start**: `POST /Sessions/Playing`
  - Body: `{"ItemId":"{id}","CanSeek":true,"PlayMethod":"DirectStream"}`

- **Progress**: `POST /Sessions/Playing/Progress`
  - Body: `{"ItemId":"{id}","PositionTicks":{ticks},"IsPaused":false}`

- **Stopped**: `POST /Sessions/Playing/Stopped`
  - Body: `{"ItemId":"{id}","PositionTicks":{ticks}}`

## Rating Scale

Jellyfin `UserData.Rating` is 0-100%. The app uses 0-10 internal scale.

Mapping:
- `jellyfin_rating = internal_rating * 10`
- `internal_rating = jellyfin_rating / 10`
- Each star = 20%

## Ticks

Jellyfin uses ticks for duration/position: 1 tick = 10,000 nanoseconds = 0.00001 seconds.

Convert: `ticks = seconds * 10_000_000`

## Track Identification

Jellyfin tracks in the playlist are identified by:
- `track.jellyfinId` — the Jellyfin item UUID
- `track.jellyfinServerId` — which Jellyfin server the track belongs to

These parallel the existing `subsonicId`/`subsonicServerId` pattern.

## Scrobbling

`JellyfinPlaybackReporter` follows the same rules as `SubsonicPlaybackReporter`:
- Reports "now playing" immediately on track start (via `POST /Sessions/Playing`)
- Reports progress periodically (via `POST /Sessions/Playing/Progress`)
- Scrobbles after 50% of track or 4 minutes, whichever comes first
- Reports stopped on track end/stop (via `POST /Sessions/Playing/Stopped`)

## Credential Storage

Jellyfin credentials are stored using `KeychainHelper`:
- Key: `jellyfin_servers`
- Stores: `[JellyfinServerCredentials]` (includes access token and userId)
- Currently uses UserDefaults for development; set `useKeychain = true` for production

## Music Library Selection

Unlike Subsonic (which has a single library), Jellyfin can have multiple music libraries. The `JellyfinManager` handles this:
- `musicLibraries: [JellyfinMusicLibrary]` — all available music libraries
- `currentMusicLibrary: JellyfinMusicLibrary?` — currently selected library
- Auto-selects if only one library exists
- Persisted via `JellyfinCurrentMusicLibraryID` UserDefaults key

## State Persistence

- Current server ID: `JellyfinCurrentServerID` (UserDefaults)
- Current music library ID: `JellyfinCurrentMusicLibraryID` (UserDefaults)
- Playlist tracks with `jellyfinId`/`jellyfinServerId` are saved/restored by `AppStateManager`

## Casting

Jellyfin tracks support casting to Sonos, Chromecast, and DLNA devices:
- Sonos requires proxy (like Subsonic) — `needsJellyfinProxy` flag
- Artwork is loaded via `JellyfinManager.shared.imageURL()`
- Stream URLs use `api_key` auth parameter, not header auth
