//
//  SettingsView.swift
//  FractalExplorer
//
//  Created by Alex Chirokov on 8/14/25.
//

import SwiftUI

class SettingsModel: ObservableObject {
    private var default_palette = Palette(name: "Greyscale", colors: ["000000","FFFFFF"])
    
    @Published var palettes: [String: Palette] = [:]
    @Published var selectedName: String = "" {
        didSet {
            UserDefaults.standard.set(selectedName, forKey: "defaultPaletteName")
        }
    }
    
    var selectedPalette: Palette {
        palettes[selectedName] ?? default_palette
    }
    
    init() {
        self.palettes = loadPalettes()
        
        // Restore saved selection from UserDefaults
        if let savedName = UserDefaults.standard.string(forKey: "defaultPaletteName"),
           palettes.keys.contains(savedName) {
            self.selectedName = savedName
        } else if let first = palettes.keys.first {
            self.selectedName = first
        } else {
            // Fallback if no palettes exist
            self.palettes = [default_palette.name: default_palette]
            self.selectedName = default_palette.name
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
                    Picker("Palette", selection: $settings.selectedName) {
                        ForEach(Array(settings.palettes.keys), id: \.self) { name in
                            Text(name).tag(name)
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
