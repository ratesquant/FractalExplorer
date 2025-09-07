//
//  FractalBase.swift
//  FractalExplorer
//
//  Created by Alex Сhirokov on 8/24/25.
//

import SwiftUI
import Metal
import MetalKit

struct FractalParams {
    var width: UInt32
    var height: UInt32
    var maxIterations: UInt32
    var xmin: Float
    var ymin: Float
    var dx: Float
    var dy: Float
}

struct FractalRegistry {
    static let all: [String: FractalBase] = [
        "Mandelbrot": FractalMandelbrot(),
        "MandelbrotGPU": FractalMandelbrotGPU(),
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


final class FractalMandelbrotGPU: FractalBase {
    let name = "Mandelbrot"
    let xRange: ClosedRange<Double> = -2.5...1.0
    let yRange: ClosedRange<Double> = -1.0...1.0

    // Cache GPU objects
    private static var device: MTLDevice? = MTLCreateSystemDefaultDevice()
    private static var commandQueue: MTLCommandQueue? = device?.makeCommandQueue()
    private static var pipelineState: MTLComputePipelineState? = {
        guard let library = device?.makeDefaultLibrary(),
              let kernel = library.makeFunction(name: "mandelbrotKernel") else { return nil }
        return try? device?.makeComputePipelineState(function: kernel)
    }()

    func compute(width: Int,
                 height: Int,
                 buffer: inout [Int],
                 maxIterations: Int,
                 xRange: ClosedRange<Double>,
                 yRange: ClosedRange<Double>) {

        guard let device = Self.device,
              let queue = Self.commandQueue,
              let pipeline = Self.pipelineState else {
            // fallback to CPU if Metal not available
            return computeCPU(width: width, height: height, buffer: &buffer,
                              maxIterations: maxIterations,
                              xRange: xRange, yRange: yRange)
        }

        let bufferSize = width * height * MemoryLayout<Int32>.stride
        guard let metalBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared) else { return }        
      
        let params = FractalParams(
            width: UInt32(width),
            height: UInt32(height),
            maxIterations: UInt32(maxIterations),
            xmin: Float(xRange.lowerBound),
            ymin: Float(yRange.lowerBound),
            dx: Float((xRange.upperBound - xRange.lowerBound)/Double(width)),
            dy: Float((yRange.upperBound - yRange.lowerBound)/Double(height))
        )

        
        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(metalBuffer, offset: 0, index: 0)

        var paramsCopy = params
        encoder.setBytes(&paramsCopy, length: MemoryLayout<FractalParams>.stride, index: 1)

        let threadsPerThreadgroup = MTLSizeMake(16, 16, 1)
        let threadgroups = MTLSize(
            width: (width + 15)/16,
            height: (height + 15)/16,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let data = metalBuffer.contents().bindMemory(to: Int32.self, capacity: width * height)
        for i in 0..<(width*height) { buffer[i] = Int(data[i]) }
    }

    private func computeCPU(width: Int,
                            height: Int,
                            buffer: inout [Int],
                            maxIterations: Int,
                            xRange: ClosedRange<Double>,
                            yRange: ClosedRange<Double>) {
        let fractal = FractalMandelbrot()
        
        fractal.compute(
            width: width,
            height: height,
            buffer: &buffer,
            maxIterations: maxIterations,
            xRange: xRange,
            yRange: xRange
        )
    }
}

