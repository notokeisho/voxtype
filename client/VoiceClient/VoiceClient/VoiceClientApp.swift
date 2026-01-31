import SwiftUI

/// Main application entry point for VoiceClient.
/// This is a menu bar application that provides voice-to-text functionality.
@main
struct VoiceClientApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService.shared
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var coordinator = AppCoordinator.shared

    var body: some Scene {
        // Menu bar extra (system tray icon)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(authService)
                .environmentObject(hotkeyManager)
                .onAppear {
                    // Initialize coordinator with shared instances
                    coordinator.setup(
                        appState: appState,
                        authService: authService,
                        hotkeyManager: hotkeyManager
                    )
                }
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
                .environmentObject(hotkeyManager)
        }
    }
}

/// Coordinator that manages app-wide interactions between services.
@MainActor
class AppCoordinator: ObservableObject {
    /// Shared instance.
    static let shared = AppCoordinator()

    private weak var appState: AppState?
    private weak var authService: AuthService?
    private weak var hotkeyManager: HotkeyManager?

    private var isSetup = false

    private init() {}

    /// Set up the coordinator with shared instances.
    func setup(appState: AppState, authService: AuthService, hotkeyManager: HotkeyManager) {
        guard !isSetup else { return }
        isSetup = true

        self.appState = appState
        self.authService = authService
        self.hotkeyManager = hotkeyManager

        setupHotkeyCallbacks()
        startHotkeyMonitoring()

        // Check auth status and request notification permission on launch
        Task {
            await authService.checkAuthStatus()
            _ = await NotificationManager.shared.requestAuthorization()
        }
    }

    private func setupHotkeyCallbacks() {
        guard let hotkeyManager = hotkeyManager else { return }

        hotkeyManager.onHotkeyDown = { [weak self] in
            self?.handleHotkeyDown()
        }

        hotkeyManager.onHotkeyUp = { [weak self] in
            self?.handleHotkeyUp()
        }
    }

    private func startHotkeyMonitoring() {
        guard let hotkeyManager = hotkeyManager else { return }

        // Start monitoring if we have accessibility permission
        if hotkeyManager.checkAccessibilityPermission() {
            hotkeyManager.startMonitoring()
        }
    }

    private func handleHotkeyDown() {
        guard let appState = appState,
              let authService = authService else { return }

        // Only start recording if authenticated and idle
        guard authService.isAuthenticated else {
            appState.setError("Please log in to use voice transcription")
            return
        }

        guard appState.status == .idle else { return }

        appState.startRecording()
    }

    private func handleHotkeyUp() {
        guard let appState = appState else { return }

        guard appState.status == .recording else { return }

        let audioURL = appState.stopRecording()

        // TODO: Send audio to server for transcription (Task 4.7)
        if let url = audioURL {
            processRecording(url: url)
        }
    }

    private func processRecording(url: URL) {
        guard let appState = appState else { return }

        let apiClient = APIClient.shared
        let clipboardManager = ClipboardManager.shared

        Task {
            do {
                // Send audio to server for transcription
                let response = try await apiClient.transcribe(audioURL: url)

                // Paste the transcribed text at cursor position
                clipboardManager.pasteText(response.text) {
                    // Complete after paste is done
                    Task { @MainActor in
                        appState.completeTranscription(text: response.text)
                    }
                }

            } catch let error as APIError {
                appState.setError(error.localizedDescription)
                // Show notification for critical errors
                error.showNotificationIfNeeded()
            } catch {
                appState.setError(error.localizedDescription)
            }
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
