import Foundation
import Carbon
import Cocoa

/// Manager for global hotkey monitoring.
/// Uses CGEvent tap to monitor keyboard events system-wide.
@MainActor
class HotkeyManager: ObservableObject {
    enum KeyboardHoldTransition {
        case none
        case start
        case stop
    }

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

    /// Called when model change hotkey is pressed.
    var onModelHotkeyPressed: (() -> Void)?

    /// Called when mouse hotkey long press starts.
    var onMouseHotkeyDown: ((NSRunningApplication?) -> Void)?

    /// Called when mouse hotkey long press ends.
    var onMouseHotkeyUp: (() -> Void)?

    /// Called when right-shift double-tap is detected.
    var onRightShiftDoubleTapToggle: (() -> Void)?

    // MARK: - Private Properties

    /// The event tap for monitoring keyboard events.
    private var eventTap: CFMachPort?

    /// Run loop source for the event tap.
    private var runLoopSource: CFRunLoopSource?

    /// Timer for mouse long press detection.
    private var mouseHoldTimer: Timer?

    /// Whether mouse long press is active.
    private var isMouseHoldActive = false

    /// Whether mouse is currently pressed.
    private var isMousePressed = false

    /// Frontmost app captured on mouse press.
    private var mouseHotkeyTargetApp: NSRunningApplication?

    /// Right-shift key code.
    nonisolated private static let rightShiftKeyCode: UInt16 = 60

    /// Double-tap state holder for right-shift mode.
    nonisolated private static let rightShiftTapStateLock = NSLock()
    nonisolated(unsafe) private static var lastRightShiftTapAt: TimeInterval?

    /// Snapshot mode used by active recording session.
    private var activeRecordingMode: RecordingHotkeyMode?

    /// Right-shift input-test state.
    nonisolated private static let rightShiftInputTestLock = NSLock()
    nonisolated(unsafe) private static var isRightShiftInputTestActive = false
    private var rightShiftInputTestCompletion: ((Bool) -> Void)?

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
        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)

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
        activeRecordingMode = nil
    }

    /// Refresh monitoring based on current settings.
    func refreshMonitoring() {
        if settings.hotkeyEnabled || settings.modelHotkeyEnabled {
            _ = startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    /// Run one-shot input test for right shift without starting recording.
    func runRightShiftInputTest(timeout: TimeInterval = 3.0, completion: @escaping (Bool) -> Void) {
        guard timeout > 0 else {
            completion(false)
            return
        }

        rightShiftInputTestCompletion = completion

        Self.rightShiftInputTestLock.lock()
        Self.isRightShiftInputTestActive = true
        Self.rightShiftInputTestLock.unlock()

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finishRightShiftInputTest(success: false)
        }
    }

    /// Check if accessibility permission is granted.
    @discardableResult
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
        print("🔐 [Accessibility] checkAccessibilityPermission: 権限=\(hasAccessibilityPermission)")
        return hasAccessibilityPermission
    }

    /// Request accessibility permission (shows system dialog).
    func requestAccessibilityPermission() {
        print("🔐 [Accessibility] requestAccessibilityPermission: ダイアログ表示を試みる")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let result = AXIsProcessTrustedWithOptions(options)
        print("🔐 [Accessibility] requestAccessibilityPermission: 結果=\(result)")

        // Check again after a delay (user might grant permission)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    /// Request accessibility permission on app launch.
    /// This is called from App init() to show the dialog immediately.
    nonisolated func requestAccessibilityPermissionOnLaunch() {
        print("🔐 [Accessibility] requestAccessibilityPermissionOnLaunch: アプリ起動時に権限リクエスト")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let result = AXIsProcessTrustedWithOptions(options)
        print("🔐 [Accessibility] requestAccessibilityPermissionOnLaunch: 結果=\(result)")
    }

    // MARK: - Private Methods

    private func createEventTap(eventMask: CGEventMask) -> CFMachPort? {
        // Store self reference for callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            if manager.handleRightShiftInputTestSync(type: type, event: event) {
                return Unmanaged.passRetained(event)
            }

            if manager.isRightShiftDoubleTapModeSync() && type == .flagsChanged {
                let shouldConsume = manager.handleRightShiftDoubleTapSync(event: event)
                return shouldConsume ? nil : Unmanaged.passRetained(event)
            }

            // Check if this is our hotkey (synchronously, thread-safe)
            let isHotkey = manager.isMatchingHotkeySync(event: event)
            let isModelHotkey = manager.isMatchingModelHotkeySync(event: event)
            let isMouseHotkey = manager.isMatchingMouseHotkeySync(event: event)

            // For keyDown, check if it matches our hotkey
            if type == .keyDown && isModelHotkey {
                DispatchQueue.main.async {
                    manager.handleModelHotkey(event: event)
                }
                // Consume the event to prevent key from being typed
                return nil
            }

            if type == .keyDown && isHotkey {
                DispatchQueue.main.async {
                    manager.handleEvent(type: type, event: event)
                }
                // Consume the event to prevent key from being typed
                return nil
            }

            if type == .otherMouseDown && isMouseHotkey {
                DispatchQueue.main.async {
                    manager.handleMouseDown(event: event)
                }
                return Unmanaged.passRetained(event)
            }

            if type == .otherMouseUp && isMouseHotkey {
                let shouldConsume = manager.shouldConsumeMouseUp()
                DispatchQueue.main.async {
                    manager.handleMouseUp(event: event)
                }
                return shouldConsume ? nil : Unmanaged.passRetained(event)
            }

            // For keyUp and flagsChanged, always pass to handleEvent
            // so we can properly detect when the hotkey is released
            if type == .keyUp || type == .flagsChanged {
                DispatchQueue.main.async {
                    manager.handleEvent(type: type, event: event)
                }
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

    /// Thread-safe hotkey matching for use in CGEventTap callback.
    /// Reads directly from UserDefaults which is thread-safe.
    nonisolated private func isMatchingHotkeySync(event: CGEvent) -> Bool {
        let isEnabled = UserDefaults.standard.object(forKey: "hotkeyEnabled") as? Bool ?? true
        guard isEnabled else { return false }

        let mode = UserDefaults.standard.string(forKey: "recordingHotkeyMode") ?? "keyboard"
        guard mode == "keyboardHold" || mode == "keyboard" else { return false }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Read directly from UserDefaults (thread-safe)
        let configuredKeyCode = UInt16(UserDefaults.standard.integer(forKey: "hotkeyKeyCode"))
        let configuredModifiers = UInt(UserDefaults.standard.integer(forKey: "hotkeyModifiers"))

        // Use defaults if not set
        let effectiveKeyCode = configuredKeyCode == 0 ? UInt16(47) : configuredKeyCode // Period (.)
        let effectiveModifiers = configuredModifiers == 0 ? UInt(0x040000) : configuredModifiers // Control

        // Check key code
        guard keyCode == effectiveKeyCode else { return false }

        // Check modifiers
        var currentModifiers: UInt = 0
        if flags.contains(.maskCommand) {
            currentModifiers |= (1 << 20)
        }
        if flags.contains(.maskShift) {
            currentModifiers |= (1 << 17)
        }
        if flags.contains(.maskControl) {
            currentModifiers |= (1 << 18)
        }
        if flags.contains(.maskAlternate) {
            currentModifiers |= (1 << 19)
        }

        return (currentModifiers & effectiveModifiers) == effectiveModifiers
    }

    /// Thread-safe model hotkey matching for use in CGEventTap callback.
    /// Reads directly from UserDefaults which is thread-safe.
    nonisolated private func isMatchingModelHotkeySync(event: CGEvent) -> Bool {
        let isEnabled = UserDefaults.standard.object(forKey: "modelHotkeyEnabled") as? Bool ?? true
        guard isEnabled else { return false }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let configuredKeyCode = UInt16(UserDefaults.standard.integer(forKey: "modelHotkeyKeyCode"))
        let configuredModifiers = UInt(UserDefaults.standard.integer(forKey: "modelHotkeyModifiers"))

        let effectiveKeyCode = configuredKeyCode == 0 ? UInt16(46) : configuredKeyCode // M
        let effectiveModifiers = configuredModifiers == 0 ? UInt(0x040000) : configuredModifiers // Control

        guard keyCode == effectiveKeyCode else { return false }

        var currentModifiers: UInt = 0
        if flags.contains(.maskCommand) {
            currentModifiers |= (1 << 20)
        }
        if flags.contains(.maskShift) {
            currentModifiers |= (1 << 17)
        }
        if flags.contains(.maskControl) {
            currentModifiers |= (1 << 18)
        }
        if flags.contains(.maskAlternate) {
            currentModifiers |= (1 << 19)
        }

        return (currentModifiers & effectiveModifiers) == effectiveModifiers
    }

    nonisolated private func isMatchingMouseHotkeySync(event: CGEvent) -> Bool {
        let isEnabled = UserDefaults.standard.object(forKey: "hotkeyEnabled") as? Bool ?? true
        guard isEnabled else { return false }

        let mode = UserDefaults.standard.string(forKey: "recordingHotkeyMode") ?? "keyboard"
        guard mode == "mouseWheelHold" || mode == "mouseWheel" else { return false }

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        return buttonNumber == 2
    }

    private func handleModelHotkey(event: CGEvent) {
        let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        guard !isAutoRepeat else { return }

        onModelHotkeyPressed?()
    }

    private func handleMouseDown(event: CGEvent) {
        guard !isMousePressed else { return }

        isMousePressed = true
        mouseHotkeyTargetApp = NSWorkspace.shared.frontmostApplication

        mouseHoldTimer?.invalidate()
        mouseHoldTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isMousePressed else { return }

                self.isMouseHoldActive = true
                self.activeRecordingMode = .mouseWheelHold
                self.onMouseHotkeyDown?(self.mouseHotkeyTargetApp)
            }
        }
    }

    private func handleMouseUp(event: CGEvent) {
        guard isMousePressed else { return }

        isMousePressed = false
        mouseHoldTimer?.invalidate()
        mouseHoldTimer = nil

        if isMouseHoldActive {
            isMouseHoldActive = false
            activeRecordingMode = nil
            onMouseHotkeyUp?()
        }

        mouseHotkeyTargetApp = nil
    }

    private func shouldConsumeMouseUp() -> Bool {
        isMouseHoldActive
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        if effectiveRecordingMode() == .rightShiftDoubleTap {
            return
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let isKeyboardHoldMode = effectiveRecordingMode() == .keyboardHold
        let isKeyDownHotkeyMatch = isMatchingHotkey(keyCode: keyCode, flags: flags)
        let isKeyUpConfiguredKeyMatch = settings.hotkeyEnabled
            && isKeyboardHoldMode
            && keyCode == settings.hotkeyKeyCode
        let transition = Self.resolveKeyboardHoldTransition(
            type: type,
            isKeyboardHoldMode: isKeyboardHoldMode,
            isKeyDownHotkeyMatch: isKeyDownHotkeyMatch,
            isKeyUpConfiguredKeyMatch: isKeyUpConfiguredKeyMatch,
            isHotkeyPressed: isHotkeyPressed,
            isModifierPressed: type == .flagsChanged ? checkModifiersMatch(flags: flags) : false
        )

        switch transition {
        case .start:
            isHotkeyPressed = true
            activeRecordingMode = .keyboardHold
            onHotkeyDown?()
        case .stop:
            isHotkeyPressed = false
            activeRecordingMode = nil
            onHotkeyUp?()
        case .none:
            break
        }
    }

    static func resolveKeyboardHoldTransition(
        type: CGEventType,
        isKeyboardHoldMode: Bool,
        isKeyDownHotkeyMatch: Bool,
        isKeyUpConfiguredKeyMatch: Bool,
        isHotkeyPressed: Bool,
        isModifierPressed: Bool
    ) -> KeyboardHoldTransition {
        guard isKeyboardHoldMode else { return .none }

        switch type {
        case .keyDown:
            return (!isHotkeyPressed && isKeyDownHotkeyMatch) ? .start : .none
        case .keyUp:
            return (isHotkeyPressed && isKeyUpConfiguredKeyMatch) ? .stop : .none
        case .flagsChanged:
            return (isHotkeyPressed && !isModifierPressed) ? .stop : .none
        default:
            return .none
        }
    }

    private func isMatchingHotkey(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        guard settings.hotkeyEnabled else { return false }
        guard effectiveRecordingMode() == .keyboardHold else { return false }

        // Get configured hotkey
        let configuredKeyCode = settings.hotkeyKeyCode
        let configuredModifiers = settings.hotkeyModifiers

        // Check key code
        guard keyCode == configuredKeyCode else { return false }

        // Check modifiers
        return checkModifiersMatch(flags: flags, required: configuredModifiers)
    }

    private func effectiveRecordingMode() -> RecordingHotkeyMode {
        if isHotkeyPressed, let activeRecordingMode {
            return activeRecordingMode
        }
        return settings.recordingHotkeyMode
    }

    nonisolated private func isRightShiftDoubleTapModeSync() -> Bool {
        let mode = UserDefaults.standard.string(forKey: "recordingHotkeyMode") ?? "keyboard"
        return mode == "rightShiftDoubleTap"
    }

    nonisolated private func handleRightShiftDoubleTapSync(event: CGEvent) -> Bool {
        let isEnabled = UserDefaults.standard.object(forKey: "hotkeyEnabled") as? Bool ?? true
        guard isEnabled else { return false }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let isShiftPressed = event.flags.contains(.maskShift)
        let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if keyCode != Self.rightShiftKeyCode {
            Self.rightShiftTapStateLock.lock()
            Self.lastRightShiftTapAt = nil
            Self.rightShiftTapStateLock.unlock()
            return false
        }

        guard isShiftPressed, !isAutoRepeat else { return false }

        let now = CFAbsoluteTimeGetCurrent()

        Self.rightShiftTapStateLock.lock()
        defer { Self.rightShiftTapStateLock.unlock() }

        let shouldToggle: Bool
        if let last = Self.lastRightShiftTapAt, now - last <= 0.4 {
            shouldToggle = true
            Self.lastRightShiftTapAt = nil
        } else {
            shouldToggle = false
            Self.lastRightShiftTapAt = now
        }

        guard shouldToggle else { return false }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isHotkeyPressed.toggle()
            if self.isHotkeyPressed {
                self.activeRecordingMode = .rightShiftDoubleTap
                self.onHotkeyDown?()
            } else {
                self.activeRecordingMode = nil
                self.onHotkeyUp?()
            }
            self.onRightShiftDoubleTapToggle?()
        }

        return true
    }

    nonisolated private func handleRightShiftInputTestSync(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .flagsChanged else { return false }

        Self.rightShiftInputTestLock.lock()
        let isActive = Self.isRightShiftInputTestActive
        Self.rightShiftInputTestLock.unlock()
        guard isActive else { return false }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let isShiftPressed = event.flags.contains(.maskShift)
        guard keyCode == Self.rightShiftKeyCode, isShiftPressed else { return false }

        DispatchQueue.main.async { [weak self] in
            self?.finishRightShiftInputTest(success: true)
        }
        return true
    }

    private func finishRightShiftInputTest(success: Bool) {
        Self.rightShiftInputTestLock.lock()
        let wasActive = Self.isRightShiftInputTestActive
        Self.isRightShiftInputTestActive = false
        Self.rightShiftInputTestLock.unlock()
        guard wasActive else { return }

        let completion = rightShiftInputTestCompletion
        rightShiftInputTestCompletion = nil
        completion?(success)
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

    /// Reset hotkey to default (Control+Period).
    func resetToDefault() {
        settings.hotkeyKeyCode = 47 // Period key (.)
        settings.hotkeyModifiers = 0x040000 // Control only
    }
}
