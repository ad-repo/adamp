---
name: Fix Playlist Window Skin
overview: Rewrite the playlist window to use proper Winamp skin sprites (like the working EQ and main windows), fix all button functionality, and add support for controlling both local audio and Plex/video playback.
todos:
  - id: skin-elements
    content: Update SkinElements.swift with correct playlist sprite coordinates from webamp
    status: completed
  - id: skin-renderer
    content: Add playlist rendering methods to SkinRenderer.swift
    status: completed
  - id: playlist-view-drawing
    content: Rewrite PlaylistView drawing to use skin sprites instead of programmatic drawing
    status: completed
  - id: button-hit-testing
    content: Implement button hit testing and visual feedback in PlaylistView
    status: completed
  - id: button-actions
    content: Implement button actions with popup menus (ADD, REM, SEL, MISC, LIST)
    status: completed
  - id: transport-controls
    content: Add transport controls integration for local and Plex/video playback
    status: completed
  - id: testing
    content: Test playlist window matches reference screenshots
    status: completed
---

# Fix Playlist Window to Match Winamp Reference

## Problem Analysis

The playlist window currently uses **programmatic drawing** instead of the skin sprite system that works correctly for the main window and equalizer. Comparing the reference screenshots with the current implementation reveals:

1. **Visual issues**: Title bar, buttons (ADD/REM/SEL/MISC/LIST OPTS), scrollbar, and bottom bar are all drawn programmatically instead of using `PLEDIT.BMP` sprites
2. **Non-functional buttons**: No hit testing or action handlers implemented
3. **Missing transport controls**: The reference shows playback position/time display but no transport buttons

## Correct Sprite Coordinates (from webamp)

The `PLEDIT.BMP` sprite sheet is **280x186 pixels**. Key sprites:

**Title Bar (height: 20px)**:

- Active: `(0, 0)` to `(178, 20)`
- Inactive: `(0, 21)` to `(178, 41)`
- Left corner: 25px, Title text: 100px, Tile: 25px, Right corner: 25px

**Side Tiles**:

- Left: `(0, 42, 12, 29)`
- Right: `(31, 42, 20, 29)`

**Bottom Bar (height: 38px)**:

- Left corner: `(0, 72, 125, 38)`
- Right corner: `(126, 72, 150, 38)`
- Tile: `(179, 0, 25, 38)`

**Button Groups (22x18 each)**:

- ADD: URL `(0,111)`, Dir `(0,130)`, File `(0,149)` - pressed at x+23
- REM: All `(54,111)`, Crop `(54,130)`, Selected `(54,149)`, Misc `(54,168)` - pressed at x+23
- SEL: Invert `(104,111)`, Zero `(104,130)`, All `(104,149)` - pressed at x+23
- MISC: Sort `(154,111)`, Info `(154,130)`, Options `(154,149)` - pressed at x+23
- LIST: New `(204,111)`, Save `(204,130)`, Load `(204,149)` - pressed at x+23

**Scrollbar**:

- Handle normal: `(52, 53, 8, 18)`
- Handle pressed: `(61, 53, 8, 18)`

## Implementation Plan

### 1. Update SkinElements.swift

Add corrected playlist sprite coordinates based on webamp source:

```swift
struct Playlist {
    // Title bar sprites (active/inactive)
    static let titleBarActiveLeft = NSRect(x: 0, y: 0, width: 25, height: 20)
    static let titleBarActiveTitle = NSRect(x: 26, y: 0, width: 100, height: 20)
    static let titleBarActiveTile = NSRect(x: 127, y: 0, width: 25, height: 20)
    static let titleBarActiveRight = NSRect(x: 153, y: 0, width: 25, height: 20)
    // ... inactive versions at y=21
    
    // Button sprites for all 5 groups
    struct Buttons { ... }
}
```

### 2. Update SkinRenderer.swift  

Add playlist-specific rendering methods:

- `drawPlaylistTitleBar(in:bounds:isActive:)` - using skin sprites
- `drawPlaylistBottomBar(in:bounds:buttonStates:)` - using skin sprites
- `drawPlaylistScrollbar(in:bounds:thumbPosition:isPressed:)` - using skin sprites
- `drawPlaylistButton(_:state:at:in:)` - for button groups

### 3. Rewrite PlaylistView.swift

Follow the pattern established by `EQView.swift` and `MainWindowView.swift`:

- Use coordinate transformation for Winamp's top-down coordinate system
- Implement proper hit testing for all buttons
- Add button press/release handling with visual feedback
- Add transport controls in the time display area
- Support both local and Plex/video playback control
- Use `RegionManager` for hit testing consistency

Key methods to implement:

- `draw(_:)` - delegate to SkinRenderer
- `mouseDown(with:)` - hit test buttons, start drags
- `mouseUp(with:)` - execute actions
- `performAction(for:)` - handle button actions

### 4. Button Actions to Implement

| Button | Action |

|--------|--------|

| ADD | Show popup: URL, Dir, File options |

| REM | Show popup: All, Crop, Selected, Misc |

| SEL | Show popup: Invert, Zero, All |

| MISC | Show popup: Sort, Info, Options |

| LIST OPTS | Show popup: New, Save, Load |

| Close | Close playlist window |

| Shade | Toggle shade mode |

### 5. Add Transport Controls

The reference shows time display in the bottom bar. Add:

- Mini transport buttons (or use the time area as clickable for play/pause)
- Current time / total time display using skin font
- Track count display

## Files to Modify

1. **[`SkinElements.swift`](Sources/AdAmp/Skin/SkinElements.swift)** - Add corrected playlist sprite coordinates
2. **[`SkinRenderer.swift`](Sources/AdAmp/Skin/SkinRenderer.swift)** - Add playlist rendering methods
3. **[`PlaylistView.swift`](Sources/AdAmp/Windows/Playlist/PlaylistView.swift)** - Complete rewrite following EQView pattern
4. **[`PlaylistWindowController.swift`](Sources/AdAmp/Windows/Playlist/PlaylistWindowController.swift)** - Minor updates for actions

## Implementation Order

1. Update SkinElements with correct coordinates
2. Add SkinRenderer methods for playlist
3. Rewrite PlaylistView drawing to use skin sprites
4. Add button hit testing and visual feedback
5. Implement button actions (popup menus)
6. Add transport controls integration
7. Test with skin to match reference screenshots