# Modern Skin Creation Guide

This guide covers creating custom skins for NullPlayer's modern UI mode.

## Overview

Modern skins are built on the **ModernSkin Engine**, a theme-agnostic system that renders UI elements from a combination of:

1. **JSON configuration** (`skin.json`) -- colors, fonts, layout, animations
2. **PNG image assets** -- optional per-element images
3. **Programmatic fallback** -- elements without images are drawn using palette colors

This means you can create a skin with just a `skin.json` (pure programmatic) or provide custom images for every element.

## Skin Directory Structure

```
MySkin/
├── skin.json              # Required: skin configuration
└── images/                # Optional: PNG assets
    ├── btn_play_normal.png
    ├── btn_play_pressed.png
    ├── btn_play_normal@2x.png    # Optional Retina version
    ├── btn_play_pressed@2x.png
    ├── time_digit_0.png
    ├── ...
    └── background.png
```

## `skin.json` Schema

```json
{
    "meta": {
        "name": "My Skin",
        "author": "Your Name",
        "version": "1.0",
        "description": "A custom modern skin"
    },
    "palette": {
        "primary": "#00ffcc",
        "secondary": "#00aaff",
        "accent": "#ff00aa",
        "highlight": "#00ffee",
        "background": "#0a0a12",
        "surface": "#0d1117",
        "text": "#00ffcc",
        "textDim": "#006655",
        "positive": "#00ff88",
        "negative": "#ff3366",
        "warning": "#ffaa00",
        "border": "#00ffcc"
    },
    "fonts": {
        "primaryName": "DepartureMono-Regular",
        "fallbackName": "Menlo",
        "titleSize": 8,
        "bodySize": 9,
        "smallSize": 7,
        "timeSize": 20,
        "infoSize": 6.5,
        "eqLabelSize": 7,
        "eqValueSize": 6,
        "marqueeSize": 11.7,
        "playlistSize": 8
    },
    "background": {
        "image": "background.png",
        "grid": {
            "color": "#0a2a2a",
            "spacing": 20,
            "angle": 75,
            "opacity": 0.15,
            "perspective": true
        }
    },
    "glow": {
        "enabled": true,
        "radius": 8,
        "intensity": 0.6,
        "threshold": 0.7,
        "color": "#00ffcc",
        "elementBlur": 1.0
    },
    "window": {
        "borderWidth": 1,
        "borderColor": "#00ffcc",
        "cornerRadius": 8,
        "scale": 1.25,
        "seamlessDocking": 1.0
    },
    "marquee": {
        "scrollSpeed": 30,
        "scrollGap": 50
    },
    "titleText": {
        "mode": "image",
        "charSpacing": 1,
        "charHeight": 10,
        "alignment": "center",
        "tintColor": "#d4cfc0",
        "padLeft": 0,
        "padRight": 0,
        "verticalOffset": 0,
        "decorationLeft": "title_decoration_skull",
        "decorationRight": "title_decoration_skull",
        "decorationSpacing": 3
    },
    "elements": {
        "btn_play": {
            "color": "#00ff00",
            "x": 33, "y": 8, "width": 23, "height": 20
        }
    },
    "animations": {
        "seek_fill": {
            "type": "glow",
            "duration": 3.0,
            "minValue": 0.4,
            "maxValue": 1.0
        }
    }
}
```

## Color Palette

The palette defines 17 named colors used throughout the UI:

| Key | Purpose | Fallback |
|-----|---------|----------|
| `primary` | Main accent color (buttons, text, indicators) | Required |
| `secondary` | Secondary accent | Required |
| `accent` | Highlight accent (spectrum bars, volume gradient) | Required |
| `highlight` | Bright highlight | Defaults to `primary` |
| `background` | Window fill color | Required |
| `surface` | Panel/recessed area background | Required |
| `text` | Primary text color | Required |
| `textDim` | Dimmed/inactive text | Required |
| `positive` | Positive indicator | `#00ff00` |
| `negative` | Error/negative indicator | `#ff0000` |
| `warning` | Warning indicator | `#ffaa00` |
| `border` | Window border color | Same as `primary` |
| `timeColor` | Time display digit color | `#d9d900` (warm yellow) |
| `marqueeColor` | Scrolling title/marquee text color | `#d9d900` (warm yellow) |
| `dataColor` | Data field values: playlist track numbers, library browser info (source, library, item count), star ratings in art-only mode | `#d9d900` (warm yellow) |
| `eqLow` | EQ color at -12dB (bottom of slider) | `#00d900` (green) |
| `eqMid` | EQ color at 0dB (middle of slider) | `#d9d900` (yellow) |
| `eqHigh` | EQ color at +12dB (top of slider) | `#d92600` (red) |

All colors are hex strings (e.g., `"#00ffcc"`).

## Element Catalog

Every skinnable element has an ID, default position/size, and valid states.

### Window Chrome

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `window_background` | 0,0,275,116 | normal | Full window background |
| `window_border` | 0,0,275,116 | normal | Window border overlay |

### Title Bar

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `titlebar` | 0,102,275,14 | normal | Title bar background |
| `titlebar_text` | 50,102,175,14 | normal | Title text area |
| `btn_close` | 255,103,12,12 | normal, pressed | Close button |
| `btn_minimize` | 228,103,12,12 | normal, pressed | Minimize button |
| `btn_shade` | 241,103,12,12 | normal, pressed | Shade mode button |

### Time Display

| Element ID | Default Rect | Description |
|-----------|-------------|-------------|
| `time_display` | 10,66,80,30 | Time display area |
| `time_digit_0` through `time_digit_9` | 14x22 each | 7-segment LED digits |
| `time_colon` | 7x22 | Colon separator |
| `time_minus` | 14x22 | Minus sign (remaining time) |

### Info Panel

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `marquee_bg` | 95,66,170,30 | normal | Marquee background panel |
| `info_bitrate` | 95,62,40,9 | normal | Bitrate label |
| `info_samplerate` | 135,62,30,9 | normal | Sample rate label |
| `info_bpm` | 165,62,30,9 | normal | BPM label |
| `info_stereo` | 198,62,32,9 | off, on | Stereo indicator |
| `info_mono` | 198,62,32,9 | off, on | Mono indicator |
| `info_cast` | 232,62,34,9 | off, on | Cast active indicator |

### Status & Spectrum

| Element ID | Default Rect | Description |
|-----------|-------------|-------------|
| `status_play` | 10,48,12,12 | Play status indicator |
| `status_pause` | 10,48,12,12 | Pause status indicator |
| `status_stop` | 10,48,12,12 | Stop status indicator |
| `spectrum_area` | 24,44,60,20 | Mini spectrum analyzer |

### Seek Bar

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `seek_track` | 10,36,255,6 | normal | Seek bar track |
| `seek_fill` | 10,36,*,6 | normal | Filled portion |
| `seek_thumb` | *,34,10,10 | normal, pressed | Seek position thumb |

### Transport Buttons

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `btn_prev` | 10,8,23,20 | normal, pressed, disabled | Previous track |
| `btn_play` | 33,8,23,20 | normal, pressed, disabled | Play |
| `btn_pause` | 56,8,23,20 | normal, pressed, disabled | Pause |
| `btn_stop` | 79,8,23,20 | normal, pressed, disabled | Stop |
| `btn_next` | 102,8,23,20 | normal, pressed, disabled | Next track |
| `btn_eject` | 125,8,23,20 | normal, pressed | Open file |

### Toggle Buttons

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `btn_shuffle` | 154,8,40,20 | off, on, off_pressed, on_pressed | Shuffle toggle |
| `btn_repeat` | 196,8,40,20 | off, on, off_pressed, on_pressed | Repeat toggle |
| `btn_eq` | 154,8,23,12 | off, on, off_pressed, on_pressed | EQ window toggle |
| `btn_playlist` | 178,8,23,12 | off, on, off_pressed, on_pressed | Playlist toggle |

### Volume

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `volume_track` | 240,8,28,6 | normal | Volume bar track |
| `volume_fill` | 240,8,*,6 | normal | Filled portion |
| `volume_thumb` | *,6,8,10 | normal, pressed | Volume thumb |

### Spectrum Window Chrome

The standalone Spectrum Analyzer window uses the modern skin system for its chrome. By default it shares the main window's chrome elements (`window_background`, `window_border`). Skins can optionally provide spectrum-specific images for per-window customization:

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `spectrum_titlebar` | 0,102,275,14 | normal | Spectrum window title bar (falls back to `titlebar` rendering) |
| `spectrum_btn_close` | 261,104,10,10 | normal, pressed | Spectrum window close button (falls back to `btn_close` rendering) |

### Playlist Window Chrome

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `playlist_titlebar` | 0,102,275,14 | normal | Playlist window title bar (falls back to `titlebar` rendering) |
| `playlist_btn_close` | 261,104,10,10 | normal, pressed | Playlist close button (falls back to `btn_close`) |
| `playlist_btn_shade` | 249,104,10,10 | normal, pressed | Playlist shade button (falls back to `btn_shade`) |

The modern playlist does not have bottom bar buttons -- all playlist operations (add, remove, sort, etc.) are available via the right-click context menu and keyboard shortcuts. The currently playing track is rendered in `accent` color (magenta in NeonWave).

### EQ Window Chrome

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `eq_titlebar` | 0,102,275,14 | normal | EQ window title bar (falls back to `titlebar` rendering) |
| `eq_btn_close` | 261,104,10,10 | normal, pressed | EQ close button (falls back to `btn_close`) |
| `eq_btn_shade` | 249,104,10,10 | normal, pressed | EQ shade button (falls back to `btn_shade`) |

The modern EQ window renders a 10-band graphic equalizer with preamp, ON/OFF toggle, AUTO toggle (genre-based presets), and PRESETS menu. Sliders use a color-coded fill: green (-12dB) through yellow (0dB) to red (+12dB). The EQ curve graph displays the current band values with the same color mapping and glow effects.

If a skin provides no window-specific images, the renderer falls back to the shared chrome elements, then to programmatic fallback using palette colors.

### ProjectM Window Chrome

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `projectm_titlebar` | 0,102,275,14 | normal | ProjectM window title bar (falls back to `titlebar` rendering) |
| `projectm_btn_close` | 256,104,10,10 | normal, pressed | ProjectM close button (falls back to `btn_close`) |

The modern ProjectM window embeds the same `VisualizationGLView` (OpenGL) used by the classic version. It supports full multi-edge resizing and custom fullscreen mode (borderless windows don't support native macOS fullscreen). All preset navigation, visualization engine selection, audio/beat sensitivity controls, and performance mode options are available via the right-click context menu and keyboard shortcuts.

### Library Browser Window Chrome

| Element ID | Default Rect | States | Description |
|-----------|-------------|--------|-------------|
| `library_titlebar` | 0,102,275,14 | normal | Library browser title bar (falls back to `titlebar` rendering) |
| `library_btn_close` | 256,104,10,10 | normal, pressed | Library browser close button (falls back to `btn_close`) |
| `library_btn_shade` | 244,104,10,10 | normal, pressed | Library browser shade button (falls back to `btn_shade`) |

The modern library browser provides multi-source browsing (Local Files, Plex, Subsonic/Navidrome, Internet Radio) with multiple browse modes (Artists, Albums, Tracks, Playlists, Movies, Shows, Search, Radio). Tabs and selections use the modern boxed toggle style with `accent` color when active and `textDim` color when inactive. The window supports multi-edge resizing (all four edges and corners).

**Configurable columns:** The library browser displays metadata in resizable, toggleable columns. Users can drag column borders to resize, right-click the header to show/hide columns, and sort by clicking headers. Column widths, visibility, and sort preferences persist in UserDefaults (`BrowserColumnWidths`, `BrowserVisibleTrackColumns`, `BrowserVisibleAlbumColumns`, `BrowserVisibleArtistColumns`, `BrowserColumnSortId`, `BrowserColumnSortAscending`). Available track columns include: #, Title, Artist, Album, Album Artist, Year, Genre, Time, Bitrate, Sample Rate, Channels, Size, Rating, Plays, Disc, Date Added, Last Played, Path. The `currentVisibleColumns()` method returns the filtered/ordered column set for rendering and hit testing. The resize threshold scales with `sizeMultiplier` for Double Size mode compatibility.

## Multi-Window Support

The modern skin system renders multiple windows:

- **Main Window** -- transport controls, time display, marquee, mini spectrum
- **Playlist Window** -- track list with selection, scrolling, marquee, accent-colored playing track
- **EQ Window** -- 10-band graphic equalizer with preamp, Auto EQ, presets, curve graph
- **Spectrum Analyzer Window** -- standalone visualization with skin chrome
- **ProjectM Window** -- ProjectM visualization with skin chrome, presets, fullscreen
- **Library Browser Window** -- multi-source browser (Local/Plex/Subsonic/Radio) with hierarchy, columns, artwork, visualizer

All windows share the same `window_background`, `window_border`, palette colors, glow, grid, and font settings from the active skin. To customize individual windows differently, prefix element IDs with the window name (e.g., `spectrum_titlebar` vs `titlebar`).

### Seamless Docked Borders

When windows are snapped/docked together, the shared edges normally show a double-thick border (each window's border drawn side by side). The `seamlessDocking` property in the `window` config controls how aggressively these shared-edge borders are suppressed:

| Value | Effect |
|-------|--------|
| `0.0` (default) | Full double borders -- current traditional behavior |
| `0.5` | Shared-edge borders faded to 50% -- subtle seam still visible |
| `0.8` | Mostly hidden -- faint hint of separation |
| `1.0` | Fully hidden -- docked windows appear as one seamless unit |

```json
"window": {
    "borderWidth": 1.5,
    "seamlessDocking": 1.0
}
```

The feature detects adjacent windows automatically using the existing docking threshold (20px). When a value less than 1.0 is used, the border on shared edges is faded by overdrawing with the background color at the configured alpha. At 1.0, shared edges are clipped entirely before drawing, which also cleanly removes glow effects on those edges.

**Bundled skin values**: NeonWave uses `1.0` (fully seamless -- suits the glow/neon aesthetic), Skulls uses `0.8` (subtle seam -- suits the lo-fi receiver aesthetic).

## NeonWave Default Skin

The bundled default skin ("NeonWave") uses palette colors and the renderer's programmatic fallback for most UI elements, with sprite-based title text for window title bars. Title character sprites (white 7x11 pixel art) are generated by `scripts/generate_neonwave_title_sprites.swift` and tinted to cyan (#00ffcc) at render time via `titleText.tintColor`.

**Windows covered**: Main window + Playlist window + EQ window + Spectrum Analyzer window + ProjectM window + Library Browser window

**Palette**: `#00ffcc` (cyan primary), `#ff00aa` (magenta accent), `#080810` (background)

**Spectrum colors**: Auto-derived gradient from `palette.accent` (bottom, magenta) to `palette.primary` (top, cyan) via `ModernSkin.spectrumColors()`. These colors are applied to the Metal-based `SpectrumAnalyzerView`.

## Title Text System (Developer Reference)

The title text system supports three rendering tiers with automatic fallback. It allows skin authors to replace the system font title bar text with custom pixel-art character sprites or pre-rendered title images.

### `TitleTextConfig` Schema

Defined in `ModernSkinConfig.swift`. All fields are optional; omitting the entire `titleText` section defaults to font-based rendering.

```swift
struct TitleTextConfig: Codable {
    let mode: TitleTextMode?            // "image" | "font" (default "font")
    let charSpacing: CGFloat?           // Extra spacing between glyphs in base coords (default 1)
    let charHeight: CGFloat?            // Glyph render height in base coords (default 10)
    let alignment: TitleTextAlignment?  // "left" | "center" | "right" (default "center")
    let tintColor: String?              // Hex color to tint grayscale sprites (nil = draw as-is)
    let padLeft: CGFloat?               // Left padding in base coords (default 0)
    let padRight: CGFloat?              // Right padding in base coords (default 0)
    let verticalOffset: CGFloat?        // Vertical nudge in base coords (default 0, positive = up)
    let decorationLeft: String?         // Image key for left decoration sprite (nil = none)
    let decorationRight: String?        // Image key for right decoration sprite (nil = none)
    let decorationSpacing: CGFloat?     // Spacing between decoration and title text (default 3)
}
```

| Field | JSON Key | Type | Default | Notes |
|-------|----------|------|---------|-------|
| mode | `"mode"` | `"image"` or `"font"` | `"font"` | Must be `"image"` to enable sprite/image rendering |
| charSpacing | `"charSpacing"` | CGFloat | 1 | Extra pixels between glyphs. Negative tightens kerning |
| charHeight | `"charHeight"` | CGFloat | 10 | Height in base coords (title bar is 14 units). 10-11 fills well |
| alignment | `"alignment"` | `"left"` / `"center"` / `"right"` | `"center"` | Horizontal alignment within title bar after padding |
| tintColor | `"tintColor"` | Hex string | nil | Colorizes grayscale/white sprites. Overridden per-window via elements |
| padLeft | `"padLeft"` | CGFloat | 0 | Left inset from title bar edge |
| padRight | `"padRight"` | CGFloat | 0 | Right inset from title bar edge |
| verticalOffset | `"verticalOffset"` | CGFloat | 0 | Positive moves text up. For fine alignment with custom title bar images |
| decorationLeft | `"decorationLeft"` | String | nil | Image key for sprite drawn to the left of the title text |
| decorationRight | `"decorationRight"` | String | nil | Image key for sprite drawn to the right of the title text |
| decorationSpacing | `"decorationSpacing"` | CGFloat | 3 | Space between decoration sprites and title text in base coords |

### Three-Tier Fallback in `drawTitleBar`

The `drawTitleBar(in:title:prefix:context:)` method in `ModernSkinRenderer.swift` implements the full rendering pipeline:

```
drawTitleBar(in:title:prefix:context:)
  │
  ├─ 1. Titlebar background image:
  │      {prefix}titlebar image → titlebar image → transparent (no fill)
  │
  ├─ 2. Separator line at bottom of title bar (with optional glow)
  │
  ├─ 3. Title text (if titleText.mode == .image):
  │    ├─ Tier 1: Full pre-rendered title image
  │    │    Look up: {prefix}titlebar_text → titlebar_text
  │    │    If found: center in title bar, apply tint, draw with pixel art interpolation, RETURN
  │    │
  │    ├─ Tier 2: Character sprite compositing
  │    │    Check: skin.hasTitleCharSprites (any title_upper_/title_lower_/title_char_ images?)
  │    │    For each character in title string:
  │    │      - Try skin.titleCharImage(for: char) → returns sprite or nil
  │    │      - If sprite found: measure width from aspect ratio, apply tint
  │    │      - If sprite missing: use system font for just that character (mixed mode)
  │    │    Layout glyphs with charSpacing, alignment, padding, verticalOffset
  │    │    Draw with drawPixelArtImage() (nearest-neighbor, no smoothing)
  │    │    If at least 1 sprite was found: RETURN
  │    │
  │    └─ Tier 3: System font fallback (NSAttributedString + NSFont)
  │
  └─ 4. Title text (if titleText.mode == .font or nil):
       Skip directly to system font rendering
```

### Per-Window Prefixes

Each window passes its prefix to `drawTitleBar` for per-window image resolution. The prefix is used for both titlebar background images and title text images.

| Window | View File | Prefix | Title String |
|--------|-----------|--------|-------------|
| Main | `ModernMainWindowView.swift` | `""` (default) | `"NULLPLAYER"` |
| Playlist | `ModernPlaylistView.swift` | `"playlist_"` | `"NULLPLAYER PLAYLIST"` |
| EQ | `ModernEQView.swift` | `"eq_"` | `"NULLPLAYER EQUALIZER"` |
| Spectrum | `ModernSpectrumView.swift` | `"spectrum_"` | `"NULLPLAYER ANALYZER"` |
| ProjectM | `ModernProjectMView.swift` | `"projectm_"` | `"projectM"` |
| Library | `ModernLibraryBrowserView.swift` | `"library_"` | `"NULLPLAYER LIBRARY"` |

**Consolidation note**: Before this change, `ModernSpectrumView` and `ModernProjectMView` manually drew their per-window titlebar background image before calling `drawTitleBar`. This is now handled inside `drawTitleBar` via the prefix parameter. The manual image draws were removed.

**Shade mode**: `ModernMainWindowView` and `ModernLibraryBrowserView` previously drew shade-mode title text directly with `NSAttributedString`, bypassing the renderer. These now call `renderer.drawTitleBar()` so image-based title text works in shade mode too.

### Character-to-Image-Key Mapping (Filesystem-Safe)

Defined in `ModernSkin.titleCharImageKey(for:)`. Uses `title_upper_`/`title_lower_` prefixes for letters to avoid case collisions on macOS's case-insensitive APFS filesystem.

| Character | Image Key | Filename Example |
|-----------|-----------|-----------------|
| `A`-`Z` | `title_upper_A` ... `title_upper_Z` | `title_upper_N.png` |
| `a`-`z` | `title_lower_a` ... `title_lower_z` | `title_lower_n.png` |
| `0`-`9` | `title_char_0` ... `title_char_9` | `title_char_5.png` |
| Space | `title_char_space` | `title_char_space.png` |
| `-` | `title_char_dash` | `title_char_dash.png` |
| `.` | `title_char_dot` | `title_char_dot.png` |
| `_` | `title_char_underscore` | `title_char_underscore.png` |
| `:` | `title_char_colon` | `title_char_colon.png` |
| `(` / `)` | `title_char_lparen` / `title_char_rparen` | |
| `[` / `]` | `title_char_lbracket` / `title_char_rbracket` | |
| `&` | `title_char_amp` | |
| `'` | `title_char_apos` | |
| `+` | `title_char_plus` | |
| `#` | `title_char_hash` | |
| `/` | `title_char_slash` | |

**Why not `title_char_A` / `title_char_a`?** On macOS APFS (default case-insensitive), `title_char_N.png` and `title_char_n.png` collide -- the filesystem treats them as the same file. The second write overwrites the first, causing half the uppercase letters to go missing. The `title_upper_`/`title_lower_` prefixes solve this.

**Lowercase fallback chain**: `titleCharImage(for: 'p')` tries `title_lower_p` first, then falls back to `title_upper_P`. Skin authors can ship just uppercase sprites.

### Tint Color Resolution

Implemented in `ModernSkinRenderer.resolveTitleTintColor(prefix:)`. Priority chain:

1. Per-window element config: `elements["{prefix}titlebar_text"]["color"]`
2. Shared element config: `elements["titlebar_text"]["color"]` (if prefix is non-empty)
3. Global titleText config: `titleText.tintColor`
4. No tinting (sprites drawn as-is)

Tinted images are cached in `ModernSkin.tintedImageCache` by `"{imageKey}_{colorHex}"`. Cache is automatically invalidated when a new `ModernSkin` instance is created (on skin change). The tinting uses `NSImage.lockFocus()` + `sourceAtop` compositing.

### Pixel Art Rendering

Character sprites and time digit images are drawn with `drawPixelArtImage()` which sets `NSGraphicsContext.current?.imageInterpolation = .none` (nearest-neighbor). This keeps pixel art crisp when scaled up from small source images (e.g. 7x11 pixels) to display size.

The standard `drawImage()` uses default (bilinear) interpolation and is used for non-pixel-art elements.

### Variable-Width Glyph Layout

Each character sprite's actual pixel width is measured at render time:
```swift
let aspect = image.size.width / max(image.size.height, 1)
let glyphWidth = charHeight * aspect
```

This means proportional fonts work naturally. Total string width = sum of individual glyph widths + `(count - 1) * charSpacing * scaleFactor`.

### Title Decorations

Decorative sprites can be drawn on either side of the title text on all windows. Configured via `decorationLeft`, `decorationRight`, and `decorationSpacing` in the `titleText` config.

Decorations work with all three rendering tiers:
- **Tier 1** (full title image): Decorations flank the pre-rendered image, centered as a group.
- **Tier 2** (character sprites): Decorations are included in the total width calculation and drawn before/after the glyph sequence.
- **Tier 3** (system font): Decorations flank the rendered text, centered as a group.

Decoration sprites are:
- Rendered at the same height as the title text (`charHeight` for sprite mode, font height for font mode, 80% title bar height for full image mode)
- Aspect-ratio-preserved (width calculated from the source image aspect ratio)
- Drawn with `drawPixelArtImage()` for crisp nearest-neighbor scaling
- Tinted using the same tint color resolution chain as character sprites

**Example** (Skulls skin -- skull decorations):
```json
"titleText": {
    "mode": "image",
    "charSpacing": 2,
    "charHeight": 10,
    "alignment": "center",
    "decorationLeft": "title_decoration_skull",
    "decorationRight": "title_decoration_skull",
    "decorationSpacing": 3
}
```

The skull sprite (`title_decoration_skull.png`) is an 11x11 pixel art image generated by `scripts/generate_skulls_skin.swift` in the same cream color as the title character sprites.

### Mixed Mode (Per-Character Fallback)

If `mode == .image` and a specific character has no sprite, only that character falls back to the system font. The rest of the string still uses sprites. The `drawTitleTextFromSprites` method returns `false` (triggering full font fallback) only if zero sprites were found for the entire string.

### Key Source Files

| File | Role |
|------|------|
| `ModernSkinConfig.swift` | `TitleTextConfig` struct with all config fields and enums |
| `ModernSkin.swift` | `titleCharImage(for:)` character-to-image lookup with lowercase fallback, `tintedImage()` with caching, `hasTitleCharSprites` quick check, `titleCharImageKey(for:)` filesystem-safe key mapping |
| `ModernSkinRenderer.swift` | `drawTitleBar(in:title:prefix:context:)` three-tier pipeline, `drawTitleTextFromSprites()` variable-width compositor, `drawPixelArtImage()` nearest-neighbor rendering, `resolveTitleTintColor()` tint chain |
| `ModernSkinLoader.swift` | No changes to image loading -- existing `loadImages()` picks up all sprite filenames automatically |

### Reference Skin

The bundled **Skulls** skin (`Resources/Skins/Skulls/`) is the reference implementation for image-based title text. It includes:

- **Bold 7x11 pixel character sprites** (`title_upper_*.png`) with 2px-thick strokes in cream (#d4cfc0)
- **Amber 13x20 7-segment time digits** (`time_digit_*.png`)
- **Beveled 28x24 transport buttons** with normal and pressed states
- **6x6 silver seek/volume thumbs**

Assets are generated by `scripts/generate_skulls_skin.swift` using `NSBitmapImageRep` -- a standalone Swift script that can be run with `swift scripts/generate_skulls_skin.swift`. It serves as a template for generating skin assets programmatically.

## Image Naming Convention

Images go in the `images/` subdirectory with this naming:

```
{element_id}_{state}.png       # State-specific image
{element_id}.png               # Used for all states (if no state-specific image)
{element_id}_{state}@2x.png   # Retina version (optional)
```

**Examples:**
- `btn_play_normal.png` -- Play button, normal state
- `btn_play_pressed.png` -- Play button, pressed state
- `seek_thumb.png` -- Seek thumb, all states
- `time_digit_5.png` -- Digit "5" for time display
- `time_colon.png` -- Colon for time display

The engine automatically checks for `@2x` variants on Retina displays.

## Background Configuration

You can use either a background image or a procedural grid (or both):

### Image Background

```json
"background": {
    "image": "background.png"
}
```

### Grid Background

```json
"background": {
    "grid": {
        "color": "#0a2a2a",
        "spacing": 20,
        "angle": 75,
        "opacity": 0.15,
        "perspective": true
    }
}
```

- `color`: Grid line color
- `spacing`: Distance between lines (points)
- `angle`: Line angle in degrees
- `opacity`: Line opacity (0-1)
- `perspective`: Enable Tron-style vanishing point effect

## Glow/Bloom Configuration

The bloom post-processor adds glow effects to bright elements:

```json
"glow": {
    "enabled": true,
    "radius": 8,
    "intensity": 0.6,
    "threshold": 0.7,
    "color": "#00ffcc",
    "elementBlur": 1.0
}
```

- `enabled`: Master on/off
- `radius`: Blur kernel size (larger = softer glow)
- `intensity`: Bloom brightness multiplier
- `threshold`: Brightness threshold (0-1, pixels above this glow)
- `color`: Override glow color (defaults to palette primary)
- `elementBlur`: Multiplier for per-element glow blur on buttons, text, sliders (default 1.0, set 0 for flat)

## Animation Configuration

Two animation types are supported:

### Sprite Frame Animation

```json
"animations": {
    "status_play": {
        "type": "spriteFrames",
        "frames": ["status_play_0.png", "status_play_1.png", "status_play_2.png"],
        "duration": 1.0,
        "repeatMode": "loop"
    }
}
```

### Parametric Animation

```json
"animations": {
    "seek_fill": {
        "type": "glow",
        "duration": 3.0,
        "minValue": 0.4,
        "maxValue": 1.0
    }
}
```

Types: `pulse`, `glow`, `rotate`, `colorCycle`
Repeat modes: `loop`, `reverse`, `once`

## Font Configuration

All font sizes are **unscaled base values**. The engine multiplies them by the UI scale factor (`window.scale`, default 1.25) automatically. The 9 configurable sizes cover every text context in the player chrome windows. The library browser uses proportional system fonts for readability in dense data views, scaled by `window.scale` but not affected by font name settings.

| Key | Used for | Default |
|-----|----------|---------|
| `titleSize` | Title bar text | 8 |
| `bodySize` | Body text, source/tab labels | 9 |
| `smallSize` | Small labels, toggle buttons | 7 |
| `timeSize` | Time display digits | 20 |
| `infoSize` | Info labels (bitrate, samplerate, BPM) | 6.5 |
| `eqLabelSize` | EQ frequency labels | 7 |
| `eqValueSize` | EQ dB value text | 6 |
| `marqueeSize` | Scrolling title text | 11.7 |
| `playlistSize` | Playlist track list | 8 |

### Using the Bundled Font

The app ships with **Departure Mono** (SIL OFL license). Use it by name:

```json
"fonts": {
    "primaryName": "DepartureMono-Regular",
    "fallbackName": "Menlo"
}
```

### Using a Custom Font

Include a TTF/OTF in `fonts/` within your skin bundle:

```
MySkin/
├── skin.json
├── fonts/
│   └── MyCustomFont.ttf
└── images/
```

Reference by PostScript name:

```json
"fonts": {
    "primaryName": "MyCustomFont"
}
```

## Creating a Minimal Skin

The simplest skin is just a `skin.json` with palette colors:

```json
{
    "meta": { "name": "Minimal", "author": "Me", "version": "1.0" },
    "palette": {
        "primary": "#ff6600",
        "secondary": "#ffaa00",
        "accent": "#ff0066",
        "background": "#1a1a2e",
        "surface": "#16213e",
        "text": "#ff6600",
        "textDim": "#664400"
    },
    "fonts": { "primaryName": "DepartureMono-Regular", "fallbackName": "Menlo" },
    "background": { "grid": { "color": "#332200", "spacing": 15, "angle": 80, "opacity": 0.1, "perspective": false } },
    "glow": { "enabled": true, "radius": 6, "intensity": 0.5, "threshold": 0.6 },
    "window": { "borderWidth": 1, "cornerRadius": 6, "seamlessDocking": 1.0 }
}
```

All elements will render programmatically using the palette colors.

## Packaging for Distribution (`.nps` Bundle)

ZIP your skin directory and rename the extension to `.nps`:

```bash
cd MySkin/
zip -r ../MySkin.nps .
```

Users can place `.nps` files in:
```
~/Library/Application Support/NullPlayer/ModernSkins/
```

Or use folder-based skins for development (unzipped directory in the same location).

## Installation

### User Skins Directory

Place skin folders or `.nps` files at:
```
~/Library/Application Support/NullPlayer/ModernSkins/
```

### Selecting a Skin

Right-click the player → **Modern UI** → **Select Skin** → choose from the list.

Skin changes take effect immediately. Switching between Classic and Modern mode requires a restart -- NullPlayer will prompt you to restart automatically when you switch modes.

## Double Size (2x) Mode

Toggle via the **2X** button on the main window (first toggle button in the row) or right-click context menu → **Double Size** (modern UI only). This doubles all window dimensions and rendering scale.

### How It Works

`ModernSkinElements.scaleFactor` is a computed property: `baseScaleFactor * sizeMultiplier`.

- `baseScaleFactor` -- set by skin.json `window.scale` (default 1.25)
- `sizeMultiplier` -- set by double size mode (1.0 normal, 2.0 double)

When double size is toggled:
1. `WindowManager` sets `ModernSkinElements.sizeMultiplier` to 2.0 (or 1.0)
2. All computed sizes in `ModernSkinElements` automatically update (window sizes, title bar heights, border widths, shade heights, etc.)
3. `WindowManager.applyDoubleSize()` resizes all windows to the new sizes
4. The `doubleSizeDidChange` notification triggers views to recreate their renderers with the new `scaleFactor`
5. All rendering scales correctly because the renderer receives the updated `scaleFactor`

### Interaction with Hide Title Bars

Both features compose naturally because they both derive from `scaleFactor`. In double size mode, title bar heights also double. When title bars are hidden in double size mode, the doubled title bar height is correctly subtracted from the doubled window size.

### Side Windows (Library Browser, ProjectM)

Side windows (Library Browser, ProjectM) scale their width by `sizeMultiplier` and match the vertical stack height. Their internal layout constants (`itemHeight`, `tabBarHeight`, `serverBarHeight`, etc.) and fonts (`scaledSystemFont`, `sideWindowFont`) also scale by `sizeMultiplier` so the content is proportionally correct in 2x mode. Hardcoded pixel padding values in drawing methods must be multiplied by `ModernSkinElements.sizeMultiplier` to maintain proportions.

### Interaction with Skin Scale

A skin with `"window": { "scale": 1.5 }` sets `baseScaleFactor` to 1.5. In double size mode, the effective `scaleFactor` becomes 3.0 (1.5 x 2.0). All rendering and window sizing adjusts accordingly.

## Adding a Modern Sub-Window (Developer Guide)

This section documents the repeatable pattern for creating modern-skinned versions of sub-windows. Future agents creating Modern EQ, Modern Playlist, Modern ProjectM, etc. should follow this recipe.

**Reference implementation**: `ModernSpectrumWindowController` + `ModernSpectrumView` (simplest sub-window -- just chrome + embedded content).

### Layer-by-Layer Checklist

1. **`ModernSkinElements.swift`** -- Add window layout constants (size, shade height, title bar height, border width) and optional per-window element IDs (e.g., `{window}_titlebar`, `{window}_btn_close`). Add new elements to `allElements` array.

2. **`ModernSkinRenderer.swift`** -- Add any new element IDs to the fallback switch in `drawWindowControlButton` (e.g., `"spectrum_btn_close"` alongside `"btn_close"`).

3. **Create `App/{Window}WindowProviding.swift`** -- Protocol matching `MainWindowProviding` / `SpectrumWindowProviding` pattern with `window`, `showWindow`, `skinDidChange`, etc.

4. **Add conformance to existing classic controller** -- The classic controller already has the required methods; just add the protocol conformance declaration.

5. **Create `Windows/Modern{Window}/Modern{Window}WindowController.swift`** -- Borderless window, shade mode, fullscreen, `NSWindowDelegate` for docking, conforms to the protocol. Zero classic skin imports.

6. **Create `Windows/Modern{Window}/Modern{Window}View.swift`** -- Compose `ModernSkinRenderer` methods for chrome (`drawWindowBackground`, `drawWindowBorder`, `drawTitleBar`, `drawWindowControlButton`), skin change observation via `ModernSkinDidChange` notification. Zero classic skin imports. Note: `GridBackgroundLayer` is only used in the main window; sub-windows use solid backgrounds.

7. **Update `WindowManager.swift`** -- Change the controller property type to the protocol. Conditionally create modern or classic controller in the show method based on `isModernUIEnabled`.

8. **Update NeonWave `skin.json`** -- Add per-window element entries if needed (e.g., `"spectrum_titlebar": { "color": "#0c1018" }`).

9. **Update docs** -- `MODERN_SKIN_GUIDE.md` (element catalog), `CLAUDE.md` (key files, architecture), relevant `AGENT_DOCS/` files.

### Key Rules

- **Zero classic imports**: Files in `ModernSkin/` and `Windows/Modern{Window}/` must NEVER import or reference anything from `Skin/` or `Windows/{ClassicWindow}/`
- **Skin changes**: Observe `ModernSkinEngine.skinDidChangeNotification` to re-create renderer
- **Double size changes**: Observe `.doubleSizeDidChange` notification and call `skinDidChange()` to recreate the renderer with the updated scale factor
- **Scale factor**: Use `ModernSkinElements.scaleFactor` for all geometry. This is a computed property: `baseScaleFactor * sizeMultiplier`. The `baseScaleFactor` is set by skin.json `window.scale` (default 1.25); the `sizeMultiplier` is set by double size mode (1.0 or 2.0). Do NOT cache `scaleFactor` in a `let` -- use a computed `var` or reference `ModernSkinElements.scaleFactor` directly
- **Coordinates**: Standard macOS bottom-left origin (no flipping needed, unlike classic skin system)

### Element Image Fallback Chain

When the renderer looks up an image for a per-window element:

1. `{window}_{element}_{state}.png` (e.g., `spectrum_btn_close_pressed.png`)
2. `{window}_{element}.png` (e.g., `spectrum_btn_close.png`)
3. Programmatic fallback using palette colors (e.g., X icon drawn with `textDimColor`)
