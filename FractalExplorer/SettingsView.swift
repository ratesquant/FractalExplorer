//
//  SettingsView.swift
//  FractalExplorer
//
//  Created by Alex Chirokov on 8/14/25.
//

import SwiftUI

class SettingsModel: ObservableObject {
    private var default_palette = Palette(name: "Greyscale", colors: ["000000","FFFFFF"])
    private var default_fractal = FractalMandelbrot()
    
    @Published var palettes: [String: Palette] = [:]
    @Published var selectedPaletteName: String = "" {
        didSet {
            UserDefaults.standard.set(selectedPaletteName, forKey: "defaultPaletteName")
        }
    }
    
    @Published var fractals: [String: FractalBase] = FractalRegistry.all
    @Published var selectedFractalName: String = "" {
            didSet {
                UserDefaults.standard.set(selectedFractalName, forKey: "defaultFractalName")
            }
        }
    
    var selectedPalette: Palette {
        palettes[selectedPaletteName] ?? default_palette
    }
    
    var selectedFractal: FractalBase {
        fractals[selectedFractalName] ?? default_fractal
    }
    
    
    
    init() {
        self.palettes = loadPalettes()
        
        // Restore saved selection from UserDefaults
        if let savedPaletteName = UserDefaults.standard.string(forKey: "defaultPaletteName"),
           palettes.keys.contains(savedPaletteName) {
            self.selectedPaletteName = savedPaletteName
        } else if let first = palettes.keys.first {
            self.selectedPaletteName = first
        } else {
            // Fallback if no palettes exist
            self.palettes = [default_palette.name: default_palette]
            self.selectedPaletteName = default_palette.name
        }
        
        if let savedFractalName = UserDefaults.standard.string(forKey: "defaultFractalName"),
           fractals.keys.contains(savedFractalName) {
            self.selectedFractalName = savedFractalName
        } else if let first = fractals.keys.first {
            self.selectedFractalName = first
        }else {
            self.fractals = [default_fractal.name: default_fractal]
            self.selectedFractalName = default_fractal.name
        }
    }
}



struct SettingsView: View {
    @EnvironmentObject var settings: SettingsModel

    var body: some View {
        Form {
            Section(header: Text("Fractal")) {
                if settings.fractals.isEmpty {
                    Text("Loading fractals...")
                } else {
                    Picker("Fractal", selection: $settings.selectedFractalName) {
                        ForEach(Array(settings.fractals.keys), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            Section(header: Text("Color Palette")) {
                if settings.palettes.isEmpty {
                    Text("Loading palettes...")
                } else {
                    Picker("Palette", selection: $settings.selectedPaletteName) {
                        ForEach(Array(settings.palettes.keys), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }//palette
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
