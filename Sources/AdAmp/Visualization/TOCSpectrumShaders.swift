import Foundation

/// GLSL shaders for TOC Spectrum visualization
///
/// These shaders render vertical spectrum bars with height-based color gradients.
/// Compatible with OpenGL 3.2 Core Profile (GLSL 150).
enum TOCSpectrumShaders {

    // MARK: - Vertex Shader

    /// Vertex shader for spectrum bars
    ///
    /// Transforms bar vertices from normalized device coordinates and passes
    /// height and bar index to the fragment shader for coloring.
    static let vertexShader = """
    #version 150 core

    in vec3 position;       // Vertex position (x, y, height multiplier)
    in float barIndex;      // Which bar this vertex belongs to

    out float vHeight;      // Height for fragment shader
    out float vBarIndex;    // Bar index for fragment shader

    uniform mat4 projection;
    uniform float maxHeight;

    void main() {
        // Scale y coordinate by height
        vec3 pos = position;
        pos.y *= position.z;  // z component contains height multiplier

        gl_Position = projection * vec4(pos.x, pos.y, 0.0, 1.0);
        vHeight = pos.y;
        vBarIndex = barIndex;
    }
    """

    // MARK: - Fragment Shader

    /// Fragment shader for spectrum bars
    ///
    /// Applies height-based color gradients based on the selected color scheme.
    /// Supports Classic (green), Modern (blue-purple), and Ozone (blue-cyan) schemes.
    static let fragmentShader = """
    #version 150 core

    in float vHeight;
    in float vBarIndex;

    out vec4 fragColor;

    uniform int colorScheme;    // 0=classic, 1=modern, 2=ozone
    uniform float maxHeight;
    uniform int barCount;

    // Classic green gradient (traditional analyzer)
    vec3 getClassicColor(float normalizedHeight) {
        vec3 darkGreen = vec3(0.0, 0.2, 0.0);
        vec3 brightGreen = vec3(0.0, 1.0, 0.2);
        return mix(darkGreen, brightGreen, normalizedHeight);
    }

    // Modern blue-purple gradient
    vec3 getModernColor(float normalizedHeight) {
        vec3 darkPurple = vec3(0.1, 0.0, 0.3);
        vec3 brightBlue = vec3(0.3, 0.5, 1.0);
        return mix(darkPurple, brightBlue, normalizedHeight);
    }

    // Ozone blue-cyan gradient (iZotope-inspired)
    vec3 getOzoneColor(float normalizedHeight) {
        vec3 darkBlue = vec3(0.0, 0.2, 0.4);
        vec3 brightCyan = vec3(0.2, 0.8, 1.0);
        return mix(darkBlue, brightCyan, normalizedHeight);
    }

    void main() {
        float normalizedHeight = clamp(vHeight / maxHeight, 0.0, 1.0);

        vec3 baseColor;
        if (colorScheme == 0) {
            baseColor = getClassicColor(normalizedHeight);
        } else if (colorScheme == 1) {
            baseColor = getModernColor(normalizedHeight);
        } else {
            baseColor = getOzoneColor(normalizedHeight);
        }

        // Add slight brightness boost at peaks for visual pop
        float brightness = 1.0 + normalizedHeight * 0.3;
        vec3 finalColor = baseColor * brightness;

        fragColor = vec4(finalColor, 1.0);
    }
    """

    // MARK: - Reflection Shaders (Phase 3)

    /// Vertex shader for reflection rendering
    ///
    /// Flips and fades the spectrum bars below the main visualization.
    static let reflectionVertexShader = """
    #version 150 core

    in vec3 position;
    in float barIndex;

    out float vHeight;
    out float vBarIndex;
    out float vReflectionFade;

    uniform mat4 projection;
    uniform float maxHeight;

    void main() {
        // Flip vertically and scale by height
        vec3 pos = position;
        pos.y *= position.z;  // Apply height
        pos.y = -pos.y;       // Flip for reflection

        gl_Position = projection * vec4(pos.x, pos.y, 0.0, 1.0);
        vHeight = abs(pos.y);
        vBarIndex = barIndex;

        // Fade based on distance from reflection origin
        vReflectionFade = 1.0 - clamp(abs(pos.y) / maxHeight, 0.0, 1.0);
    }
    """

    /// Fragment shader for reflection rendering
    ///
    /// Same color logic as main shader but with fade applied.
    static let reflectionFragmentShader = """
    #version 150 core

    in float vHeight;
    in float vBarIndex;
    in float vReflectionFade;

    out vec4 fragColor;

    uniform int colorScheme;
    uniform float maxHeight;
    uniform int barCount;

    vec3 getClassicColor(float normalizedHeight) {
        vec3 darkGreen = vec3(0.0, 0.2, 0.0);
        vec3 brightGreen = vec3(0.0, 1.0, 0.2);
        return mix(darkGreen, brightGreen, normalizedHeight);
    }

    vec3 getModernColor(float normalizedHeight) {
        vec3 darkPurple = vec3(0.1, 0.0, 0.3);
        vec3 brightBlue = vec3(0.3, 0.5, 1.0);
        return mix(darkPurple, brightBlue, normalizedHeight);
    }

    vec3 getOzoneColor(float normalizedHeight) {
        vec3 darkBlue = vec3(0.0, 0.2, 0.4);
        vec3 brightCyan = vec3(0.2, 0.8, 1.0);
        return mix(darkBlue, brightCyan, normalizedHeight);
    }

    void main() {
        float normalizedHeight = clamp(vHeight / maxHeight, 0.0, 1.0);

        vec3 baseColor;
        if (colorScheme == 0) {
            baseColor = getClassicColor(normalizedHeight);
        } else if (colorScheme == 1) {
            baseColor = getModernColor(normalizedHeight);
        } else {
            baseColor = getOzoneColor(normalizedHeight);
        }

        float brightness = 1.0 + normalizedHeight * 0.3;
        vec3 finalColor = baseColor * brightness;

        // Apply reflection fade (50% opacity at base, fading to 0)
        float alpha = vReflectionFade * 0.5;
        fragColor = vec4(finalColor, alpha);
    }
    """
}
