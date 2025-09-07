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
        let normX = anchor.x // already normalized 0...1
        let normY = anchor.y // already normalized 0...1

        let centerX = xRange.lowerBound + normX * (xRange.upperBound - xRange.lowerBound)
        let centerY = yRange.lowerBound + normY * (yRange.upperBound - yRange.lowerBound)

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

    @State private var renderWorkItem: DispatchWorkItem? = nil //debouncer state
    @State private var cgImage: CGImage? = nil
    @State private var current_size: CGSize = .zero
    @State private var displayedBounds: (xmin: Double, xmax: Double, ymin: Double, ymax: Double)? = nil
    @State private var pinchBaseScale: CGFloat = 1.0
    
    private let maxIter = 256
    @State private var isInteracting = false

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
            // Pan + Pinch combined
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            isInteracting = true
                            viewport.dragOffset = value.translation
                            scheduleRender(size: current_size)
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
                            // Initialize base scale at start
                            if abs(pinchBaseScale - 1.0) < 1e-6 {
                                pinchBaseScale = value
                                return
                            }
                            
                            let incremental = Double(value / pinchBaseScale)
                            pinchBaseScale = value
                            
                            // Zoom around gesture midpoint (use center if multiple fingers)
                            // SwiftUI doesn't expose touch positions directly, so default to center
                            let anchor = CGPoint(x: 0.5, y: 0.5)
                            viewport.zoom(factor: incremental, anchor: anchor)
                            scheduleRender(size: current_size)
                        }
                        .onEnded { _ in
                            isInteracting = false
                            pinchBaseScale = 1.0
                            render(size: geo.size)
                        }
                    /*
                        .onEnded { value in
                            // Final adjustment
                            let finalIncrement = Double(value / pinchBaseScale)
                            let anchor = CGPoint(x: 0.5, y: 0.5)
                            viewport.zoom(factor: finalIncrement, anchor: anchor)
                            
                            viewport = viewport.fitted(to: geo.size)
                            pinchBaseScale = 1.0
                        }
                     */
                )
            )

            
        }
    }
    
    private func drawCanvas(context: GraphicsContext, size: CGSize) {
        guard let img = cgImage else {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            return
        }
        #if os(iOS)
        let uiImage = UIImage(cgImage: img)
        let image = Image(uiImage: uiImage)
        #elseif os(macOS)
        let image = Image(nsImage: NSImage(cgImage: img, size: .zero))
        #endif
        context.draw(image, in: CGRect(origin: .zero, size: size))
    }
 
    
    private func scheduleRender(size: CGSize, delay: TimeInterval = 0.05) {
        // Cancel any pending render
        renderWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            self.render(size: size)
        }
        
        renderWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }



    // MARK: - Rendering
    private func render(size: CGSize) {
        let scale: CGFloat = isInteracting ? 0.5 : 1.0
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        guard width > 0 && height > 0 else { return }
        let iterations = isInteracting ? 64 : maxIter
        
        let fittedViewport = viewport.fitted(to: size)
        
        displayedBounds = (
            xmin: fittedViewport.xRange.lowerBound,
            xmax: fittedViewport.xRange.upperBound,
            ymin: fittedViewport.yRange.lowerBound,
            ymax: fittedViewport.yRange.upperBound
        )
        
        var palette = settings.selectedPalette
        let fractalCopy = settings.selectedFractal
        
        palette.buildLookup(maxIterations: iterations)
                
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool { //to deallocated memory
                //let start = CFAbsoluteTimeGetCurrent()
                let start = DispatchTime.now()
                
                var buffer = [Int](repeating: 0, count: width * height)
                
                fractalCopy.compute(
                    width: width,
                    height: height,
                    buffer: &buffer,
                    maxIterations: iterations,
                    xRange: fittedViewport.xRange,
                    yRange: fittedViewport.yRange
                )
                
                guard let img = FractalCanvasView.makeImage(
                               width: width,
                               height: height,
                               buffer: buffer,
                               palette: palette
                           )else {
                               return
                           }
                 
                 // Update UI on main thread, Render took 94.33 ms (fps: 10.60)
                 let end = DispatchTime.now()
                 let elapsed = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) * 1e-6
                 print(String(format: "Render took %.2f ms (fps: %.2f)", elapsed, 1000.0 / elapsed))
                 
                 DispatchQueue.main.async {
                     self.cgImage = img
                 }
            }
        }
    }
 
    // MARK: - Make Image
    private static func makeImage(width: Int, height: Int, buffer: [Int], palette: Palette) -> CGImage? {
        guard width * height == buffer.count else { return nil }
        
        var pixels = [UInt8](repeating: 0, count: buffer.count * 4)

        for i in 0..<buffer.count {
            let iter = buffer[i]
            let color = palette.colorUInt(for: iter)
            let (r, g, b) = palette.to_rgb(color)
            let idx = i * 4
            pixels[idx] = r
            pixels[idx+1] = g
            pixels[idx+2] = b
            pixels[idx+3] = 255
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
