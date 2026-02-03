import SwiftUI

/// View displayed in the menu bar dropdown.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status header
            statusHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Recording button
            if authService.isAuthenticated {
                recordingButton
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                Divider()
            }

            // Recording info (shown during recording)
            if appState.status == .recording {
                recordingInfo
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                Divider()
            }

            // Last transcribed text (if any)
            if let text = appState.lastTranscribedText, !text.isEmpty {
                lastTranscribedSection(text: text)
                Divider()
            }

            // Error message (if any)
            if let error = appState.lastError {
                errorSection(error: error)
                Divider()
            }

            // Menu items
            menuItems
                .padding(.vertical, 4)
        }
        .frame(width: 280)
    }

    // MARK: - Subviews

    private var statusHeader: some View {
        HStack(spacing: 8) {
            // Animated status icon
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.statusText)
                    .font(.headline)

                if authService.isAuthenticated {
                    if let user = authService.currentUser {
                        Text(user.githubUsername ?? user.githubId)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Authenticated")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Not logged in")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Hotkey hint
            Text(AppSettings.shared.hotkeyDisplayString)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if #available(macOS 14.0, *) {
            Image(systemName: appState.statusIcon)
                .font(.title2)
                .foregroundColor(appState.statusColor)
                .symbolEffect(.pulse, isActive: appState.status == .processing)
                .animation(.easeInOut, value: appState.status)
        } else {
            Image(systemName: appState.statusIcon)
                .font(.title2)
                .foregroundColor(appState.statusColor)
                .animation(.easeInOut, value: appState.status)
        }
    }

    private var recordingInfo: some View {
        HStack {
            // Recording indicator
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(pulsingOpacity)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulsingOpacity)

            Text("Recording")
                .font(.subheadline)
                .foregroundColor(.red)

            Spacer()

            // Duration
            Text(appState.recordingDurationText)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.secondary)

            Text("/ \(formatDuration(appState.maxRecordingDuration))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @State private var pulsingOpacity: Double = 1.0

    @ViewBuilder
    private var recordingButton: some View {
        switch appState.status {
        case .idle, .error, .completed:
            Button(action: { AppCoordinator.shared.startRecordingFromUI() }) {
                Label("録音開始", systemImage: "record.circle")
            }
            .buttonStyle(RecordingButtonStyle(isRecording: false))

        case .recording:
            Button(action: { AppCoordinator.shared.stopRecordingFromUI() }) {
                Label("録音停止", systemImage: "stop.circle.fill")
            }
            .buttonStyle(RecordingButtonStyle(isRecording: true))

        case .processing:
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("処理中...")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func lastTranscribedSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last transcription:")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(text.prefix(100) + (text.count > 100 ? "..." : ""))
                .font(.callout)
                .lineLimit(3)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

            Button("Copy to Clipboard") {
                copyToClipboard(text)
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func errorSection(error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var menuItems: some View {
        VStack(spacing: 0) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Label("Settings...", systemImage: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)
            } else {
                Button(action: openSettings) {
                    Label("Settings...", systemImage: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            if authService.isAuthenticated {
                Button(action: logout) {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Button(action: login) {
                    Label("Login with GitHub", systemImage: "person.badge.key")
                }
            }

            Divider()
                .padding(.vertical, 4)

            Button(action: quitApp) {
                Label("Quit VoxType", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .buttonStyle(MenuButtonStyle())
    }

    // MARK: - Actions

    private func openSettings() {
        // Fallback for macOS 13
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private func login() {
        authService.login()
    }

    private func logout() {
        authService.logout()
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Custom Button Style

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
    }
}

struct RecordingButtonStyle: ButtonStyle {
    let isRecording: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isRecording ? Color.red : Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Preview

#if DEBUG
struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Idle state
            MenuBarView()
                .environmentObject(AppState())
                .environmentObject(AuthService.shared)
                .previewDisplayName("Idle")

            // Recording state
            MenuBarView()
                .environmentObject(AppState())
                .environmentObject(AuthService.shared)
                .previewDisplayName("Recording")
        }
    }
}
#endif
