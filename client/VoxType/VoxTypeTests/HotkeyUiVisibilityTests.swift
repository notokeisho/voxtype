import XCTest
@testable import VoxType

final class HotkeyUiVisibilityTests: XCTestCase {
    func testKeyboardHoldShowsKeyboardEditor() {
        let visibility = HotkeyUiVisibility.resolve(
            hotkeyEnabled: true,
            mode: .keyboardHold
        )

        XCTAssertTrue(visibility.showModePicker)
        XCTAssertTrue(visibility.showKeyboardEditor)
        XCTAssertFalse(visibility.showRightShiftHint)
        XCTAssertFalse(visibility.showMouseHoldHint)
    }

    func testRightShiftDoubleTapHidesKeyboardEditor() {
        let visibility = HotkeyUiVisibility.resolve(
            hotkeyEnabled: true,
            mode: .rightShiftDoubleTap
        )

        XCTAssertTrue(visibility.showModePicker)
        XCTAssertFalse(visibility.showKeyboardEditor)
        XCTAssertTrue(visibility.showRightShiftHint)
        XCTAssertFalse(visibility.showMouseHoldHint)
    }

    func testMouseWheelHoldHidesKeyboardEditor() {
        let visibility = HotkeyUiVisibility.resolve(
            hotkeyEnabled: true,
            mode: .mouseWheelHold
        )

        XCTAssertTrue(visibility.showModePicker)
        XCTAssertFalse(visibility.showKeyboardEditor)
        XCTAssertFalse(visibility.showRightShiftHint)
        XCTAssertTrue(visibility.showMouseHoldHint)
    }

    func testDisabledHotkeyHidesAllDetailBlocks() {
        let visibility = HotkeyUiVisibility.resolve(
            hotkeyEnabled: false,
            mode: .keyboardHold
        )

        XCTAssertFalse(visibility.showModePicker)
        XCTAssertFalse(visibility.showKeyboardEditor)
        XCTAssertFalse(visibility.showRightShiftHint)
        XCTAssertFalse(visibility.showMouseHoldHint)
    }
}
