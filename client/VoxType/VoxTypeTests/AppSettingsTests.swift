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
    func testRecordingHotkeyModeDefaultIsRightShiftDoubleTap() {
        let settings = AppSettings.shared
        settings.resetToDefaults()

        XCTAssertEqual(
            settings.recordingHotkeyMode.rawValue,
            "rightShiftDoubleTap",
            "録音方式の既定値は rightShiftDoubleTap である必要があります。"
        )
    }

    @MainActor
    func testRecordingHotkeyModePersistedValueIsRightShiftDoubleTap() {
        let settings = AppSettings.shared
        settings.resetToDefaults()

        let stored = UserDefaults.standard.string(forKey: recordingHotkeyModeKey)
        XCTAssertEqual(
            stored,
            "rightShiftDoubleTap",
            "recordingHotkeyMode の保存値は rightShiftDoubleTap である必要があります。"
        )
    }
}
