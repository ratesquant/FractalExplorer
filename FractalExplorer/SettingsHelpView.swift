// File: SettingsHelpView.swift
import SwiftUI

struct SettingsHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Fractal Explorer").font(.title).bold()
                Text("Explore a variety of fractals with stunning detail. Fractal Explorer supports both GPU and CPU calculations: GPU provides fast rendering, while CPU allows for extremely high zoom levels (but is slower). Customize color palettes for unique, visually striking images.").font(.body)
                
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                }
                
                Text("Settings").font(.title).bold()
                Text("**Fractal:** Choose which fractal set to explore.")
                Text("**Palette:** Select the color scheme used for rendering the fractal. The stable region is always black.")
                Text("**Interpolate Palette:** Smoothly blends between palette colors for a gradient effect.")
                Text("**Invert Palette:** Reverses the order of colors in the palette.")
                Text("**Histogram Colors:** Applies coloring based on histogram data for enhanced fractal detail.")
                Text("Use these options in the Settings screen to customize your fractal exploration experience.")
            }
            .padding()
        }
        .navigationTitle("About Fractal Explorer")
    }
}

#Preview {
    SettingsHelpView()
}
