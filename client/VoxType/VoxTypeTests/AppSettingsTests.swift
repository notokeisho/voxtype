import XCTest
@testable import VoxType

final class AppSettingsTests: XCTestCase {
    private let recordingHotkeyModeKey = "recordingHotkeyMode"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: recordingHotkeyModeKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: recordingHotkeyModeKey)
        super.tearDown()
    }

    @MainActor
    func testRecordingHotkeyModeDefaultIsKeyboardHold() {
        let settings = AppSettings.shared
        settings.resetToDefaults()

        XCTAssertEqual(
            settings.recordingHotkeyMode.rawValue,
            "keyboardHold",
            "録音方式の既定値は keyboardHold である必要があります。"
        )
    }

    @MainActor
    func testRecordingHotkeyModePersistedValueIsKeyboardHold() {
        let settings = AppSettings.shared
        settings.resetToDefaults()

        let stored = UserDefaults.standard.string(forKey: recordingHotkeyModeKey)
        XCTAssertEqual(
            stored,
            "keyboardHold",
            "recordingHotkeyMode の保存値は keyboardHold である必要があります。"
        )
    }
}
