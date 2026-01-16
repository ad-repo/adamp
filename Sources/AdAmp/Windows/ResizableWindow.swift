import AppKit

/// A borderless window that can become key/main and supports manual edge resizing
class ResizableWindow: NSWindow {
    
    // MARK: - Resize Edge Detection
    
    /// Width of the resize edge detection zone in pixels
    private let edgeThickness: CGFloat = 6
    
    /// Which edges are being resized
    struct ResizeEdges: OptionSet {
        let rawValue: Int
        
        static let left   = ResizeEdges(rawValue: 1 << 0)
        static let right  = ResizeEdges(rawValue: 1 << 1)
        static let top    = ResizeEdges(rawValue: 1 << 2)
        static let bottom = ResizeEdges(rawValue: 1 << 3)
        
        static let topLeft: ResizeEdges     = [.top, .left]
        static let topRight: ResizeEdges    = [.top, .right]
        static let bottomLeft: ResizeEdges  = [.bottom, .left]
        static let bottomRight: ResizeEdges = [.bottom, .right]
        
        static let none: ResizeEdges = []
    }
    
    /// Current resize operation state
    private var resizeEdges: ResizeEdges = .none
    
    /// Initial mouse location in screen coordinates when resize started
    private var initialMouseLocation: NSPoint = .zero
    
    /// Initial window frame when resize started
    private var initialFrame: NSRect = .zero
    
    /// Whether we're currently in a resize operation
    private var isResizing: Bool = false
    
    // MARK: - Initialization
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Enable mouse moved events for cursor updates
        acceptsMouseMovedEvents = true
    }
    
    // MARK: - Key/Main Window Support
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // MARK: - Edge Detection
    
    /// Detect which edges the mouse is near for a given point in window coordinates
    private func detectEdges(at windowPoint: NSPoint) -> ResizeEdges {
        let bounds = NSRect(origin: .zero, size: frame.size)
        var edges: ResizeEdges = []
        
        // Check horizontal edges
        if windowPoint.x < edgeThickness {
            edges.insert(.left)
        } else if windowPoint.x > bounds.width - edgeThickness {
            edges.insert(.right)
        }
        
        // Check vertical edges
        if windowPoint.y < edgeThickness {
            edges.insert(.bottom)
        } else if windowPoint.y > bounds.height - edgeThickness {
            edges.insert(.top)
        }
        
        return edges
    }
    
    /// Get the appropriate cursor for the given edges
    private func cursor(for edges: ResizeEdges) -> NSCursor {
        switch edges {
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft, .bottomRight:
            // Diagonal NW-SE
            return NSCursor(image: NSImage(named: NSImage.Name("NSResizeDiagonal45Cursor")) ?? NSCursor.arrow.image, 
                          hotSpot: NSPoint(x: 8, y: 8))
        case .topRight, .bottomLeft:
            // Diagonal NE-SW
            return NSCursor(image: NSImage(named: NSImage.Name("NSResizeDiagonal135Cursor")) ?? NSCursor.arrow.image,
                          hotSpot: NSPoint(x: 8, y: 8))
        default:
            return .arrow
        }
    }
    
    // MARK: - Mouse Events
    
    override func mouseMoved(with event: NSEvent) {
        let windowPoint = event.locationInWindow
        let edges = detectEdges(at: windowPoint)
        
        if edges != .none {
            // Show appropriate resize cursor
            switch edges {
            case .left, .right:
                NSCursor.resizeLeftRight.set()
            case .top, .bottom:
                NSCursor.resizeUpDown.set()
            case .topLeft, .bottomRight:
                // Use crosshair as fallback for diagonal (macOS doesn't expose diagonal cursors easily)
                NSCursor.crosshair.set()
            case .topRight, .bottomLeft:
                NSCursor.crosshair.set()
            default:
                NSCursor.arrow.set()
            }
        } else {
            NSCursor.arrow.set()
        }
        
        super.mouseMoved(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        let windowPoint = event.locationInWindow
        let edges = detectEdges(at: windowPoint)
        
        if edges != .none {
            // Start resize operation
            isResizing = true
            resizeEdges = edges
            initialMouseLocation = NSEvent.mouseLocation
            initialFrame = frame
            
            // Don't call super - we're handling this
            return
        }
        
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isResizing {
            performResize()
            return
        }
        
        super.mouseDragged(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        if isResizing {
            isResizing = false
            resizeEdges = .none
            NSCursor.arrow.set()
            return
        }
        
        super.mouseUp(with: event)
    }
    
    // MARK: - Resize Logic
    
    private func performResize() {
        let currentMouseLocation = NSEvent.mouseLocation
        let deltaX = currentMouseLocation.x - initialMouseLocation.x
        let deltaY = currentMouseLocation.y - initialMouseLocation.y
        
        var newFrame = initialFrame
        
        // Handle horizontal resizing
        if resizeEdges.contains(.left) {
            // Resizing from left edge moves origin and changes width
            let newWidth = initialFrame.width - deltaX
            if newWidth >= minSize.width && (maxSize.width == 0 || newWidth <= maxSize.width) {
                newFrame.origin.x = initialFrame.origin.x + deltaX
                newFrame.size.width = newWidth
            }
        } else if resizeEdges.contains(.right) {
            // Resizing from right edge only changes width
            let newWidth = initialFrame.width + deltaX
            if newWidth >= minSize.width && (maxSize.width == 0 || newWidth <= maxSize.width) {
                newFrame.size.width = newWidth
            }
        }
        
        // Handle vertical resizing
        if resizeEdges.contains(.bottom) {
            // Resizing from bottom edge moves origin and changes height
            let newHeight = initialFrame.height - deltaY
            if newHeight >= minSize.height && (maxSize.height == 0 || newHeight <= maxSize.height) {
                newFrame.origin.y = initialFrame.origin.y + deltaY
                newFrame.size.height = newHeight
            }
        } else if resizeEdges.contains(.top) {
            // Resizing from top edge only changes height
            let newHeight = initialFrame.height + deltaY
            if newHeight >= minSize.height && (maxSize.height == 0 || newHeight <= maxSize.height) {
                newFrame.size.height = newHeight
            }
        }
        
        // Apply the new frame
        setFrame(newFrame, display: true)
    }
    
    // MARK: - Cursor Rect Support
    
    override func cursorUpdate(with event: NSEvent) {
        let windowPoint = event.locationInWindow
        let edges = detectEdges(at: windowPoint)
        
        if edges != .none {
            cursor(for: edges).set()
        } else {
            super.cursorUpdate(with: event)
        }
    }
}
