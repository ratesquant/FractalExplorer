import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            FractalCanvasView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Reset") {viewport = .mandelbrotDefault }
                        Spacer()
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }
}

struct FractalViewport: Equatable {
    var centerX: Double
    var centerY: Double
    var scale: Double   // 1.0 = default zoom, <1 = zoomed out (not allowed), >1 = zoomed in
    
    static let mandelbrotDefault = FractalViewport(centerX: -0.5, centerY: 0.0, scale: 1.0)
}

struct FractalCanvasView: View {
    @Binding var viewport: FractalViewport
    @EnvironmentObject var settings: SettingsModel

    @State private var cgImage: CGImage? = nil
    @State private var lastSize: CGSize = .zero
    @State private var displayedBounds: (xmin: Double, xmax: Double, ymin: Double, ymax: Double)? = nil

    @State private var lastDragValue: DragGesture.Value? = nil
    @State private var magnifyStart: Double? = nil

    private var fractal: FractalBase = FractalMandelbrot()
    private let maxIter = 50
    private var buffer: [Int] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Draw fractal image
                Canvas { context, canvasSize in
                    if let img = cgImage {
                        context.draw(
                            Image(decorative: img, scale: 1.0),
                            in: CGRect(origin: .zero, size: canvasSize)
                        )
                    } else {
                        context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(.black))
                    }
                }

                // HUD overlay
                if let b = displayedBounds {
                    VStack {
                        Spacer()
                        Text(hudText(bounds: b))
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
                if geo.size != .zero {
                    lastSize = geo.size
                    render(size: geo.size)
                }
            }
            .onChange(of: geo.size) { newSize in
                if newSize != lastSize && newSize.width > 0 && newSize.height > 0 {
                    lastSize = newSize
                    render(size: newSize)
                }
            }
            .onChange(of: settings.selectedPalette) { _ in
                render(size: lastSize)
            }
            .onChange(of: viewport) { _ in
                render(size: lastSize)
            }
            // Pan
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let dx = value.translation.width - (lastDragValue?.translation.width ?? 0)
                        let dy = value.translation.height - (lastDragValue?.translation.height ?? 0)
                        lastDragValue = value

                        let fitted = FractalCanvasView.fittedBounds(
                            for: fractal,
                            canvasWidth: Int(geo.size.width),
                            canvasHeight: Int(geo.size.height)
                        )
                        let spanX = (fitted.xmax - fitted.xmin) / viewport.scale
                        let spanY = (fitted.ymax - fitted.ymin) / viewport.scale

                        viewport.centerX -= Double(dx) / Double(geo.size.width) * spanX
                        viewport.centerY += Double(dy) / Double(geo.size.height) * spanY
                    }
                    .onEnded { _ in lastDragValue = nil }
            )
            // Pinch zoom
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        if magnifyStart == nil { magnifyStart = viewport.scale }
                        viewport.scale = max(1.0, (magnifyStart ?? viewport.scale) * value)
                    }
                    .onEnded { _ in magnifyStart = nil }
            )
        }
    }

    // MARK: - Rendering
    private func render(size: CGSize) {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else { return }

        let bounds = viewportBounds(for: fractal, viewport: viewport, canvasWidth: width, canvasHeight: height)
        displayedBounds = bounds

        var palette = settings.selectedPalette
        palette.buildLookup(maxIterations: maxIter)

        // Ensure buffer is large enough
        if buffer.count < width * height {
            buffer = Array(repeating: 0, count: width * height)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Compute fractal iteration counts
            fractal.compute(
                width: width,
                height: height,
                buffer: &buffer,
                maxIterations: maxIter,
                xmin: bounds.xmin,
                xmax: bounds.xmax,
                ymin: bounds.ymin,
                ymax: bounds.ymax
            )

            // Convert buffer to CGImage
            if let img = FractalCanvasView.makeImage(
                width: width,
                height: height,
                buffer: buffer,
                palette: palette,
                maxIter: maxIter
            ) {
                DispatchQueue.main.async {
                    cgImage = img
                }
            }
        }
    }

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

        guard let provider = CGDataProvider(data: NSData(bytes: &pixels, length: pixels.count)) else {
            return nil
        }

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

    // MARK: - Bounds
    private func viewportBounds(for fractal: FractalBase, viewport: FractalViewport, canvasWidth: Int, canvasHeight: Int) -> (xmin: Double, xmax: Double, ymin: Double, ymax: Double) {
        let fitted = FractalCanvasView.fittedBounds(for: fractal, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        let spanX = (fitted.xmax - fitted.xmin) / viewport.scale
        let spanY = (fitted.ymax - fitted.ymin) / viewport.scale

        return (
            xmin: viewport.centerX - spanX/2,
            xmax: viewport.centerX + spanX/2,
            ymin: viewport.centerY - spanY/2,
            ymax: viewport.centerY + spanY/2
        )
    }

    static func fittedBounds(for fractal: FractalBase, canvasWidth: Int, canvasHeight: Int) -> (xmin: Double, xmax: Double, ymin: Double, ymax: Double) {
        let canvasAspect = Double(canvasWidth) / Double(canvasHeight)
        let baseXmin = fractal.xRange.lowerBound
        let baseXmax = fractal.xRange.upperBound
        let baseYmin = fractal.yRange.lowerBound
        let baseYmax = fractal.yRange.upperBound
        var xmin = baseXmin, xmax = baseXmax, ymin = baseYmin, ymax = baseYmax
        let fractalAspect = (baseXmax - baseXmin) / (baseYmax - baseYmin)

        if canvasAspect > fractalAspect {
            let h = (baseYmax - baseYmin)
            let w = h * canvasAspect
            let xc = (baseXmin + baseXmax)/2
            xmin = xc - w/2
            xmax = xc + w/2
        } else {
            let w = (baseXmax - baseXmin)
            let h = w / canvasAspect
            let yc = (baseYmin + baseYmax)/2
            ymin = yc - h/2
            ymax = yc + h/2
        }
        return (xmin, xmax, ymin, ymax)
    }

    // MARK: - HUD text
    private func hudText(bounds: (xmin: Double, xmax: Double, ymin: Double, ymax: Double)) -> String {
        let baseXSpan = fractal.xRange.upperBound - fractal.xRange.lowerBound
        let curXSpan = bounds.xmax - bounds.xmin
        let zoom = baseXSpan / curXSpan
        let xText = "[\(sci2(bounds.xmin)), \(sci2(bounds.xmax))]"
        let yText = "[\(sci2(bounds.ymin)), \(sci2(bounds.ymax))]"
        return "\(fractal.name) • ×\(sig1(zoom)) • x:\(xText) y:\(yText)"
    }

    private func sig1(_ x: Double) -> String { String(format: "%.1g", x) }
    private func sci2(_ x: Double) -> String { String(format: "%.1e", x) }
}
