import SwiftUI

/// Settings view for the application.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settings = AppSettings.shared
    @StateObject private var authService = AuthService.shared

    var body: some View {
        TabView {
            AccountSettingsView()
                .environmentObject(authService)
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            GeneralSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            HotkeySettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }

            DictionarySettingsView()
                .environmentObject(authService)
                .tabItem {
                    Label("Dictionary", systemImage: "text.book.closed")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 360)
    }
}

// MARK: - Account Settings Tab

/// Account settings tab with login/logout functionality.
struct AccountSettingsView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Form {
            Section {
                switch authService.state {
                case .unknown:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking authentication...")
                            .foregroundColor(.secondary)
                    }

                case .notAuthenticated:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Not logged in")
                            .font(.headline)

                        Text("Log in with GitHub to sync your settings and use the transcription service.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: {
                            authService.login()
                        }) {
                            HStack {
                                Image(systemName: "person.badge.key")
                                Text("Log in with GitHub")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                case .authenticating:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Logging in...")
                            .foregroundColor(.secondary)
                    }

                case .authenticated(let user):
                    HStack(spacing: 12) {
                        // User avatar
                        if let avatarURL = user.githubAvatar,
                           let url = URL(string: avatarURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.githubId)
                                .font(.headline)

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Logged in")
                                    .foregroundColor(.secondary)

                                if user.isAdmin {
                                    Text("(Admin)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .font(.caption)
                        }

                        Spacer()

                        Button("Log out") {
                            authService.logout()
                        }
                        .foregroundColor(.red)
                    }

                case .error(let message):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Authentication Error")
                                .font(.headline)
                        }

                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Try Again") {
                            authService.login()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } header: {
                Text("GitHub Account")
            }

            if authService.isAuthenticated {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your data is synced with the server", systemImage: "icloud.and.arrow.up")
                        Label("Personal dictionary is available", systemImage: "text.book.closed")
                        Label("Voice transcription is enabled", systemImage: "waveform")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("Account Features")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            Task {
                await authService.checkAuthStatus()
            }
        }
    }
}

// MARK: - General Settings Tab

/// General settings tab.
struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTestingConnection = false

    enum ConnectionStatus {
        case unknown
        case testing
        case connected
        case failed(String)

        var icon: String {
            switch self {
            case .unknown: return "circle"
            case .testing: return "arrow.triangle.2.circlepath"
            case .connected: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .testing: return .orange
            case .connected: return .green
            case .failed: return .red
            }
        }
    }

    var body: some View {
        Form {
            // Server settings
            Section {
                HStack {
                    TextField("Server URL", text: $settings.serverURL)
                        .textFieldStyle(.roundedBorder)

                    // Validation indicator
                    Image(systemName: settings.isServerURLValid ? "checkmark.circle" : "xmark.circle")
                        .foregroundColor(settings.isServerURLValid ? .green : .red)
                }

                HStack {
                    // Connection status
                    HStack(spacing: 4) {
                        Image(systemName: connectionStatus.icon)
                            .foregroundColor(connectionStatus.color)
                        Text(connectionStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Test connection button
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTestingConnection || !settings.isServerURLValid)
                }
            } header: {
                Text("Server")
            }

            // Startup settings
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .toggleStyle(.switch)
            } header: {
                Text("Startup")
            }

            // Reset settings
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                    connectionStatus = .unknown
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var connectionStatusText: String {
        switch connectionStatus {
        case .unknown:
            return "Not tested"
        case .testing:
            return "Testing..."
        case .connected:
            return "Connected"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    private func testConnection() {
        guard let url = URL(string: settings.serverURL)?.appendingPathComponent("api/status") else {
            connectionStatus = .failed("Invalid URL")
            return
        }

        isTestingConnection = true
        connectionStatus = .testing

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    connectionStatus = .connected
                } else {
                    connectionStatus = .failed("Server error")
                }
            } catch {
                connectionStatus = .failed(error.localizedDescription)
            }
            isTestingConnection = false
        }
    }
}

// MARK: - Hotkey Settings Tab

/// Hotkey settings tab.
struct HotkeySettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var isRecordingHotkey = false
    @State private var showHotkeyHelp = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Hotkey")
                        .font(.headline)

                    HStack {
                        // Current hotkey display
                        Text(settings.hotkeyDisplayString)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(8)

                        Spacer()

                        // Record new hotkey button
                        Button(isRecordingHotkey ? "Press keys..." : "Change Hotkey") {
                            isRecordingHotkey.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if isRecordingHotkey {
                        Text("Press the key combination you want to use, then click Done")
                            .font(.caption)
                            .foregroundColor(.orange)

                        HStack {
                            // Modifier checkboxes
                            ModifierToggle(label: "⌘", isOn: .constant(true))
                            ModifierToggle(label: "⇧", isOn: .constant(true))
                            ModifierToggle(label: "⌃", isOn: .constant(false))
                            ModifierToggle(label: "⌥", isOn: .constant(false))

                            Spacer()

                            Button("Done") {
                                isRecordingHotkey = false
                            }
                        }
                    }

                    Text("Hold this key combination to start recording, release to stop and transcribe.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Voice Recording Hotkey")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("The hotkey works globally across all applications", systemImage: "globe")
                    Label("Hold to record, release to transcribe", systemImage: "hand.tap")
                    Label("Recording stops automatically after 60 seconds", systemImage: "timer")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } header: {
                Text("How it works")
            }

            Section {
                Button("Reset to Default (⌘⇧V)") {
                    settings.hotkeyModifiers = 0x180000
                    settings.hotkeyKeyCode = 9
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Modifier key toggle button.
struct ModifierToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .background(isOn ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isOn ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dictionary Settings Tab

/// Dictionary settings tab with full API integration.
struct DictionarySettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var service = DictionaryService.shared
    @State private var newPattern = ""
    @State private var newReplacement = ""
    @State private var showingDeleteConfirmation = false
    @State private var entryToDelete: DictionaryEntry?

    private var authToken: String? {
        authService.token
    }

    private var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()

            Divider()

            // Content
            if !isAuthenticated {
                notAuthenticatedView
            } else if service.isLoading && service.entries.isEmpty {
                loadingView
            } else if service.entries.isEmpty {
                emptyStateView
            } else {
                entryListView
            }

            Divider()

            // Add new entry form
            if isAuthenticated {
                addEntryForm
                    .padding()
            }
        }
        .onAppear {
            loadEntries()
        }
        .alert("Delete Entry", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
        } message: {
            if let entry = entryToDelete {
                Text("Delete \"\(entry.pattern)\" → \"\(entry.replacement)\"?")
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Personal Dictionary")
                .font(.headline)

            Spacer()

            if service.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Text("\(service.entryCount)/\(service.maxEntries)")
                .font(.caption)
                .foregroundColor(service.canAddMore ? .secondary : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

            if isAuthenticated {
                Button {
                    loadEntries()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(service.isLoading)
            }
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.key")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Login Required")
                .font(.headline)

            Text("Please log in to manage your personal dictionary")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading dictionary...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Dictionary Entries")
                .font(.headline)

            Text("Add patterns to customize how words are transcribed")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Example
            VStack(alignment: .leading, spacing: 4) {
                Text("Example:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack {
                    Text("くろーど")
                        .font(.caption)
                    Text("→")
                        .foregroundColor(.secondary)
                    Text("Claude")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var entryListView: some View {
        List {
            ForEach(service.entries) { entry in
                DictionaryEntryRow(
                    entry: entry,
                    onDelete: {
                        entryToDelete = entry
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    private var addEntryForm: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pattern")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("e.g., くろーど", text: $newPattern)
                        .textFieldStyle(.roundedBorder)
                }

                Text("→")
                    .foregroundColor(.secondary)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Replacement")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("e.g., Claude", text: $newReplacement)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    addEntry()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(canAdd ? .accentColor : .secondary)
                .disabled(!canAdd)
                .padding(.top, 14)
            }

            // Error message
            if let error = service.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                    Button("Dismiss") {
                        service.errorMessage = nil
                    }
                    .font(.caption)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            // Limit warning
            if !service.canAddMore {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Dictionary limit reached (100 entries)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var canAdd: Bool {
        !newPattern.isEmpty &&
        !newReplacement.isEmpty &&
        service.canAddMore &&
        !service.isLoading
    }

    // MARK: - Actions

    private func loadEntries() {
        guard let token = authToken else { return }
        Task {
            await service.fetchEntries(token: token)
        }
    }

    private func addEntry() {
        guard let token = authToken else { return }
        let pattern = newPattern.trimmingCharacters(in: .whitespaces)
        let replacement = newReplacement.trimmingCharacters(in: .whitespaces)

        guard !pattern.isEmpty, !replacement.isEmpty else { return }

        Task {
            let success = await service.addEntry(
                pattern: pattern,
                replacement: replacement,
                token: token
            )
            if success {
                newPattern = ""
                newReplacement = ""
            }
        }
    }

    private func deleteEntry(_ entry: DictionaryEntry) {
        guard let token = authToken else { return }
        Task {
            await service.deleteEntry(id: entry.id, token: token)
        }
    }
}

/// Row view for a dictionary entry.
struct DictionaryEntryRow: View {
    let entry: DictionaryEntry
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.pattern)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text("→")
                        .foregroundColor(.secondary)
                    Text(entry.replacement)
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - About Tab

/// About tab.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("VoiceClient")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("Voice-to-text client for KumaKuma AI")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com")!)
                Text("•")
                    .foregroundColor(.secondary)
                Link("Documentation", destination: URL(string: "https://github.com")!)
            }
            .font(.caption)

            Text("© 2025 KumaKuma AI")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}
#endif
