# Jellyfin Integration

NullPlayer supports Jellyfin media servers for music streaming, video playback (movies and TV shows), browsing, and scrobbling.

## Architecture

The Jellyfin integration mirrors the Subsonic/Plex integration patterns:

| File | Purpose |
|------|---------|
| `Jellyfin/JellyfinModels.swift` | Domain models (Server, Artist, Album, Song, Playlist, Movie, Show, Season, Episode) and API DTOs |
| `Jellyfin/JellyfinServerClient.swift` | HTTP client for Jellyfin REST API (music + video) |
| `Jellyfin/JellyfinManager.swift` | Singleton managing connections, caching, and track conversion (music + video) |
| `Jellyfin/JellyfinPlaybackReporter.swift` | Audio scrobbling and "now playing" reporting |
| `Jellyfin/JellyfinVideoPlaybackReporter.swift` | Video scrobbling with periodic timeline updates (mirrors PlexVideoPlaybackReporter) |
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

- **Search**: `GET /Items?searchTerm={q}&IncludeItemTypes=Audio,MusicAlbum,MusicArtist,Movie,Series,Episode&Recursive=true&userId={userId}&Fields=Overview,MediaSources&Limit=50`

### Video Browsing

- **Video libraries**: `GET /Users/{userId}/Views`
  - Filter `Items` where `CollectionType == "movies"` or `"tvshows"`

- **Movies**: `GET /Users/{userId}/Items?parentId={libId}&IncludeItemTypes=Movie&MediaTypes=Video&Recursive=true&SortBy=SortName&SortOrder=Ascending&Fields=Overview,MediaSources`
  - Paginated with `Limit` and `StartIndex`
  - `MediaTypes=Video` excludes non-video files (images, NFO, subtitles) that Jellyfin may return
  - Client-side filtering also excludes items with non-video container formats as a safety net

- **Series (TV shows)**: `GET /Users/{userId}/Items?parentId={libId}&IncludeItemTypes=Series&Recursive=true&SortBy=SortName&SortOrder=Ascending&Fields=Overview`

- **Seasons**: `GET /Shows/{seriesId}/Seasons?userId={userId}`

- **Episodes**: `GET /Shows/{seriesId}/Episodes?userId={userId}&seasonId={seasonId}&MediaTypes=Video&Fields=Overview,MediaSources`

### Streaming

- **Audio Stream**: `GET /Audio/{itemId}/stream?static=true&api_key={token}`
  - Returns original audio file (direct stream)

- **Video Stream**: `GET /Videos/{itemId}/stream?static=true&api_key={token}`
  - Returns original video file (direct stream)
  - Note: Uses `/Videos/` path, not `/Audio/`

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

## Video Models

| Model | Fields |
|-------|--------|
| `JellyfinMovie` | id, title, year, overview, duration, contentRating, imageTag, backdropTag, isFavorite, playCount, container |
| `JellyfinShow` | id, title, year, overview, imageTag, backdropTag, childCount (seasons), isFavorite |
| `JellyfinSeason` | id, title, index, seriesId, seriesName, imageTag, childCount (episodes) |
| `JellyfinEpisode` | id, title, index, parentIndex (season), seriesId, seriesName, seasonId, seasonName, overview, duration, imageTag, isFavorite, playCount, container |

## Video Playback Reporter

`JellyfinVideoPlaybackReporter` mirrors `PlexVideoPlaybackReporter` with Jellyfin API:
- Video scrobble threshold: 90% (vs 50% for audio)
- Minimum play time: 60s before scrobbling
- Periodic timeline updates every 10s via `POST /Sessions/Playing/Progress` with `PositionTicks`
- Tracks pause/resume state with `IsPaused` flag
- Reports `POST /Sessions/Playing` on start, `/Sessions/Playing/Stopped` on stop
- Uses ticks (1 tick = 100ns, `seconds × 10_000_000`) for Jellyfin API

## Music Library Selection

Unlike Subsonic (which has a single library), Jellyfin can have multiple music libraries. The `JellyfinManager` handles this:
- `musicLibraries: [JellyfinMusicLibrary]` — all available music libraries
- `currentMusicLibrary: JellyfinMusicLibrary?` — currently selected library
- Auto-selects if only one library exists
- Persisted via `JellyfinCurrentMusicLibraryID` UserDefaults key

## Video Library Selection

Jellyfin video libraries (movies and tvshows) are also managed by `JellyfinManager`:
- `videoLibraries: [JellyfinMusicLibrary]` — all movie/tvshow libraries (reuses `JellyfinMusicLibrary` struct)
- `currentMovieLibrary: JellyfinMusicLibrary?` — selected movie library
- `currentShowLibrary: JellyfinMusicLibrary?` — selected TV show library
- `JellyfinMusicLibrary.collectionType` stores the library type (`"music"`, `"movies"`, `"tvshows"`)
- Auto-selection priority: saved UserDefaults ID → match by `collectionType` → single library fallback
- Persisted via `JellyfinCurrentMovieLibraryID` / `JellyfinCurrentShowLibraryID` UserDefaults keys

## Startup Connection Deduplication

On app start, `JellyfinManager.init()` restores the saved server and calls `connectInBackground()`. Meanwhile, the library browser may restore its saved Jellyfin source and call `loadJellyfinData(serverId:)`. To avoid duplicate connections, `loadJellyfinData` checks if the manager is already in `.connecting` state for the same server and polls until it finishes instead of starting a redundant connection. The same pattern applies to `loadSubsonicData`.

## Artist Expansion Performance

When expanding a Jellyfin artist in the library browser, albums are resolved from the preloaded cache (`cachedJellyfinAlbums`) by filtering on `artistId`, making expansion instant. Network fallback only occurs if the cache has no matching albums. The same optimization applies to Subsonic artist expansion.

**Important**: Expand tasks must use `Task.detached` (not `Task { }`) to avoid inheriting cancellation state from the calling context, which can cause immediate task cancellation on the main actor.

## State Persistence

- Current server ID: `JellyfinCurrentServerID` (UserDefaults)
- Current music library ID: `JellyfinCurrentMusicLibraryID` (UserDefaults)
- Current movie library ID: `JellyfinCurrentMovieLibraryID` (UserDefaults)
- Current show library ID: `JellyfinCurrentShowLibraryID` (UserDefaults)
- Playlist tracks with `jellyfinId`/`jellyfinServerId` are saved/restored by `AppStateManager`

## Casting

Jellyfin tracks support casting to Sonos, Chromecast, and DLNA devices:
- Sonos requires proxy (like Subsonic) — `needsJellyfinProxy` flag
- Artwork is loaded via `JellyfinManager.shared.imageURL()`
- Stream URLs use `api_key` auth parameter, not header auth

### Content Type Detection for Sonos Casting

Jellyfin (and Subsonic) streaming URLs use paths like `/Audio/{id}/stream` with no file extension. This means `CastManager.detectAudioContentType(for:)` (which checks URL path extension) defaults to `audio/mpeg`, which is wrong for FLAC/WAV/etc. A content type mismatch in DIDL-Lite `protocolInfo` causes Sonos to fail silently on the first track.

**Fix**: `CastManager.prepareProxyURL(for:device:)` handles this with a multi-layer strategy:
1. Use `track.contentType` if available (set by `JellyfinManager.convertToTrack()` from the `Container` field)
2. If nil, send a HEAD request to the upstream URL and read the `Content-Type` response header
3. Pass the detected content type to both the proxy registration (for Sonos HEAD requests) and the DIDL-Lite metadata
4. Fall back to `detectAudioContentType(for:)` (URL extension) only as a last resort

**State restoration**: `SavedTrack.contentType` persists the MIME type across app restarts, so restored tracks don't lose their content type. This is a new optional `Codable` field — old saved states decode it as nil (backward compatible).

### Video Casting

Jellyfin movies and episodes can be cast to video-capable devices (Chromecast, DLNA TVs):
- `CastManager.castJellyfinMovie(_:to:startPosition:)` — cast a movie
- `CastManager.castJellyfinEpisode(_:to:startPosition:)` — cast an episode
- Stream URL uses `/Videos/{id}/stream?static=true&api_key={token}`
- `VideoPlayerWindowController` dispatches to the correct cast method based on `isJellyfinContent`
