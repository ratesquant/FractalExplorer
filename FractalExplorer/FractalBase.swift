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
        "Mandelbrot (GPU)": FractalMandelbrotGPU(),
        "Burning Ship": FractalBurningShip(),
        "Burning Ship (GPU)": FractalBurningShipGPU(),
        "Tricorn" : FractalTricorn(),
        "Tricorn (GPU)": FractalTricornGPU(),
        "Newton": FractalNewton(),
        "Julia": FractalJulia(),
        "Test": FractalTest()
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
    var max_iterations: Int { get }
    
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

class FractalGPUBased: FractalBase {
    let name: String
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    let max_iterations: Int
    private let kernelName: String
    private let cpuFallback: FractalBase

    // Shared GPU state
    private static let device: MTLDevice? = MTLCreateSystemDefaultDevice()
    private static let commandQueue: MTLCommandQueue? = device?.makeCommandQueue()

    private lazy var pipelineState: MTLComputePipelineState? = {
        guard let device = Self.device,
              let library = device.makeDefaultLibrary(),
              let kernel = library.makeFunction(name: kernelName)
        else { return nil }
        return try? device.makeComputePipelineState(function: kernel)
    }()

    init(name: String,
         xRange: ClosedRange<Double>,
         yRange: ClosedRange<Double>,
         maxIterations: Int,
         kernelName: String,
         cpuFallback: FractalBase) {
        self.name = name
        self.xRange = xRange
        self.yRange = yRange
        self.max_iterations = maxIterations
        self.kernelName = kernelName
        self.cpuFallback = cpuFallback
    }

    func compute(width: Int,
                 height: Int,
                 buffer: inout [Int],
                 maxIterations: Int,
                 xRange: ClosedRange<Double>,
                 yRange: ClosedRange<Double>) {

        guard let device = Self.device,
              let queue = Self.commandQueue,
              let pipeline = pipelineState else {
            // fallback to CPU if Metal not available
            cpuFallback.compute(width: width, height: height, buffer: &buffer,
                                maxIterations: maxIterations,
                                xRange: xRange, yRange: yRange)
            return
        }

        let bufferSize = width * height * MemoryLayout<Int32>.stride
        guard let metalBuffer = device.makeBuffer(length: bufferSize,
                                                  options: .storageModeShared) else { return }

        var params = FractalParams(
            width: UInt32(width),
            height: UInt32(height),
            maxIterations: UInt32(maxIterations),
            xmin: Float(xRange.lowerBound),
            ymin: Float(yRange.lowerBound),
            dx: Float((xRange.upperBound - xRange.lowerBound) / Double(width)),
            dy: Float((yRange.upperBound - yRange.lowerBound) / Double(height))
        )

        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(metalBuffer, offset: 0, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<FractalParams>.stride, index: 1)

        let threadsPerThreadgroup = MTLSizeMake(16, 16, 1)
        let threadgroups = MTLSize(width: (width + 15)/16,
                                   height: (height + 15)/16,
                                   depth: 1)

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let data = metalBuffer.contents().bindMemory(to: Int32.self, capacity: width * height)
        for i in 0..<(width*height) { buffer[i] = Int(data[i]) }
    }
}

final class FractalJulia: FractalBase {
    let name = "Julia"
    let xRange: ClosedRange<Double> = -2.0...2.0
    let yRange: ClosedRange<Double> = -2.0...2.0

    let exponent: Int = 5
    let independent: Double = 0.481
    let max_iterations: Int = 7
    let threshold: Double = 1e12

    func compute(width: Int,
                 height: Int,
                 buffer: inout [Int],
                 maxIterations: Int,
                 xRange: ClosedRange<Double>,
                 yRange: ClosedRange<Double>) {

        precondition(buffer.count >= width * height)

        let dx = (xRange.upperBound - xRange.lowerBound) / Double(width)
        let dy = (yRange.upperBound - yRange.lowerBound) / Double(height)

        let xStart = xRange.lowerBound + 0.5 * dx
        let yStart = yRange.lowerBound + 0.5 * dy

        var magnitudes = [Double](repeating: 0.0, count: width*height)

        // Step 1: compute magnitudes directly into array
        for py in 0..<height {
            let y0 = yStart + Double(py) * dy
            for px in 0..<width {
                let x0 = xStart + Double(px) * dx
                var x = x0
                var y = y0

                for _ in 0..<maxIterations {
                    let r = hypot(x, y)
                    let theta = atan2(y, x)
                    let rExp = pow(r, Double(exponent))
                    x = rExp * cos(Double(exponent) * theta) + independent
                    y = rExp * sin(Double(exponent) * theta)
                }

                let mag = sqrt(x*x + y*y)
                magnitudes[py*width + px] = mag.isFinite ? min(mag, threshold) : threshold
            }
        }

        // Step 2: quantiles (filter out threshold)
        let good = magnitudes.filter { $0 < threshold }
        let sorted = good.sorted()
        let quantiles: [Double] = (0...maxIterations).map { q in
            let pos = Double(q) / Double(maxIterations) * Double(sorted.count-1)
            return sorted[Int(pos)]
        }

        // Step 3: map magnitudes → bins (binary search)
        for i in 0..<buffer.count {
            let mag = magnitudes[i]
            if mag >= threshold {
                buffer[i] = maxIterations
            } else {
                // binary search
                var lo = 0, hi = quantiles.count-1
                while lo < hi {
                    let mid = (lo+hi)/2
                    if mag > quantiles[mid] { lo = mid+1 }
                    else { hi = mid }
                }
                buffer[i] = lo
            }
        }
    }
}


final class FractalMandelbrot: FractalBase {
    let name = "Mandelbrot"
    // Default initial ranges (you can change these if you prefer)
    let xRange: ClosedRange<Double> = -2.5...1.0
    let yRange: ClosedRange<Double> = -1.0...1.0
    let max_iterations: Int = 512

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
                
                // Speed-up: skip points analytically inside main cardioid or period-2 bulb.
                let q = (x0 - 0.25)*(x0 - 0.25) + y0*y0
                let period2 = (x0 + 1)*(x0 + 1) + y0*y0 < 0.0625
                let cardioid = q * (q + (x0 - 0.25)) < 0.25 * y0*y0
                if cardioid || period2 {
                    buffer[baseIndex + px] = maxIterations
                    continue
                }

                var x = 0.0
                var y = 0.0
                var iteration = 0
 
                var x2 = 0.0
                var y2 = 0.0
                //optimized version
           
                while (x2 + y2 <= 4.0 && iteration < maxIterations) {
                    y = 2 * x * y + y0
                    x = x2 - y2 + x0
                    x2 = x * x
                    y2 = y * y
                    iteration &+= 1  // &+= is faster, avoids overflow checks
                }

                buffer[baseIndex + px] = iteration
            }
        }
    }
}
#if DEBUG
final class FractalTest: FractalBase {
    let name = "Test"
    // Default initial ranges (you can change these if you prefer)
    let xRange: ClosedRange<Double> = -2.5...1.0
    let yRange: ClosedRange<Double> = -1.0...1.0
    let max_iterations: Int = 512

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
                
                // Speed-up: skip points analytically inside main cardioid or period-2 bulb.
                let q = (x0 - 0.25)*(x0 - 0.25) + y0*y0
                let period2 = (x0 + 1)*(x0 + 1) + y0*y0 < 0.0625
                let cardioid = q * (q + (x0 - 0.25)) < 0.25 * y0*y0
                if cardioid || period2 {
                    buffer[baseIndex + px] = maxIterations
                }else
                {
                    buffer[baseIndex + px] = 0
                }
            }
        }
    }
}
#endif // TEST

final class FractalBurningShip: FractalBase {
    let name = "Burning Ship"
    // Default ranges — you can zoom or adjust
    let xRange: ClosedRange<Double> = -2.5...1.0
    let yRange: ClosedRange<Double> = -1.0...1.0
    let max_iterations: Int = 100

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

        let dx = (xRange.upperBound - xmin) / Double(width)
        let dy = (yRange.upperBound - ymin) / Double(height)

        let xstart = xmin + 0.5 * dx
        let ystart = ymin + 0.5 * dy

        for py in 0..<height {
            let y0 = ystart + Double(py) * dy
            let baseIndex = py * width

            for px in 0..<width {
                let x0 = xstart + Double(px) * dx

                var x = 0.0
                var y = 0.0
                var iteration = 0

                while (x * x + y * y <= 4.0) && (iteration < maxIterations) {
                    // Burning Ship: use abs() before squaring
                    let xt = x * x - y * y + x0
                    y = abs(2.0 * x * y) + y0
                    x = abs(xt)
                    iteration += 1
                }

                buffer[baseIndex + px] = iteration
            }
        }
    }
}

final class FractalMandelbrotGPU: FractalGPUBased {
    init() {
        super.init(name: "Mandelbrot (GPU)",
                   xRange: -2.5...1.0,
                   yRange: -1.0...1.0,
                   maxIterations: 512,
                   kernelName: "mandelbrotKernel",
                   cpuFallback: FractalMandelbrot())
    }
}

final class FractalBurningShipGPU: FractalGPUBased {
    init() {
        super.init(name: "Burning Ship (GPU)",
                   xRange: -2.5...1.0,
                   yRange: -1.0...1.0,
                   maxIterations: 100,
                   kernelName: "burningShipKernel",
                   cpuFallback: FractalBurningShip())
    }
}

final class FractalTricornGPU: FractalGPUBased {
    init() {
        super.init(name: "Tricorn (GPU)",
                   xRange: -2.5...2.0,
                   yRange: -1.0...1.0,
                   maxIterations: 512,
                   kernelName: "tricornKernel",
                   cpuFallback: FractalTricorn())
    }
}


/*
final class FractalBurningShipGPU: FractalBase {
        let name = "Burning Ship"
        let xRange: ClosedRange<Double> = -2.5...1.0
        let yRange: ClosedRange<Double> = -1.0...1.0
        let max_iterations: Int = 100

        // Cache GPU objects
        private static var device: MTLDevice? = MTLCreateSystemDefaultDevice()
        private static var commandQueue: MTLCommandQueue? = device?.makeCommandQueue()
        private static var pipelineState: MTLComputePipelineState? = {
            guard let library = device?.makeDefaultLibrary(),
                  let kernel = library.makeFunction(name: "burningShipKernel") else { return nil }
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
            let fractal = FractalBurningShip()
            
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
*/

final class FractalTricorn: FractalBase {
    let name = "Tricorn"
    let xRange: ClosedRange<Double> = -2.5...2.0
    let yRange: ClosedRange<Double> = -1.0...1.0
    let max_iterations: Int = 512

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

        let dx = (xRange.upperBound - xmin) / Double(width)
        let dy = (yRange.upperBound - ymin) / Double(height)

        let xstart = xmin + 0.5 * dx
        let ystart = ymin + 0.5 * dy

        for py in 0..<height {
            let y0 = ystart + Double(py) * dy
            let baseIndex = py * width

            for px in 0..<width {
                let x0 = xstart + Double(px) * dx

                var x = 0.0
                var y = 0.0
                var iteration = 0

                while (x * x + y * y <= 4.0) && (iteration < maxIterations) {
                    // Tricorn: conjugate by flipping sign of y before squaring
                    let xt = x * x - y * y + x0
                    y = -2.0 * x * y + y0
                    x = xt
                    iteration += 1
                }

                buffer[baseIndex + px] = iteration
            }
        }
    }
}

final class FractalNewton: FractalBase {
    let name = "Newton (z^3 - 1)"
    let xRange: ClosedRange<Double> = -2.0...2.0
    let yRange: ClosedRange<Double> = -2.0...2.0
    let max_iterations: Int = 50
    let tolerance: Double = 1e-6
    
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
        
        let dx = (xRange.upperBound - xmin) / Double(width)
        let dy = (yRange.upperBound - ymin) / Double(height)
        
        let xstart = xmin + 0.5 * dx
        let ystart = ymin + 0.5 * dy
        
        // Roots of z^3 - 1 = 0 (cube roots of unity)
        let roots: [(Double, Double)] = [
            (1.0, 0.0),
            (-0.5,  sqrt(3.0) / 2.0),
            (-0.5, -sqrt(3.0) / 2.0)
        ]
        
        for py in 0..<height {
            let y0 = ystart + Double(py) * dy
            let baseIndex = py * width
            
            for px in 0..<width {
                let x0 = xstart + Double(px) * dx
                var x = x0
                var y = y0
                
                var iteration = 0
                var convergedTo = -1
                
                while iteration < maxIterations {
                    // Compute f(z) = z^3 - 1
                    let x2 = x * x
                    let y2 = y * y
                    let twoXY = 2.0 * x * y
                    
                    let fx = x * (x2 - 3 * y2) - 1.0
                    let fy = y * (3 * x2 - y2)
                    
                    // f'(z) = 3z^2
                    let dfx = 3.0 * (x2 - y2)
                    let dfy = 6.0 * x * y
                    
                    // Divide f(z)/f'(z)
                    let denom = dfx * dfx + dfy * dfy
                    if denom == 0 {  break }
                    
                    let ratioX = (fx * dfx + fy * dfy) / denom
                    let ratioY = (fy * dfx - fx * dfy) / denom
                    
                    // Newton step: z = z - f(z)/f'(z)
                    x -= ratioX
                    y -= ratioY
                    
                    // Check convergence to one of the roots
                    for (i, root) in roots.enumerated() {
                        let dxr = x - root.0
                        let dyr = y - root.1
                        if dxr * dxr + dyr * dyr < tolerance {
                            convergedTo = i
                            break
                        }
                    }
                    if convergedTo >= 0 { break }
                    
                    iteration += 1
                }
                
                // Store which root it converged to (or maxIterations if none)
                buffer[baseIndex + px] = (convergedTo >= 0) ? (convergedTo + 1) : 0
            }
        }
    }
}


/*
final class FractalMandelbrotGPU: FractalBase {
    let name = "Mandelbrot"
    let xRange: ClosedRange<Double> = -2.5...1.0
    let yRange: ClosedRange<Double> = -1.0...1.0
    let max_iterations: Int = 512

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
}*/


