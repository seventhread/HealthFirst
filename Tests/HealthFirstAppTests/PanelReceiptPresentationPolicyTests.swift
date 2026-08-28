import HealthFirstCore
import XCTest
@testable import HealthFirstApp

final class PanelReceiptPresentationPolicyTests: XCTestCase {
    func testStandingCompletionWaitsForOutroThenShowsOneBubbleInterval() {
        XCTAssertEqual(
            PanelReceiptPresentationPolicy.displayDuration(
                for: .completed,
                kind: .standing,
                reduceMotion: false
            ),
            StandingCompletionTimeline.duration
                + PanelReceiptPresentationPolicy.bubbleDisplayDuration,
            accuracy: 1e-9
        )
    }

    func testEveryOtherReceiptUsesTheShortPassiveToastDuration() {
        let receipts: [PanelReceipt] = [
            .completed,
            .snoozed(minutes: 3),
            .skipped,
            .endedEarly,
            .emergencySkipped,
        ]

        for receipt in receipts {
            for reduceMotion in [false, true] {
                XCTAssertEqual(
                    PanelReceiptPresentationPolicy.displayDuration(
                        for: receipt,
                        kind: .eye,
                        reduceMotion: reduceMotion
                    ),
                    3.6,
                    accuracy: 1e-9,
                    "unexpected duration for \(receipt)"
                )
            }
        }
    }

    func testReducedMotionSkipsTheStandingOutroWait() {
        XCTAssertEqual(
            PanelReceiptPresentationPolicy.displayDuration(
                for: .completed,
                kind: .standing,
                reduceMotion: true
            ),
            PanelReceiptPresentationPolicy.bubbleDisplayDuration,
            accuracy: 1e-9
        )
    }

    func testOnlyNonVoiceOverReceiptsPassMouseEventsThrough() {
        XCTAssertTrue(
            PanelReceiptPresentationPolicy.allowsMouseInteraction(
                hasReceipt: false,
                voiceOverEnabled: false
            )
        )
        XCTAssertFalse(
            PanelReceiptPresentationPolicy.allowsMouseInteraction(
                hasReceipt: true,
                voiceOverEnabled: false
            )
        )
        XCTAssertTrue(
            PanelReceiptPresentationPolicy.allowsMouseInteraction(
                hasReceipt: true,
                voiceOverEnabled: true
            )
        )
    }

    func testVoiceOverControlsWhetherAReceiptGetsADismissalDeadline() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)

        XCTAssertNil(
            PanelReceiptPresentationPolicy.dismissalDeadline(
                at: now,
                voiceOverEnabled: true,
                displayDuration: 3.6
            )
        )
        XCTAssertEqual(
            PanelReceiptPresentationPolicy.dismissalDeadline(
                at: now,
                voiceOverEnabled: false,
                displayDuration: 3.6
            ),
            now.addingTimeInterval(3.6)
        )
    }
}
