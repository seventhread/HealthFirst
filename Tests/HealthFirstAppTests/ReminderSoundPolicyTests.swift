import HealthFirstCore
import XCTest
@testable import HealthFirstApp

final class ReminderSoundPolicyTests: XCTestCase {
    func testOnlyAutomaticPromptPresentationsPlay() {
        XCTAssertTrue(
            ReminderSoundPolicy.shouldPlay(
                isEnabled: true,
                userInitiated: false,
                state: .firstPresented(at: .distantPast)
            )
        )
        XCTAssertTrue(
            ReminderSoundPolicy.shouldPlay(
                isEnabled: true,
                userInitiated: false,
                state: .followUpPresented(at: .distantPast)
            )
        )
        XCTAssertTrue(
            ReminderSoundPolicy.shouldPlay(
                isEnabled: true,
                userInitiated: false,
                state: .seriousPresented(at: .distantPast)
            )
        )

        XCTAssertFalse(
            ReminderSoundPolicy.shouldPlay(
                isEnabled: false,
                userInitiated: false,
                state: .firstPresented(at: .distantPast)
            )
        )
        XCTAssertFalse(
            ReminderSoundPolicy.shouldPlay(
                isEnabled: true,
                userInitiated: true,
                state: .firstPresented(at: .distantPast)
            )
        )
        XCTAssertFalse(
            ReminderSoundPolicy.shouldPlay(
                isEnabled: true,
                userInitiated: false,
                state: .guided(startedAt: .distantPast, endsAt: .distantFuture)
            )
        )
    }
}
