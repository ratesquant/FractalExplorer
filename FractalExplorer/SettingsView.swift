//
//  SettingsView.swift
//  FractalExplorer
//
//  Created by Alex Chirokov on 8/14/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var fractalType = "Mandelbrot"
    @State private var baseColor: Color = .blue

    var body: some View {
        Form {
            Section(header: Text("Fractal Type")) {
                Picker("Type", selection: $fractalType) {
                    Text("Mandelbrot").tag("Mandelbrot")
                    Text("Julia").tag("Julia")
                    Text("Burning Ship").tag("Burning Ship")
                }
            }
            Section(header: Text("Color Scheme")) {
                ColorPicker("Base Color", selection: $baseColor)
            }
        }
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
