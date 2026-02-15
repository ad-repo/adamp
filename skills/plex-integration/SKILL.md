---
name: plex-integration
description: Plex API endpoints, authentication, filtering, music radio, and video content. Use when working on Plex integration, library browsing, track queries, radio features, or video playback.
---

# Plex API for Music Radio & Playlists

This guide describes the Plex API endpoints used for querying tracks and building radio/playlist features in NullPlayer.

## Authentication

All requests require authentication headers:

```
X-Plex-Token: {token}
X-Plex-Client-Identifier: {unique-client-id}
X-Plex-Product: NullPlayer
X-Plex-Version: 1.0
X-Plex-Platform: macOS
X-Plex-Device: Mac
Accept: application/json
```

## Core Endpoints

### Library Sections

```
GET /library/sections
```

Returns all libraries. Music libraries have `type: "artist"`.

### Query Items by Type

```
GET /library/sections/{libraryID}/all?type={typeID}
```

Type values:
| Type ID | Content |
|---------|---------|
| 8 | Artists |
| 9 | Albums |
| 10 | Tracks |
| 1 | Movies |
| 2 | TV Shows |

## Popular Tracks (Last.fm Integration)

Plex identifies "hit" tracks using the `ratingCount` field, which contains **global popularity data from Last.fm** - the number of unique listeners who have scrobbled the track worldwide.

**Example**: "Purple Haze" by Jimi Hendrix would have a high `ratingCount` (millions of scrobbles), while a deep cut might have significantly lower count or none.

## Radio API

### Sonically Similar Tracks (Primary Radio API)

```
GET /library/sections/{libraryID}/all?type=10&track.sonicallySimilar={trackID}&sort=random&limit=100
```

Returns tracks that are sonically similar to the seed track. Use `sort=random` for diverse results.

### Sonically Similar Artists

```
GET /library/sections/{libraryID}/all?type=8&artist.sonicallySimilar={artistID}&limit=15
```

### Sonically Similar Albums

```
GET /library/sections/{libraryID}/all?type=9&album.sonicallySimilar={albumID}&limit=10
```

### Only the Hits Radio

Plays only popular/hit tracks based on Last.fm scrobble data.

**Threshold**: 1,000,000+ scrobbles

**Sonic Version**:
```
GET /library/sections/{libID}/all?type=10&track.sonicallySimilar={trackID}&ratingCount>=1000000&sort=random&limit=100
```

**Non-Sonic Version**:
```
GET /library/sections/{libID}/all?type=10&ratingCount>=1000000&sort=random&limit=100
```

### Deep Cuts Radio

Plays lesser-known tracks.

**Threshold**: Under 1,000 scrobbles

**Sonic Version**:
```
GET /library/sections/{libID}/all?type=10&track.sonicallySimilar={trackID}&ratingCount<=999&sort=random&limit=100
```

**Non-Sonic Version**:
```
GET /library/sections/{libID}/all?type=10&ratingCount<=999&sort=random&limit=100
```

### Rating Radio (My Ratings)

Plays tracks based on user's personal star ratings:

| Station | Min Rating | Description |
|---------|------------|-------------|
| 5 Stars Radio | 10 (5★) | Only tracks rated exactly 5 stars |
| 4+ Stars Radio | 8 (4★+) | Highly rated tracks (4-5 stars) |
| 3+ Stars Radio | 6 (3★+) | Good tracks (3-5 stars) |
| 2+ Stars Radio | 4 (2★+) | Any track rated 2+ stars |
| All Rated Radio | 0.1 | Any track with a rating |

**Note**: Plex stores ratings on a 0-10 scale internally (10 = 5 stars).

**Sonic Version**:
```
GET /library/sections/{libID}/all?type=10&track.sonicallySimilar={trackID}&userRating>=8&sort=random&limit=100
```

**Non-Sonic Version**:
```
GET /library/sections/{libID}/all?type=10&userRating>=8&sort=random&limit=100
```

### URL Encoding Warning

**IMPORTANT**: Plex filter operators (`>=`, `<=`, `=`, `!=`) must NOT be URL-encoded.

- **WRONG**: `userRating%3E%3D=8` (URLQueryItem encodes `>=` as `%3E%3D`)
- **CORRECT**: `userRating>=8` (literal `>=` in the URL)

**Note**: Plex only supports `>=`, `<=`, `=`, `!=`. The `<` and `>` operators (without equals) are NOT supported and return HTTP 400. Use `<=` with value-1 instead of `<` (e.g., `ratingCount<=999` instead of `ratingCount<1000`).

When using Swift's `URLQueryItem`, build URLs manually for filter parameters:
```swift
// WRONG - URLQueryItem encodes >=
URLQueryItem(name: "userRating>=", value: "8")  // produces userRating%3E%3D=8

// CORRECT - manual URL construction
let urlString = "\(baseURL)/library/sections/\(id)/all?type=10&userRating>=8&..."
```

## Filter Parameters

### By Artist
```
?artist.id={artistID}
```

### By Genre
```
?genre={genreID}
```

### By Year/Decade
```
?year={year}
?year>=1980&year<=1989
```

### Sorting Options
```
?sort=random            # Random order (great for radio)
?sort=titleSort         # Alphabetical
?sort=lastViewedAt:desc # Recently played
?sort=addedAt:desc      # Recently added
?sort=year:desc         # By year
```

## Video Content (Movies & TV Shows)

### Fetching Movies

```
GET /library/sections/{libraryID}/all?type=1
```

### Fetching TV Shows

```
GET /library/sections/{libraryID}/all?type=2
```

### Multi-Version Movies

Movies may contain multiple media versions:

**Important**: The top-level `duration` field may point to bonus content, not the main movie. NullPlayer uses the **longest duration** from the `Media` array to identify primary content.

### External IDs (IMDB, TMDB, TVDB)

Movies, TV shows, and episodes include external service IDs in the `Guid` array:

```json
{
  "title": "The Matrix",
  "Guid": [
    {"id": "imdb://tt0133093"},
    {"id": "tmdb://603"},
    {"id": "tvdb://12345"}
  ]
}
```

| Service | URL Pattern |
|---------|-------------|
| IMDB | `https://www.imdb.com/title/{id}/` |
| TMDB | `https://www.themoviedb.org/movie/{id}` (movies) |
| TMDB | `https://www.themoviedb.org/tv/{id}` (TV shows) |
| TVDB | `https://www.thetvdb.com/series/{id}` |

NullPlayer uses these IDs to provide "View Online" context menu links.

## Setting User Ratings

```
PUT /:/rate?key={ratingKey}&identifier=com.plexapp.plugins.library&rating={rating}
```

| Parameter | Description |
|-----------|-------------|
| key | The item's ratingKey |
| identifier | Always `com.plexapp.plugins.library` |
| rating | 0-10 scale (2 per star), or -1 to clear |

**Rating Scale**:
- 2 = 1 star, 4 = 2 stars, 6 = 3 stars, 8 = 4 stars, 10 = 5 stars, -1 = Clear

## Building Streaming URLs

```
{baseURL}{Media.Part.key}?X-Plex-Token={token}
```

Example:
```
http://192.168.0.102:32400/library/parts/653835/1723508508/file.flac?X-Plex-Token=TOKEN
```

## Requirements

- **Plex Pass** subscription (for sonic analysis)
- **Plex Media Server v1.24.0+** (64-bit)
- **Sonic analysis enabled** on the music library
- Tracks must be analyzed (check for `musicAnalysisVersion` attribute)

## Key Source Files

| File | Purpose |
|------|---------|
| `Plex/PlexManager.swift` | Singleton managing connections, caching, track conversion |
| `Plex/PlexServerClient.swift` | HTTP client for Plex REST API |
| `Plex/PlexModels.swift` | Domain models (Server, Artist, Album, Track, etc.) |
| `Plex/PlexPlaybackReporter.swift` | Audio scrobbling and "now playing" reporting |
| `Plex/PlexVideoPlaybackReporter.swift` | Video scrobbling with periodic timeline updates |

## References

- [Python PlexAPI](https://github.com/pkkid/python-plexapi)
- [Plex API Documentation](https://plexapi.dev/)
- [Plex Support - Sonic Analysis](https://support.plex.tv/articles/sonic-analysis-music/)
