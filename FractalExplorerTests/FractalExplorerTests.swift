//
//  FractalExplorerTests.swift
//  FractalExplorerTests
//
//  Created by Alex Chirokov on 8/14/25.
//

import XCTest
@testable import FractalExplorer

final class PaletteLoaderTests: XCTestCase {
    
    func testLoadPalettesNotEmpty() {
        let palettes = loadPalettes()
        for (name, palette) in palettes {
                print("Palette '\(name)' has \(palette.colors.count) colors")
            }
        XCTAssertFalse(palettes.isEmpty, "Palettes should not be empty")
    }
    
    func testLoadPalettesContainsExpectedKey() {
        let palettes = loadPalettes()
        XCTAssertNotNil(palettes["Greyscale"], "Palettes should contain a 'Greyscale' palette")
    }
    
    func testPaletteHasColors() {
        let palettes = loadPalettes()
        guard let defaultPalette = palettes["Greyscale"] else {
            XCTFail("No Greyscale palette found")
            return
        }
        XCTAssertFalse(defaultPalette.colors.isEmpty, "Greyscale palette should have at least one color")
    }
}

final class FractalExplorerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    
    func testFractalPerformance() throws {
        // Typical iPhone 15 Pro screen resolution (portrait), 0.535 sec
        let width = 2556
        let height = 1179
        let maxIter = 100
        
        let my_fractal = FractalMandelbrot()
          
        var buffer = Array(repeating: 0, count: width * height)

        self.measure {
            my_fractal.compute(
                width: width,
                height: height,
                buffer: &buffer,
                maxIterations: maxIter,
                xRange: my_fractal.xRange,
                yRange: my_fractal.yRange
            )
        }
    }
    
    func testFractalPerformanceGPU() throws {
        // Typical iPhone 15 Pro screen resolution (portrait), 0.214 sec
        let width = 2556
        let height = 1179
        let maxIter = 100
        
        let my_fractal = FractalMandelbrotGPU()
          
        var buffer = Array(repeating: 0, count: width * height)

        self.measure {
            my_fractal.compute(
                width: width,
                height: height,
                buffer: &buffer,
                maxIterations: maxIter,
                xRange: my_fractal.xRange,
                yRange: my_fractal.yRange
            )
        }
    }

}
