import SwiftUI

/// Main application entry point for VoxType.
/// This is a menu bar application that provides voice-to-text functionality.
@main
struct VoxTypeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService.shared
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var coordinator = AppCoordinator.shared

    init() {
        // Request accessibility permission on app launch
        // This shows the system dialog before user interacts with the menu
        HotkeyManager.shared.requestAccessibilityPermissionOnLaunch()
    }

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

    /// Recording overlay window for visual feedback.
    private let recordingOverlay = RecordingOverlayWindow.shared

    /// The previously active application (for focus restoration after paste).
    private var previousApp: NSRunningApplication?

    private var isSetup = false

    private init() {}

    /// Set up the coordinator with shared instances.
    func setup(appState: AppState, authService: AuthService, hotkeyManager: HotkeyManager) {
        guard !isSetup else { return }
        isSetup = true

        self.appState = appState
        self.authService = authService
        self.hotkeyManager = hotkeyManager

        // Set up recording overlay with app state
        recordingOverlay.setup(appState: appState)

        setupHotkeyCallbacks()
        startHotkeyMonitoring()
        setupPreviousAppTracking()

        // Check auth status and request permissions on launch
        Task {
            await authService.checkAuthStatus()

            // Refresh token if needed (extends expiration for active users)
            if authService.isAuthenticated {
                await authService.refreshIfNeeded()
            }

            _ = await NotificationManager.shared.requestAuthorization()

            // Request microphone permission on launch to avoid dialog during recording
            _ = await appState.checkMicrophonePermission()
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
        } else {
            hotkeyManager.requestAccessibilityPermission()
        }
    }

    private func setupPreviousAppTracking() {
        // Initialize with current frontmost app (if not VoxType)
        if let currentApp = NSWorkspace.shared.frontmostApplication,
           currentApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = currentApp
        }

        // Track the previously active app (excluding VoxType itself)
        // This is used to restore focus before pasting transcribed text
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return
            }
            Task { @MainActor in
                self?.previousApp = app
            }
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

        if appState.startRecording() {
            // Show recording overlay on successful start
            recordingOverlay.showWithAnimation()
        }
    }

    private func handleHotkeyUp() {
        guard let appState = appState else { return }

        guard appState.status == .recording else { return }

        // Hide recording overlay
        recordingOverlay.hideWithAnimation()

        let audioURL = appState.stopRecording()

        if let url = audioURL {
            processRecording(url: url)
        }
    }

    // MARK: - Public Methods for UI

    /// Start recording manually (called from UI button).
    func startRecordingFromUI() {
        handleHotkeyDown()
    }

    /// Stop recording manually (called from UI button).
    func stopRecordingFromUI() {
        handleHotkeyUp()
    }

    private func processRecording(url: URL) {
        guard let appState = appState else { return }

        let apiClient = APIClient.shared
        let clipboardManager = ClipboardManager.shared

        Task {
            do {
                // Send audio to server for transcription
                let response = try await apiClient.transcribe(audioURL: url)

                // Close menu bar window if open (orderOut does nothing if not open)
                NSApp.keyWindow?.orderOut(nil)

                // Restore focus to the previous app before pasting
                if let app = self.previousApp {
                    app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                }

                // Wait for focus to be restored, then paste
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                // Paste the transcribed text at cursor position
                clipboardManager.pasteText(response.text) {
                    Task { @MainActor in
                        appState.completeTranscription(text: response.text)

                        // Refresh token if needed (background, non-blocking)
                        Task {
                            await AuthService.shared.refreshIfNeeded()
                        }
                    }
                }

            } catch let error as APIError {
                appState.setError(error.localizedDescription)
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
