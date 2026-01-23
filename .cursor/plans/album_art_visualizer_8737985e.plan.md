---
name: Album Art Visualizer
overview: Add audio-reactive image manipulation to album art using Metal shaders, allowing the artwork itself to warp, distort, glow, and transform in sync with the music.
todos:
  - id: audio-uniforms
    content: Create AudioReactiveUniforms struct to package audio data for shaders (bass/mid/treble bands, beat flag, time)
    status: completed
  - id: shader-manager
    content: Create ShaderManager to compile and manage Metal shader pipeline
    status: completed
  - id: core-shaders
    content: "Write core Metal shaders: displacement, color effects, glitch effects, composite"
    status: completed
  - id: visualizer-view
    content: Create ArtworkVisualizerView (MTKView subclass) for rendering
    status: completed
  - id: window-controller
    content: Create ArtVisualizerWindowController for the visualization window
    status: completed
  - id: window-manager
    content: Add art visualizer window management to WindowManager
    status: completed
  - id: browser-integration
    content: Add VIS button/toggle to PlexBrowserView art-only mode
    status: completed
  - id: effect-presets
    content: Implement 5-6 effect presets with different shader combinations
    status: completed
  - id: context-menu
    content: Add visualizer options to context menu (effect selection, intensity)
    status: completed
  - id: docs-update
    content: Update documentation with new visualization feature
    status: completed
---

# Album Art Audio-Reactive Visualization

## Overview

Transform the album art display into a living, breathing visualization where the artwork itself warps, distorts, and morphs in response to the music. This uses Metal shaders to manipulate the actual image pixels based on audio frequency data.

## Recommended Approach: Metal Shaders + ISF Library

After researching the options, the best approach combines:

1. **Custom Metal shaders** for core effects (most control, best performance)
2. **ISF (Interactive Shader Format)** compatibility for access to 1000+ community effects
3. **Audio analysis pipeline** using the existing `AudioEngine` FFT/spectrum data

## Available Effect Types

### Displacement Effects (Bass-reactive)

- Wave displacement - image ripples outward on bass hits
- Radial pulse - concentric waves from center on beats
- Noise displacement - Perlin noise warps image, intensity from bass

### Color Effects (Mid-reactive)

- Chromatic aberration - RGB channels separate on louder parts
- Color cycling/palette shifts - hue rotation based on frequency
- Saturation/brightness pulses

### Glitch Effects (Beat-triggered)

- RGB channel slicing - offset color channels
- Block displacement - scramble rectangular regions
- Scanline interference
- Datamosh-style frame buffer corruption

### Advanced Effects

- Kaleidoscope/mirror - symmetry multiplies
- Reaction-diffusion - organic evolving patterns overlay
- Fluid simulation - smoke/liquid flows react to audio
- Feedback trails - motion blur with decay

## Architecture

```
Audio Source
     |
     v
AudioEngine (existing) ---> FFT/Spectrum Data
     |                            |
     v                            v
PCM Waveform              [bass, mid, treble bands]
     |                            |
     +------------+---------------+
                  |
                  v
        ArtworkVisualizerView (new)
                  |
      +-----------+-----------+
      |           |           |
      v           v           v
  MTKView    ShaderManager   EffectChain
      |           |           |
      v           v           v
   Render    Load/Compile   Chain effects:
   Pipeline    Shaders      Displacement ->
                            Color ->
                            Glitch ->
                            Output
```

## Key Files to Create

### Core Components

- `Sources/AdAmp/Visualization/ArtworkVisualizerView.swift`
  - MTKView subclass for Metal rendering
  - Receives album art NSImage + audio data
  - Manages shader pipeline

- `Sources/AdAmp/Visualization/ShaderManager.swift`
  - Compiles and manages Metal shaders
  - Hot-reload support for development
  - ISF shader loading (optional future)

- `Sources/AdAmp/Visualization/AudioReactiveUniforms.swift`
  - Struct for passing audio data to shaders
  - Bass, mid, treble bands
  - Beat detection flag
  - Time/phase values

### Metal Shaders

- `Sources/AdAmp/Resources/Shaders/Displacement.metal`
  - Wave, radial, noise displacement effects

- `Sources/AdAmp/Resources/Shaders/ColorEffects.metal`
  - Chromatic aberration, hue shift, saturation

- `Sources/AdAmp/Resources/Shaders/GlitchEffects.metal`
  - RGB split, block offset, scanlines

- `Sources/AdAmp/Resources/Shaders/Composite.metal`
  - Final compositing shader

### Window Integration

- `Sources/AdAmp/Windows/ArtVisualizer/ArtVisualizerWindowController.swift`
  - Dedicated window for visualized artwork
  - Can go fullscreen
  - Effect preset selection

## Integration Points

### Modify Existing Files

- `PlexBrowserView.swift` - Add button to launch visualizer from ART mode
- `WindowManager.swift` - Add art visualizer window management
- `ContextMenuBuilder.swift` - Add visualizer menu options
- `AudioEngine.swift` - Expose frequency band data (may already exist)

## Libraries to Consider Adding

| Library | Purpose | SwiftPM |

|---------|---------|---------|

| None required | Metal is built-in | - |

| Optional: ISFMSLKit | 1000+ ISF shader effects | Would need wrapping |

| Optional: GPUImage3 | Additional filter library | `github.com/BradLarson/GPUImage3` |

## Example Shader (Displacement + Chromatic)

```metal
fragment float4 audioReactive(
    RasterizerData in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    texture2d<float> artwork [[texture(0)]]
) {
    float2 uv = in.texCoord;
    
    // Bass-driven displacement
    float displacement = sin(uv.y * 20.0 + u.time * 3.0) * u.bass * 0.02;
    uv.x += displacement;
    
    // Chromatic aberration on loud parts
    float aberration = u.loudness * 0.01;
    float r = artwork.sample(sampler, uv + float2(aberration, 0)).r;
    float g = artwork.sample(sampler, uv).g;
    float b = artwork.sample(sampler, uv - float2(aberration, 0)).b;
    
    return float4(r, g, b, 1.0);
}
```

## User Experience

1. User clicks "ART" button in browser to show album art
2. New "VIS" button appears (or toggle on ART button)
3. Clicking opens the Art Visualizer window showing album art with effects
4. Effects react to currently playing music in real-time
5. Context menu allows selecting effect presets or adjusting intensity
6. Can go fullscreen for screensaver-like experience

## Effect Presets (Initial Set)

1. **Subtle Pulse** - Gentle brightness/scale pulse on beats
2. **Liquid Dreams** - Flowing displacement, color shifts
3. **Glitch City** - Heavy RGB split, block glitches on beats
4. **Cosmic Mirror** - Kaleidoscope + chromatic aberration
5. **Deep Bass** - Intense displacement on low frequencies
6. **Clean** - No effects, just the artwork