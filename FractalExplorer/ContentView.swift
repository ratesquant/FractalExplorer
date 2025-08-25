import SwiftUI

struct ContentView: View {
    @State private var viewport = FractalViewport.mandelbrotDefault

    var body: some View {
        NavigationStack {
            FractalCanvasView(viewport: $viewport)
                .navigationTitle("Fractal Explorer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Reset") {
                            viewport = .mandelbrotDefault
                        }
                        Spacer()
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SettingsModel())
    }
}


struct FractalViewport: Equatable {
    var xRange: ClosedRange<Double>
    var yRange: ClosedRange<Double>

    // Convenience initializer from center + scale
    init(centerX: Double, centerY: Double, scale: Double, fractal: FractalBase) {
        let baseXSpan = fractal.xRange.upperBound - fractal.xRange.lowerBound
        let baseYSpan = fractal.yRange.upperBound - fractal.yRange.lowerBound
        let spanX = baseXSpan / scale
        let spanY = baseYSpan / scale
        self.xRange = (centerX - spanX/2) ... (centerX + spanX/2)
        self.yRange = (centerY - spanY/2) ... (centerY + spanY/2)
    }
    
    init(xRange: ClosedRange<Double>, yRange: ClosedRange<Double>) {
         self.xRange = xRange
         self.yRange = yRange
     }

    // Default Mandelbrot viewport
    static var mandelbrotDefault: FractalViewport {
        FractalViewport(centerX: -0.5, centerY: 0.0, scale: 1.0, fractal: FractalMandelbrot())
    }


    // Zoom helper
    mutating func zoom(factor: Double, anchor: CGPoint) {
        let centerX = xRange.lowerBound + Double(anchor.x) * (xRange.upperBound - xRange.lowerBound)
        let centerY = yRange.lowerBound + Double(anchor.y) * (yRange.upperBound - yRange.lowerBound)
        let spanX = (xRange.upperBound - xRange.lowerBound) / factor
        let spanY = (yRange.upperBound - yRange.lowerBound) / factor
        xRange = (centerX - spanX/2) ... (centerX + spanX/2)
        yRange = (centerY - spanY/2) ... (centerY + spanY/2)
    }

    // Pan helper
    mutating func pan(deltaX: Double, deltaY: Double) {
        xRange = (xRange.lowerBound + deltaX) ... (xRange.upperBound + deltaX)
        yRange = (yRange.lowerBound + deltaY) ... (yRange.upperBound + deltaY)
    }
    
    func fitted(to canvasSize: CGSize) -> FractalViewport {
           let canvasAspect = Double(canvasSize.width / canvasSize.height)
           let viewportXSpan = xRange.upperBound - xRange.lowerBound
           let viewportYSpan = yRange.upperBound - yRange.lowerBound
           let viewportAspect = viewportXSpan / viewportYSpan

           var newXRange = xRange
           var newYRange = yRange

           if canvasAspect > viewportAspect {
               let centerX = (xRange.lowerBound + xRange.upperBound) / 2
               let newSpanX = viewportYSpan * canvasAspect
               newXRange = (centerX - newSpanX/2)...(centerX + newSpanX/2)
           } else {
               let centerY = (yRange.lowerBound + yRange.upperBound) / 2
               let newSpanY = viewportXSpan / canvasAspect
               newYRange = (centerY - newSpanY/2)...(centerY + newSpanY/2)
           }

           return FractalViewport(xRange: newXRange, yRange: newYRange)
       }
}

struct FractalCanvasView: View {
    @Binding var viewport: FractalViewport
    @EnvironmentObject var settings: SettingsModel

    @State private var cgImage: CGImage? = nil
    @State private var lastSize: CGSize = .zero
    @State private var displayedBounds: (xmin: Double, xmax: Double, ymin: Double, ymax: Double)? = nil
    @State private var magnifyStart: CGFloat? = nil

    private let fractal: FractalBase = FractalMandelbrot()
    private let maxIter = 50
    @State private var buffer: [Int] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Fractal image
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

                // HUD overlay
                if displayedBounds != nil {
                    VStack {
                        Spacer()
                        Text(hudText())
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 10)
                    }
                }
            }
            .onAppear {
                lastSize = geo.size
                render(size: geo.size)
            }
            .onChange(of: geo.size) { newSize in
                if newSize != lastSize && newSize.width > 0 && newSize.height > 0 {
                    lastSize = newSize
                    render(size: newSize)
                }
            }
            .onChange(of: viewport) { _ in render(size: lastSize) }
            .onChange(of: settings.selectedPalette) { _ in render(size: lastSize) }
            // Pan gesture
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let dx = Double(value.translation.width) / Double(geo.size.width)
                        let dy = Double(value.translation.height) / Double(geo.size.height)
                        let spanX = viewport.xRange.upperBound - viewport.xRange.lowerBound
                        let spanY = viewport.yRange.upperBound - viewport.yRange.lowerBound
                        viewport.pan(deltaX: -dx * spanX, deltaY: dy * spanY)
                    }
            )
            // Pinch zoom
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        if magnifyStart == nil { magnifyStart = 1.0 }
                        let factor = value / (magnifyStart ?? 1.0)
                        magnifyStart = value
                        let anchor = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                        viewport.zoom(factor: factor, anchor: anchor)
                    }
                    .onEnded { _ in magnifyStart = nil }
            )
        }
    }

    // MARK: - Rendering
    private func render(size: CGSize) {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0 && height > 0 else { return }

        displayedBounds = (
            xmin: viewport.xRange.lowerBound,
            xmax: viewport.xRange.upperBound,
            ymin: viewport.yRange.lowerBound,
            ymax: viewport.yRange.upperBound
        )

        var palette = settings.selectedPalette
        palette.buildLookup(maxIterations: maxIter)

        if buffer.isEmpty || buffer.count < width * height {
            buffer = Array(repeating: 0, count: width * height)
        }
                
        let bufferCopy = buffer
        let fractalCopy = fractal
        
        let fittedViewport = viewport.fitted(to: size)

        DispatchQueue.global(qos: .userInitiated).async {
            var localBuffer = bufferCopy

            fractalCopy.compute(
                width: width,
                height: height,
                buffer: &localBuffer,
                maxIterations: maxIter,
                xRange: fittedViewport.xRange,
                yRange: fittedViewport.yRange
            )

            let img = FractalCanvasView.makeImage(
                width: width,
                height: height,
                buffer: localBuffer,
                palette: palette,
                maxIter: maxIter
            )

            DispatchQueue.main.async {
                self.cgImage = img
                self.buffer = localBuffer
            }
        }
    }

    // MARK: - Make Image
    private static func makeImage(width: Int, height: Int, buffer: [Int], palette: Palette, maxIter: Int) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let iter = buffer[y * width + x]
                let color = palette.colorUInt(for: iter, maxIterations: maxIter)
                let (r, g, b) = palette.to_rgb(color)
                let offset = (y * width + x) * 4
                pixels[offset] = r
                pixels[offset+1] = g
                pixels[offset+2] = b
                pixels[offset+3] = 255
            }
        }

        guard let provider = CGDataProvider(data: NSData(bytes: &pixels, length: pixels.count)) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - HUD
    private func hudText() -> String {
        let zoomX = (fractal.xRange.upperBound - fractal.xRange.lowerBound) /
                    (viewport.xRange.upperBound - viewport.xRange.lowerBound)
        let xText = "[\(sci2(viewport.xRange.lowerBound)), \(sci2(viewport.xRange.upperBound))]"
        let yText = "[\(sci2(viewport.yRange.lowerBound)), \(sci2(viewport.yRange.upperBound))]"
        return "\(fractal.name) • ×\(zoom_tonum(zoomX)) • x:\(xText) y:\(yText)"
    }

    private func zoom_tonum(_ x: Double) -> String { String(format: "%.2g", x) }
    private func sci2(_ x: Double) -> String { String(format: "%.1e", x) }
}
