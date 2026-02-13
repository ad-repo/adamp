import Foundation
import AppKit

/// Singleton managing Jellyfin server connections and state
class JellyfinManager {
    
    // MARK: - Singleton
    
    static let shared = JellyfinManager()
    
    // MARK: - Notifications
    
    static let serversDidChangeNotification = Notification.Name("JellyfinServersDidChange")
    static let connectionStateDidChangeNotification = Notification.Name("JellyfinConnectionStateDidChange")
    static let libraryContentDidPreloadNotification = Notification.Name("JellyfinLibraryContentDidPreload")
    
    // MARK: - Server State
    
    /// All configured servers
    private(set) var servers: [JellyfinServer] = [] {
        didSet {
            NotificationCenter.default.post(name: Self.serversDidChangeNotification, object: self)
        }
    }
    
    /// Currently selected server
    private(set) var currentServer: JellyfinServer? {
        didSet {
            if oldValue?.id != currentServer?.id {
                serverClient = nil
                clearCachedContent()
                
                if let server = currentServer,
                   let credentials = KeychainHelper.shared.getJellyfinServer(id: server.id) {
                    serverClient = JellyfinServerClient(credentials: credentials)
                }
            }
            UserDefaults.standard.set(currentServer?.id, forKey: "JellyfinCurrentServerID")
        }
    }
    
    /// Client for the current server
    private(set) var serverClient: JellyfinServerClient?
    
    // MARK: - Music Libraries
    
    /// Available music libraries on the current server
    private(set) var musicLibraries: [JellyfinMusicLibrary] = []
    
    /// Currently selected music library
    private(set) var currentMusicLibrary: JellyfinMusicLibrary? {
        didSet {
            UserDefaults.standard.set(currentMusicLibrary?.id, forKey: "JellyfinCurrentMusicLibraryID")
        }
    }
    
    // MARK: - Connection State
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(Error)
    }
    
    private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            NotificationCenter.default.post(name: Self.connectionStateDidChangeNotification, object: self)
        }
    }
    
    // MARK: - Cached Library Content
    
    /// Cached artists
    private(set) var cachedArtists: [JellyfinArtist] = []
    
    /// Cached albums
    private(set) var cachedAlbums: [JellyfinAlbum] = []
    
    /// Cached playlists
    private(set) var cachedPlaylists: [JellyfinPlaylist] = []
    
    /// Whether library content has been preloaded
    private(set) var isContentPreloaded: Bool = false
    
    /// Loading state for preload
    private(set) var isPreloading: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        loadSavedServers()
    }
    
    // MARK: - Server Persistence
    
    private func loadSavedServers() {
        let credentials = KeychainHelper.shared.getJellyfinServers()
        servers = credentials.map { cred in
            JellyfinServer(
                id: cred.id,
                name: cred.name,
                url: cred.url,
                username: cred.username,
                userId: cred.userId
            )
        }
        
        NSLog("JellyfinManager: Loaded %d saved servers", servers.count)
        
        // Restore previous server selection
        if let savedServerID = UserDefaults.standard.string(forKey: "JellyfinCurrentServerID"),
           let savedServer = servers.first(where: { $0.id == savedServerID }) {
            Task {
                await connectInBackground(to: savedServer)
            }
        }
    }
    
    // MARK: - Server Management
    
    /// Add a new server
    @discardableResult
    func addServer(name: String, url: String, username: String, password: String) async throws -> JellyfinServer {
        // Clean up URL
        var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        // Generate a unique ID
        let id = UUID().uuidString
        let deviceId = KeychainHelper.shared.getOrCreateClientIdentifier()
        
        // Authenticate with the server first
        let authResponse: JellyfinAuthResponse
        do {
            authResponse = try await JellyfinServerClient.authenticate(
                url: cleanURL,
                username: username,
                password: password,
                deviceId: deviceId
            )
        } catch {
            throw error
        }
        
        // Create credentials with auth token
        let credentials = JellyfinServerCredentials(
            id: id,
            name: name,
            url: cleanURL,
            username: username,
            password: password,
            accessToken: authResponse.AccessToken,
            userId: authResponse.User.Id
        )
        
        // Save to keychain
        _ = KeychainHelper.shared.addJellyfinServer(credentials)
        
        // Create server object
        let server = JellyfinServer(
            id: id,
            name: name,
            url: cleanURL,
            username: username,
            userId: authResponse.User.Id
        )
        
        await MainActor.run {
            self.servers.append(server)
        }
        
        // Connect to the new server
        try await connect(to: server)
        
        NSLog("JellyfinManager: Added server '%@' at %@", name, cleanURL)
        
        return server
    }
    
    /// Update an existing server
    func updateServer(id: String, name: String, url: String, username: String, password: String) async throws {
        var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        let deviceId = KeychainHelper.shared.getOrCreateClientIdentifier()
        
        // Re-authenticate to get fresh token
        let authResponse = try await JellyfinServerClient.authenticate(
            url: cleanURL,
            username: username,
            password: password,
            deviceId: deviceId
        )
        
        let credentials = JellyfinServerCredentials(
            id: id,
            name: name,
            url: cleanURL,
            username: username,
            password: password,
            accessToken: authResponse.AccessToken,
            userId: authResponse.User.Id
        )
        
        // Update in keychain
        _ = KeychainHelper.shared.updateJellyfinServer(credentials)
        
        // Update local server list
        let server = JellyfinServer(
            id: id,
            name: name,
            url: cleanURL,
            username: username,
            userId: authResponse.User.Id
        )
        
        await MainActor.run {
            if let index = self.servers.firstIndex(where: { $0.id == id }) {
                self.servers[index] = server
            }
            
            // If this is the current server, reconnect
            if self.currentServer?.id == id {
                self.currentServer = server
                self.serverClient = JellyfinServerClient(credentials: credentials)
            }
        }
        
        NSLog("JellyfinManager: Updated server '%@'", name)
    }
    
    /// Remove a server
    func removeServer(id: String) {
        _ = KeychainHelper.shared.removeJellyfinServer(id: id)
        
        servers.removeAll { $0.id == id }
        
        // If this was the current server, disconnect
        if currentServer?.id == id {
            currentServer = nil
            serverClient = nil
            connectionState = .disconnected
            clearCachedContent()
        }
        
        NSLog("JellyfinManager: Removed server with ID %@", id)
    }
    
    /// Connect to a specific server
    func connect(to server: JellyfinServer) async throws {
        guard let credentials = KeychainHelper.shared.getJellyfinServer(id: server.id) else {
            throw JellyfinClientError.unauthorized
        }
        
        guard let client = JellyfinServerClient(credentials: credentials) else {
            throw JellyfinClientError.invalidURL
        }
        
        NSLog("JellyfinManager: Connecting to server '%@'", server.name)
        
        await MainActor.run {
            self.connectionState = .connecting
        }
        
        do {
            _ = try await client.ping()
            
            // Fetch music libraries
            let libraries = try await client.fetchMusicLibraries()
            
            await MainActor.run {
                self.currentServer = server
                self.serverClient = client
                self.musicLibraries = libraries
                self.connectionState = .connected
                
                // Auto-select music library
                if let savedLibId = UserDefaults.standard.string(forKey: "JellyfinCurrentMusicLibraryID"),
                   let savedLib = libraries.first(where: { $0.id == savedLibId }) {
                    self.currentMusicLibrary = savedLib
                } else if libraries.count == 1 {
                    self.currentMusicLibrary = libraries.first
                }
            }
            
            NSLog("JellyfinManager: Connected to '%@' with %d music libraries", server.name, libraries.count)
            
            // Preload library content in background
            await preloadLibraryContent()
            
        } catch {
            await MainActor.run {
                self.connectionState = .error(error)
            }
            throw error
        }
    }
    
    /// Connect in background (for startup)
    private func connectInBackground(to server: JellyfinServer) async {
        do {
            try await connect(to: server)
        } catch {
            NSLog("JellyfinManager: Background connection failed: %@", error.localizedDescription)
        }
    }
    
    /// Disconnect from current server
    func disconnect() {
        currentServer = nil
        serverClient = nil
        connectionState = .disconnected
        musicLibraries = []
        currentMusicLibrary = nil
        clearCachedContent()
        UserDefaults.standard.removeObject(forKey: "JellyfinCurrentServerID")
        UserDefaults.standard.removeObject(forKey: "JellyfinCurrentMusicLibraryID")
    }
    
    /// Select a music library
    func selectMusicLibrary(_ library: JellyfinMusicLibrary) {
        currentMusicLibrary = library
        clearCachedContent()
        
        // Reload content for new library
        Task {
            await preloadLibraryContent()
        }
    }
    
    // MARK: - Library Preloading
    
    /// Preload library content in the background
    func preloadLibraryContent() async {
        guard let client = serverClient else {
            NSLog("JellyfinManager: Cannot preload - no server connected")
            return
        }
        
        guard !isPreloading else {
            NSLog("JellyfinManager: Already preloading, skipping")
            return
        }
        
        await MainActor.run {
            isPreloading = true
        }
        
        let libraryId = currentMusicLibrary?.id
        
        NSLog("JellyfinManager: Starting library content preload (library: %@)", libraryId ?? "all")
        
        do {
            // Fetch artists, albums, and playlists in parallel
            async let artistsTask = client.fetchAllArtists(libraryId: libraryId)
            async let albumsTask = client.fetchAllAlbums(libraryId: libraryId)
            async let playlistsTask = client.fetchPlaylists()
            
            let (artists, albums, playlists) = try await (artistsTask, albumsTask, playlistsTask)
            
            await MainActor.run {
                self.cachedArtists = artists
                self.cachedAlbums = albums
                self.cachedPlaylists = playlists
                self.isContentPreloaded = true
                self.isPreloading = false
                
                NSLog("JellyfinManager: Preloaded %d artists, %d albums, %d playlists",
                      artists.count, albums.count, playlists.count)
                
                NotificationCenter.default.post(name: Self.libraryContentDidPreloadNotification, object: self)
            }
            
        } catch {
            NSLog("JellyfinManager: Library preload failed: %@", error.localizedDescription)
            await MainActor.run {
                self.isPreloading = false
            }
        }
    }
    
    /// Clear cached library content
    private func clearCachedContent() {
        cachedArtists = []
        cachedAlbums = []
        cachedPlaylists = []
        isContentPreloaded = false
    }
    
    // MARK: - Content Fetching
    
    /// Fetch artists (uses cache if available)
    func fetchArtists() async throws -> [JellyfinArtist] {
        if isContentPreloaded && !cachedArtists.isEmpty {
            return cachedArtists
        }
        
        guard let client = serverClient else { return [] }
        return try await client.fetchAllArtists(libraryId: currentMusicLibrary?.id)
    }
    
    /// Fetch albums (uses cache if available)
    func fetchAlbums() async throws -> [JellyfinAlbum] {
        if isContentPreloaded && !cachedAlbums.isEmpty {
            return cachedAlbums
        }
        
        guard let client = serverClient else { return [] }
        return try await client.fetchAllAlbums(libraryId: currentMusicLibrary?.id)
    }
    
    /// Fetch playlists (uses cache if available)
    func fetchPlaylists() async throws -> [JellyfinPlaylist] {
        if isContentPreloaded && !cachedPlaylists.isEmpty {
            return cachedPlaylists
        }
        
        guard let client = serverClient else { return [] }
        return try await client.fetchPlaylists()
    }
    
    /// Fetch albums for an artist
    func fetchAlbums(forArtist artist: JellyfinArtist) async throws -> [JellyfinAlbum] {
        guard let client = serverClient else { return [] }
        let (_, albums) = try await client.fetchArtist(id: artist.id)
        return albums
    }
    
    /// Fetch songs for an album
    func fetchSongs(forAlbum album: JellyfinAlbum) async throws -> [JellyfinSong] {
        guard let client = serverClient else { return [] }
        let (_, songs) = try await client.fetchAlbum(id: album.id)
        return songs
    }
    
    /// Search the library
    func search(query: String) async throws -> JellyfinSearchResults {
        guard let client = serverClient else {
            return JellyfinSearchResults()
        }
        return try await client.search(query: query)
    }
    
    // MARK: - Favorites
    
    /// Favorite an item
    func favorite(itemId: String) async throws {
        guard let client = serverClient else { return }
        try await client.favorite(itemId: itemId)
    }
    
    /// Unfavorite an item
    func unfavorite(itemId: String) async throws {
        guard let client = serverClient else { return }
        try await client.unfavorite(itemId: itemId)
    }
    
    // MARK: - Rating
    
    /// Set the rating for an item
    /// - Parameters:
    ///   - itemId: The Jellyfin item ID
    ///   - rating: Rating 0-100 (percentage)
    func setRating(itemId: String, rating: Int) async throws {
        guard let client = serverClient else { return }
        try await client.setRating(itemId: itemId, rating: rating)
    }
    
    // MARK: - URL Generation
    
    /// Get streaming URL for a song
    func streamURL(for song: JellyfinSong) -> URL? {
        serverClient?.streamURL(for: song)
    }
    
    /// Get image URL for an item
    func imageURL(itemId: String, imageTag: String?, size: Int = 300) -> URL? {
        serverClient?.imageURL(itemId: itemId, imageTag: imageTag, size: size)
    }
    
    // MARK: - Track Conversion
    
    /// Convert a Jellyfin song to an AudioEngine-compatible Track
    func convertToTrack(_ song: JellyfinSong) -> Track? {
        guard let streamURL = streamURL(for: song) else { return nil }
        
        return Track(
            url: streamURL,
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: song.durationInSeconds,
            bitrate: song.bitRate,
            sampleRate: song.sampleRate,
            channels: song.channels,
            plexRatingKey: nil,
            subsonicId: nil,
            subsonicServerId: nil,
            jellyfinId: song.id,
            jellyfinServerId: currentServer?.id,
            artworkThumb: song.imageTag,
            genre: song.genre
        )
    }
    
    /// Convert multiple Jellyfin songs to Tracks
    func convertToTracks(_ songs: [JellyfinSong]) -> [Track] {
        songs.compactMap { convertToTrack($0) }
    }
}
