//
//  Palette.swift
//  FractalExplorer
//
//  Created by Alex Сhirokov on 8/21/25.
//

//import Foundation

import SwiftUI

struct Palette: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let colors: [String]
    
    private(set) var colorTable: [UInt32] = [] // converted UInt32s
    private(set) var lookupTable: [UInt32] = [] // precomputed per iteration

    enum CodingKeys: String, CodingKey {
        case name, colors
    }
    
    // Custom initializer
    init(id: UUID = UUID(), name: String, colors: [String]) {
        self.id = id
        self.name = name
        self.colors = colors
        self.colorTable = Palette.makeColorTable(from: colors)
    }
    
    init(from decoder: Decoder) throws {
         let container = try decoder.container(keyedBy: CodingKeys.self)
         self.id = UUID()
         self.name = try container.decode(String.self, forKey: .name)
         self.colors = try container.decode([String].self, forKey: .colors)
         self.colorTable = Palette.makeColorTable(from: colors)
     }
 
    // Utility to build color table from hex strings
    private static func makeColorTable(from colors: [String]) -> [UInt32] {
      return colors.compactMap { hexString in
          let cleanedHex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
          var value: UInt64 = 0
          let scanner = Scanner(string: cleanedHex)
          guard scanner.scanHexInt64(&value) else { return nil }
          return UInt32(value)
      }
    }
    
   
    mutating func buildLookup(maxIterations: Int) {
        guard !colorTable.isEmpty, lookupTable.count != maxIterations  else { return }
        let scale = 1.0 / Double(maxIterations - 1)
        lookupTable = (0..<maxIterations).map { i in
                let t = Double(i) * scale
                return interpolatedColor(at: t)
            }
        }

   
    // Linear interpolation in floating-point, returns UInt32 RGB
        private func interpolatedColor(at t: Double) -> UInt32 {
            guard !colorTable.isEmpty else { return 0x000000 }
            
            let clampedT = max(0, min(1, t))
            let scaled = clampedT * Double(colorTable.count - 1)
            let i = Int(floor(scaled))
            let j = min(i+1, colorTable.count-1)
            let frac = CGFloat(scaled - Double(i))
            
            let c1 = colorTable[i]
            let c2 = colorTable[j]
            
            let r = UInt8((CGFloat((c1 >> 16) & 0xFF) + (CGFloat((c2 >> 16) & 0xFF) - CGFloat((c1 >> 16) & 0xFF)) * frac))
            let g = UInt8((CGFloat((c1 >> 8) & 0xFF) + (CGFloat((c2 >> 8) & 0xFF) - CGFloat((c1 >> 8) & 0xFF)) * frac))
            let b = UInt8((CGFloat(c1 & 0xFF) + (CGFloat(c2 & 0xFF) - CGFloat(c1 & 0xFF)) * frac))
            
            return from_rgb(r: r, g: g, b: b)
        }
    
    private func from_rgb(r: UInt8, g: UInt8, b: UInt8) -> UInt32 {
            return (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
        }
        
   
    func to_rgb(_ color: UInt32) -> (r: UInt8, g: UInt8, b: UInt8) {
          let r = UInt8((color >> 16) & 0xFF)
          let g = UInt8((color >> 8) & 0xFF)
          let b = UInt8(color & 0xFF)
          return (r,g,b)
      }
    
    
    func colorUInt(for iteration: Int) -> UInt32 {
         guard !lookupTable.isEmpty,
               iteration >= 0,
               iteration < lookupTable.count else { return 0x000000 }
         return lookupTable[iteration]
     }
   /*
    func colorComponents(for iteration: Int, maxIterations: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        return extractRGB(colorUInt(for iteration, maxIterations: maxIterations))
    }*/
    
}

func loadPalettes_ex() -> [Palette] {
    guard let url = Bundle.main.url(forResource: "palettes", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let palettes = try? JSONDecoder().decode([Palette].self, from: data)
    else {
        print("Failed to load palettes.json")
        return []
    }
    return palettes
}

func loadPalettes_array() -> [Palette] {
    guard let url = Bundle.main.url(forResource: "palettes", withExtension: "json") else {
        print("Cannot find palettes.json in bundle")
        return []
    }
    
    guard let data = try? Data(contentsOf: url) else {
        print("Cannot read palettes.json data")
        return []
    }
    // print the raw JSON
    //print(String(data: data, encoding: .utf8) ?? "Invalid UTF8")
    
    guard let palettes = try? JSONDecoder().decode([Palette].self, from: data) else {
        print("Failed to decode palettes.json")
        return []
    }
    
    return palettes
}

func loadPalettes() -> [String: Palette] {
    guard let url = Bundle.main.url(forResource: "palettes", withExtension: "json") else {
        print("Cannot find palettes.json in bundle")
        return [:]
    }
    
    guard let data = try? Data(contentsOf: url) else {
        print("Cannot read palettes.json data")
        return [:]
    }
    
    do {
        let paletteArray = try JSONDecoder().decode([Palette].self, from: data)
        // Convert into dictionary using name as the key
        let paletteDict = Dictionary(uniqueKeysWithValues: paletteArray.map { ($0.name, $0) })
        return paletteDict
    } catch {
        print("Failed to decode palettes.json: \(error)")
        return [:]
    }
}

