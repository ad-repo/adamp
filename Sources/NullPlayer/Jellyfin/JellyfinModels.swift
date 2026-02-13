import Foundation

// MARK: - Jellyfin Server

/// A Jellyfin media server connection
struct JellyfinServer: Codable, Identifiable, Equatable {
    let id: String           // UUID string
    let name: String
    let url: String          // Base URL e.g. "http://myserver:8096"
    let username: String
    let userId: String       // Jellyfin User.Id (UUID)
    
    /// Display URL without credentials
    var displayURL: String {
        url
    }
    
    /// Get the base URL for API calls
    var baseURL: URL? {
        URL(string: url)
    }
}

/// Credentials for a Jellyfin server (stored in keychain)
struct JellyfinServerCredentials: Codable {
    let id: String
    let name: String
    let url: String
    let username: String
    let password: String         // Stored encrypted in keychain
    let accessToken: String      // From auth response
    let userId: String           // From auth response
}

// MARK: - Library Content

/// An artist in a Jellyfin music library
struct JellyfinArtist: Identifiable, Equatable {
    let id: String           // Jellyfin uses UUID strings
    let name: String
    let albumCount: Int
    let imageTag: String?    // For artwork URL construction
    let isFavorite: Bool
}

/// An album in a Jellyfin music library
struct JellyfinAlbum: Identifiable, Equatable {
    let id: String
    let name: String
    let artist: String?
    let artistId: String?
    let year: Int?
    let genre: String?
    let imageTag: String?
    let songCount: Int
    let duration: Int            // seconds (RunTimeTicks / 10_000_000)
    let created: Date?
    let isFavorite: Bool
    let playCount: Int?
    
    var formattedDuration: String {
        let minutes = duration / 60
        let hours = minutes / 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes % 60, duration % 60)
        }
        return String(format: "%d:%02d", minutes, duration % 60)
    }
}

/// A song (track) in a Jellyfin music library
struct JellyfinSong: Identifiable, Equatable {
    let id: String
    let title: String
    let album: String?
    let artist: String?
    let albumId: String?
    let artistId: String?
    let track: Int?              // IndexNumber
    let year: Int?               // ProductionYear
    let genre: String?
    let imageTag: String?
    let size: Int64?
    let contentType: String?     // Container e.g. "flac"
    let duration: Int            // seconds
    let bitRate: Int?            // kbps
    let sampleRate: Int?
    let channels: Int?
    let path: String?
    let discNumber: Int?         // ParentIndexNumber
    let created: Date?           // DateCreated
    let isFavorite: Bool
    let playCount: Int?
    let userRating: Int?         // 0-100 scale, nil if unrated
    
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var durationInSeconds: TimeInterval {
        TimeInterval(duration)
    }
}

/// A playlist in Jellyfin
struct JellyfinPlaylist: Identifiable, Equatable {
    let id: String
    let name: String
    let songCount: Int
    let duration: Int
    let imageTag: String?
    
    var formattedDuration: String {
        let minutes = duration / 60
        let hours = minutes / 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes % 60, duration % 60)
        }
        return String(format: "%d:%02d", minutes, duration % 60)
    }
}

/// A music library in Jellyfin (Jellyfin can have multiple music libraries)
struct JellyfinMusicLibrary: Identifiable, Equatable {
    let id: String
    let name: String
}

// MARK: - Search Results

/// Results from a Jellyfin search query
struct JellyfinSearchResults {
    var artists: [JellyfinArtist] = []
    var albums: [JellyfinAlbum] = []
    var songs: [JellyfinSong] = []
    
    var isEmpty: Bool {
        artists.isEmpty && albums.isEmpty && songs.isEmpty
    }
    
    var totalCount: Int {
        artists.count + albums.count + songs.count
    }
}

// MARK: - API Response DTOs

/// Single DTO for all Jellyfin items (BaseItemDto has many optional fields)
struct JellyfinItemDTO: Decodable {
    let Id: String
    let Name: String
    let ItemType: String?          // "MusicArtist", "MusicAlbum", "Audio", "Playlist", "CollectionFolder"
    let AlbumArtist: String?
    let AlbumArtists: [NameIdPair]?
    let Album: String?
    let AlbumId: String?
    let Artists: [String]?
    let ArtistItems: [NameIdPair]?
    let IndexNumber: Int?          // Track number
    let ParentIndexNumber: Int?    // Disc number
    let ProductionYear: Int?
    let Genres: [String]?
    let RunTimeTicks: Int64?
    let Size: Int64?
    let Container: String?
    let Path: String?
    let ImageTags: [String: String]?
    let ChildCount: Int?           // Album count for artists, song count for albums
    let SongCount: Int?
    let DateCreated: String?
    let CollectionType: String?    // "music" for music libraries
    let MediaSources: [MediaSourceDTO]?
    let UserData: UserDataDTO?
    
    enum CodingKeys: String, CodingKey {
        case Id, Name, AlbumArtist, AlbumArtists, Album, AlbumId, Artists, ArtistItems
        case IndexNumber, ParentIndexNumber, ProductionYear, Genres, RunTimeTicks, Size
        case Container, Path, ImageTags, ChildCount, SongCount, DateCreated, CollectionType
        case MediaSources, UserData
        case ItemType = "Type"
    }
    
    struct NameIdPair: Decodable { let Name: String; let Id: String }
    struct UserDataDTO: Decodable { let IsFavorite: Bool?; let PlayCount: Int?; let Rating: Double? }
    struct MediaSourceDTO: Decodable { let Bitrate: Int?; let Container: String?; let Size: Int64? }
    
    // MARK: - Converter Methods
    
    func toArtist() -> JellyfinArtist {
        JellyfinArtist(
            id: Id,
            name: Name,
            albumCount: ChildCount ?? 0,
            imageTag: ImageTags?["Primary"],
            isFavorite: UserData?.IsFavorite ?? false
        )
    }
    
    func toAlbum() -> JellyfinAlbum {
        let durationSeconds: Int
        if let ticks = RunTimeTicks {
            durationSeconds = Int(ticks / 10_000_000)
        } else {
            durationSeconds = 0
        }
        
        return JellyfinAlbum(
            id: Id,
            name: Name,
            artist: AlbumArtist ?? AlbumArtists?.first?.Name,
            artistId: AlbumArtists?.first?.Id,
            year: ProductionYear,
            genre: Genres?.first,
            imageTag: ImageTags?["Primary"],
            songCount: ChildCount ?? SongCount ?? 0,
            duration: durationSeconds,
            created: parseJellyfinDate(DateCreated),
            isFavorite: UserData?.IsFavorite ?? false,
            playCount: UserData?.PlayCount
        )
    }
    
    func toSong() -> JellyfinSong {
        let durationSeconds: Int
        if let ticks = RunTimeTicks {
            durationSeconds = Int(ticks / 10_000_000)
        } else {
            durationSeconds = 0
        }
        
        // Extract bitrate from MediaSources (convert from bps to kbps)
        let bitRateKbps: Int?
        if let bps = MediaSources?.first?.Bitrate {
            bitRateKbps = bps / 1000
        } else {
            bitRateKbps = nil
        }
        
        return JellyfinSong(
            id: Id,
            title: Name,
            album: Album,
            artist: Artists?.first ?? ArtistItems?.first?.Name,
            albumId: AlbumId,
            artistId: ArtistItems?.first?.Id,
            track: IndexNumber,
            year: ProductionYear,
            genre: Genres?.first,
            imageTag: ImageTags?["Primary"],
            size: Size ?? MediaSources?.first?.Size,
            contentType: Container ?? MediaSources?.first?.Container,
            duration: durationSeconds,
            bitRate: bitRateKbps,
            sampleRate: nil,  // Not directly available in BaseItemDto
            channels: nil,    // Not directly available in BaseItemDto
            path: Path,
            discNumber: ParentIndexNumber,
            created: parseJellyfinDate(DateCreated),
            isFavorite: UserData?.IsFavorite ?? false,
            playCount: UserData?.PlayCount,
            userRating: UserData?.Rating != nil ? Int(UserData!.Rating!) : nil
        )
    }
    
    func toPlaylist() -> JellyfinPlaylist {
        let durationSeconds: Int
        if let ticks = RunTimeTicks {
            durationSeconds = Int(ticks / 10_000_000)
        } else {
            durationSeconds = 0
        }
        
        return JellyfinPlaylist(
            id: Id,
            name: Name,
            songCount: ChildCount ?? 0,
            duration: durationSeconds,
            imageTag: ImageTags?["Primary"]
        )
    }
    
    func toMusicLibrary() -> JellyfinMusicLibrary {
        JellyfinMusicLibrary(
            id: Id,
            name: Name
        )
    }
}

// MARK: - Auth Response

/// Authentication response from Jellyfin server
struct JellyfinAuthResponse: Decodable {
    let AccessToken: String
    let User: JellyfinUserDTO
    
    struct JellyfinUserDTO: Decodable {
        let Id: String
        let Name: String
    }
}

// MARK: - Query Result

/// Items query result wrapper
struct JellyfinQueryResult: Decodable {
    let Items: [JellyfinItemDTO]
    let TotalRecordCount: Int?
}

/// Views response
struct JellyfinViewsResponse: Decodable {
    let Items: [JellyfinItemDTO]
}

// MARK: - Date Parsing Helper

/// Parse ISO 8601 date strings from Jellyfin API
private func parseJellyfinDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    
    // Try ISO 8601 with fractional seconds first
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    // Try without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    // Try simple date format (yyyy-MM-dd)
    let simpleFormatter = DateFormatter()
    simpleFormatter.dateFormat = "yyyy-MM-dd"
    return simpleFormatter.date(from: dateString)
}

// MARK: - Errors

enum JellyfinClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case unauthorized
    case serverOffline
    case networkError(Error)
    case authenticationFailed
    case noContent
    
    var errorDescription: String? {
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
