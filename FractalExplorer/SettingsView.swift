//
//  SettingsView.swift
//  FractalExplorer
//
//  Created by Alex Chirokov on 8/14/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var fractalType = "Mandelbrot"
    @State private var selectedPaletteIndex = 0
    @State private var palettes: [Palette] = []

    var body: some View {
        Form {
            Section(header: Text("Fractal Type")) {
                Picker("Type", selection: $fractalType) {
                    Text("Mandelbrot").tag("Mandelbrot")
                    Text("Julia").tag("Julia")
                    Text("Burning Ship").tag("Burning Ship")
                }
            }

            Section(header: Text("Color Palette")) {
                if palettes.isEmpty {
                    Text("Loading palettes...")
                } else {
                    Picker("Palette", selection: $selectedPaletteIndex) {
                        ForEach(0..<palettes.count, id: \.self) { i in
                            Text(palettes[i].name)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            loadAndInitializePalettes()
        }
    }

    private func loadAndInitializePalettes() {
        var loaded = loadPalettes()
        for i in 0..<loaded.count {
            loaded[i].initializeTable()
        }
        palettes = loaded
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
