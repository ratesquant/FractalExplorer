//
//  PaletteStripView.swift
//  FractalExplorer
//
//  Created by Alex Сhirokov on 9/22/25.
//

import SwiftUI

struct PaletteStripView: View {
    let palette: Palette
    let invert: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = max(Int(geometry.size.width.rounded(.down)), 1)
            let colors = palette.buildLookup(maxIterations: width, invert: invert, interpolate: true)
            HStack(spacing: 0) {
                ForEach(0..<colors.count, id: \.self) { idx in
                    Rectangle()
                        .fill(Color(bgra: colors[idx]))
                        .frame(width: 1, height: 24)
                }
            }
        }
        .cornerRadius(3)
        .frame(maxWidth: .infinity, minHeight: 24)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
    }
}

extension Color {
    init(bgra: UInt32) {
        let b = Double((bgra >> 0) & 0xFF) / 255.0
        let g = Double((bgra >> 8) & 0xFF) / 255.0
        let r = Double((bgra >> 16) & 0xFF) / 255.0
        let a = Double((bgra >> 24) & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
