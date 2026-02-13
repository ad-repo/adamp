import Foundation

// MARK: - Jellyfin Server

/// A Jellyfin media server connection
public struct JellyfinServer: Codable, Identifiable, Equatable {
    public let id: String           // UUID string
    public let name: String
    public let url: String          // Base URL e.g. "http://myserver:8096"
    public let username: String
    public let userId: String       // Jellyfin User.Id (UUID)
    
    public init(id: String, name: String, url: String, username: String, userId: String) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.userId = userId
    }
    
    /// Display URL without credentials
    public var displayURL: String {
        url
    }
    
    /// Get the base URL for API calls
    public var baseURL: URL? {
        URL(string: url)
    }
}

/// Credentials for a Jellyfin server (stored in keychain)
public struct JellyfinServerCredentials: Codable {
    public let id: String
    public let name: String
    public let url: String
    public let username: String
    public let password: String         // Stored encrypted in keychain
    public let accessToken: String      // From auth response
    public let userId: String           // From auth response
    
    public init(id: String, name: String, url: String, username: String, password: String, accessToken: String, userId: String) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.password = password
        self.accessToken = accessToken
        self.userId = userId
    }
}

// MARK: - Library Content

/// An artist in a Jellyfin music library
public struct JellyfinArtist: Identifiable, Equatable {
    public let id: String           // Jellyfin uses UUID strings
    public let name: String
    public let albumCount: Int
    public let imageTag: String?    // For artwork URL construction
    public let isFavorite: Bool
    
    public init(id: String, name: String, albumCount: Int, imageTag: String?, isFavorite: Bool) {
        self.id = id
        self.name = name
        self.albumCount = albumCount
        self.imageTag = imageTag
        self.isFavorite = isFavorite
    }
}

/// An album in a Jellyfin music library
public struct JellyfinAlbum: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let artist: String?
    public let artistId: String?
    public let year: Int?
    public let genre: String?
    public let imageTag: String?
    public let songCount: Int
    public let duration: Int            // seconds (RunTimeTicks / 10_000_000)
    public let created: Date?
    public let isFavorite: Bool
    public let playCount: Int?
    
    public init(id: String, name: String, artist: String?, artistId: String?, year: Int?,
                genre: String?, imageTag: String?, songCount: Int, duration: Int,
                created: Date?, isFavorite: Bool, playCount: Int?) {
        self.id = id
        self.name = name
        self.artist = artist
        self.artistId = artistId
        self.year = year
        self.genre = genre
        self.imageTag = imageTag
        self.songCount = songCount
        self.duration = duration
        self.created = created
        self.isFavorite = isFavorite
        self.playCount = playCount
    }
    
    public var formattedDuration: String {
        let minutes = duration / 60
        let hours = minutes / 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes % 60, duration % 60)
        }
        return String(format: "%d:%02d", minutes, duration % 60)
    }
}

/// A song (track) in a Jellyfin music library
public struct JellyfinSong: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let album: String?
    public let artist: String?
    public let albumId: String?
    public let artistId: String?
    public let track: Int?              // IndexNumber
    public let year: Int?               // ProductionYear
    public let genre: String?
    public let imageTag: String?
    public let size: Int64?
    public let contentType: String?     // Container e.g. "flac"
    public let duration: Int            // seconds
    public let bitRate: Int?            // kbps
    public let sampleRate: Int?
    public let channels: Int?
    public let path: String?
    public let discNumber: Int?         // ParentIndexNumber
    public let created: Date?           // DateCreated
    public let isFavorite: Bool
    public let playCount: Int?
    public let userRating: Int?         // 0-100 scale, nil if unrated
    
    public init(id: String, title: String, album: String?, artist: String?,
                albumId: String?, artistId: String?, track: Int?, year: Int?,
                genre: String?, imageTag: String?, size: Int64?, contentType: String?,
                duration: Int, bitRate: Int?, sampleRate: Int?, channels: Int?,
                path: String?, discNumber: Int?, created: Date?, isFavorite: Bool,
                playCount: Int?, userRating: Int?) {
        self.id = id
        self.title = title
        self.album = album
        self.artist = artist
        self.albumId = albumId
        self.artistId = artistId
        self.track = track
        self.year = year
        self.genre = genre
        self.imageTag = imageTag
        self.size = size
        self.contentType = contentType
        self.duration = duration
        self.bitRate = bitRate
        self.sampleRate = sampleRate
        self.channels = channels
        self.path = path
        self.discNumber = discNumber
        self.created = created
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.userRating = userRating
    }
    
    public var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var durationInSeconds: TimeInterval {
        TimeInterval(duration)
    }
}

/// A playlist in Jellyfin
public struct JellyfinPlaylist: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let songCount: Int
    public let duration: Int
    public let imageTag: String?
    
    public init(id: String, name: String, songCount: Int, duration: Int, imageTag: String?) {
        self.id = id
        self.name = name
        self.songCount = songCount
        self.duration = duration
        self.imageTag = imageTag
    }
    
    public var formattedDuration: String {
        let minutes = duration / 60
        let hours = minutes / 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes % 60, duration % 60)
        }
        return String(format: "%d:%02d", minutes, duration % 60)
    }
}

/// A music library in Jellyfin (Jellyfin can have multiple music libraries)
public struct JellyfinMusicLibrary: Identifiable, Equatable {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Video Content

/// A movie in a Jellyfin video library
public struct JellyfinMovie: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let year: Int?
    public let overview: String?
    public let duration: Int?          // seconds
    public let contentRating: String?
    public let imageTag: String?
    public let backdropTag: String?
    public let isFavorite: Bool
    public let playCount: Int?
    public let container: String?
    
    public init(id: String, title: String, year: Int?, overview: String?, duration: Int?,
                contentRating: String?, imageTag: String?, backdropTag: String?,
                isFavorite: Bool, playCount: Int?, container: String?) {
        self.id = id
        self.title = title
        self.year = year
        self.overview = overview
        self.duration = duration
        self.contentRating = contentRating
        self.imageTag = imageTag
        self.backdropTag = backdropTag
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.container = container
    }
    
    public var formattedDuration: String? {
        guard let dur = duration else { return nil }
        let hours = dur / 3600
        let minutes = (dur % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
}

/// A TV show (series) in a Jellyfin video library
public struct JellyfinShow: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let year: Int?
    public let overview: String?
    public let imageTag: String?
    public let backdropTag: String?
    public let childCount: Int
    public let isFavorite: Bool
    
    public init(id: String, title: String, year: Int?, overview: String?, imageTag: String?,
                backdropTag: String?, childCount: Int, isFavorite: Bool) {
        self.id = id
        self.title = title
        self.year = year
        self.overview = overview
        self.imageTag = imageTag
        self.backdropTag = backdropTag
        self.childCount = childCount
        self.isFavorite = isFavorite
    }
}

/// A season of a TV show in Jellyfin
public struct JellyfinSeason: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let index: Int?
    public let seriesId: String
    public let seriesName: String?
    public let imageTag: String?
    public let childCount: Int
    
    public init(id: String, title: String, index: Int?, seriesId: String, seriesName: String?,
                imageTag: String?, childCount: Int) {
        self.id = id
        self.title = title
        self.index = index
        self.seriesId = seriesId
        self.seriesName = seriesName
        self.imageTag = imageTag
        self.childCount = childCount
    }
}

/// An episode of a TV show in Jellyfin
public struct JellyfinEpisode: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let index: Int?
    public let parentIndex: Int?
    public let seriesId: String
    public let seriesName: String?
    public let seasonId: String?
    public let seasonName: String?
    public let overview: String?
    public let duration: Int?
    public let imageTag: String?
    public let isFavorite: Bool
    public let playCount: Int?
    public let container: String?
    
    public init(id: String, title: String, index: Int?, parentIndex: Int?, seriesId: String,
                seriesName: String?, seasonId: String?, seasonName: String?, overview: String?,
                duration: Int?, imageTag: String?, isFavorite: Bool, playCount: Int?, container: String?) {
        self.id = id
        self.title = title
        self.index = index
        self.parentIndex = parentIndex
        self.seriesId = seriesId
        self.seriesName = seriesName
        self.seasonId = seasonId
        self.seasonName = seasonName
        self.overview = overview
        self.duration = duration
        self.imageTag = imageTag
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.container = container
    }
    
    public var episodeIdentifier: String {
        let s = parentIndex.map { String(format: "S%02d", $0) } ?? ""
        let e = index.map { String(format: "E%02d", $0) } ?? ""
        return "\(s)\(e)"
    }
    
    public var formattedDuration: String? {
        guard let dur = duration else { return nil }
        let hours = dur / 3600
        let minutes = (dur % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
}

// MARK: - Search Results

/// Results from a Jellyfin search query
public struct JellyfinSearchResults {
    public var artists: [JellyfinArtist] = []
    public var albums: [JellyfinAlbum] = []
    public var songs: [JellyfinSong] = []
    public var movies: [JellyfinMovie] = []
    public var shows: [JellyfinShow] = []
    public var episodes: [JellyfinEpisode] = []
    
    public init(artists: [JellyfinArtist] = [], albums: [JellyfinAlbum] = [], songs: [JellyfinSong] = [],
                movies: [JellyfinMovie] = [], shows: [JellyfinShow] = [], episodes: [JellyfinEpisode] = []) {
        self.artists = artists
        self.albums = albums
        self.songs = songs
        self.movies = movies
        self.shows = shows
        self.episodes = episodes
    }
    
    public var isEmpty: Bool {
        artists.isEmpty && albums.isEmpty && songs.isEmpty && movies.isEmpty && shows.isEmpty && episodes.isEmpty
    }
    
    public var totalCount: Int {
        artists.count + albums.count + songs.count + movies.count + shows.count + episodes.count
    }
}

// MARK: - Errors

public enum JellyfinClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case unauthorized
    case serverOffline
    case networkError(Error)
    case authenticationFailed
    case noContent
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error: \(code)"
        case .unauthorized:
            return "Authentication failed - check username and password"
        case .serverOffline:
            return "Server is offline or unreachable"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed:
            return "Invalid username or password"
        case .noContent:
            return "No content returned from server"
        }
    }
}
