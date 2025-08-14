//
//  ContentView.swift
//  FractalExplorer
//
//  Created by Alex Chirokov on 8/14/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            FractalView()
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

struct FractalView: View {
    @State private var image: Image? = nil

    var body: some View {
        ZStack {
            if let img = image {
                img
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                ProgressView("Rendering…")
            }
        }
        .onAppear {
            renderFractal()
        }
    }

    func renderFractal() {
        let width = 400
        let height = 400
        let maxIter = 100
        let xmin = -2.0, xmax = 1.0
        let ymin = -1.5, ymax = 1.5

        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let cx = xmin + (xmax - xmin) * Double(x) / Double(width)
                let cy = ymin + (ymax - ymin) * Double(y) / Double(height)
                var zx = 0.0
                var zy = 0.0
                var iter = 0
                while zx*zx + zy*zy < 4.0 && iter < maxIter {
                    let temp = zx*zx - zy*zy + cx
                    zy = 2.0 * zx * zy + cy
                    zx = temp
                    iter += 1
                }
                let offset = (y * width + x) * 4
                let color = UInt8(Double(iter) / Double(maxIter) * 255.0)
                pixels[offset] = color     // R
                pixels[offset+1] = 0       // G
                pixels[offset+2] = 255-color // B
                pixels[offset+3] = 255     // A
            }
        }

        if let cgImage = pixelsToCGImage(pixels: pixels, width: width, height: height) {
            image = Image(decorative: cgImage, scale: 1.0)
        }
    }

    func pixelsToCGImage(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let providerRef = CGDataProvider(data: NSData(bytes: pixels, length: pixels.count) )
        return CGImage(width: width,
                       height: height,
                       bitsPerComponent: 8,
                       bitsPerPixel: 32,
                       bytesPerRow: width * 4,
                       space: colorSpace,
                       bitmapInfo: bitmapInfo,
                       provider: providerRef!,
                       decode: nil,
                       shouldInterpolate: true,
                       intent: .defaultIntent)
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
