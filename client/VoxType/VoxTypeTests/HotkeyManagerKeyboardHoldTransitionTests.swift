import XCTest
@testable import VoxType

final class HotkeyManagerKeyboardHoldTransitionTests: XCTestCase {
    func testKeyUpStopsEvenWhenMatchingHotkeyIsFalse() {
        let transition = HotkeyManager.resolveKeyboardHoldTransition(
            type: .keyUp,
            isKeyboardHoldMode: true,
            isMatchingHotkey: false,
            isHotkeyPressed: true,
            isModifierPressed: false
        )

        XCTAssertEqual(
            transition,
            .stop,
            "modifier先離し後の keyUp でも停止する必要があります。"
        )
    }

    func testFlagsChangedStopsOnModifierBreakEvenWhenMatchingHotkeyIsFalse() {
        let transition = HotkeyManager.resolveKeyboardHoldTransition(
            type: .flagsChanged,
            isKeyboardHoldMode: true,
            isMatchingHotkey: false,
            isHotkeyPressed: true,
            isModifierPressed: false
        )

        XCTAssertEqual(
            transition,
            .stop,
            "required modifier 崩れの flagsChanged で停止する必要があります。"
        )
    }

    func testIrrelevantKeyUpDoesNotStopWhenNotPressed() {
        let transition = HotkeyManager.resolveKeyboardHoldTransition(
            type: .keyUp,
            isKeyboardHoldMode: true,
            isMatchingHotkey: false,
            isHotkeyPressed: false,
            isModifierPressed: false
        )

        XCTAssertEqual(
            transition,
            .none,
            "録音中でない keyUp では停止しない必要があります。"
        )
    }
}
