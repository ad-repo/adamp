import AppKit

/// Manages all application windows and their interactions
/// Handles window docking, snapping, and coordinated movement
class WindowManager {
    
    // MARK: - Singleton
    
    static let shared = WindowManager()
    
    // MARK: - Properties
    
    /// The audio engine instance
    let audioEngine = AudioEngine()
    
    /// The currently loaded skin
    private(set) var currentSkin: Skin?
    
    /// Main player window controller
    private(set) var mainWindowController: MainWindowController?
    
    /// Playlist window controller
    private(set) var playlistWindowController: PlaylistWindowController?
    
    /// Equalizer window controller
    private(set) var equalizerWindowController: EQWindowController?
    
    /// Media library window controller
    private var mediaLibraryWindowController: MediaLibraryWindowController?
    
    /// Snap threshold in pixels
    private let snapThreshold: CGFloat = 10
    
    /// Docking threshold - windows closer than this are considered docked
    private let dockThreshold: CGFloat = 2
    
    /// Track which window is currently being dragged
    private var draggingWindow: NSWindow?
    
    /// Track the last drag delta for grouped movement
    private var lastDragDelta: NSPoint = .zero
    
    /// Windows that should move together with the dragging window
    private var dockedWindowsToMove: [NSWindow] = []
    
    // MARK: - Initialization
    
    private init() {
        // Load default skin
        loadDefaultSkin()
    }
    
    // MARK: - Window Management
    
    func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        mainWindowController?.showWindow(nil)
    }
    
    func toggleMainWindow() {
        if let controller = mainWindowController, controller.window?.isVisible == true {
            controller.window?.orderOut(nil)
        } else {
            showMainWindow()
        }
    }
    
    func showPlaylist() {
        if playlistWindowController == nil {
            playlistWindowController = PlaylistWindowController()
        }
        playlistWindowController?.showWindow(nil)
        notifyMainWindowVisibilityChanged()
    }

    var isPlaylistVisible: Bool {
        playlistWindowController?.window?.isVisible == true
    }
    
    func togglePlaylist() {
        if let controller = playlistWindowController, controller.window?.isVisible == true {
            controller.window?.orderOut(nil)
        } else {
            showPlaylist()
        }
        notifyMainWindowVisibilityChanged()
    }
    
    func showEqualizer() {
        if equalizerWindowController == nil {
            equalizerWindowController = EQWindowController()
        }
        equalizerWindowController?.showWindow(nil)
        notifyMainWindowVisibilityChanged()
    }

    var isEqualizerVisible: Bool {
        equalizerWindowController?.window?.isVisible == true
    }
    
    func toggleEqualizer() {
        if let controller = equalizerWindowController, controller.window?.isVisible == true {
            controller.window?.orderOut(nil)
        } else {
            showEqualizer()
        }
        notifyMainWindowVisibilityChanged()
    }
    
    func showMediaLibrary() {
        if mediaLibraryWindowController == nil {
            mediaLibraryWindowController = MediaLibraryWindowController()
        }
        mediaLibraryWindowController?.showWindow(nil)
    }
    
    var isMediaLibraryVisible: Bool {
        mediaLibraryWindowController?.window?.isVisible == true
    }
    
    func toggleMediaLibrary() {
        if let controller = mediaLibraryWindowController, controller.window?.isVisible == true {
            controller.window?.orderOut(nil)
        } else {
            showMediaLibrary()
        }
    }

    func notifyMainWindowVisibilityChanged() {
        mainWindowController?.windowVisibilityDidChange()
    }
    
    // MARK: - Skin Management
    
    func loadSkin(from url: URL) {
        do {
            let skin = try SkinLoader.shared.load(from: url)
            currentSkin = skin
            notifySkinChanged()
        } catch {
            print("Failed to load skin: \(error)")
        }
    }
    
    private func loadDefaultSkin() {
        currentSkin = SkinLoader.shared.loadDefault()
    }
    
    private func notifySkinChanged() {
        // Notify all windows to redraw with new skin
        mainWindowController?.skinDidChange()
        playlistWindowController?.skinDidChange()
        equalizerWindowController?.skinDidChange()
        mediaLibraryWindowController?.skinDidChange()
    }
    
    // MARK: - Window Snapping & Docking
    
    /// Called when a window drag begins
    func windowWillStartDragging(_ window: NSWindow) {
        draggingWindow = window
        // Find all windows that are docked to this window
        dockedWindowsToMove = findDockedWindows(to: window)
    }
    
    /// Called when a window drag ends
    func windowDidFinishDragging(_ window: NSWindow) {
        draggingWindow = nil
        dockedWindowsToMove.removeAll()
    }
    
    /// Called when a window is being dragged - just return the new position without constraints
    func windowWillMove(_ window: NSWindow, to newOrigin: NSPoint) -> NSPoint {
        // Let macOS handle window positioning naturally - no snapping or constraints
        return newOrigin
    }
    
    /// Find all windows that are docked (touching) the given window
    private func findDockedWindows(to window: NSWindow) -> [NSWindow] {
        var dockedWindows: [NSWindow] = []
        var windowsToCheck: [NSWindow] = [window]
        var checkedWindows: Set<ObjectIdentifier> = [ObjectIdentifier(window)]
        
        // Use BFS to find all transitively docked windows
        while !windowsToCheck.isEmpty {
            let currentWindow = windowsToCheck.removeFirst()
            
            for otherWindow in allWindows() {
                let otherId = ObjectIdentifier(otherWindow)
                if checkedWindows.contains(otherId) { continue }
                
                if areWindowsDocked(currentWindow, otherWindow) {
                    dockedWindows.append(otherWindow)
                    windowsToCheck.append(otherWindow)
                    checkedWindows.insert(otherId)
                }
            }
        }
        
        return dockedWindows
    }
    
    /// Check if two windows are docked (touching edges)
    private func areWindowsDocked(_ window1: NSWindow, _ window2: NSWindow) -> Bool {
        let frame1 = window1.frame
        let frame2 = window2.frame
        
        // Check if windows are touching horizontally (side by side)
        let horizontallyAligned = (frame1.minY < frame2.maxY && frame1.maxY > frame2.minY)
        let touchingHorizontally = horizontallyAligned && (
            abs(frame1.maxX - frame2.minX) <= dockThreshold ||  // window1 left of window2
            abs(frame1.minX - frame2.maxX) <= dockThreshold     // window1 right of window2
        )
        
        // Check if windows are touching vertically (stacked)
        let verticallyAligned = (frame1.minX < frame2.maxX && frame1.maxX > frame2.minX)
        let touchingVertically = verticallyAligned && (
            abs(frame1.maxY - frame2.minY) <= dockThreshold ||  // window1 below window2
            abs(frame1.minY - frame2.maxY) <= dockThreshold     // window1 above window2
        )
        
        return touchingHorizontally || touchingVertically
    }
    
    /// Get all managed windows
    private func allWindows() -> [NSWindow] {
        var windows: [NSWindow] = []
        if let w = mainWindowController?.window, w.isVisible { windows.append(w) }
        if let w = playlistWindowController?.window, w.isVisible { windows.append(w) }
        if let w = equalizerWindowController?.window, w.isVisible { windows.append(w) }
        if let w = mediaLibraryWindowController?.window, w.isVisible { windows.append(w) }
        return windows
    }
    
    /// Get all visible windows
    func visibleWindows() -> [NSWindow] {
        return allWindows()
    }
    
    // MARK: - State Persistence
    
    func saveWindowPositions() {
        let defaults = UserDefaults.standard
        
        if let frame = mainWindowController?.window?.frame {
            defaults.set(NSStringFromRect(frame), forKey: "MainWindowFrame")
        }
        if let frame = playlistWindowController?.window?.frame {
            defaults.set(NSStringFromRect(frame), forKey: "PlaylistWindowFrame")
        }
        if let frame = equalizerWindowController?.window?.frame {
            defaults.set(NSStringFromRect(frame), forKey: "EqualizerWindowFrame")
        }
        if let frame = mediaLibraryWindowController?.window?.frame {
            defaults.set(NSStringFromRect(frame), forKey: "MediaLibraryWindowFrame")
        }
    }
    
    func restoreWindowPositions() {
        let defaults = UserDefaults.standard
        
        if let frameString = defaults.string(forKey: "MainWindowFrame"),
           let window = mainWindowController?.window {
            let frame = NSRectFromString(frameString)
            window.setFrame(frame, display: true)
        }
        if let frameString = defaults.string(forKey: "PlaylistWindowFrame"),
           let window = playlistWindowController?.window {
            let frame = NSRectFromString(frameString)
            window.setFrame(frame, display: true)
        }
        if let frameString = defaults.string(forKey: "EqualizerWindowFrame"),
           let window = equalizerWindowController?.window {
            let frame = NSRectFromString(frameString)
            window.setFrame(frame, display: true)
        }
        if let frameString = defaults.string(forKey: "MediaLibraryWindowFrame"),
           let window = mediaLibraryWindowController?.window {
            let frame = NSRectFromString(frameString)
            window.setFrame(frame, display: true)
        }
    }
}