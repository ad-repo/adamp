import MetalKit
import os.lock

// =============================================================================
// SPECTRUM ANALYZER VIEW - Metal-based real-time audio visualization
// =============================================================================
// A GPU-accelerated spectrum analyzer that supports two quality modes:
// - Winamp: Discrete color palette, pixel-art aesthetic
// - Enhanced: Smooth gradients with optional glow effect
//
// Uses CADisplayLink for 60Hz rendering synchronized to the display refresh.
// Thread-safe spectrum data updates via OSAllocatedUnfairLock.
// =============================================================================

// MARK: - Enums

/// Quality mode for spectrum analyzer rendering
enum SpectrumQualityMode: String, CaseIterable {
    case winamp = "Winamp"       // Discrete colors, pixel-art aesthetic
    case enhanced = "Enhanced"   // Smooth gradients with glow
    
    var displayName: String { rawValue }
}

/// Decay mode controlling how quickly bars fall
enum SpectrumDecayMode: String, CaseIterable {
    case instant = "Instant"     // No smoothing, immediate response
    case snappy = "Snappy"       // 25% retention - fast and punchy
    case balanced = "Balanced"   // 40% retention - good middle ground
    case smooth = "Smooth"       // 55% retention - original Winamp feel
    
    var displayName: String { rawValue }
    
    /// Decay factor (0 = instant, higher = slower decay)
    var decayFactor: Float {
        switch self {
        case .instant: return 0.0
        case .snappy: return 0.25
        case .balanced: return 0.40
        case .smooth: return 0.55
        }
    }
}

// MARK: - LED Parameters (for Metal shader)

/// Parameters passed to the Metal shader (must match Metal struct exactly)
/// Total size: 40 bytes, 8-byte aligned
struct LEDParams {
    var viewportSize: SIMD2<Float>  // 8 bytes (offset 0)
    var columnCount: Int32          // 4 bytes (offset 8)
    var rowCount: Int32             // 4 bytes (offset 12)
    var cellWidth: Float            // 4 bytes (offset 16)
    var cellHeight: Float           // 4 bytes (offset 20)
    var cellSpacing: Float          // 4 bytes (offset 24)
    var qualityMode: Int32          // 4 bytes (offset 28)
    var maxHeight: Float            // 4 bytes (offset 32)
    var padding: Float = 0          // 4 bytes (offset 36) - alignment to 40
}

// MARK: - Spectrum Analyzer View

/// Metal-based spectrum analyzer visualization view
class SpectrumAnalyzerView: NSView {
    
    // MARK: - Configuration
    
    /// Quality mode (Winamp discrete vs Enhanced smooth)
    var qualityMode: SpectrumQualityMode = .winamp {
        didSet {
            UserDefaults.standard.set(qualityMode.rawValue, forKey: "spectrumQualityMode")
            let mode = qualityMode
            dataLock.withLock {
                renderQualityMode = mode
            }
        }
    }
    
    /// Decay/responsiveness mode
    var decayMode: SpectrumDecayMode = .snappy {
        didSet {
            UserDefaults.standard.set(decayMode.rawValue, forKey: "spectrumDecayMode")
            let factor = decayMode.decayFactor
            dataLock.withLock {
                renderDecayFactor = factor
            }
        }
    }
    
    /// Number of bars to display
    var barCount: Int = 19 {
        didSet {
            let count = barCount
            dataLock.withLock {
                renderBarCount = count
            }
        }
    }
    
    /// Bar width in pixels (scaled in shader)
    var barWidth: CGFloat = 3.0 {
        didSet {
            let width = barWidth
            dataLock.withLock {
                renderBarWidth = width
            }
        }
    }
    
    /// Spacing between bars
    var barSpacing: CGFloat = 1.0
    
    /// Glow intensity for enhanced mode (0-1)
    var glowIntensity: Float = 0.5
    
    // MARK: - Metal Resources
    
    private var metalLayer: CAMetalLayer!
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState?
    
    // Pipeline states for both modes
    private var ledPipelineState: MTLRenderPipelineState?
    private var barPipelineState: MTLRenderPipelineState?
    
    // Buffers
    private var vertexBuffer: MTLBuffer?
    private var colorBuffer: MTLBuffer?
    private var heightBuffer: MTLBuffer?
    private var paramsBuffer: MTLBuffer?
    
    // LED Matrix buffers
    private var cellBrightnessBuffer: MTLBuffer?
    private var peakPositionsBuffer: MTLBuffer?
    
    // MARK: - Display Sync
    
    private var displayLink: CVDisplayLink?
    private var isRendering = false
    
    // MARK: - Thread-Safe Spectrum Data
    // Note: These properties are accessed from both the main thread and the CVDisplayLink callback thread.
    // They are protected by dataLock and marked nonisolated(unsafe) to allow cross-thread access.
    
    private let dataLock = OSAllocatedUnfairLock()
    nonisolated(unsafe) private var rawSpectrum: [Float] = []       // From audio engine (75 bands)
    nonisolated(unsafe) private var displaySpectrum: [Float] = []   // After decay smoothing
    nonisolated(unsafe) private var renderBarCount: Int = 19        // Bar count for rendering
    nonisolated(unsafe) private var renderDecayFactor: Float = 0.25 // Decay factor for rendering
    nonisolated(unsafe) private var renderColorPalette: [SIMD4<Float>] = [] // Colors for rendering
    nonisolated(unsafe) private var renderBarWidth: CGFloat = 3.0   // Bar width for rendering
    nonisolated(unsafe) private var renderQualityMode: SpectrumQualityMode = .winamp // Quality mode for rendering
    
    // LED Matrix state tracking (for Enhanced mode)
    nonisolated(unsafe) private var peakHoldPositions: [Float] = []  // Peak hold position per column (0-1)
    nonisolated(unsafe) private var cellBrightness: [[Float]] = []   // Brightness per cell [column][row]
    private let ledRowCount = 16  // Number of LED rows in matrix
    
    // MARK: - Color Palette
    
    /// Current skin's visualization colors (24 colors, updated on skin change)
    private var colorPalette: [SIMD4<Float>] = []
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        wantsLayer = true
        
        // Restore saved settings
        if let savedQuality = UserDefaults.standard.string(forKey: "spectrumQualityMode"),
           let mode = SpectrumQualityMode(rawValue: savedQuality) {
            qualityMode = mode
        }
        
        if let savedDecay = UserDefaults.standard.string(forKey: "spectrumDecayMode"),
           let mode = SpectrumDecayMode(rawValue: savedDecay) {
            decayMode = mode
        }
        
        // Initialize display spectrum and sync to render-safe variables
        displaySpectrum = Array(repeating: 0, count: barCount)
        renderBarCount = barCount
        renderDecayFactor = decayMode.decayFactor
        renderBarWidth = barWidth
        renderQualityMode = qualityMode
        
        // Set up Metal
        setupMetal()
        
        // Load colors from current skin
        updateColorsFromSkin()
        
        // Start rendering
        startRendering()
    }
    
    deinit {
        stopRendering()
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        // Get the default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            NSLog("SpectrumAnalyzerView: Metal is not supported on this device")
            return
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            NSLog("SpectrumAnalyzerView: Failed to create command queue")
            return
        }
        self.commandQueue = commandQueue
        
        // Configure Metal layer
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.frame = bounds
        layer?.addSublayer(metalLayer)
        
        // Load shaders and create pipeline
        setupPipeline()
        
        // Create buffers
        setupBuffers()
    }
    
    private func setupPipeline() {
        guard let device = device else { return }
        
        // Load shader source from file (runtime compilation for SPM compatibility)
        // This is required because makeDefaultLibrary() returns nil in SPM executables
        guard let shaderURL = BundleHelper.url(forResource: "SpectrumShaders", withExtension: "metal"),
              let shaderSource = try? String(contentsOf: shaderURL, encoding: .utf8) else {
            NSLog("SpectrumAnalyzerView: Failed to load shader source file")
            return
        }
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            
            // Create LED matrix pipeline (Enhanced mode)
            if let vertexFunc = library.makeFunction(name: "led_matrix_vertex"),
               let fragmentFunc = library.makeFunction(name: "led_matrix_fragment") {
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.label = "LED Matrix Pipeline"
                descriptor.vertexFunction = vertexFunc
                descriptor.fragmentFunction = fragmentFunc
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                ledPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            }
            
            // Create bar pipeline (Winamp mode)
            if let vertexFunc = library.makeFunction(name: "spectrum_vertex"),
               let fragmentFunc = library.makeFunction(name: "spectrum_fragment") {
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.label = "Spectrum Bar Pipeline"
                descriptor.vertexFunction = vertexFunc
                descriptor.fragmentFunction = fragmentFunc
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                barPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            }
            
            // Keep pipelineState for backward compatibility (points to current mode)
            pipelineState = qualityMode == .enhanced ? ledPipelineState : barPipelineState
            
            NSLog("SpectrumAnalyzerView: Metal pipelines created successfully")
        } catch {
            NSLog("SpectrumAnalyzerView: Failed to compile shaders: \(error)")
        }
    }
    
    private func setupBuffers() {
        guard let device = device else { return }
        
        let maxColumns = 64
        let maxRows = 16
        let maxCells = maxColumns * maxRows
        
        // Cell brightness buffer (one float per cell) - for LED matrix mode
        cellBrightnessBuffer = device.makeBuffer(
            length: maxCells * MemoryLayout<Float>.stride,
            options: .storageModeShared
        )
        
        // Peak positions buffer (one float per column) - for LED matrix mode
        peakPositionsBuffer = device.makeBuffer(
            length: maxColumns * MemoryLayout<Float>.stride,
            options: .storageModeShared
        )
        
        // Heights buffer (for Winamp bar mode, reused from existing)
        heightBuffer = device.makeBuffer(
            length: maxColumns * MemoryLayout<Float>.stride,
            options: .storageModeShared
        )
        
        // Colors buffer (24 colors for Winamp palette)
        colorBuffer = device.makeBuffer(
            length: 24 * MemoryLayout<SIMD4<Float>>.stride,
            options: .storageModeShared
        )
        
        // Params buffer (shared between both modes)
        paramsBuffer = device.makeBuffer(
            length: MemoryLayout<LEDParams>.stride,
            options: .storageModeShared
        )
    }
    
    // MARK: - Display Link
    
    private func startRendering() {
        guard !isRendering else { return }
        isRendering = true
        
        // Create display link
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        
        guard let displayLink = link else {
            NSLog("SpectrumAnalyzerView: Failed to create display link")
            return
        }
        
        self.displayLink = displayLink
        
        // Set output callback
        let callbackPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, callbackPointer)
        
        // Start the display link
        CVDisplayLinkStart(displayLink)
    }
    
    private func stopRendering() {
        guard isRendering else { return }
        isRendering = false
        
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
    }
    
    // MARK: - Rendering
    
    /// Called by display link at 60Hz
    /// Note: This is internal (not private) so the display link callback can access it
    func render() {
        guard isRendering, let metalLayer = metalLayer else { return }
        
        // Update display spectrum with decay
        updateDisplaySpectrum()
        
        // Get drawable
        guard let drawable = metalLayer.nextDrawable() else { return }
        
        // Select pipeline based on quality mode (use render-safe copy)
        var currentMode: SpectrumQualityMode = .winamp
        dataLock.withLock {
            currentMode = renderQualityMode
        }
        let activePipeline = currentMode == .enhanced ? ledPipelineState : barPipelineState
        
        guard let pipeline = activePipeline,
              let commandBuffer = commandQueue?.makeCommandBuffer() else {
            NSLog("SpectrumAnalyzerView: Metal pipeline not ready")
            return
        }
        
        // Create render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Update buffers with current data
        updateBuffers()
        
        // Set pipeline state
        encoder.setRenderPipelineState(pipeline)
        
        // Get bar count for vertex calculation
        var localBarCount: Int = 0
        dataLock.withLock {
            localBarCount = renderBarCount
        }
        
        if currentMode == .enhanced {
            // LED Matrix mode - bind LED buffers
            if let buffer = cellBrightnessBuffer {
                encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            }
            if let buffer = peakPositionsBuffer {
                encoder.setVertexBuffer(buffer, offset: 0, index: 1)
            }
            if let buffer = paramsBuffer {
                encoder.setVertexBuffer(buffer, offset: 0, index: 2)
                encoder.setFragmentBuffer(buffer, offset: 0, index: 1)
            }
            
            // Each cell is 6 vertices, total cells = columns * rows
            let vertexCount = localBarCount * ledRowCount * 6
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        } else {
            // Winamp bar mode - bind bar buffers
            if let buffer = heightBuffer {
                encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            }
            if let buffer = paramsBuffer {
                encoder.setVertexBuffer(buffer, offset: 0, index: 2)
            }
            if let buffer = colorBuffer {
                encoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            }
            if let buffer = paramsBuffer {
                encoder.setFragmentBuffer(buffer, offset: 0, index: 1)
            }
            
            // 6 vertices per bar
            let vertexCount = localBarCount * 6
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        }
        
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func updateDisplaySpectrum() {
        dataLock.withLock {
            let decay = renderDecayFactor
            let outputCount = renderBarCount
            
            // Map raw spectrum to display bars
            if rawSpectrum.isEmpty {
                // Decay existing values when no input
                for i in 0..<displaySpectrum.count {
                    displaySpectrum[i] *= decay
                    if displaySpectrum[i] < 0.01 {
                        displaySpectrum[i] = 0
                    }
                }
            } else {
                // Map input bands to display bars
                let inputCount = rawSpectrum.count
                
                // Ensure displaySpectrum has correct size
                if displaySpectrum.count != outputCount {
                    displaySpectrum = Array(repeating: 0, count: outputCount)
                }
                
                // Match main window's spectrum mapping exactly (simple averaging, no processing)
                // Scale factor leaves visual headroom at top (0.95 = peaks show at 95% height)
                let displayScale: Float = 0.95
                
                if inputCount >= outputCount {
                    // Average multiple input bands into each display bar
                    let bandsPerBar = inputCount / outputCount
                    for barIndex in 0..<outputCount {
                        let start = barIndex * bandsPerBar
                        let end = min(start + bandsPerBar, inputCount)
                        var sum: Float = 0
                        for i in start..<end {
                            sum += rawSpectrum[i]
                        }
                        let newValue = (sum / Float(end - start)) * displayScale
                        
                        // Apply decay
                        if newValue > displaySpectrum[barIndex] {
                            displaySpectrum[barIndex] = newValue  // Fast attack
                        } else {
                            displaySpectrum[barIndex] = displaySpectrum[barIndex] * decay + newValue * (1 - decay)
                        }
                    }
                } else {
                    // Interpolate when fewer input bands than display bars
                    for barIndex in 0..<outputCount {
                        let sourceIndex = Float(barIndex) * Float(inputCount - 1) / Float(outputCount - 1)
                        let lowerIndex = Int(sourceIndex)
                        let upperIndex = min(lowerIndex + 1, inputCount - 1)
                        let fraction = sourceIndex - Float(lowerIndex)
                        let newValue = (rawSpectrum[lowerIndex] * (1 - fraction) + rawSpectrum[upperIndex] * fraction) * displayScale
                        
                        // Apply decay
                        if newValue > displaySpectrum[barIndex] {
                            displaySpectrum[barIndex] = newValue
                        } else {
                            displaySpectrum[barIndex] = displaySpectrum[barIndex] * decay + newValue * (1 - decay)
                        }
                    }
                }
            }
            
            // Update LED matrix state only when in Enhanced mode
            if renderQualityMode == .enhanced {
                updateLEDMatrixState()
            }
        }
    }
    
    /// Updates peak hold positions and per-cell brightness for LED matrix mode
    /// Note: Only called when qualityMode == .enhanced
    private func updateLEDMatrixState() {
        let colCount = renderBarCount
        
        // Initialize arrays if needed
        if peakHoldPositions.count != colCount {
            peakHoldPositions = Array(repeating: 0, count: colCount)
        }
        if cellBrightness.count != colCount {
            cellBrightness = Array(repeating: Array(repeating: Float(0), count: ledRowCount), count: colCount)
        }
        
        let peakDecayRate: Float = 0.012      // How fast peak falls (per frame)
        let peakHoldFrames: Float = 0.985     // Slight delay before peak starts falling
        let cellFadeRate: Float = 0.025       // How fast cells fade out (slower = longer trails)
        
        for col in 0..<min(colCount, displaySpectrum.count) {
            let currentLevel = displaySpectrum[col]
            let currentRow = Int(currentLevel * Float(ledRowCount))
            
            // Update peak hold position
            if currentLevel > peakHoldPositions[col] {
                // New peak - jump to current level
                peakHoldPositions[col] = currentLevel
            } else {
                // Decay peak slowly
                peakHoldPositions[col] = max(0, peakHoldPositions[col] * peakHoldFrames - peakDecayRate)
            }
            
            // Update per-cell brightness
            for row in 0..<ledRowCount {
                if row < currentRow {
                    // Cell is currently lit - set to full brightness
                    cellBrightness[col][row] = 1.0
                } else {
                    // Cell is not lit - fade out
                    cellBrightness[col][row] = max(0, cellBrightness[col][row] - cellFadeRate)
                }
            }
        }
    }
    
    private func updateBuffers() {
        // Get render-safe values inside lock
        var localBarCount: Int = 0
        var localBarWidth: CGFloat = 0
        var localColors: [SIMD4<Float>] = []
        var localSpectrum: [Float] = []
        var localPeakPositions: [Float] = []
        var localCellBrightness: [[Float]] = []
        var localQualityMode: SpectrumQualityMode = .winamp
        
        dataLock.withLock {
            localBarCount = renderBarCount
            localBarWidth = renderBarWidth
            localColors = renderColorPalette
            localSpectrum = displaySpectrum
            localPeakPositions = peakHoldPositions
            localCellBrightness = cellBrightness
            localQualityMode = renderQualityMode
        }
        
        let scale = metalLayer?.contentsScale ?? 1.0
        let scaledWidth = Float(bounds.width * scale)
        let scaledHeight = Float(bounds.height * scale)
        
        // Calculate cell dimensions
        let cellSpacing: Float = 2.0 * Float(scale)
        let cellHeight = (scaledHeight - Float(ledRowCount - 1) * cellSpacing) / Float(ledRowCount)
        let cellWidth = Float(localBarWidth * scale) - 1.0
        
        // Update params buffer
        if let buffer = paramsBuffer {
            let ptr = buffer.contents().bindMemory(to: LEDParams.self, capacity: 1)
            ptr.pointee = LEDParams(
                viewportSize: SIMD2<Float>(scaledWidth, scaledHeight),
                columnCount: Int32(localBarCount),
                rowCount: Int32(ledRowCount),
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                cellSpacing: cellSpacing,
                qualityMode: localQualityMode == .winamp ? 0 : 1,
                maxHeight: scaledHeight
            )
        }
        
        if localQualityMode == .enhanced {
            // Update cell brightness buffer (LED matrix mode)
            if let buffer = cellBrightnessBuffer {
                let ptr = buffer.contents().bindMemory(to: Float.self, capacity: localBarCount * ledRowCount)
                for col in 0..<localBarCount {
                    for row in 0..<ledRowCount {
                        let index = col * ledRowCount + row
                        if col < localCellBrightness.count && row < localCellBrightness[col].count {
                            ptr[index] = localCellBrightness[col][row]
                        } else {
                            ptr[index] = 0
                        }
                    }
                }
            }
            
            // Update peak positions buffer
            if let buffer = peakPositionsBuffer {
                let ptr = buffer.contents().bindMemory(to: Float.self, capacity: localBarCount)
                for col in 0..<localBarCount {
                    ptr[col] = col < localPeakPositions.count ? localPeakPositions[col] : 0
                }
            }
        } else {
            // Update heights buffer (Winamp bar mode)
            if let buffer = heightBuffer {
                let ptr = buffer.contents().bindMemory(to: Float.self, capacity: localBarCount)
                for i in 0..<min(localBarCount, localSpectrum.count) {
                    ptr[i] = localSpectrum[i]
                }
            }
            
            // Update colors buffer
            if let buffer = colorBuffer {
                let ptr = buffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: 24)
                for (i, color) in localColors.prefix(24).enumerated() {
                    ptr[i] = color
                }
            }
        }
    }
    
    // MARK: - Public API
    
    /// Update spectrum data from audio engine (called from audio thread)
    func updateSpectrum(_ levels: [Float]) {
        dataLock.withLock {
            rawSpectrum = levels
        }
    }
    
    /// Update colors from current skin
    func updateColorsFromSkin() {
        let skin = WindowManager.shared.currentSkin ?? SkinLoader.shared.loadDefault()
        let nsColors = skin.visColors
        
        // Convert NSColor to SIMD4<Float>
        colorPalette = nsColors.map { color in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
        }
        
        // Ensure we have at least 24 colors
        while colorPalette.count < 24 {
            let brightness = Float(colorPalette.count) / 23.0
            colorPalette.append(SIMD4<Float>(0, brightness, 0, 1))
        }
        
        // Sync to render-safe variable
        let colors = colorPalette
        dataLock.withLock {
            renderColorPalette = colors
        }
    }
    
    /// Notify that skin changed
    func skinDidChange() {
        updateColorsFromSkin()
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        metalLayer?.frame = bounds
        metalLayer?.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            metalLayer?.contentsScale = window?.backingScaleFactor ?? 2.0
            startRendering()
        } else {
            // Window closed - stop the display link to release CPU
            stopRendering()
        }
    }
    
}

// MARK: - Display Link Callback

private func displayLinkCallback(
    displayLink: CVDisplayLink,
    inNow: UnsafePointer<CVTimeStamp>,
    inOutputTime: UnsafePointer<CVTimeStamp>,
    flagsIn: CVOptionFlags,
    flagsOut: UnsafeMutablePointer<CVOptionFlags>,
    displayLinkContext: UnsafeMutableRawPointer?
) -> CVReturn {
    guard let context = displayLinkContext else { return kCVReturnError }
    
    let view = Unmanaged<SpectrumAnalyzerView>.fromOpaque(context).takeUnretainedValue()
    view.render()
    
    return kCVReturnSuccess
}
