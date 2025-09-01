import SwiftUI

struct ContentView: View {
    @State private var viewport = FractalViewport.mandelbrotDefault
    @EnvironmentObject var settings: SettingsModel
    @State private var canvasSize: CGSize = .zero   // track screen size

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SettingsModel())
    }
}


struct FractalViewport: Equatable {
    var xRange: ClosedRange<Double>
    var yRange: ClosedRange<Double>
    var dragOffset: CGSize = .zero

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
         
         // **Invert Y to match natural drag**
         xRange = (xRange.lowerBound - dx) ... (xRange.upperBound - dx)
         yRange = (yRange.lowerBound + dy) ... (yRange.upperBound + dy)
         
         dragOffset = .zero
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

    func fitted(to canvasSize: CGSize) -> FractalViewport {
        let canvasAspect = Double(canvasSize.width / canvasSize.height)

        let rawSpanX = xRange.upperBound - xRange.lowerBound
        let rawSpanY = yRange.upperBound - yRange.lowerBound
        let rawAspect = rawSpanX / rawSpanY

        // Determine the final (fitted) spans on both axes
        let fittedSpanX: Double
        let fittedSpanY: Double
        if canvasAspect > rawAspect {
            // pad X
            fittedSpanY = rawSpanY
            fittedSpanX = rawSpanY * canvasAspect
        } else {
            // pad Y
            fittedSpanX = rawSpanX
            fittedSpanY = rawSpanX / canvasAspect
        }

        // Current center (before drag)
        let centerX = (xRange.lowerBound + xRange.upperBound) / 2
        let centerY = (yRange.lowerBound + yRange.upperBound) / 2

        // Scale pixel drag to complex-plane drag using the *fitted* spans
        let dx = Double(dragOffset.width  / canvasSize.width)  * fittedSpanX
        let dy = Double(dragOffset.height / canvasSize.height) * fittedSpanY

        // Translate centers by drag (subtract so content follows finger)
        let newCenterX = centerX - dx
        let newCenterY = centerY - dy

        let newXRange = (newCenterX - fittedSpanX / 2) ... (newCenterX + fittedSpanX / 2)
        let newYRange = (newCenterY - fittedSpanY / 2) ... (newCenterY + fittedSpanY / 2)

        // Return a fitted viewport (dragOffset stays on the original `viewport`)
        return FractalViewport(xRange: newXRange, yRange: newYRange)
    }

}

struct FractalCanvasView: View {
    @Binding var viewport: FractalViewport
    @EnvironmentObject var settings: SettingsModel

    @State private var cgImage: CGImage? = nil
    @State private var current_size: CGSize = .zero
    @State private var displayedBounds: (xmin: Double, xmax: Double, ymin: Double, ymax: Double)? = nil
    @State private var magnifyStart: CGFloat? = nil
    
    private let maxIter = 256
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
                current_size = geo.size
                render(size: geo.size)
            }
            .onChange(of: geo.size) { newSize in
                if newSize != current_size && newSize.width > 0 && newSize.height > 0 {
                    current_size = newSize
                    render(size: newSize)
                }
            }
            .onChange(of: viewport) { _ in render(size: current_size) }
            .onChange(of: settings.selectedPalette) { _ in render(size: current_size) }
            // Pan gesture
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewport.dragOffset = value.translation
                    }
                    .onEnded { _ in
                        
                        viewport = viewport.fitted(to: geo.size)
                        viewport.dragOffset = .zero
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
        
        let fittedViewport = viewport.fitted(to: size)
        
        displayedBounds = (
            xmin: fittedViewport.xRange.lowerBound,
            xmax: fittedViewport.xRange.upperBound,
            ymin: fittedViewport.yRange.lowerBound,
            ymax: fittedViewport.yRange.upperBound
        )
        
        var palette = settings.selectedPalette
        let fractalCopy = settings.selectedFractal
        
        palette.buildLookup(maxIterations: maxIter)

        if buffer.isEmpty || buffer.count < width * height {
            buffer = Array(repeating: 0, count: width * height)
        }
                
        let bufferCopy = buffer
        
              
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

            guard let img = FractalCanvasView.makeImage(
                width: width,
                height: height,
                buffer: localBuffer,
                palette: palette,
                maxIter: maxIter
            )else {
                return
            }
            /*
            // Overlay HUD text
            let renderer = UIGraphicsImageRenderer(size: size)
            let finalImage = renderer.image { ctx in
                // Draw fractal first
                ctx.cgContext.draw(img, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                
                // HUD
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraphStyle
                ]
                
                let text = self.hudText()
                let hudRect = CGRect(x: 0, y: size.height - 24, width: size.width, height: 20)
                text.draw(in: hudRect, withAttributes: attrs)
            }*/

            DispatchQueue.main.async {
                self.cgImage = img
                //self.cgImage = finalImage.cgImage
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
        let fractal = settings.selectedFractal
        let zoomX = (fractal.xRange.upperBound - fractal.xRange.lowerBound) /
                    (viewport.xRange.upperBound - viewport.xRange.lowerBound)
        let xText = "[\(sci2(viewport.xRange.lowerBound)), \(sci2(viewport.xRange.upperBound))]"
        let yText = "[\(sci2(viewport.yRange.lowerBound)), \(sci2(viewport.yRange.upperBound))]"
        return "\(fractal.name): ×\(zoom_tonum(zoomX)) x:\(xText) y:\(yText)"
    }

    private func zoom_tonum(_ x: Double) -> String { String(format: "%.1f", x) }
    private func sci2(_ x: Double) -> String { String(format: "%.4f", x) }
}
