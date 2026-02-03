import Foundation
import SwiftUI

/// Application settings stored in UserDefaults.
@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let serverURL = "serverURL"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let launchAtLogin = "launchAtLogin"
        static let showInDock = "showInDock"
    }

    // MARK: - Default Values

    private enum Defaults {
        static let serverURL = "http://localhost:8000"
        static let hotkeyModifiers: UInt = 0x040000  // Control only
        static let hotkeyKeyCode: UInt16 = 47        // Period key (.)
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

    // MARK: - Computed Properties

    /// Human-readable hotkey string.
    var hotkeyDisplayString: String {
        var parts: [String] = []

        if hotkeyModifiers & (1 << 18) != 0 { parts.append("⌃") }  // Control
        if hotkeyModifiers & (1 << 19) != 0 { parts.append("⌥") }  // Option
        if hotkeyModifiers & (1 << 17) != 0 { parts.append("⇧") }  // Shift
        if hotkeyModifiers & (1 << 20) != 0 { parts.append("⌘") }  // Command

        // Default to ⌘⇧ if no modifiers set
        if parts.isEmpty {
            parts = ["⌘", "⇧"]
        }

        let keyName = keyCodeToString(hotkeyKeyCode)
        parts.append(keyName)

        return parts.joined()
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
        let storedLaunchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        let storedShowInDock = UserDefaults.standard.bool(forKey: Keys.showInDock)

        self.serverURL = storedServerURL ?? Defaults.serverURL
        self.hotkeyModifiers = storedModifiers != 0 ? UInt(storedModifiers) : Defaults.hotkeyModifiers
        self.hotkeyKeyCode = storedKeyCode != 0 ? UInt16(storedKeyCode) : Defaults.hotkeyKeyCode
        self.launchAtLogin = storedLaunchAtLogin
        self.showInDock = storedShowInDock
    }

    // MARK: - Methods

    /// Reset all settings to defaults.
    func resetToDefaults() {
        serverURL = Defaults.serverURL
        hotkeyModifiers = Defaults.hotkeyModifiers
        hotkeyKeyCode = Defaults.hotkeyKeyCode
        launchAtLogin = false
        showInDock = false
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
