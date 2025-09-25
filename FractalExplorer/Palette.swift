//
//  Palette.swift
//  FractalExplorer
//
//  Created by Alex Сhirokov on 8/21/25.
//

import SwiftUI

struct Palette: Codable, Equatable, Identifiable, Hashable {
    // MARK: - Properties
    
    let id: UUID
    let name: String
    let colors: [String]
    
    static let stableColor: UInt32 = 0xFF000000
    
    private(set) var colorTable: [UInt32] = []

    enum CodingKeys: String, CodingKey {
        case name, colors
    }
    
    // MARK: - Initializers
    
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
    
    // MARK: - Color Table Utilities
    
    private static func makeColorTable(from colors: [String]) -> [UInt32] {
        return colors.compactMap { hexString in
            let cleanedHex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
            var value: UInt64 = 0
            let scanner = Scanner(string: cleanedHex)
            guard scanner.scanHexInt64(&value) else { return nil }
            return UInt32(value)
        }
    }
    
    // MARK: - Lookup Table Builders
    
    func buildLookup(maxIterations: Int, invert: Bool = false, interpolate: Bool = true) -> [UInt32] {
        guard maxIterations > 1 else { return [] }
        
        var rawLookup: [UInt32]
        
        if interpolate {
            let scale = 1.0 / Double(maxIterations - 1)
            rawLookup = (0..<maxIterations).map { i in
                let t = Double(i) * scale
                return interpolatedColor(at: t)
            }
        } else {
            guard !colorTable.isEmpty else { return [] }
            rawLookup = (0..<maxIterations).map { i in
                let colorIndex = i % colorTable.count
                return colorTable[colorIndex]
            }
        }
        
        if invert {
            rawLookup = rawLookup.reversed()
        }
        
        return convertLookupToBGRA(rawLookup)
    }
    
    // MARK: - Color Interpolation
    
    private func interpolatedColor(at t: Double) -> UInt32 {
        guard !colorTable.isEmpty else { return 0x000000 }
        
        let clampedT = max(0, min(1, t))
        let scaled = clampedT * Double(colorTable.count - 1)
        let i = Int(floor(scaled))
        let j = min(i + 1, colorTable.count - 1)
        let frac = CGFloat(scaled - Double(i))
        
        let c1 = colorTable[i]
        let c2 = colorTable[j]
        
        let r = UInt8(CGFloat((c1 >> 16) & 0xFF) + (CGFloat((c2 >> 16) & 0xFF) - CGFloat((c1 >> 16) & 0xFF)) * frac)
        let g = UInt8(CGFloat((c1 >> 8) & 0xFF) + (CGFloat((c2 >> 8) & 0xFF) - CGFloat((c1 >> 8) & 0xFF)) * frac)
        let b = UInt8(CGFloat(c1 & 0xFF) + (CGFloat(c2 & 0xFF) - CGFloat(c1 & 0xFF)) * frac)
        
        return fromRgb(r: r, g: g, b: b)
    }
    
    private func fromRgb(r: UInt8, g: UInt8, b: UInt8) -> UInt32 {
        return (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
    }
    
    func toRgb(_ color: UInt32) -> (r: UInt8, g: UInt8, b: UInt8) {
        let r = UInt8((color >> 16) & 0xFF)
        let g = UInt8((color >> 8) & 0xFF)
        let b = UInt8(color & 0xFF)
        return (r, g, b)
    }
    
    /// Convert array of 0xRRGGBB colors to premultiplied BGRA UInt32 values.
    /// Returned integer layout is 0xAARRGGBB (memory bytes [B,G,R,A] little-endian).
    func convertLookupToBGRA(_ lookup: [UInt32]) -> [UInt32] {
        return lookup.map { rgb in
            let r = (rgb >> 16) & 0xFF
            let g = (rgb >> 8) & 0xFF
            let b = rgb & 0xFF
            let a: UInt32 = 0xFF
            
            // premultiply alpha (a is always 255 here, so no effect but kept for correctness)
            let rP = (r * a) / 255
            let gP = (g * a) / 255
            let bP = (b * a) / 255
            
            return (a << 24) | (rP << 16) | (gP << 8) | bP
        }
    }
}

// MARK: - Palette Loading

func loadPalettes_ex() -> [Palette] {
    guard let url = Bundle.main.url(forResource: "palettes", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let palettes = try? JSONDecoder().decode([Palette].self, from: data) else {
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
        let paletteDict = Dictionary(uniqueKeysWithValues: paletteArray.map { ($0.name, $0) })
        return paletteDict
    } catch {
        print("Failed to decode palettes.json: \(error)")
        return [:]
    }
}
