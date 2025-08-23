//
//  FractalExplorerApp.swift
//  FractalExplorer
//
//  Created by Alex Chirokov on 8/14/25.
//

import SwiftUI

@main
struct FractalExplorerApp: App {
    @StateObject private var settings = SettingsModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(settings)
        }
    }
}
