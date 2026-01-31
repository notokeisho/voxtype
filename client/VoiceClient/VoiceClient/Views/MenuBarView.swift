import SwiftUI

/// View displayed in the menu bar dropdown.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status display
            HStack {
                Image(systemName: appState.statusIcon)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.headline)
            }
            .padding(.horizontal)

            Divider()

            // Last transcribed text (if any)
            if let text = appState.lastTranscribedText {
                Text("Last: \(text.prefix(50))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .lineLimit(2)

                Divider()
            }

            // Error message (if any)
            if let error = appState.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .lineLimit(2)

                Divider()
            }

            // Menu items
            if appState.isAuthenticated {
                Button("Settings...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Logout") {
                    logout()
                }
            } else {
                Button("Login with GitHub") {
                    login()
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
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

    private var statusText: String {
        switch appState.status {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .completed:
            return "Completed"
        case .error:
            return "Error"
        }
    }

    // MARK: - Actions

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func login() {
        // TODO: Implement OAuth login
    }

    private func logout() {
        // TODO: Implement logout
        appState.isAuthenticated = false
    }
}

// MARK: - Preview

#if DEBUG
struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
            .environmentObject(AppState())
            .frame(width: 250)
    }
}
#endif
