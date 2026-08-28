import HealthFirstCore
import XCTest
@testable import HealthFirstApp

final class AppModelReminderReliabilityTests: XCTestCase {
    func testSeriousPresentationSurvivesTransitionIntoGuidance() throws {
        let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        var reminder = try seriousReminderPresented(at: startedAt)

        XCTAssertTrue(
            ReminderRuntimePolicy.usesSeriousPresentation(reminder)
        )

        try reminder.send(.start, at: startedAt)

        XCTAssertTrue(
            ReminderRuntimePolicy.usesSeriousPresentation(reminder),
            "Serious guidance must keep the full-screen surface and emergency skip"
        )

        try reminder.send(.emergencySkip, at: startedAt.addingTimeInterval(1))

        XCTAssertFalse(
            ReminderRuntimePolicy.usesSeriousPresentation(reminder)
        )
    }

    func testStandardGuidanceNeverUsesSeriousPresentation() throws {
        let startedAt = Date(timeIntervalSinceReferenceDate: 2_000)
        var reminder = ReminderInstance(
            kind: .eye,
            dueAt: startedAt,
            mode: .standard
        )
        try reminder.send(.deadlineReached, at: startedAt)
        try reminder.send(.start, at: startedAt)

        XCTAssertFalse(
            ReminderRuntimePolicy.usesSeriousPresentation(reminder)
        )
    }

    func testOnlyAutomaticPresentationDefersOutsideWorkday() throws {
        let reminder = try firstPresentedReminder()

        XCTAssertTrue(
            ReminderRuntimePolicy.shouldDeferOutsideWorkday(
                reminder: reminder,
                isManual: false,
                isWithinWorkday: false
            )
        )
        XCTAssertFalse(
            ReminderRuntimePolicy.shouldDeferOutsideWorkday(
                reminder: reminder,
                isManual: true,
                isWithinWorkday: false
            ),
            "Manual previews keep running outside configured hours"
        )
        XCTAssertFalse(
            ReminderRuntimePolicy.shouldDeferOutsideWorkday(
                reminder: reminder,
                isManual: false,
                isWithinWorkday: true
            )
        )
    }

    func testDisablingKindDiscardsOnlyItsAutomaticRuntimeSurfaces() throws {
        let reminder = try firstPresentedReminder(kind: .standing)
        let exit = PanelExitAnimation.retry(.standing)

        XCTAssertTrue(
            ReminderRuntimePolicy.shouldDiscardActiveReminder(
                of: .standing,
                reminder: reminder,
                isManual: false
            )
        )
        XCTAssertFalse(
            ReminderRuntimePolicy.shouldDiscardActiveReminder(
                of: .eye,
                reminder: reminder,
                isManual: false
            )
        )
        XCTAssertFalse(
            ReminderRuntimePolicy.shouldDiscardActiveReminder(
                of: .standing,
                reminder: reminder,
                isManual: true
            ),
            "Turning off scheduling must not cancel an explicit preview"
        )
        XCTAssertTrue(
            ReminderRuntimePolicy.shouldDiscardExitAnimation(
                of: .standing,
                animation: exit,
                isManual: false
            )
        )
        XCTAssertFalse(
            ReminderRuntimePolicy.shouldDiscardExitAnimation(
                of: .standing,
                animation: exit,
                isManual: true
            )
        )
    }

    private func firstPresentedReminder(
        kind: ReminderKind = .eye
    ) throws -> ReminderInstance {
        let dueAt = Date(timeIntervalSinceReferenceDate: 3_000)
        var reminder = ReminderInstance(kind: kind, dueAt: dueAt)
        try reminder.send(.deadlineReached, at: dueAt)
        return reminder
    }

    private func seriousReminderPresented(
        at date: Date
    ) throws -> ReminderInstance {
        var reminder = ReminderInstance(
            kind: .standing,
            dueAt: date,
            mode: .serious,
            retryDelay: 0
        )
        try reminder.send(.deadlineReached, at: date)
        try reminder.send(.noResponse, at: date)
        try reminder.send(.deadlineReached, at: date)
        try reminder.send(.noResponse, at: date)
        return reminder
    }
}
