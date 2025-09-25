// File: SettingsHelpView.swift
import SwiftUI

struct SettingsHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings").font(.title).bold()
                Text("**Fractal:** Choose which fractal set to explore.")
                Text("**Palette:** Select the color scheme used for rendering the fractal.")
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
