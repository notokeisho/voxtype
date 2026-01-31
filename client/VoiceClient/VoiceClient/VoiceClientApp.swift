import SwiftUI

/// Main application entry point for VoiceClient.
/// This is a menu bar application that provides voice-to-text functionality.
@main
struct VoiceClientApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menu bar extra (system tray icon)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.statusIcon)
        }

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
