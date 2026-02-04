import SwiftUI

/// View displayed in the menu bar dropdown.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var localization: LocalizationManager

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
                        Text(localization.t("menu.authenticated"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(localization.t("menu.notLoggedIn"))
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

            Text(localization.t("menu.recording"))
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
                Label(localization.t("menu.startRecording"), systemImage: "record.circle")
            }
            .buttonStyle(RecordingButtonStyle(isRecording: false))

        case .recording:
            Button(action: { AppCoordinator.shared.stopRecordingFromUI() }) {
                Label(localization.t("menu.stopRecording"), systemImage: "stop.circle.fill")
            }
            .buttonStyle(RecordingButtonStyle(isRecording: true))

        case .processing:
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text(localization.t("menu.processing"))
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func lastTranscribedSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localization.t("menu.lastTranscription"))
                .font(.caption)
                .foregroundColor(.secondary)

            Text(text.prefix(100) + (text.count > 100 ? "..." : ""))
                .font(.callout)
                .lineLimit(3)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

            Button(localization.t("menu.copyToClipboard")) {
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
            settingsButton
                .keyboardShortcut(",", modifiers: .command)

            if authService.isAuthenticated {
                Button(action: logout) {
                    Label(localization.t("menu.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Button(action: login) {
                    Label(localization.t("menu.login"), systemImage: "person.badge.key")
                }
            }

            Divider()
                .padding(.vertical, 4)

            Button(action: quitApp) {
                Label(localization.t("menu.quit"), systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .buttonStyle(MenuButtonStyle())
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Label(localization.t("menu.settings"), systemImage: "gear")
            }
            .simultaneousGesture(TapGesture().onEnded {
                bringSettingsToFront()
            })
        } else {
            Button(action: openSettingsLegacy) {
                Label(localization.t("menu.settings"), systemImage: "gear")
            }
        }
    }

    // MARK: - Settings

    private func openSettingsLegacy() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        bringSettingsToFront()
    }

    private func bringSettingsToFront() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - Actions

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
