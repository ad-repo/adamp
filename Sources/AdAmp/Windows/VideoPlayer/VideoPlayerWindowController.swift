import AppKit
import KSPlayer

/// Window controller for video playback with KSPlayer and skinned UI
class VideoPlayerWindowController: NSWindowController, NSWindowDelegate {
    
    // MARK: - Properties
    
    private var videoPlayerView: VideoPlayerView!
    
    /// Whether video is currently playing
    private(set) var isPlaying: Bool = false
    
    /// Current video title
    private(set) var currentTitle: String?
    
    // MARK: - Static Configuration
    
    /// Configure KSPlayer globally (call once at app startup)
    static func configureKSPlayer() {
        // Use FFmpeg-only backend for consistent behavior across all formats
        // KSMEPlayer is the FFmpeg-based player, KSAVPlayer is the AVPlayer-based one
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = nil  // No fallback - use FFmpeg only
        
        // Enable hardware acceleration
        KSOptions.hardwareDecode = true
        
        // Configure playback behavior
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = false
        
        NSLog("VideoPlayerWindowController: KSPlayer configured for FFmpeg-only playback")
    }
    
    // MARK: - Initialization
    
    init() {
        // Create a borderless window for skinned video playback
        let contentRect = NSRect(x: 0, y: 0, width: 854, height: 480)
        let styleMask: NSWindow.StyleMask = [.borderless, .resizable, .fullSizeContentView]
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        window.title = "Video Player"
        window.minSize = NSSize(width: 480, height: 270 + SkinElements.titleBarHeight)
        window.isReleasedWhenClosed = false
        window.center()
        
        // Dark appearance for video
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        
        // Allow window to be moved by dragging anywhere (though we handle title bar specifically)
        window.isMovableByWindowBackground = false
        
        // Allow resizing from edges
        window.isOpaque = true
        window.hasShadow = true
        
        super.init(window: window)
        
        setupVideoView()
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupVideoView() {
        videoPlayerView = VideoPlayerView(frame: window!.contentView!.bounds)
        videoPlayerView.autoresizingMask = [.width, .height]
        window?.contentView?.addSubview(videoPlayerView)
        
        // Set up callbacks for window controls
        videoPlayerView.onClose = { [weak self] in
            self?.close()
        }
        
        videoPlayerView.onMinimize = { [weak self] in
            self?.window?.miniaturize(nil)
        }
        
        // Track playback state changes
        videoPlayerView.onPlaybackStateChanged = { [weak self] playing in
            self?.updatePlayingState(playing)
        }
    }
    
    // MARK: - Playback Control
    
    /// Play a video from URL with optional title
    func play(url: URL, title: String) {
        currentTitle = title
        window?.title = title
        videoPlayerView.play(url: url, title: title, isPlexURL: false, plexToken: nil)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        isPlaying = true
        WindowManager.shared.videoPlaybackDidStart()
    }
    
    /// Play a Plex movie
    func play(movie: PlexMovie) {
        guard let url = PlexManager.shared.streamURL(for: movie) else {
            NSLog("Failed to get stream URL for movie: %@", movie.title)
            return
        }
        
        let token = PlexManager.shared.account?.authToken
        currentTitle = movie.title
        window?.title = movie.title
        videoPlayerView.play(url: url, title: movie.title, isPlexURL: true, plexToken: token)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        isPlaying = true
        WindowManager.shared.videoPlaybackDidStart()
    }
    
    /// Play a Plex episode
    func play(episode: PlexEpisode) {
        guard let url = PlexManager.shared.streamURL(for: episode) else {
            NSLog("Failed to get stream URL for episode: %@", episode.title)
            return
        }
        
        let token = PlexManager.shared.account?.authToken
        let title = "\(episode.grandparentTitle ?? "Unknown") - \(episode.episodeIdentifier) - \(episode.title)"
        currentTitle = title
        window?.title = title
        videoPlayerView.play(url: url, title: title, isPlexURL: true, plexToken: token)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        isPlaying = true
        WindowManager.shared.videoPlaybackDidStart()
    }
    
    /// Stop playback
    func stop() {
        videoPlayerView.stop()
        isPlaying = false
        currentTitle = nil
        WindowManager.shared.videoPlaybackDidStop()
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        videoPlayerView.togglePlayPause()
    }
    
    /// Skip forward
    func skipForward(_ seconds: TimeInterval = 10) {
        videoPlayerView.skipForward(seconds)
    }
    
    /// Skip backward
    func skipBackward(_ seconds: TimeInterval = 10) {
        videoPlayerView.skipBackward(seconds)
    }
    
    /// Update playing state (called from VideoPlayerView)
    func updatePlayingState(_ playing: Bool) {
        isPlaying = playing
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        stop()
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        videoPlayerView.updateActiveState(true)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        videoPlayerView.updateActiveState(false)
    }
    
    // MARK: - Keyboard Shortcuts
    
    @objc func toggleFullScreen(_ sender: Any?) {
        window?.toggleFullScreen(sender)
    }
}
