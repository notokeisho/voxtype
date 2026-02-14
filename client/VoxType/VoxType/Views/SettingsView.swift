import SwiftUI

/// Settings view for the application.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var settings = AppSettings.shared
    @StateObject private var authService = AuthService.shared

    var body: some View {
        TabView {
            AccountSettingsView()
                .environmentObject(authService)
                .environmentObject(localization)
                .tabItem {
                    Label(localization.t("settings.account"), systemImage: "person.circle")
                }

            GeneralSettingsView()
                .environmentObject(settings)
                .environmentObject(localization)
                .tabItem {
                    Label(localization.t("settings.general"), systemImage: "gear")
                }

            HotkeySettingsView()
                .environmentObject(settings)
                .environmentObject(localization)
                .tabItem {
                    Label(localization.t("settings.hotkey"), systemImage: "keyboard")
                }

            DictionarySettingsView()
                .environmentObject(authService)
                .environmentObject(localization)
                .tabItem {
                    Label(localization.t("settings.dictionary"), systemImage: "text.book.closed")
                }

            GlobalDictionaryRequestView()
                .environmentObject(authService)
                .environmentObject(localization)
                .tabItem {
                    Label(localization.t("settings.globalDictionaryRequest"), systemImage: "tray.and.arrow.up")
                }

            LanguageSettingsView()
                .environmentObject(localization)
                .tabItem {
                    Label(localization.t("settings.language"), systemImage: "globe")
                }

            AboutView()
                .environmentObject(localization)
                .tabItem {
                    Label(localization.t("settings.about"), systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 360)
    }
}

// MARK: - Account Settings Tab

/// Account settings tab with login/logout functionality.
struct AccountSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        Form {
            Section {
                switch authService.state {
                case .unknown:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(localization.t("account.checking"))
                            .foregroundColor(.secondary)
                    }

                case .notAuthenticated:
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localization.t("account.notLoggedIn"))
                            .font(.headline)

                        Text(localization.t("account.loginDescription"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: {
                            authService.login()
                        }) {
                            HStack {
                                Image(systemName: "person.badge.key")
                                Text(localization.t("account.loginButton"))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                case .authenticating:
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(localization.t("account.loggingIn"))
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
                            Text(user.githubUsername ?? user.githubId)
                                .font(.headline)

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(localization.t("account.loggedIn"))
                                    .foregroundColor(.secondary)

                                if user.isAdmin {
                                    Text(localization.t("account.admin"))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .font(.caption)
                        }

                        Spacer()

                        Button(localization.t("account.logoutButton")) {
                            authService.logout()
                        }
                        .foregroundColor(.red)
                    }

                case .error(let message):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(localization.t("account.authError"))
                                .font(.headline)
                        }

                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(localization.t("account.tryAgain")) {
                            authService.login()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } header: {
                Text(localization.t("account.title"))
            }

            if authService.isAuthenticated {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(localization.t("account.feature.sync"), systemImage: "icloud.and.arrow.up")
                        Label(localization.t("account.feature.dictionary"), systemImage: "text.book.closed")
                        Label(localization.t("account.feature.transcription"), systemImage: "waveform")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text(localization.t("account.features"))
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
    @EnvironmentObject var localization: LocalizationManager
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
                    TextField(localization.t("general.serverURL"), text: $settings.serverURL)
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
                    Button(localization.t("general.testConnection")) {
                        testConnection()
                    }
                    .disabled(isTestingConnection || !settings.isServerURLValid)
                }
            } header: {
                Text(localization.t("general.server"))
            }

            // Startup settings
            Section {
                Toggle(localization.t("general.launchAtLogin"), isOn: $settings.launchAtLogin)
                    .toggleStyle(.switch)
            } header: {
                Text(localization.t("general.startup"))
            }

            // Transcription model settings
            Section {
                Picker(localization.t("general.transcriptionModel"), selection: $settings.whisperModel) {
                    ForEach(WhisperModel.allCases, id: \.self) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.inline)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(WhisperModel.allCases, id: \.self) { model in
                        HStack {
                            Text(model.displayName)
                                .fontWeight(.medium)
                            Text("- \(modelDescription(for: model))")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            } header: {
                Text(localization.t("general.model"))
            }

            // Noise filter (VAD)
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(localization.t("general.noiseFilter"))
                        Spacer()
                        Text(noiseFilterDisplayValue)
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.noiseFilterLevel, in: 0.0...0.5, step: 0.05)
                }
            }

            // Reset settings
            Section {
                Button(localization.t("general.resetToDefaults")) {
                    settings.resetToDefaults()
                    connectionStatus = .unknown
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var noiseFilterDisplayValue: String {
        if settings.noiseFilterLevel == 0 {
            return localization.t("general.off")
        }
        return String(format: "%.2f", settings.noiseFilterLevel)
    }

    private func modelDescription(for model: WhisperModel) -> String {
        switch model {
        case .fast:
            return localization.t("general.model.fastDescription")
        case .smart:
            return localization.t("general.model.smartDescription")
        }
    }

    private var connectionStatusText: String {
        switch connectionStatus {
        case .unknown:
            return localization.t("general.connectionNotTested")
        case .testing:
            return localization.t("general.connectionTesting")
        case .connected:
            return localization.t("general.connectionConnected")
        case .failed(let message):
            return localization.t("general.connectionFailed", params: ["message": message])
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
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @State private var isEditing = false
    @State private var isEditingModelHotkey = false

    // Editing state
    @State private var useCommand = false
    @State private var useShift = false
    @State private var useControl = false
    @State private var useOption = true
    @State private var selectedKeyCode: UInt16 = 49  // Space
    @State private var modelUseCommand = false
    @State private var modelUseShift = false
    @State private var modelUseControl = false
    @State private var modelUseOption = true
    @State private var modelSelectedKeyCode: UInt16 = 49  // Space

    // Available keys for selection
    private let availableKeys: [(String, UInt16)] = [
        ("Space", 49),
        ("A", 0), ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3),
        ("G", 5), ("H", 4), ("I", 34), ("J", 38), ("K", 40), ("L", 37),
        ("M", 46), ("N", 45), ("O", 31), ("P", 35), ("Q", 12), ("R", 15),
        ("S", 1), ("T", 17), ("U", 32), ("V", 9), ("W", 13), ("X", 7),
        ("Y", 16), ("Z", 6),
        ("0", 29), ("1", 18), ("2", 19), ("3", 20), ("4", 21),
        ("5", 23), ("6", 22), ("7", 26), ("8", 28), ("9", 25),
        (",", 43), (".", 47), ("/", 44), (";", 41),
        ("[", 33), ("]", 30), ("-", 27),
        ("F1", 122), ("F2", 120), ("F3", 99), ("F4", 118), ("F5", 96),
        ("F6", 97), ("F7", 98), ("F8", 100), ("F9", 101), ("F10", 109),
        ("F11", 103), ("F12", 111)
    ]

    var body: some View {
        Form {
            // Accessibility Permission Section
            Section {
                HStack {
                    if hotkeyManager.hasAccessibilityPermission {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(localization.t("hotkey.accessGranted"))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localization.t("hotkey.accessRequired"))
                                .fontWeight(.medium)
                            Text(localization.t("hotkey.accessDescription"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if !hotkeyManager.hasAccessibilityPermission {
                        Button(localization.t("hotkey.grantAccess")) {
                            hotkeyManager.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if !hotkeyManager.hasAccessibilityPermission {
                    Text(localization.t("hotkey.accessInstructions"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(localization.t("hotkey.permissions"))
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(localization.t("hotkey.recordingEnabled"), isOn: $settings.hotkeyEnabled)
                        .toggleStyle(.switch)

                    if settings.hotkeyEnabled {
                        Divider()

                        if settings.recordingHotkeyMode == .keyboard {
                            HStack {
                                Text(localization.t("hotkey.current"))
                                    .font(.headline)
                                Spacer()
                                Text(settings.hotkeyDisplayString)
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.15))
                                    .cornerRadius(8)
                            }

                            if !isEditing {
                                Button(localization.t("hotkey.change")) {
                                    loadCurrentSettings()
                                    isEditing = true
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(localization.t("hotkey.selectModifiers"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 8) {
                                        ModifierToggle(label: "⌃", isOn: $useControl)
                                        ModifierToggle(label: "⌥", isOn: $useOption)
                                        ModifierToggle(label: "⇧", isOn: $useShift)
                                        ModifierToggle(label: "⌘", isOn: $useCommand)

                                        Text("+")
                                            .foregroundColor(.secondary)

                                        Picker("Key", selection: $selectedKeyCode) {
                                            ForEach(availableKeys, id: \.1) { key in
                                                Text(key.0).tag(key.1)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 100)
                                    }

                                    if !hasValidModifiers {
                                        Text(localization.t("hotkey.modifierRequired"))
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    if isRecordingHotkeyDuplicate {
                                        Text(localization.t("hotkey.duplicateWarning"))
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }

                                    HStack {
                                        Button(localization.t("hotkey.cancel")) {
                                            isEditing = false
                                        }
                                        .buttonStyle(.bordered)

                                        Button(localization.t("hotkey.save")) {
                                            saveHotkey()
                                            isEditing = false
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(!hasValidModifiers || isRecordingHotkeyDuplicate)
                                    }
                                }
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                            Toggle(localization.t("hotkey.mouseHoldEnabled"), isOn: $settings.isMouseWheelRecordingEnabled)
                                .toggleStyle(.switch)

                            Text(localization.t("hotkey.description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Toggle(localization.t("hotkey.mouseHoldEnabled"), isOn: $settings.isMouseWheelRecordingEnabled)
                                .toggleStyle(.switch)

                            Text(localization.t("hotkey.mouseHoldHint"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text(localization.t("hotkey.title"))
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(localization.t("hotkey.modelEnabled"), isOn: $settings.modelHotkeyEnabled)
                        .toggleStyle(.switch)

                    if settings.modelHotkeyEnabled {
                        Divider()

                        HStack {
                            Text(localization.t("hotkey.modelTitle"))
                                .font(.headline)
                            Spacer()
                            Text(settings.modelHotkeyDisplayString)
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(8)
                        }

                        if !isEditingModelHotkey {
                            Button(localization.t("hotkey.modelChange")) {
                                loadCurrentModelHotkeySettings()
                                isEditingModelHotkey = true
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(localization.t("hotkey.selectModifiers"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    ModifierToggle(label: "⌃", isOn: $modelUseControl)
                                    ModifierToggle(label: "⌥", isOn: $modelUseOption)
                                    ModifierToggle(label: "⇧", isOn: $modelUseShift)
                                    ModifierToggle(label: "⌘", isOn: $modelUseCommand)

                                    Text("+")
                                        .foregroundColor(.secondary)

                                    Picker("Key", selection: $modelSelectedKeyCode) {
                                        ForEach(availableKeys, id: \.1) { key in
                                            Text(key.0).tag(key.1)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 100)
                                }

                                if !hasValidModelModifiers {
                                    Text(localization.t("hotkey.modifierRequired"))
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                if isModelHotkeyDuplicate {
                                    Text(localization.t("hotkey.duplicateWarning"))
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }

                                HStack {
                                    Button(localization.t("hotkey.cancel")) {
                                        isEditingModelHotkey = false
                                    }
                                    .buttonStyle(.bordered)

                                    Button(localization.t("hotkey.save")) {
                                        saveModelHotkey()
                                        isEditingModelHotkey = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!hasValidModelModifiers || isModelHotkeyDuplicate)
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }

                    Text(localization.t("hotkey.modelDescription"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(localization.t("hotkey.modelTitle"))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(localization.t("hotkey.tip.global"), systemImage: "globe")
                    Label(localization.t("hotkey.tip.holdRelease"), systemImage: "hand.tap")
                    Label(localization.t("hotkey.tip.autoStop"), systemImage: "timer")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } header: {
                Text(localization.t("hotkey.howItWorks"))
            }

            Section {
                Button(localization.t("hotkey.resetToDefault")) {
                    settings.hotkeyModifiers = 0x040000  // Control only
                    settings.hotkeyKeyCode = 47          // Period (.)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            hotkeyManager.checkAccessibilityPermission()
        }
        .onChange(of: settings.hotkeyEnabled) { newValue in
            if !newValue {
                isEditing = false
            }
        }
        .onChange(of: settings.modelHotkeyEnabled) { newValue in
            if !newValue {
                isEditingModelHotkey = false
            }
        }
        .padding()
    }

    private var hasValidModifiers: Bool {
        useCommand || useShift || useControl || useOption
    }

    private var hasValidModelModifiers: Bool {
        modelUseCommand || modelUseShift || modelUseControl || modelUseOption
    }

    private var isRecordingHotkeyDuplicate: Bool {
        let modifiers = currentRecordingModifiers()
        return modifiers == settings.modelHotkeyModifiers && selectedKeyCode == settings.modelHotkeyKeyCode
    }

    private var isModelHotkeyDuplicate: Bool {
        let modifiers = currentModelModifiers()
        return modifiers == settings.hotkeyModifiers && modelSelectedKeyCode == settings.hotkeyKeyCode
    }

    private func loadCurrentSettings() {
        let mods = settings.hotkeyModifiers
        useControl = (mods & (1 << 18)) != 0
        useOption = (mods & (1 << 19)) != 0
        useShift = (mods & (1 << 17)) != 0
        useCommand = (mods & (1 << 20)) != 0
        selectedKeyCode = settings.hotkeyKeyCode
    }

    private func loadCurrentModelHotkeySettings() {
        let mods = settings.modelHotkeyModifiers
        modelUseControl = (mods & (1 << 18)) != 0
        modelUseOption = (mods & (1 << 19)) != 0
        modelUseShift = (mods & (1 << 17)) != 0
        modelUseCommand = (mods & (1 << 20)) != 0
        modelSelectedKeyCode = settings.modelHotkeyKeyCode
    }

    private func saveHotkey() {
        let modifiers = currentRecordingModifiers()
        settings.hotkeyModifiers = modifiers
        settings.hotkeyKeyCode = selectedKeyCode
    }

    private func saveModelHotkey() {
        let modifiers = currentModelModifiers()
        settings.modelHotkeyModifiers = modifiers
        settings.modelHotkeyKeyCode = modelSelectedKeyCode
    }

    private func currentRecordingModifiers() -> UInt {
        var modifiers: UInt = 0
        if useControl { modifiers |= (1 << 18) }
        if useOption { modifiers |= (1 << 19) }
        if useShift { modifiers |= (1 << 17) }
        if useCommand { modifiers |= (1 << 20) }
        return modifiers
    }

    private func currentModelModifiers() -> UInt {
        var modifiers: UInt = 0
        if modelUseControl { modifiers |= (1 << 18) }
        if modelUseOption { modifiers |= (1 << 19) }
        if modelUseShift { modifiers |= (1 << 17) }
        if modelUseCommand { modifiers |= (1 << 20) }
        return modifiers
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
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var service = DictionaryService.shared
    @State private var newPattern = ""
    @State private var newReplacement = ""
    @State private var showingDeleteConfirmation = false
    @State private var entryToDelete: DictionaryEntry?

    // Focus management for keyboard navigation
    @State private var isPatternFocused = false
    @State private var isReplacementFocused = false

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
            // Auto-focus pattern field when tab appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if isAuthenticated {
                    isPatternFocused = true
                }
            }
        }
        .alert(localization.t("dictionary.deleteTitle"), isPresented: $showingDeleteConfirmation) {
            Button(localization.t("common.cancel"), role: .cancel) {}
            Button(localization.t("dictionary.delete"), role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
        } message: {
            if let entry = entryToDelete {
                Text(localization.t("dictionary.deleteConfirm", params: ["pattern": entry.pattern, "replacement": entry.replacement]))
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(localization.t("dictionary.title"))
                .font(.headline)

            Spacer()

            if service.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            HStack(spacing: 0) {
                Text("\(service.manualCount)/\(service.maxEntries)")
                if service.rejectedCount > 0 {
                    Text(" +\(service.rejectedCount)")
                        .foregroundColor(.green)
                }
            }
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

            Text(localization.t("dictionary.loginRequired"))
                .font(.headline)

            Text(localization.t("dictionary.loginDescription"))
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
            Text(localization.t("dictionary.loading"))
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

            Text(localization.t("dictionary.empty"))
                .font(.headline)

            Text(localization.t("dictionary.emptyDescription"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Example
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.t("dictionary.example"))
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
                    Text(localization.t("dictionary.pattern"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    IMETextField(
                        text: $newPattern,
                        placeholder: "e.g., くろーど",
                        onSubmit: {
                            // Move focus to replacement field
                            isPatternFocused = false
                            isReplacementFocused = true
                        },
                        isFocused: $isPatternFocused
                    )
                    .frame(height: 22)
                }

                Text("→")
                    .foregroundColor(.secondary)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.t("dictionary.replacement"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    IMETextField(
                        text: $newReplacement,
                        placeholder: "e.g., Claude",
                        onSubmit: {
                            // Add entry and return focus to pattern field
                            if canAdd {
                                addEntry()
                                isReplacementFocused = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isPatternFocused = true
                                }
                            }
                        },
                        isFocused: $isReplacementFocused
                    )
                    .frame(height: 22)
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
                    Button(localization.t("dictionary.dismiss")) {
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
                    Text(localization.t("dictionary.limitReached"))
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

/// About tab with version info and licenses.
struct AboutView: View {
    @EnvironmentObject var localization: LocalizationManager

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 20)

                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                Text("VoxType")
                    .font(.title)
                    .fontWeight(.bold)

                Text("\(localization.t("about.version")) \(appVersion) (\(buildNumber))")
                    .foregroundColor(.secondary)

                Text(localization.t("about.voiceToText"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()
                    .padding(.vertical, 8)

                // License section
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.t("about.licenses"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LicenseRow(name: "whisper.cpp", license: "MIT", url: "https://github.com/ggerganov/whisper.cpp")
                    LicenseRow(name: "OpenAI Whisper", license: "MIT", url: "https://github.com/openai/whisper")
                    LicenseRow(name: "FastAPI", license: "MIT", url: "https://fastapi.tiangolo.com")
                    LicenseRow(name: "SQLAlchemy", license: "MIT", url: "https://www.sqlalchemy.org")
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 8)

                HStack(spacing: 16) {
                    Link(localization.t("about.github"), destination: URL(string: "https://github.com")!)
                    Text("•")
                        .foregroundColor(.secondary)
                    Link(localization.t("about.documentation"), destination: URL(string: "https://github.com")!)
                }
                .font(.caption)

                Text("© 2025 VoxType")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

/// Row displaying license information for a dependency.
struct LicenseRow: View {
    let name: String
    let license: String
    let url: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                Text(license)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Link(destination: URL(string: url)!) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Global Dictionary Request Tab

struct GlobalDictionaryRequestView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var requestService = GlobalDictionaryRequestService.shared
    @State private var pattern = ""
    @State private var replacement = ""
    @State private var successMessage: String?

    var body: some View {
        Form {
            if !authService.isAuthenticated {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text(localization.t("globalRequest.loginRequired"))
                        .font(.headline)

                    Text(localization.t("globalRequest.loginDescription"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(localization.t("globalRequest.pattern"), text: $pattern)
                        TextField(localization.t("globalRequest.replacement"), text: $replacement)

                        Button(localization.t("globalRequest.submit")) {
                            submitRequest()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(requestService.isLoading || pattern.isEmpty || replacement.isEmpty)

                        if let successMessage {
                            Text(successMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let errorMessage = requestService.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text(localization.t("globalRequest.title"))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func submitRequest() {
        guard let token = authService.token else { return }

        Task {
            let success = await requestService.submitRequest(
                pattern: pattern.trimmingCharacters(in: .whitespacesAndNewlines),
                replacement: replacement.trimmingCharacters(in: .whitespacesAndNewlines),
                token: token
            )

            if success {
                pattern = ""
                replacement = ""
                successMessage = localization.t("globalRequest.successNote")
                requestService.errorMessage = nil
            } else {
                successMessage = nil
            }
        }
    }
}

// MARK: - Language Settings Tab

/// Language settings tab for changing app display language.
struct LanguageSettingsView: View {
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        Form {
            Section {
                Picker(localization.t("language.appLanguage"), selection: $localization.language) {
                    ForEach(Language.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.inline)

                Text(localization.t("language.description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(localization.t("language.title"))
            }
        }
        .formStyle(.grouped)
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
