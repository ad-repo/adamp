import AppKit

/// A borderless window that can become key/main
class ResizableWindow: NSWindow {
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
