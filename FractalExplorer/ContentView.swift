import SwiftUI

struct ContentView: View {
    @State private var viewport = FractalViewport.mandelbrotDefault
    @EnvironmentObject var settings: SettingsModel
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            FractalCanvasView(viewport: $viewport)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { canvasSize = geo.size }
                            .onChange(of: geo.size) { newSize in
                                canvasSize = newSize
                            }
                    }
                )
                .navigationTitle("Fractal Explorer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Reset") {
                            resetViewport()
                        }
                        Spacer()
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .onChange(of: settings.selectedFractalName) { _ in
                    resetViewport()
                }
        }
    }

    private func resetViewport() {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        viewport = FractalViewport.fittedToCanvas(
            for: settings.selectedFractal,
            canvasSize: canvasSize
        )
    }
}


#Preview {
    ContentView()
        .environmentObject(SettingsModel())
}


struct FractalViewport: Equatable {
    var xRange: ClosedRange<Double>
    var yRange: ClosedRange<Double>
    var dragOffset: CGSize = .zero

    init(centerX: Double, centerY: Double, scale: Double, fractal: FractalBase) {
        let baseXSpan = fractal.xRange.upperBound - fractal.xRange.lowerBound
        let baseYSpan = fractal.yRange.upperBound - fractal.yRange.lowerBound
        let spanX = baseXSpan / scale
        let spanY = baseYSpan / scale
        self.xRange = (centerX - spanX / 2) ... (centerX + spanX / 2)
        self.yRange = (centerY - spanY / 2) ... (centerY + spanY / 2)
    }
    
    init(xRange: ClosedRange<Double>, yRange: ClosedRange<Double>) {
        self.xRange = xRange
        self.yRange = yRange
    }

    static var mandelbrotDefault: FractalViewport {
        FractalViewport(centerX: -0.5, centerY: 0.0, scale: 1.0, fractal: FractalMandelbrot())
    }
    
    static func fittedToCanvas(for fractal: FractalBase, canvasSize: CGSize) -> FractalViewport {
        let baseViewport = FractalViewport(
            xRange: fractal.xRange,
            yRange: fractal.yRange
        )
        return baseViewport.fitted(to: canvasSize)
    }

    mutating func applyDragOffset(canvasSize: CGSize) {
        let dx = Double(dragOffset.width) / Double(canvasSize.width) * (xRange.upperBound - xRange.lowerBound)
        let dy = Double(dragOffset.height) / Double(canvasSize.height) * (yRange.upperBound - yRange.lowerBound)
        
        // Invert Y to match natural drag
        xRange = (xRange.lowerBound - dx) ... (xRange.upperBound - dx)
        yRange = (yRange.lowerBound + dy) ... (yRange.upperBound + dy)
        
        dragOffset = .zero
    }
   
    mutating func zoom(factor: Double, anchor: CGPoint) {
        let normX = anchor.x
        let normY = anchor.y

        let centerX = xRange.lowerBound + normX * (xRange.upperBound - xRange.lowerBound)
        let centerY = yRange.lowerBound + normY * (yRange.upperBound - yRange.lowerBound)

        let spanX = (xRange.upperBound - xRange.lowerBound) / factor
        let spanY = (yRange.upperBound - yRange.lowerBound) / factor

        xRange = (centerX - spanX / 2) ... (centerX + spanX / 2)
        yRange = (centerY - spanY / 2) ... (centerY + spanY / 2)
    }

    func fitted(to canvasSize: CGSize) -> FractalViewport {
        let canvasAspect = Double(canvasSize.width / canvasSize.height)

        let rawSpanX = xRange.upperBound - xRange.lowerBound
        let rawSpanY = yRange.upperBound - yRange.lowerBound
        let rawAspect = rawSpanX / rawSpanY

        let fittedSpanX: Double
        let fittedSpanY: Double

        if canvasAspect > rawAspect {
            // Pad X
            fittedSpanY = rawSpanY
            fittedSpanX = rawSpanY * canvasAspect
        } else {
            // Pad Y
            fittedSpanX = rawSpanX
            fittedSpanY = rawSpanX / canvasAspect
        }

        let centerX = (xRange.lowerBound + xRange.upperBound) / 2
        let centerY = (yRange.lowerBound + yRange.upperBound) / 2

        let dx = Double(dragOffset.width / canvasSize.width) * fittedSpanX
        let dy = Double(dragOffset.height / canvasSize.height) * fittedSpanY

        let newCenterX = centerX - dx
        let newCenterY = centerY - dy

        let newXRange = (newCenterX - fittedSpanX / 2) ... (newCenterX + fittedSpanX / 2)
        let newYRange = (newCenterY - fittedSpanY / 2) ... (newCenterY + fittedSpanY / 2)

        return FractalViewport(xRange: newXRange, yRange: newYRange)
    }
}


struct FractalCanvasView: View {
    @Binding var viewport: FractalViewport
    @EnvironmentObject var settings: SettingsModel

    @State private var renderWorkItem: DispatchWorkItem? = nil
    @State private var cgImage: CGImage? = nil
    @State private var currentSize: CGSize = .zero
    @State private var displayedBounds: (xmin: Double, xmax: Double, ymin: Double, ymax: Double)? = nil
    @State private var pinchBaseScale: CGFloat = 1.0
    @State private var isInteracting = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    if let img = cgImage {
                        context.draw(
                            Image(decorative: img, scale: 1.0),
                            in: CGRect(origin: .zero, size: size)
                        )
                    } else {
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.black)
                        )
                    }
                }

                if displayedBounds != nil {
                    VStack {
                        Spacer()
                        Text(hudText())
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .padding(.horizontal, 3)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 10)
                    }
                }
            }
            .onAppear {
                currentSize = geo.size
                render(size: geo.size)
            }
            .onChange(of: geo.size) { newSize in
                if newSize != currentSize, newSize.width > 0, newSize.height > 0 {
                    currentSize = newSize
                    render(size: newSize)
                }
            }
            .onChange(of: viewport) { _ in render(size: currentSize) }
            .onChange(of: settings.selectedPalette) { _ in render(size: currentSize) }
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            isInteracting = true
                            viewport.dragOffset = value.translation
                            scheduleRender(size: currentSize)
                        }
                        .onEnded { _ in
                            isInteracting = false
                            viewport = viewport.fitted(to: geo.size)
                            viewport.dragOffset = .zero
                            render(size: geo.size)
                        },
                    MagnificationGesture()
                        .onChanged { value in
                            isInteracting = true
                            if abs(pinchBaseScale - 1.0) < 1e-6 {
                                pinchBaseScale = value
                                return
                            }
                            
                            let incremental = Double(value / pinchBaseScale)
                            pinchBaseScale = value
                            
                            let anchor = CGPoint(x: 0.5, y: 0.5)
                            viewport.zoom(factor: incremental, anchor: anchor)
                            scheduleRender(size: currentSize)
                        }
                        .onEnded { _ in
                            isInteracting = false
                            pinchBaseScale = 1.0
                            render(size: geo.size)
                        }
                )
            )
        }
    }
    
    private func scheduleRender(size: CGSize, delay: TimeInterval = 0.05) {
        renderWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            self.render(size: size)
        }
        
        renderWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    @inline(__always)
    private func colorUInt(for iter: Int, lookup: [UInt32]) -> UInt32 {
        guard iter >= 0 else { return Palette.stableColor }
        
        if iter < lookup.count {
            return lookup[iter]
        } else {
            return Palette.stableColor
        }
    }

    @inline(__always)
    private func colorUInt(for iter_norm: Double, lookup: [UInt32]) -> UInt32 {
        let idx = min(max(Int(iter_norm * Double(lookup.count - 1)), 0), lookup.count - 1)
        return lookup[idx]
    }
    
    private func render(size: CGSize) {
        let scale: CGFloat = isInteracting ? 0.25 : 1.0
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        guard width > 0, height > 0 else { return }
        
        let fittedViewport = viewport.fitted(to: size)
        displayedBounds = (
            xmin: fittedViewport.xRange.lowerBound,
            xmax: fittedViewport.xRange.upperBound,
            ymin: fittedViewport.yRange.lowerBound,
            ymax: fittedViewport.yRange.upperBound
        )
        
        let palette = settings.selectedPalette
        let fractalCopy = settings.selectedFractal
        let invertPalette = settings.invertPalette
        let interpolatePalette = settings.interpolatePalette
        let histogramColors = settings.histogramColors
        
        let iterations = fractalCopy.max_iterations
        
        let lookupBGRA = palette.buildLookup(maxIterations: iterations, invert: invertPalette, interpolate: interpolatePalette)

        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let start = CFAbsoluteTimeGetCurrent()

                var buffer = [Int](repeating: 0, count: width * height)
                fractalCopy.compute(
                    width: width,
                    height: height,
                    buffer: &buffer,
                    maxIterations: iterations,
                    xRange: fittedViewport.xRange,
                    yRange: fittedViewport.yRange
                )
                let fractalComputed = CFAbsoluteTimeGetCurrent()
                
                let pixelCount = width * height
                var pixels = [UInt32](repeating: 0, count: pixelCount)
                let lookupLocal = lookupBGRA
       
                if histogramColors {
                    var histogram = [Int](repeating: 0, count: iterations)
                    for v in buffer where v < iterations {
                        histogram[v] &+= 1
                    }

                    var total = 0
                    var cdf = [Double](repeating: 0, count: iterations)
                    for i in 0..<iterations {
                        total += histogram[i]
                        cdf[i] = Double(total)
                    }
                    let norm = Double(total)
                    for i in 0..<iterations {
                        cdf[i] /= norm
                    }
                    
                    DispatchQueue.concurrentPerform(iterations: height) { row in
                        let rowBase = row * width
                        for x in 0..<width {
                            let iter = buffer[rowBase + x]
                            let myColor: UInt32
                            if iter < iterations {
                                let t = cdf[iter]
                                myColor = colorUInt(for: t, lookup: lookupLocal)
                            } else {
                                myColor = 0xFF000000
                            }
                            pixels[rowBase + x] = myColor
                        }
                    }
                } else {
                    DispatchQueue.concurrentPerform(iterations: height) { row in
                        let rowBase = row * width
                        for x in 0..<width {
                            let iter = buffer[rowBase + x]
                            let colorUInt = colorUInt(for: iter, lookup: lookupLocal)
                            pixels[rowBase + x] = colorUInt
                        }
                    }
                }

                let bytesPerRow = width * 4
                let data = NSData(bytes: &pixels, length: pixels.count * 4)
                guard let provider = CGDataProvider(data: data as CFData) else { return }
                
                guard let cgImg = CGImage(
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                    provider: provider,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent
                ) else { return }

                let end = CFAbsoluteTimeGetCurrent()
                let elapsed = (end - start) * 1000

                if let minVal = buffer.min(), let maxVal = buffer.max() {
                    print(String(format: "Render took %.2f ms (fps: %.2f), fractal calc: %.2f ms, min: %d, max: %d",
                                 elapsed, 1000.0 / elapsed, (fractalComputed - start) * 1000, minVal, maxVal))
                } else {
                    print(String(format: "Render took %.2f ms (fps: %.2f)", elapsed, 1000.0 / elapsed))
                }

                DispatchQueue.main.async {
                    self.cgImage = cgImg
                }
            }
        }
    }

    private func hudText() -> String {
        let fractal = settings.selectedFractal
        let zoomX = (fractal.xRange.upperBound - fractal.xRange.lowerBound) /
                    (viewport.xRange.upperBound - viewport.xRange.lowerBound)
        let xText = sci2(0.5 * (viewport.xRange.lowerBound + viewport.xRange.upperBound))
        let yText = sci2(0.5 * (viewport.yRange.lowerBound + viewport.yRange.upperBound))
        return "  \(fractal.name), Zoom: ×\(zoom_tonum(zoomX)) \n  x:\(xText), y:\(yText)  "
    }

    private func zoom_tonum(_ x: Double) -> String { String(format: "%.2e", x) }
    private func sci2(_ x: Double) -> String { String(format: "%.12e", x) }
}
