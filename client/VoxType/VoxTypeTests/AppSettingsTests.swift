import XCTest
@testable import VoxType

final class AppSettingsTests: XCTestCase {
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
}
