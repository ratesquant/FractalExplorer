//
//  FractalBase.swift
//  FractalExplorer
//
//  Created by Alex Сhirokov on 8/24/25.
//

import SwiftUI

struct FractalRegistry {
    static let all: [String: FractalBase] = [
        "Mandelbrot": FractalMandelbrot()
        // later: "Julia": FractalJulia(), etc.
    ]
    
    static var names: [String] {
        Array(all.keys).sorted()
    }
}


// MARK: - Abstract Fractal Base, to add new fractals (just implement protocol + add to registry).
protocol FractalBase {
    var name: String { get }
    var xRange: ClosedRange<Double> { get }
    var yRange: ClosedRange<Double> { get }
    
    func compute(width: Int,
                 height: Int,
                 buffer: inout [Int],
                 maxIterations: Int,
                 xRange: ClosedRange<Double>,
                 yRange: ClosedRange<Double>)
    
    var aspectRatio: Double { get }
}

extension FractalBase {
    var aspectRatio: Double {
        let dx = xRange.upperBound - xRange.lowerBound
        let dy = yRange.upperBound - yRange.lowerBound
        return dx / dy
    }
}

final class FractalMandelbrot: FractalBase {
    let name = "Mandelbrot"
    // Default initial ranges (you can change these if you prefer)
    let xRange: ClosedRange<Double> = -2.5...1.0
    let yRange: ClosedRange<Double> = -1.0...1.0

    func compute(width: Int,
                 height: Int,
                 buffer: inout [Int],
                 maxIterations: Int,
                 xRange: ClosedRange<Double>,
                 yRange: ClosedRange<Double>) {

        precondition(width > 0 && height > 0, "Invalid size")
        precondition(buffer.count >= width * height, "Buffer too small for given resolution")

        let xmin = xRange.lowerBound
        let ymin = yRange.lowerBound
        
        // map resolution -> continuous increments (pixel centers)
        let dx = (xRange.upperBound - xmin) / Double(width)
        let dy = (yRange.upperBound - ymin) / Double(height)
        
        let xstart = xmin + 0.5 * dx
        let ystart = ymin + 0.5 * dy

        // iterate over pixels
        for py in 0..<height {
            // y coordinate for pixel center
            let y0 = ystart + Double(py) * dy

             let baseIndex = py * width
            for px in 0..<width {
                let x0 = xstart + Double(px) * dx

                var x = 0.0
                var y = 0.0
                var iteration = 0

                /*
                while (x * x + y * y) <= 4.0 && iteration < maxIterations {
                    let xt = x * x - y * y + x0
                    y = 2.0 * x * y + y0
                    x = xt
                    iteration += 1
                }*/
                var x2 = 0.0
                var y2 = 0.0
                var w = 0.0
                //optimized version
                while (x2 + y2 <= 4 && iteration < maxIterations) {
                    x = x2 - y2 + x0
                    y = w - x2 - y2 + y0
                    x2 = x * x
                    y2 = y * y
                    w = (x + y) * (x + y)
                    iteration += 1
                }
                        

                buffer[baseIndex + px] = iteration
            }
        }
    }
}
