import Foundation
import OpenGL.GL3
import Accelerate

/// TOC Spectrum visualization renderer
///
/// Renders a classic spectrum analyzer visualization with vertical bars
/// that respond to audio frequency data. Inspired by early 2000s analyzers
/// and the iZotope Ozone aesthetic.
class TOCSpectrumRenderer: VisualizationEngine {

    // MARK: - VisualizationEngine Protocol

    private(set) var isAvailable: Bool = false

    var displayName: String {
        return "TOC Spectrum"
    }

    // MARK: - Types

    /// Color scheme for the visualization
    enum ColorScheme: String, CaseIterable {
        case classic = "Classic"
        case modern = "Modern"
        case ozone = "Ozone"

        var glValue: Int32 {
            switch self {
            case .classic: return 0
            case .modern: return 1
            case .ozone: return 2
            }
        }
    }

    /// Scale mode for frequency mapping
    enum ScaleMode: String {
        case linear = "Linear"
        case logarithmic = "Logarithmic"
    }

    // MARK: - Properties

    private var viewportWidth: Int = 0
    private var viewportHeight: Int = 0

    // Spectrum data
    private var spectrumBands: [Float] = []
    private var smoothedSpectrum: [Float] = []
    private let dataLock = NSLock()

    // OpenGL resources
    private var shaderProgram: GLuint = 0
    private var reflectionShaderProgram: GLuint = 0
    private var vao: GLuint = 0
    private var vbo: GLuint = 0
    private var ebo: GLuint = 0

    // Shader uniforms
    private var projectionUniform: GLint = -1
    private var maxHeightUniform: GLint = -1
    private var colorSchemeUniform: GLint = -1
    private var barCountUniform: GLint = -1

    // Reflection shader uniforms
    private var reflectionProjectionUniform: GLint = -1
    private var reflectionMaxHeightUniform: GLint = -1
    private var reflectionColorSchemeUniform: GLint = -1
    private var reflectionBarCountUniform: GLint = -1

    // Settings (loaded from UserDefaults)
    private var colorScheme: ColorScheme = .classic
    private var barCount: Int = 128
    private var scaleMode: ScaleMode = .logarithmic
    private var smoothingFactor: Float = 0.75
    private var reflectionEnabled: Bool = false
    private var wireframeMode: Bool = false

    // MARK: - Initialization

    required init(width: Int, height: Int) {
        viewportWidth = width
        viewportHeight = height

        // Load settings from UserDefaults
        loadSettings()

        // Initialize spectrum arrays
        spectrumBands = Array(repeating: 0, count: barCount)
        smoothedSpectrum = Array(repeating: 0, count: barCount)

        // Set up OpenGL resources
        setupOpenGL()

        NSLog("TOCSpectrumRenderer: Initialized with %dx%d viewport, %d bars", width, height, barCount)
    }

    deinit {
        cleanup()
    }

    // MARK: - Settings

    private func loadSettings() {
        let defaults = UserDefaults.standard

        if let schemeStr = defaults.string(forKey: "tocSpectrumColorScheme"),
           let scheme = ColorScheme(rawValue: schemeStr) {
            colorScheme = scheme
        }

        let savedBarCount = defaults.integer(forKey: "tocSpectrumBarCount")
        if savedBarCount > 0 {
            barCount = savedBarCount
        }

        if let modeStr = defaults.string(forKey: "tocSpectrumScaleMode"),
           let mode = ScaleMode(rawValue: modeStr) {
            scaleMode = mode
        }

        if defaults.object(forKey: "tocSpectrumSmoothing") != nil {
            smoothingFactor = defaults.float(forKey: "tocSpectrumSmoothing")
        }

        reflectionEnabled = defaults.bool(forKey: "tocSpectrumReflection")
        wireframeMode = defaults.bool(forKey: "tocSpectrumWireframe")
    }

    // MARK: - OpenGL Setup

    private func setupOpenGL() {
        // Compile shaders
        guard compileShaders() else {
            NSLog("TOCSpectrumRenderer: Shader compilation failed")
            isAvailable = false
            return
        }

        // Create vertex array object
        glGenVertexArrays(1, &vao)
        glBindVertexArray(vao)

        // Create vertex buffer
        glGenBuffers(1, &vbo)
        glGenBuffers(1, &ebo)

        // Set up vertex attributes
        setupVertexAttributes()

        glBindVertexArray(0)

        isAvailable = true
        NSLog("TOCSpectrumRenderer: OpenGL setup complete")
    }

    private func compileShaders() -> Bool {
        // Compile main shader program
        shaderProgram = createShaderProgram(
            vertexSource: TOCSpectrumShaders.vertexShader,
            fragmentSource: TOCSpectrumShaders.fragmentShader
        )

        guard shaderProgram != 0 else {
            NSLog("TOCSpectrumRenderer: Failed to create main shader program")
            return false
        }

        // Get uniform locations for main shader
        glUseProgram(shaderProgram)
        projectionUniform = glGetUniformLocation(shaderProgram, "projection")
        maxHeightUniform = glGetUniformLocation(shaderProgram, "maxHeight")
        colorSchemeUniform = glGetUniformLocation(shaderProgram, "colorScheme")
        barCountUniform = glGetUniformLocation(shaderProgram, "barCount")

        // Compile reflection shader program
        reflectionShaderProgram = createShaderProgram(
            vertexSource: TOCSpectrumShaders.reflectionVertexShader,
            fragmentSource: TOCSpectrumShaders.reflectionFragmentShader
        )

        guard reflectionShaderProgram != 0 else {
            NSLog("TOCSpectrumRenderer: Failed to create reflection shader program")
            // Non-fatal - reflection is optional
        }

        // Get uniform locations for reflection shader
        if reflectionShaderProgram != 0 {
            glUseProgram(reflectionShaderProgram)
            reflectionProjectionUniform = glGetUniformLocation(reflectionShaderProgram, "projection")
            reflectionMaxHeightUniform = glGetUniformLocation(reflectionShaderProgram, "maxHeight")
            reflectionColorSchemeUniform = glGetUniformLocation(reflectionShaderProgram, "colorScheme")
            reflectionBarCountUniform = glGetUniformLocation(reflectionShaderProgram, "barCount")
        }

        glUseProgram(0)
        return true
    }

    private func createShaderProgram(vertexSource: String, fragmentSource: String) -> GLuint {
        // Compile vertex shader
        let vertexShader = compileShader(source: vertexSource, type: GLenum(GL_VERTEX_SHADER))
        guard vertexShader != 0 else { return 0 }

        // Compile fragment shader
        let fragmentShader = compileShader(source: fragmentSource, type: GLenum(GL_FRAGMENT_SHADER))
        guard fragmentShader != 0 else {
            glDeleteShader(vertexShader)
            return 0
        }

        // Link program
        let program = glCreateProgram()
        glAttachShader(program, vertexShader)
        glAttachShader(program, fragmentShader)
        glLinkProgram(program)

        // Check link status
        var linkStatus: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &linkStatus)
        if linkStatus == GL_FALSE {
            var logLength: GLint = 0
            glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            if logLength > 0 {
                var log = [GLchar](repeating: 0, count: Int(logLength))
                glGetProgramInfoLog(program, logLength, nil, &log)
                NSLog("TOCSpectrumRenderer: Shader link error: %s", String(cString: log))
            }
            glDeleteProgram(program)
            glDeleteShader(vertexShader)
            glDeleteShader(fragmentShader)
            return 0
        }

        // Clean up shaders (no longer needed after linking)
        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)

        return program
    }

    private func compileShader(source: String, type: GLenum) -> GLuint {
        let shader = glCreateShader(type)
        var sourcePtr: UnsafePointer<GLchar>? = (source as NSString).utf8String
        glShaderSource(shader, 1, &sourcePtr, nil)
        glCompileShader(shader)

        // Check compile status
        var compileStatus: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compileStatus)
        if compileStatus == GL_FALSE {
            var logLength: GLint = 0
            glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            if logLength > 0 {
                var log = [GLchar](repeating: 0, count: Int(logLength))
                glGetShaderInfoLog(shader, logLength, nil, &log)
                let typeName = type == GLenum(GL_VERTEX_SHADER) ? "vertex" : "fragment"
                NSLog("TOCSpectrumRenderer: %s shader compile error: %s", typeName, String(cString: log))
            }
            glDeleteShader(shader)
            return 0
        }

        return shader
    }

    private func setupVertexAttributes() {
        // We'll update this dynamically in renderFrame
        // For now, just bind the buffers
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), ebo)

        // Set up vertex attribute pointers
        // Position (vec3: x, y, height_multiplier)
        let positionAttrib = GLuint(glGetAttribLocation(shaderProgram, "position"))
        glEnableVertexAttribArray(positionAttrib)
        glVertexAttribPointer(positionAttrib, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE),
                             GLsizei(4 * MemoryLayout<GLfloat>.size), nil)

        // Bar index (float)
        let barIndexAttrib = GLuint(glGetAttribLocation(shaderProgram, "barIndex"))
        glEnableVertexAttribArray(barIndexAttrib)
        glVertexAttribPointer(barIndexAttrib, 1, GLenum(GL_FLOAT), GLboolean(GL_FALSE),
                             GLsizei(4 * MemoryLayout<GLfloat>.size),
                             UnsafeRawPointer(bitPattern: 3 * MemoryLayout<GLfloat>.size))
    }

    // MARK: - VisualizationEngine Protocol Methods

    func setViewportSize(width: Int, height: Int) {
        guard width != viewportWidth || height != viewportHeight else { return }
        viewportWidth = width
        viewportHeight = height
    }

    func addPCMMono(_ samples: [Float]) {
        // We don't use PCM directly - we'll get spectrum data from the data source
        // But we need to implement this for protocol conformance
    }

    func renderFrame() {
        guard isAvailable else { return }

        // Set viewport
        glViewport(0, 0, GLsizei(viewportWidth), GLsizei(viewportHeight))

        // Clear background to black
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        // Get spectrum data snapshot
        dataLock.lock()
        let spectrum = smoothedSpectrum
        dataLock.unlock()

        // Skip rendering if no data
        guard !spectrum.isEmpty else { return }

        // Set up projection matrix (orthographic)
        let projection = createOrthographicMatrix(
            left: -1.0, right: 1.0,
            bottom: -1.0, top: 1.0,
            near: -1.0, far: 1.0
        )

        // Render main spectrum
        renderSpectrum(spectrum: spectrum, projection: projection, isReflection: false)

        // Render reflection if enabled
        if reflectionEnabled && reflectionShaderProgram != 0 {
            renderSpectrum(spectrum: spectrum, projection: projection, isReflection: true)
        }
    }

    private func renderSpectrum(spectrum: [Float], projection: [GLfloat], isReflection: Bool) {
        let program = isReflection ? reflectionShaderProgram : shaderProgram
        guard program != 0 else { return }

        glUseProgram(program)

        // Set uniforms
        let projUniform = isReflection ? reflectionProjectionUniform : projectionUniform
        let maxHUniform = isReflection ? reflectionMaxHeightUniform : maxHeightUniform
        let colorUniform = isReflection ? reflectionColorSchemeUniform : colorSchemeUniform
        let barCUniform = isReflection ? reflectionBarCountUniform : barCountUniform

        glUniformMatrix4fv(projUniform, 1, GLboolean(GL_FALSE), projection)
        glUniform1f(maxHUniform, 0.9)  // Max height in normalized coords
        glUniform1i(colorUniform, colorScheme.glValue)
        glUniform1i(barCUniform, GLint(barCount))

        // Generate geometry for bars
        var vertices: [GLfloat] = []
        var indices: [GLuint] = []

        let barWidth = 2.0 / Float(barCount)  // Total width is 2.0 in NDC
        let barGap = barWidth * 0.1  // 10% gap between bars

        for i in 0..<barCount {
            let height = spectrum[i]
            let x = -1.0 + Float(i) * barWidth
            let barW = barWidth - barGap

            // Create quad for this bar (2 triangles)
            let baseIndex = GLuint(vertices.count / 4)

            // Bottom-left
            vertices.append(contentsOf: [x, 0.0, height, Float(i)])
            // Bottom-right
            vertices.append(contentsOf: [x + barW, 0.0, height, Float(i)])
            // Top-right
            vertices.append(contentsOf: [x + barW, 0.9, height, Float(i)])
            // Top-left
            vertices.append(contentsOf: [x, 0.9, height, Float(i)])

            // Indices for two triangles
            indices.append(contentsOf: [
                baseIndex, baseIndex + 1, baseIndex + 2,
                baseIndex, baseIndex + 2, baseIndex + 3
            ])
        }

        // Upload geometry
        glBindVertexArray(vao)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        glBufferData(GLenum(GL_ARRAY_BUFFER),
                    vertices.count * MemoryLayout<GLfloat>.size,
                    vertices, GLenum(GL_DYNAMIC_DRAW))

        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), ebo)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
                    indices.count * MemoryLayout<GLuint>.size,
                    indices, GLenum(GL_DYNAMIC_DRAW))

        // Draw
        if wireframeMode {
            glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(GL_LINE))
        }

        if isReflection {
            glEnable(GLenum(GL_BLEND))
            glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        }

        glDrawElements(GLenum(GL_TRIANGLES), GLsizei(indices.count), GLenum(GL_UNSIGNED_INT), nil)

        if isReflection {
            glDisable(GLenum(GL_BLEND))
        }

        if wireframeMode {
            glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(GL_FILL))
        }

        glBindVertexArray(0)
        glUseProgram(0)
    }

    private func createOrthographicMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> [GLfloat] {
        var matrix = [GLfloat](repeating: 0, count: 16)

        matrix[0] = 2.0 / (right - left)
        matrix[5] = 2.0 / (top - bottom)
        matrix[10] = -2.0 / (far - near)
        matrix[12] = -(right + left) / (right - left)
        matrix[13] = -(top + bottom) / (top - bottom)
        matrix[14] = -(far + near) / (far - near)
        matrix[15] = 1.0

        return matrix
    }

    // MARK: - Spectrum Processing

    /// Update spectrum data from external source (e.g., AudioEngine)
    /// - Parameter input: Array of spectrum values (typically 75 bands from AudioEngine)
    func updateSpectrum(_ input: [Float]) {
        guard !input.isEmpty else { return }

        dataLock.lock()
        defer { dataLock.unlock() }

        // Resample to target bar count
        let resampled = resampleSpectrum(input, toCount: barCount)

        // Smooth with previous frame (fast attack, slow decay)
        for i in 0..<barCount {
            let newValue = resampled[i]
            let oldValue = smoothedSpectrum[i]

            if newValue > oldValue {
                // Fast attack
                smoothedSpectrum[i] = newValue
            } else {
                // Slow decay
                smoothedSpectrum[i] = oldValue * smoothingFactor + newValue * (1.0 - smoothingFactor)
            }
        }
    }

    private func resampleSpectrum(_ input: [Float], toCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: toCount)

        for i in 0..<toCount {
            // Map to input range with interpolation
            let position = Float(i) * Float(input.count - 1) / Float(toCount - 1)
            let index = Int(position)
            let fraction = position - Float(index)

            if index < input.count - 1 {
                // Linear interpolation
                output[i] = input[index] * (1.0 - fraction) + input[index + 1] * fraction
            } else {
                output[i] = input[index]
            }

            // Apply power curve for visual dynamics
            output[i] = pow(output[i], 0.5)

            // Ensure minimum height for visual appeal
            output[i] = max(output[i], 0.01)
        }

        return output
    }

    // MARK: - Cleanup

    func cleanup() {
        if vao != 0 {
            glDeleteVertexArrays(1, &vao)
            vao = 0
        }
        if vbo != 0 {
            glDeleteBuffers(1, &vbo)
            vbo = 0
        }
        if ebo != 0 {
            glDeleteBuffers(1, &ebo)
            ebo = 0
        }
        if shaderProgram != 0 {
            glDeleteProgram(shaderProgram)
            shaderProgram = 0
        }
        if reflectionShaderProgram != 0 {
            glDeleteProgram(reflectionShaderProgram)
            reflectionShaderProgram = 0
        }

        isAvailable = false
        NSLog("TOCSpectrumRenderer: Cleaned up OpenGL resources")
    }
}
