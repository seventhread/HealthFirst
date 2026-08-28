import HealthFirstCore
import XCTest
@testable import HealthFirstApp

final class ReminderCopyTests: XCTestCase {
    func testSnoozeActionUsesPlainDelayLabelForEveryToneAndKind() {
        for kind in ReminderKind.allCases {
            for tone in ReminderCopyTone.allCases {
                XCTAssertEqual(
                    ReminderCopy.actionLabels(
                        for: kind,
                        tone: tone,
                        snoozeDelay: 3 * 60
                    ).snooze,
                    "3 分钟后提醒"
                )
                XCTAssertEqual(
                    ReminderCopy.actionLabels(
                        for: kind,
                        tone: tone,
                        snoozeDelay: 10 * 60
                    ).snooze,
                    "10 分钟后提醒"
                )
            }
        }
    }

    func testActionLabelsUseConfiguredGuideDurations() {
        XCTAssertEqual(
            ReminderCopy.actionLabels(
                for: .eye,
                tone: .gentle,
                guideDuration: 45
            ).start,
            "好，望远 45 秒"
        )
        XCTAssertEqual(
            ReminderCopy.actionLabels(
                for: .standing,
                tone: .gentle,
                guideDuration: 90
            ).start,
            "好，起身 90 秒"
        )
        XCTAssertEqual(
            ReminderCopy.actionLabels(
                for: .quietPractice,
                tone: .gentle,
                guideDuration: 60
            ).start,
            "好，做 1 分钟小动作"
        )
    }

    func testCompletionCopyReplacesLegacyDefaultDurationText() {
        let eye = ReminderCopy.receipt(
            for: .eye,
            outcome: .completed,
            tone: .gentle,
            guideDuration: 45
        )
        XCTAssertTrue(eye.message.contains("45 秒"))
        XCTAssertFalse(eye.message.contains("20 秒"))

        let standing = ReminderCopy.receipt(
            for: .standing,
            outcome: .completed,
            tone: .gentle,
            guideDuration: 90
        )
        XCTAssertTrue(standing.message.contains("90 秒"))
        XCTAssertFalse(standing.message.contains("60 秒"))

        let quietPrompts = (0..<64).map { seed in
            ReminderCopy.prompt(
                for: .quietPractice,
                stage: .first,
                tone: .gentle,
                seed: UInt64(seed),
                guideDuration: 60
            )
        }
        XCTAssertTrue(
            quietPrompts.contains {
                $0.title.contains("1 分钟") || $0.message.contains("1 分钟")
            }
        )
        XCTAssertFalse(
            quietPrompts.contains {
                $0.title.contains("30 秒")
                    || $0.message.contains("30 秒")
                    || $0.title.contains("半分钟")
                    || $0.message.contains("半分钟")
            }
        )
    }
}
