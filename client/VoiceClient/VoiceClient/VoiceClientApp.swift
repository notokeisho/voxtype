import SwiftUI

/// Main application entry point for VoiceClient.
/// This is a menu bar application that provides voice-to-text functionality.
@main
struct VoiceClientApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService.shared

    init() {
        // Check authentication status on launch
        Task { @MainActor in
            await AuthService.shared.checkAuthStatus()
        }
    }

    var body: some Scene {
        // Menu bar extra (system tray icon)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(authService)
        } label: {
            MenuBarLabel()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(authService)
        }
    }
}

/// Custom label for the menu bar icon with dynamic appearance.
struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: appState.statusIcon)
                .symbolRenderingMode(.palette)
                .foregroundStyle(iconColor)

            // Show recording time in menu bar during recording
            if appState.status == .recording {
                Text(appState.recordingDurationText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var iconColor: Color {
        switch appState.status {
        case .idle:
            return .primary
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
}
