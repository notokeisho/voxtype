import Foundation
import SwiftUI

enum RecordingHotkeyMode: String, CaseIterable {
    case keyboardHold
    case rightShiftDoubleTap
    case mouseWheelHold

    // Temporary aliases to keep incremental migration compile-safe.
    static let keyboard = RecordingHotkeyMode.keyboardHold
    static let mouseWheel = RecordingHotkeyMode.mouseWheelHold
}

/// Application settings stored in UserDefaults.
@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let serverURL = "serverURL"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyEnabled = "hotkeyEnabled"
        static let recordingHotkeyMode = "recordingHotkeyMode"
        static let modelHotkeyModifiers = "modelHotkeyModifiers"
        static let modelHotkeyKeyCode = "modelHotkeyKeyCode"
        static let modelHotkeyEnabled = "modelHotkeyEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let showInDock = "showInDock"
        static let whisperModel = "whisperModel"
        static let noiseFilterLevel = "noiseFilterLevel"
    }

    // MARK: - Default Values

    private enum Defaults {
        static let serverURL = "http://localhost:8000"
        static let hotkeyModifiers: UInt = 0x040000  // Control only
        static let hotkeyKeyCode: UInt16 = 47        // Period key (.)
        static let hotkeyEnabled = true
        static let recordingHotkeyMode: RecordingHotkeyMode = .rightShiftDoubleTap
        static let modelHotkeyModifiers: UInt = 0x040000  // Control only
        static let modelHotkeyKeyCode: UInt16 = 46        // M key
        static let modelHotkeyEnabled = true
        static let noiseFilterLevel: Double = 0.3
    }

    // MARK: - Published Properties

    /// Server URL for the API.
    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: Keys.serverURL)
        }
    }

    /// Hotkey modifier flags (Command, Shift, Option, Control).
    @Published var hotkeyModifiers: UInt {
        didSet {
            UserDefaults.standard.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers)
        }
    }

    /// Hotkey key code.
    @Published var hotkeyKeyCode: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode)
        }
    }

    /// Whether recording hotkey is enabled.
    @Published var hotkeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hotkeyEnabled, forKey: Keys.hotkeyEnabled)
            HotkeyManager.shared.refreshMonitoring()
        }
    }

    /// Recording hotkey input mode.
    @Published var recordingHotkeyMode: RecordingHotkeyMode {
        didSet {
            UserDefaults.standard.set(recordingHotkeyMode.rawValue, forKey: Keys.recordingHotkeyMode)
            HotkeyManager.shared.refreshMonitoring()
        }
    }

    var isMouseWheelRecordingEnabled: Bool {
        get { recordingHotkeyMode == .mouseWheelHold }
        set { recordingHotkeyMode = newValue ? .mouseWheelHold : .keyboardHold }
    }

    /// Model change hotkey modifier flags.
    @Published var modelHotkeyModifiers: UInt {
        didSet {
            UserDefaults.standard.set(modelHotkeyModifiers, forKey: Keys.modelHotkeyModifiers)
        }
    }

    /// Model change hotkey key code.
    @Published var modelHotkeyKeyCode: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(modelHotkeyKeyCode), forKey: Keys.modelHotkeyKeyCode)
        }
    }

    /// Whether model change hotkey is enabled.
    @Published var modelHotkeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(modelHotkeyEnabled, forKey: Keys.modelHotkeyEnabled)
            HotkeyManager.shared.refreshMonitoring()
        }
    }

    /// Whether to launch at login.
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }

    /// Whether to show in Dock (requires restart).
    @Published var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: Keys.showInDock)
        }
    }

    /// Selected Whisper model for transcription.
    @Published var whisperModel: WhisperModel {
        didSet {
            UserDefaults.standard.set(whisperModel.rawValue, forKey: Keys.whisperModel)
        }
    }

    /// Noise filter level for VAD (0.0 disables VAD).
    @Published var noiseFilterLevel: Double {
        didSet {
            UserDefaults.standard.set(noiseFilterLevel, forKey: Keys.noiseFilterLevel)
        }
    }

    // MARK: - Computed Properties

    /// Human-readable hotkey string.
    var hotkeyDisplayString: String {
        formatHotkeyDisplayString(modifiers: hotkeyModifiers, keyCode: hotkeyKeyCode)
    }

    /// Human-readable model change hotkey string.
    var modelHotkeyDisplayString: String {
        formatHotkeyDisplayString(modifiers: modelHotkeyModifiers, keyCode: modelHotkeyKeyCode)
    }

    /// Server URL as URL object.
    var serverURLValue: URL? {
        URL(string: serverURL)
    }

    /// Whether the server URL is valid.
    var isServerURLValid: Bool {
        guard let url = serverURLValue else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    // MARK: - Initialization

    private init() {
        // Load all properties at once to avoid initialization order issues
        let storedServerURL = UserDefaults.standard.string(forKey: Keys.serverURL)
        let storedModifiers = UserDefaults.standard.integer(forKey: Keys.hotkeyModifiers)
        let storedKeyCode = UserDefaults.standard.integer(forKey: Keys.hotkeyKeyCode)
        let storedHotkeyEnabled = UserDefaults.standard.object(forKey: Keys.hotkeyEnabled) as? Bool
        let storedRecordingMode = UserDefaults.standard.string(forKey: Keys.recordingHotkeyMode)
        let storedModelModifiers = UserDefaults.standard.integer(forKey: Keys.modelHotkeyModifiers)
        let storedModelKeyCode = UserDefaults.standard.integer(forKey: Keys.modelHotkeyKeyCode)
        let storedModelHotkeyEnabled = UserDefaults.standard.object(forKey: Keys.modelHotkeyEnabled) as? Bool
        let storedLaunchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        let storedShowInDock = UserDefaults.standard.bool(forKey: Keys.showInDock)
        let storedWhisperModel = UserDefaults.standard.string(forKey: Keys.whisperModel)
        let storedNoiseFilterLevel = UserDefaults.standard.object(forKey: Keys.noiseFilterLevel) as? Double

        self.serverURL = storedServerURL ?? Defaults.serverURL
        self.hotkeyModifiers = storedModifiers != 0 ? UInt(storedModifiers) : Defaults.hotkeyModifiers
        self.hotkeyKeyCode = storedKeyCode != 0 ? UInt16(storedKeyCode) : Defaults.hotkeyKeyCode
        self.hotkeyEnabled = storedHotkeyEnabled ?? Defaults.hotkeyEnabled
        self.recordingHotkeyMode = Self.migrateRecordingHotkeyMode(storedRecordingMode) ?? Defaults.recordingHotkeyMode
        self.modelHotkeyModifiers = storedModelModifiers != 0 ? UInt(storedModelModifiers) : Defaults.modelHotkeyModifiers
        self.modelHotkeyKeyCode = storedModelKeyCode != 0 ? UInt16(storedModelKeyCode) : Defaults.modelHotkeyKeyCode
        self.modelHotkeyEnabled = storedModelHotkeyEnabled ?? Defaults.modelHotkeyEnabled
        self.launchAtLogin = storedLaunchAtLogin
        self.showInDock = storedShowInDock
        self.whisperModel = storedWhisperModel.flatMap { WhisperModel(rawValue: $0) } ?? .fast
        self.noiseFilterLevel = storedNoiseFilterLevel ?? Defaults.noiseFilterLevel
    }

    // MARK: - Methods

    /// Reset all settings to defaults.
    func resetToDefaults() {
        serverURL = Defaults.serverURL
        hotkeyModifiers = Defaults.hotkeyModifiers
        hotkeyKeyCode = Defaults.hotkeyKeyCode
        hotkeyEnabled = Defaults.hotkeyEnabled
        recordingHotkeyMode = Defaults.recordingHotkeyMode
        modelHotkeyModifiers = Defaults.modelHotkeyModifiers
        modelHotkeyKeyCode = Defaults.modelHotkeyKeyCode
        modelHotkeyEnabled = Defaults.modelHotkeyEnabled
        launchAtLogin = false
        showInDock = false
        whisperModel = .fast
        noiseFilterLevel = Defaults.noiseFilterLevel
    }

    private func formatHotkeyDisplayString(modifiers: UInt, keyCode: UInt16) -> String {
        var parts: [String] = []

        if modifiers & (1 << 18) != 0 { parts.append("⌃") }  // Control
        if modifiers & (1 << 19) != 0 { parts.append("⌥") }  // Option
        if modifiers & (1 << 17) != 0 { parts.append("⇧") }  // Shift
        if modifiers & (1 << 20) != 0 { parts.append("⌘") }  // Command

        // Default to ⌘⇧ if no modifiers set
        if parts.isEmpty {
            parts = ["⌘", "⇧"]
        }

        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)

        return parts.joined()
    }

    /// Convert key code to human-readable string.
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'",
            40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12",
            113: "F15", 118: "F4", 119: "End", 120: "F2", 121: "PgDn",
            122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
}

private extension AppSettings {
    static func migrateRecordingHotkeyMode(_ storedValue: String?) -> RecordingHotkeyMode? {
        guard let storedValue else { return nil }

        if let mode = RecordingHotkeyMode(rawValue: storedValue) {
            return mode
        }

        switch storedValue {
        case "keyboard":
            return .keyboardHold
        case "mouseWheel":
            return .mouseWheelHold
        default:
            return .keyboardHold
        }
    }
}
