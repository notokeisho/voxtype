import Foundation
import Carbon
import Cocoa

/// Manager for global hotkey monitoring.
/// Uses CGEvent tap to monitor keyboard events system-wide.
@MainActor
class HotkeyManager: ObservableObject {
    /// Shared instance.
    static let shared = HotkeyManager()

    // MARK: - Published Properties

    /// Whether the hotkey is currently pressed.
    @Published private(set) var isHotkeyPressed = false

    /// Whether the manager is currently monitoring.
    @Published private(set) var isMonitoring = false

    /// Whether accessibility permission is granted.
    @Published private(set) var hasAccessibilityPermission = false

    // MARK: - Callbacks

    /// Called when hotkey is pressed down.
    var onHotkeyDown: (() -> Void)?

    /// Called when hotkey is released.
    var onHotkeyUp: (() -> Void)?

    // MARK: - Private Properties

    /// The event tap for monitoring keyboard events.
    private var eventTap: CFMachPort?

    /// Run loop source for the event tap.
    private var runLoopSource: CFRunLoopSource?

    /// Settings reference for hotkey configuration.
    private let settings = AppSettings.shared

    // MARK: - Initialization

    private init() {
        checkAccessibilityPermission()
    }

    // MARK: - Public Methods

    /// Start monitoring for hotkey events.
    /// - Returns: `true` if monitoring started successfully.
    @discardableResult
    func startMonitoring() -> Bool {
        guard !isMonitoring else { return true }

        // Check accessibility permission
        guard checkAccessibilityPermission() else {
            requestAccessibilityPermission()
            return false
        }

        // Create event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        // We need to use a static callback, so we'll use a different approach
        guard let tap = createEventTap(eventMask: CGEventMask(eventMask)) else {
            print("Failed to create event tap")
            return false
        }

        eventTap = tap

        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source = runLoopSource else {
            print("Failed to create run loop source")
            return false
        }

        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)

        // Enable the event tap
        CGEvent.tapEnable(tap: tap, enable: true)

        isMonitoring = true
        return true
    }

    /// Stop monitoring for hotkey events.
    func stopMonitoring() {
        guard isMonitoring else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        isHotkeyPressed = false
    }

    /// Check if accessibility permission is granted.
    @discardableResult
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
        return hasAccessibilityPermission
    }

    /// Request accessibility permission (shows system dialog).
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Check again after a delay (user might grant permission)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    // MARK: - Private Methods

    private func createEventTap(eventMask: CGEventMask) -> CFMachPort? {
        // Store self reference for callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            // Handle the event on main thread
            DispatchQueue.main.async {
                manager.handleEvent(type: type, event: event)
            }

            return Unmanaged.passRetained(event)
        }

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: refcon
        )
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Check if this is our hotkey
        guard isMatchingHotkey(keyCode: keyCode, flags: flags) else {
            return
        }

        switch type {
        case .keyDown:
            if !isHotkeyPressed {
                isHotkeyPressed = true
                onHotkeyDown?()
            }

        case .keyUp:
            if isHotkeyPressed {
                isHotkeyPressed = false
                onHotkeyUp?()
            }

        case .flagsChanged:
            // Handle modifier-only hotkeys or modifier release
            let isModifierPressed = checkModifiersMatch(flags: flags)
            if isHotkeyPressed && !isModifierPressed {
                // Modifiers were released
                isHotkeyPressed = false
                onHotkeyUp?()
            }

        default:
            break
        }
    }

    private func isMatchingHotkey(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        // Get configured hotkey
        let configuredKeyCode = settings.hotkeyKeyCode
        let configuredModifiers = settings.hotkeyModifiers

        // Check key code
        guard keyCode == configuredKeyCode else { return false }

        // Check modifiers
        return checkModifiersMatch(flags: flags, required: configuredModifiers)
    }

    private func checkModifiersMatch(flags: CGEventFlags, required: UInt? = nil) -> Bool {
        let modifiers = required ?? settings.hotkeyModifiers

        // Convert CGEventFlags to our modifier format
        var currentModifiers: UInt = 0

        if flags.contains(.maskCommand) {
            currentModifiers |= (1 << 20) // Command
        }
        if flags.contains(.maskShift) {
            currentModifiers |= (1 << 17) // Shift
        }
        if flags.contains(.maskControl) {
            currentModifiers |= (1 << 18) // Control
        }
        if flags.contains(.maskAlternate) {
            currentModifiers |= (1 << 19) // Option
        }

        // Check if required modifiers are present
        return (currentModifiers & modifiers) == modifiers
    }

    deinit {
        // Note: deinit won't be called on MainActor, but we handle cleanup in stopMonitoring
    }
}

// MARK: - Hotkey Configuration Helper

extension HotkeyManager {
    /// Get the display string for the current hotkey configuration.
    var hotkeyDisplayString: String {
        settings.hotkeyDisplayString
    }

    /// Update the hotkey configuration.
    func setHotkey(keyCode: UInt16, modifiers: UInt) {
        settings.hotkeyKeyCode = keyCode
        settings.hotkeyModifiers = modifiers
    }

    /// Reset hotkey to default (Option+Space).
    func resetToDefault() {
        settings.hotkeyKeyCode = 49 // Space key
        settings.hotkeyModifiers = 0x080000 // Option only
    }
}
