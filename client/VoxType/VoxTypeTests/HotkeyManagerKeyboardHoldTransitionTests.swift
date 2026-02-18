import XCTest
@testable import VoxType

final class HotkeyManagerKeyboardHoldTransitionTests: XCTestCase {
    func testKeyDownStartsOnlyWhenHotkeyMatches() {
        let startTransition = HotkeyManager.resolveKeyboardHoldTransition(
            type: .keyDown,
            isKeyboardHoldMode: true,
            isKeyDownHotkeyMatch: true,
            isKeyUpConfiguredKeyMatch: false,
            isHotkeyPressed: false,
            isModifierPressed: false
        )
        XCTAssertEqual(startTransition, .start)

        let nonStartTransition = HotkeyManager.resolveKeyboardHoldTransition(
            type: .keyDown,
            isKeyboardHoldMode: true,
            isKeyDownHotkeyMatch: false,
            isKeyUpConfiguredKeyMatch: false,
            isHotkeyPressed: false,
            isModifierPressed: false
        )
        XCTAssertEqual(nonStartTransition, .none)
    }

    func testKeyUpStopsEvenWhenMatchingHotkeyIsFalse() {
        let transition = HotkeyManager.resolveKeyboardHoldTransition(
            type: .keyUp,
            isKeyboardHoldMode: true,
            isKeyDownHotkeyMatch: false,
            isKeyUpConfiguredKeyMatch: true,
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
            isKeyDownHotkeyMatch: false,
            isKeyUpConfiguredKeyMatch: false,
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
            isKeyDownHotkeyMatch: false,
            isKeyUpConfiguredKeyMatch: false,
            isHotkeyPressed: false,
            isModifierPressed: false
        )

        XCTAssertEqual(
            transition,
            .none,
            "録音中でない keyUp では停止しない必要があります。"
        )
    }

    func testKeyUpWithDifferentConfiguredKeyDoesNotStop() {
        let transition = HotkeyManager.resolveKeyboardHoldTransition(
            type: .keyUp,
            isKeyboardHoldMode: true,
            isKeyDownHotkeyMatch: false,
            isKeyUpConfiguredKeyMatch: false,
            isHotkeyPressed: true,
            isModifierPressed: false
        )
        XCTAssertEqual(transition, .none)
    }

    func testFlagsChangedKeepsRecordingWhenModifierStillPressed() {
        let transition = HotkeyManager.resolveKeyboardHoldTransition(
            type: .flagsChanged,
            isKeyboardHoldMode: true,
            isKeyDownHotkeyMatch: false,
            isKeyUpConfiguredKeyMatch: false,
            isHotkeyPressed: true,
            isModifierPressed: true
        )
        XCTAssertEqual(transition, .none)
    }

    func testNonKeyboardHoldModeNeverTransitions() {
        let events: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        for event in events {
            let transition = HotkeyManager.resolveKeyboardHoldTransition(
                type: event,
                isKeyboardHoldMode: false,
                isKeyDownHotkeyMatch: true,
                isKeyUpConfiguredKeyMatch: true,
                isHotkeyPressed: true,
                isModifierPressed: false
            )
            XCTAssertEqual(transition, .none)
        }
    }
}
