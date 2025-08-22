import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            FractalCanvasView()
                .navigationTitle("Fractal Explorer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Reset") { /* … */ }
                        Spacer()
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }
}

// Fractal definition
struct Fractal {
    let name: String
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    
    static let mandelbrot = Fractal(
        name: "Mandelbrot",
        xRange: -2.5...1.0,
        yRange: -1.0...1.0
    )
}


// MARK: - Canvas-based Fractal View
struct FractalCanvasView: View {
    @State private var cgImage: CGImage? = nil
    @State private var lastSize: CGSize = .zero
    
    var fractal = Fractal.mandelbrot
    @State private var palette: Palette = {
        var p = Palette(name: "Greyscale", colors: ["000000","FFFFFF"])
        p.initializeTable()
        return p
    }()
    
    let maxIter = 50
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, canvasSize in
                if let img = cgImage {
                    context.draw(Image(img, scale: 1, label: Text("")), in: CGRect(origin: .zero, size: canvasSize))
                } else {
                    context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(.black))
                }
            }
            .onChange(of: geo.size) { newSize in
                let width = Int(newSize.width)
                let height = Int(newSize.height)
                
                guard width > 0, height > 0, newSize != lastSize else { return }
                lastSize = newSize
                
                // build lookup table
                var p = palette
                p.buildLookup(maxIterations: maxIter)
                
                DispatchQueue.global(qos: .userInitiated).async {
                    if let img = renderFractal(width: width, height: height, fractal: fractal, palette: p, maxIter: maxIter) {
                        DispatchQueue.main.async {
                            self.cgImage = img
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Fractal rendering
    func renderFractal(width: Int, height: Int, fractal: Fractal, palette: Palette, maxIter: Int) -> CGImage? {
        let canvasAspect = Double(width)/Double(height)
        let fractalAspect = (fractal.xRange.upperBound - fractal.xRange.lowerBound) /
                            (fractal.yRange.upperBound - fractal.yRange.lowerBound)
        
        var xmin = fractal.xRange.lowerBound
        var xmax = fractal.xRange.upperBound
        var ymin = fractal.yRange.lowerBound
        var ymax = fractal.yRange.upperBound
        
        if canvasAspect > fractalAspect {
            // pad horizontally
            let w = (ymax - ymin) * canvasAspect
            let xc = (xmin+xmax)/2
            xmin = xc - w/2
            xmax = xc + w/2
        } else {
            // pad vertically
            let h = (xmax - xmin)/canvasAspect
            let yc = (ymin+ymax)/2
            ymin = yc - h/2
            ymax = yc + h/2
        }
        
        var pixels = [UInt8](repeating: 0, count: width*height*4)
        
        for y in 0..<height {
            for x in 0..<width {
                let cx = xmin + (xmax - xmin) * Double(x)/Double(width)
                let cy = ymin + (ymax - ymin) * Double(y)/Double(height)
                var zx = 0.0
                var zy = 0.0
                var iter = 0
                while zx*zx + zy*zy < 4.0 && iter < maxIter {
                    let temp = zx*zx - zy*zy + cx
                    zy = 2.0 * zx * zy + cy
                    zx = temp
                    iter += 1
                }
                
                let offset = (y*width + x)*4
                
                let my_color = palette.colorUInt(for: iter, maxIterations: maxIter)
                let (r,g,b) = palette.to_rgb(my_color)
                pixels[offset]   = r
                pixels[offset+1] = g
                pixels[offset+2] = b
                pixels[offset+3] = 255
                /*
                let uiColor = palette.color(for: iter, maxIterations: maxIter)
                var r: CGFloat=0, g: CGFloat=0, b: CGFloat=0, a: CGFloat=0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                pixels[offset]   = UInt8(r*255)
                pixels[offset+1] = UInt8(g*255)
                pixels[offset+2] = UInt8(b*255)
                pixels[offset+3] = 255
                */
            }
        }
        
        guard let provider = CGDataProvider(data: NSData(bytes: &pixels, length: pixels.count)) else { return nil }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width*4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

