# Dead Code Analysis

This document lists potentially unused code identified for review and possible removal.

---

## 1. Unused Debug Function

**File:** `Sources/AdAmp/Audio/AudioOutputManager.swift`  
**Lines:** 387-446

```swift
func printDeviceDebugInfo() {
    // ... prints debug info to console
    print("=== Audio Device Debug Info ===")
    // ...
    print("=== End Debug Info ===")
}
```

**Status:** Never called anywhere in the codebase.  
**Recommendation:** Remove if not needed for manual debugging.

---

## 2. Debug Print Statements

**File:** `Sources/AdAmp/Windows/Playlist/PlaylistView.swift`  
**Lines:** 876-882

```swift
print(">>> STOP BUTTON PRESSED <<<")
// ...
print(">>> Calling engine.stop() <<<")
```

**Status:** Leftover debugging code.  
**Recommendation:** Remove these debug prints.

---

## 3. Unused `SliderDragTracker` Class

**File:** `Sources/AdAmp/Skin/SkinRegion.swift`  
**Lines:** 508-553

```swift
class SliderDragTracker {
    var isDragging = false
    var sliderType: SliderType?
    var startValue: CGFloat = 0
    var startPoint: NSPoint = .zero
    
    func beginDrag(slider: SliderType, at point: NSPoint, currentValue: CGFloat) { ... }
    func updateDrag(to point: NSPoint, in rect: NSRect) -> CGFloat { ... }
    func endDrag() { ... }
}
```

**Status:** Class is defined but never instantiated.  
**Recommendation:** Remove entirely.

---

## 4. Unused `VideoTitleBarView` Class

**File:** `Sources/AdAmp/Windows/VideoPlayer/VideoPlayerView.swift`  
**Lines:** 670-837

```swift
class VideoTitleBarView: NSView {
    var title: String = ""
    var isWindowActive: Bool = true
    var onClose: (() -> Void)?
    var onMinimize: (() -> Void)?
    // ... ~170 lines of implementation
}
```

**Status:** Class is defined but never instantiated or used.  
**Recommendation:** Remove entirely.

---

## 5. Unused `VisualizationDataSource` Protocol

**File:** `Sources/AdAmp/Windows/Milkdrop/VisualizationGLView.swift`  
**Lines:** 11-20, 29

```swift
protocol VisualizationDataSource: AnyObject {
    var spectrumData: [Float] { get }
    var pcmData: [Float] { get }
    var sampleRate: Double { get }
}

// In VisualizationGLView:
weak var dataSource: VisualizationDataSource?  // Never assigned
```

**Status:** Protocol defined and property declared, but `dataSource` is never assigned. The visualization receives data via `NotificationCenter` instead.  
**Recommendation:** Remove the protocol and the `dataSource` property.

---

## 6. Unused `LibraryFilter` Struct and `filteredTracks` Function

**File:** `Sources/AdAmp/Data/Models/MediaLibrary.swift`

### LibraryFilter (Lines 169-179)
```swift
struct LibraryFilter: Codable {
    var searchText: String = ""
    var artists: Set<String> = []
    var albums: Set<String> = []
    var genres: Set<String> = []
    var yearRange: ClosedRange<Int>?
    
    var isEmpty: Bool { ... }
}
```

### filteredTracks Function (Lines 476-549)
```swift
func filteredTracks(filter: LibraryFilter, sortBy: LibrarySortOption, ascending: Bool = true) -> [LibraryTrack] {
    // ... ~70 lines of filtering logic
}
```

**Status:** Both are defined but never used. The library uses simpler search methods (`searchTracks(query:)`) instead.  
**Recommendation:** Remove both.

---

## 7. Unused `hexString` Property

**File:** `Sources/AdAmp/Skin/Skin.swift`  
**Lines:** 176-182

```swift
extension NSColor {
    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
```

**Status:** Only used in unit tests (`AdAmpTests.swift`), not in production code.  
**Recommendation:** Keep if useful for debugging/testing, otherwise remove.

---

## Summary

| Item | File | Lines | Severity |
|------|------|-------|----------|
| `printDeviceDebugInfo()` | AudioOutputManager.swift | 387-446 | Low |
| Debug prints | PlaylistView.swift | 876-882 | Low |
| `SliderDragTracker` | SkinRegion.swift | 508-553 | Medium |
| `VideoTitleBarView` | VideoPlayerView.swift | 670-837 | Medium |
| `VisualizationDataSource` | VisualizationGLView.swift | 11-20, 29 | Low |
| `LibraryFilter` + `filteredTracks` | MediaLibrary.swift | 169-179, 476-549 | Medium |
| `hexString` | Skin.swift | 176-182 | Low |

**Estimated removable lines:** ~400 lines

---

*Generated: 2026-01-21*
