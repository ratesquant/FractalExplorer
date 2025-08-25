//
//  FractalExplorerUITests.swift
//  FractalExplorerUITests
//
//  Created by Alex Chirokov on 8/14/25.
//

import XCTest
@testable import FractalExplorer
import SwiftUI

final class FractalExplorerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    /*
    func testFractalRenderPerformance() throws {
        // Typical iPhone 15 Pro screen resolution (portrait)
        let width = 2556
        let height = 1179
        
        let fractal = Fractal.mandelbrot

        let grayscalePalette = Palette(name: "Grayscale", colors: ["#000000", "#FFFFFF"] )
        
        let maxIter = 100
        
        var paletteCopy = grayscalePalette
        paletteCopy.buildLookup(maxIterations: maxIter)

        measure {
            
            let image = FractalCanvasView.renderFractal(
               width: width,
               height: height,
               fractal: fractal,
               palette: paletteCopy,
               maxIter: maxIter
           )
           
           XCTAssertNotNil(image, "Fractal render should produce a CGImage")
            
        }
    }*/

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
