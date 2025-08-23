//
//  SettingsView.swift
//  FractalExplorer
//
//  Created by Alex Chirokov on 8/14/25.
//

import SwiftUI

import SwiftUI

class SettingsModel: ObservableObject {
    @Published var palettes: [Palette] = []
    @Published var selectedIndex: Int = 0 {
        didSet {
            guard palettes.indices.contains(selectedIndex) else { return }
            palettes[selectedIndex].initializeTable()
        }
    }

    var selectedPalette: Palette {
        palettes[selectedIndex]
    }

    init() {
        let loaded = loadPalettes()
        self.palettes = loaded

        if !loaded.isEmpty {
            // initialize the first palette by default
            self.selectedIndex = 0
            palettes[0].initializeTable()
        } else {
            // fallback if JSON empty
            let fallback = Palette(name: "Greyscale", colors: ["000000","FFFFFF"])
            var array = [fallback]
            array[0].initializeTable()
            self.palettes = array
            self.selectedIndex = 0
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsModel
    @State private var fractalType = "Mandelbrot"

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
                if settings.palettes.isEmpty {
                    Text("Loading palettes...")
                } else {
                    Picker("Palette", selection: $settings.selectedIndex) {
                                        ForEach(settings.palettes.indices, id: \.self) { index in
                                            Text(settings.palettes[index].name).tag(index)
                                        }
                                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsModel())
    }
}
