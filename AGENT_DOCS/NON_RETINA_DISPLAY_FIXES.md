# Non-Retina Display Fixes

This document details the work done to fix rendering artifacts on non-Retina (1x) displays, specifically with the default Winamp skin.

## Overview

Two main issues were identified on non-Retina displays:
1. **Blue line artifacts** - Blue-tinted pixels in the skin became visible as harsh lines/artifacts
2. **Lines under titles** - Horizontal lines appearing below window titles (Library Browser, Milkdrop)

## Root Causes

### Blue Line Artifacts

The default Winamp skin (`base-2.91.wsz`) contains many subtle blue-tinted pixels throughout its BMP sprite sheets. On Retina (2x) displays, these blend smoothly due to higher pixel density and anti-aliasing. On non-Retina displays, these blue pixels become visible as distinct colored lines/artifacts due to:
- Lower pixel density (1x vs 2x)
- Less effective anti-aliasing at 1x scale
- Sub-pixel rendering differences

Affected skin files: `PLEDIT.BMP`, `EQMAIN.BMP`, `MAIN.BMP`, `TITLEBAR.BMP`, `GEN.BMP`, `VOLUME.BMP`, `BALANCE.BMP`, and others.

### Lines Under Titles

This issue was caused by specific code changes that disabled anti-aliasing on non-Retina displays. When `context.setShouldAntialias(false)` was applied to `PlexBrowserView`, it created hard edges at sprite boundaries that appeared as lines under window titles.

## Approaches That Did NOT Work

### 1. Modifying Skin BMP Files Directly

**Approach**: Created Swift scripts to extract the `.wsz` skin archive, modify BMP files (converting blue pixels to grayscale), and repackage.

**Problems**:
- BMP files saved by `NSBitmapImageRep` had different format characteristics than the originals
- This caused rendering artifacts, including the "lines under titles" problem
- Some attempts resulted in magenta (transparency color) becoming visible
- The modified BMPs worked differently than originals when loaded by the skin renderer

**Scripts tried**:
- `fix_blues.swift` - Basic blue-to-grayscale conversion
- `fix_blues_preserve_titlebar.swift` - Preserved title bar rows in PLEDIT.BMP
- Various iterations with different pixel selection criteria

### 2. Disabling Anti-Aliasing in Views

**Approach**: Added conditional code to disable anti-aliasing on non-Retina displays:

```swift
let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
if backingScale < 1.5 {
    context.interpolationQuality = .none
    context.setShouldAntialias(false)
    context.setAllowsAntialiasing(false)
}
```

**Problems**:
- Made the blue line artifacts MORE pronounced, not less
- Created harsh edges at sprite boundaries (the "lines under titles")
- Anti-aliasing was actually helping to blend the problematic pixels

### 3. Masking Specific Rows in Title Bars

**Approach**: Added code to `SkinRenderer.swift` to fill specific Y-coordinate rows with background color to hide highlight lines.

**Problems**:
- Required precise knowledge of which rows contained artifacts
- Different skins have different sprite layouts
- Fragile solution that could break with other skins

## Approaches That DID Work

### 1. Runtime Image Processing in SkinLoader (Current Solution)

**Approach**: Process skin images at load time, converting blue-tinted pixels to grayscale only on non-Retina displays.

**Implementation** in `SkinLoader.swift`:

```swift
private func loadSkin(from directory: URL) throws -> Skin {
    // Check if we're on a non-Retina display
    let isNonRetina = (NSScreen.main?.backingScaleFactor ?? 2.0) < 1.5
    
    func loadImage(_ name: String) -> NSImage? {
        // ... load BMP ...
        if var image = loadBMP(from: url) {
            if isNonRetina {
                image = processForNonRetina(image)
            }
            return image
        }
    }
}

private func processForNonRetina(_ image: NSImage) -> NSImage {
    // Convert blue-tinted pixels to grayscale while preserving:
    // - Magenta transparency (255, 0, 255)
    // - Bright/white pixels
    // - Warm colors (red/yellow/orange)
    
    for each pixel:
        if b > r || b > g:  // Has blue tint
            gray = luminance(r, g, b)
            set pixel to (gray, gray, gray)
}
```

**Why it works**:
- Original skin files remain unchanged
- Processing happens in memory, avoiding BMP format issues
- Only affects non-Retina displays
- Preserves transparency and warm colors

### 2. Rounded Coordinates for Text/Scroll

**Approach**: Round pixel coordinates to integers on non-Retina displays to prevent sub-pixel positioning artifacts.

**Implementation** in `PlexBrowserView.swift` and `PlaylistView.swift`:

```swift
let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
let roundedScrollOffset = backingScale < 1.5 ? round(scrollOffset) : scrollOffset
```

**Why it works**:
- Prevents text "shimmering" during scroll
- Ensures pixels align to display grid
- No visual impact on Retina displays

### 3. Opaque Backgrounds on Non-Retina

**Approach**: Use fully opaque colors instead of alpha-blended backgrounds on non-Retina displays.

**Implementation** in `PlexBrowserView.swift`:

```swift
if backingScaleForBg < 1.5 {
    colors.normalBackground.setFill()  // Opaque
} else {
    colors.normalBackground.withAlphaComponent(0.6).setFill()  // Semi-transparent
}
```

**Why it works**:
- Prevents compositing artifacts from alpha blending
- Ensures consistent background appearance

### 4. Opaque Window on Non-Retina

**Approach**: Make the Library Browser window opaque on non-Retina displays.

**Implementation** in `PlexBrowserWindowController.swift`:

```swift
let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
if backingScale < 1.5 {
    window.backgroundColor = .black
    window.isOpaque = true
} else {
    window.backgroundColor = .clear
    window.isOpaque = false
}
```

### 5. Skip Highlight Lines in SkinRenderer

**Approach**: Conditionally skip drawing certain 1-pixel highlight lines on non-Retina displays.

**Implementation** in `SkinRenderer.swift`:

```swift
let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
if backingScale >= 1.5 {
    // Only draw highlight on Retina
    NSColor(calibratedRed: 0.20, green: 0.20, blue: 0.30, alpha: 1.0).setFill()
    context.fill(NSRect(x: borderWidth - 1, y: titleHeight, width: 1, height: ...))
}
```

### 6. NSImage-Based Title Bar Rendering (Library Browser)

**Approach**: Use NSImage-based sprite drawing instead of CGImage with `interpolationQuality = .none` for title bars.

**Problem**: The Library Browser title bar had visible horizontal lines while Milkdrop's title bar looked clean. The difference was:
- Library Browser used `CGImage`-based `drawSprite` with `context.interpolationQuality = .none`
- Milkdrop used `NSImage`-based `drawSprite` without forcing interpolation off

**Solution**: Changed `drawPlexBrowserTitleBarFromPledit` to use the same NSImage-based rendering approach as Milkdrop:

```swift
// Before (caused horizontal lines):
drawSprite(from: cgImage, sourceRect: leftCorner,
          destRect: NSRect(...), in: context)

// After (matches Milkdrop - no lines):
drawSprite(from: pleditImage, sourceRect: leftCorner,
          to: NSRect(...), in: context)
```

**Why it works**:
- NSImage-based drawing uses default interpolation which blends pixel edges
- CGImage with `.none` interpolation makes every pixel edge sharp, revealing lines in sprites
- Both title bars now use identical rendering path

## Current State

### Files Changed from `main`

1. **`Sources/AdAmp/Skin/SkinLoader.swift`**
   - Added `processForNonRetina()` function
   - Applied processing to loaded images on non-Retina displays

2. **`Sources/AdAmp/Skin/SkinRenderer.swift`**
   - Skip certain highlight lines on non-Retina displays
   - Use NSImage-based rendering for Library Browser title bar (matches Milkdrop)

3. **`Sources/AdAmp/Windows/PlexBrowser/PlexBrowserView.swift`**
   - Rounded coordinates for text positioning
   - Rounded scroll offset
   - Opaque backgrounds on non-Retina
   - Fill list area background to prevent gaps
   - Optimized scroll redraw

4. **`Sources/AdAmp/Windows/PlexBrowser/PlexBrowserWindowController.swift`**
   - Opaque window on non-Retina displays

5. **`Sources/AdAmp/Windows/Playlist/PlaylistView.swift`**
   - Rounded scroll offset on non-Retina

## Remaining Work

1. **Blue artifacts may still appear in some areas** - The grayscale conversion helps but may not catch all problematic pixels

2. **Other skins untested** - The runtime processing currently applies to all skins; may need refinement

3. **Performance consideration** - Image processing at load time adds startup overhead on non-Retina displays

## Key Learnings

1. **Don't disable anti-aliasing** - It actually helps blend problematic pixels
2. **Avoid modifying BMP files** - Format differences cause rendering issues
3. **Runtime processing is safer** - Keeps original assets intact
4. **Test on actual hardware** - Simulator behavior differs from real non-Retina displays
5. **Blue detection needs careful thresholds** - Must preserve intended colors while removing artifacts
6. **NSImage vs CGImage rendering matters** - CGImage with `interpolationQuality = .none` makes sprite edges harsh; NSImage with default interpolation blends them smoothly
