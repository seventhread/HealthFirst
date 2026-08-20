import HealthFirstCore
import XCTest
@testable import HealthFirstApp

final class ReminderSchedulePolicyTests: XCTestCase {
    func testSuspensionPreservesRemainingIntervalDuringCurrentWorkday() {
        let suspendedAt = date(day: 17, hour: 10)
        let originalDue = date(day: 17, hour: 10, minute: 25)
        let resumedAt = date(day: 17, hour: 10, minute: 40)
        let snapshot = policy.captureForSuspension(
            nextDue: [.standing: originalDue],
            at: suspendedAt
        )

        let restored = policy.restore(
            snapshot,
            preserving: [.standing: originalDue],
            at: resumedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(restored[.standing], date(day: 17, hour: 11, minute: 5))
    }

    func testSuspensionBeforeWorkUsesAFullInterval() {
        let suspendedAt = date(day: 17, hour: 8)
        let originalDue = date(day: 17, hour: 9, minute: 10)
        let resumedAt = date(day: 17, hour: 8, minute: 30)
        let snapshot = policy.captureForSuspension(
            nextDue: [.standing: originalDue],
            at: suspendedAt
        )

        let restored = policy.restore(
            snapshot,
            preserving: [.standing: originalDue],
            at: resumedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(restored[.standing], date(day: 17, hour: 9, minute: 40))
    }

    func testWeekendSuspensionUsesAFullIntervalOnNextWorkday() {
        let suspendedAt = date(day: 22, hour: 10) // Saturday
        let originalDue = date(day: 24, hour: 9, minute: 10)
        let resumedAt = date(day: 23, hour: 14) // Sunday
        let snapshot = policy.captureForSuspension(
            nextDue: [.standing: originalDue],
            at: suspendedAt
        )

        let restored = policy.restore(
            snapshot,
            preserving: [.standing: originalDue],
            at: resumedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(restored[.standing], date(day: 24, hour: 9, minute: 40))
    }

    func testOverdueIntervalHasZeroRemainingWork() {
        let suspendedAt = date(day: 17, hour: 10)
        let originalDue = date(day: 17, hour: 9, minute: 55)
        let resumedAt = date(day: 17, hour: 10, minute: 30)
        let snapshot = policy.captureForSuspension(
            nextDue: [.standing: originalDue],
            at: suspendedAt
        )

        let restored = policy.restore(
            snapshot,
            preserving: [.standing: originalDue],
            at: resumedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(restored[.standing], resumedAt)
    }

    func testTwentySecondsOfSystemInactivityResetsEyeInterval() {
        let suspendedAt = date(day: 17, hour: 10)
        let originalDue = date(day: 17, hour: 10, minute: 5)
        let resumedAt = date(day: 17, hour: 10, minute: 30)
        let snapshot = policy.captureForSuspension(
            nextDue: [.eye: originalDue],
            at: suspendedAt
        )

        let justUnderThreshold = policy.restore(
            snapshot,
            preserving: [.eye: originalDue],
            at: resumedAt,
            systemInactivity: 19.999
        )
        let naturalRest = policy.restore(
            snapshot,
            preserving: [.eye: originalDue],
            at: resumedAt,
            systemInactivity: 20
        )

        XCTAssertEqual(
            justUnderThreshold[.eye],
            date(day: 17, hour: 10, minute: 35)
        )
        XCTAssertEqual(
            naturalRest[.eye],
            date(day: 17, hour: 10, minute: 50)
        )
    }

    func testStaleQuietDeadlineMovesToCurrentDaysNextCadenceSlot() {
        let staleDue = date(day: 17, hour: 15)
        let currentDate = date(day: 18, hour: 10)

        let replacement = policy.replacementForStaleQuietDeadline(
            staleDue,
            at: currentDate
        )

        XCTAssertEqual(replacement, date(day: 18, hour: 11))
    }

    func testGuidanceKeepsQuietRemindersRemainingThirtySeconds() {
        let guidanceStartedAt = date(day: 17, hour: 10)
        let originalDue = date(day: 17, hour: 10, second: 30)
        let guidanceEndedAt = date(day: 17, hour: 10, minute: 1)
        let snapshot = policy.captureForGuidance(
            nextDue: [.quietPractice: originalDue],
            at: guidanceStartedAt
        )

        let restored = policy.restore(
            snapshot,
            preserving: [.quietPractice: originalDue],
            at: guidanceEndedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(
            restored[.quietPractice],
            date(day: 17, hour: 10, minute: 1, second: 30)
        )
    }

    func testGuidanceReslotsQuietReminderWhenItEndsOnAnotherDay() {
        let guidanceStartedAt = date(day: 17, hour: 16, minute: 59)
        let originalDue = date(day: 17, hour: 16, minute: 59, second: 30)
        let guidanceEndedAt = date(day: 18, hour: 10)
        let snapshot = policy.captureForGuidance(
            nextDue: [.quietPractice: originalDue],
            at: guidanceStartedAt
        )

        let restored = policy.restore(
            snapshot,
            preserving: [.quietPractice: originalDue],
            at: guidanceEndedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(restored[.quietPractice], date(day: 18, hour: 11))
    }

    func testNaturalRestAlsoResetsEyeDeadlineFrozenByGuidance() {
        let guidanceStartedAt = date(day: 17, hour: 10)
        let originalDue = date(day: 17, hour: 10, second: 30)
        let guidanceEndedAt = date(day: 17, hour: 10, minute: 1)
        let captured = policy.captureForGuidance(
            nextDue: [.eye: originalDue],
            at: guidanceStartedAt
        )
        let reset = policy.resettingEyeCycle(in: captured)

        let restored = policy.restore(
            reset,
            preserving: [.eye: originalDue],
            at: guidanceEndedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(restored[.eye], date(day: 17, hour: 10, minute: 21))
    }

    func testNestedSystemSuspensionRestoresGuidanceSnapshotLast() {
        let guidanceStartedAt = date(day: 17, hour: 10)
        let standingDue = date(day: 17, hour: 10, minute: 1)
        let systemSuspendedAt = date(day: 17, hour: 10, second: 10)
        let resumedAt = date(day: 18, hour: 10)

        let guidance = policy.captureForGuidance(
            nextDue: [.standing: standingDue],
            at: guidanceStartedAt
        )
        let outerSuspension = policy.captureForSuspension(
            nextDue: [.standing: standingDue],
            at: systemSuspendedAt
        )
        let afterOuterSuspension = policy.restore(
            outerSuspension,
            preserving: [.standing: standingDue],
            at: resumedAt,
            systemInactivity: 60
        )
        let afterGuidance = policy.restore(
            guidance,
            preserving: afterOuterSuspension,
            at: resumedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(
            afterOuterSuspension[.standing],
            date(day: 18, hour: 10, second: 50)
        )
        XCTAssertEqual(
            afterGuidance[.standing],
            date(day: 18, hour: 10, minute: 1)
        )
    }

    func testOverlappingSystemReasonsCountTheirUnionOnce() {
        enum Reason: Hashable {
            case sleep
            case locked
        }

        var tracker = SystemInactivityTracker<Reason>()
        XCTAssertTrue(tracker.begin(.sleep, at: date(day: 17, hour: 10)))
        XCTAssertFalse(tracker.begin(.sleep, at: date(day: 17, hour: 10, second: 1)))
        XCTAssertTrue(tracker.begin(.locked, at: date(day: 17, hour: 10, second: 5)))

        XCTAssertTrue(tracker.end(.sleep, at: date(day: 17, hour: 10, second: 10)))
        XCTAssertTrue(tracker.isInactive)
        XCTAssertEqual(tracker.accumulatedDuration, 0)

        XCTAssertTrue(tracker.end(.locked, at: date(day: 17, hour: 10, second: 20)))
        XCTAssertFalse(tracker.isInactive)
        XCTAssertEqual(tracker.accumulatedDuration, 20)
    }

    func testWallClockDetectorIgnoresIrregularTicksAndFindsSignedJumps() throws {
        var detector = WallClockJumpDetector(minimumJumpMagnitude: 1)
        let instant = ContinuousClock.now
        let wall = date(day: 17, hour: 10)

        XCTAssertNil(detector.observe(wallDate: wall, continuousInstant: instant))
        XCTAssertNil(
            detector.observe(
                wallDate: wall.addingTimeInterval(37),
                continuousInstant: instant.advanced(by: .seconds(37))
            )
        )
        let forwardJump = try XCTUnwrap(
            detector.observe(
                wallDate: wall.addingTimeInterval(3_638),
                continuousInstant: instant.advanced(by: .seconds(38))
            )
        )
        XCTAssertEqual(forwardJump, 3_600, accuracy: 0.000_001)

        let backwardJump = try XCTUnwrap(
            detector.observe(
                wallDate: wall.addingTimeInterval(1_839),
                continuousInstant: instant.advanced(by: .seconds(39))
            )
        )
        XCTAssertEqual(backwardJump, -1_800, accuracy: 0.000_001)
    }

    func testSnapshotRebaseKeepsGuidanceRemainingTime() {
        let startedAt = date(day: 17, hour: 10)
        let snapshot = policy.captureForGuidance(
            nextDue: [.standing: startedAt.addingTimeInterval(60)],
            at: startedAt
        )
        let rebased = policy.rebasing(snapshot, by: 3_600)
        let restored = policy.restore(
            rebased,
            preserving: [:],
            at: startedAt.addingTimeInterval(3_630),
            systemInactivity: 0
        )

        XCTAssertEqual(
            restored[.standing],
            startedAt.addingTimeInterval(3_690)
        )
    }

    func testSnapshotRebaseMovesQuietCalendarIdentityWithTheClock() {
        let startedAt = date(day: 17, hour: 16, minute: 59)
        let originalDue = startedAt.addingTimeInterval(30)
        let snapshot = policy.captureForGuidance(
            nextDue: [.quietPractice: originalDue],
            at: startedAt
        )
        let rebased = policy.rebasing(snapshot, by: 86_400)
        let resumedAt = startedAt.addingTimeInterval(86_410)
        let restored = policy.restore(
            rebased,
            preserving: [:],
            at: resumedAt,
            systemInactivity: 0
        )

        XCTAssertEqual(
            restored[.quietPractice],
            startedAt.addingTimeInterval(86_440)
        )
    }

    func testClockRebaseCarriesIntervalRemainderAcrossWorkdayBoundary() {
        let beforeJump = date(day: 17, hour: 16, minute: 50)
        let snapshot = policy.captureForClockRebase(
            nextDue: [
                .standing: date(day: 17, hour: 16, minute: 55),
            ],
            at: beforeJump
        )

        let restored = policy.restoreAfterClockRebase(
            snapshot,
            at: date(day: 17, hour: 17, minute: 50)
        )

        XCTAssertEqual(
            restored[.standing],
            date(day: 18, hour: 9, minute: 5)
        )
    }

    func testRepeatedClockRebaseRetainsDeferredPartialInterval() {
        let firstCapture = policy.captureForClockRebase(
            nextDue: [
                .standing: date(day: 17, hour: 16, minute: 55),
            ],
            at: date(day: 17, hour: 16, minute: 50)
        )
        let afterFirstJump = policy.restoreAfterClockRebase(
            firstCapture,
            at: date(day: 17, hour: 17, minute: 50)
        )
        let deferredRemaining = policy.intervalRemaining(in: firstCapture)

        let secondCapture = policy.captureForClockRebase(
            nextDue: afterFirstJump,
            deferredIntervalRemaining: deferredRemaining,
            at: date(day: 17, hour: 17, minute: 55)
        )
        let afterSecondJump = policy.restoreAfterClockRebase(
            secondCapture,
            at: date(day: 17, hour: 18, minute: 55)
        )

        XCTAssertEqual(
            afterSecondJump[.standing],
            date(day: 18, hour: 9, minute: 5)
        )
    }

    func testSuspensionSnapshotRetainsDeferredPartialInterval() {
        let suspendedAt = date(day: 17, hour: 18)
        let snapshot = policy.captureForSuspension(
            nextDue: [.standing: date(day: 18, hour: 9, minute: 5)],
            deferredIntervalRemaining: [.standing: 5 * 60],
            at: suspendedAt
        )

        let restored = policy.restore(
            snapshot,
            preserving: [:],
            at: date(day: 18, hour: 8),
            systemInactivity: 0
        )

        XCTAssertEqual(
            restored[.standing],
            date(day: 18, hour: 9, minute: 5)
        )
        XCTAssertEqual(
            policy.intervalRemaining(
                in: snapshot,
                systemInactivity: 0
            )[.standing],
            5 * 60
        )
    }

    func testClockRebaseRealignsFutureQuietCadence() {
        let beforeJump = date(day: 17, hour: 10, minute: 30)
        let snapshot = policy.captureForClockRebase(
            nextDue: [.quietPractice: date(day: 17, hour: 11)],
            at: beforeJump
        )

        let restored = policy.restoreAfterClockRebase(
            snapshot,
            at: date(day: 17, hour: 11, minute: 30)
        )

        XCTAssertEqual(
            restored[.quietPractice],
            date(day: 17, hour: 13)
        )
    }

    func testClockRebasePreservesBlockedOverdueQuietOccurrence() {
        let beforeJump = date(day: 17, hour: 10, minute: 30)
        let snapshot = policy.captureForClockRebase(
            nextDue: [.quietPractice: date(day: 17, hour: 10)],
            at: beforeJump
        )

        let restored = policy.restoreAfterClockRebase(
            snapshot,
            at: date(day: 17, hour: 11, minute: 30)
        )

        XCTAssertEqual(
            restored[.quietPractice],
            date(day: 17, hour: 11)
        )
    }

    func testClockRebaseUsesUpdatedTimeZoneCalendar() {
        let oldCalendar = calendar
        var updatedCalendar = calendar
        updatedCalendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        let oldPolicy = makePolicy(calendar: oldCalendar)
        let updatedPolicy = makePolicy(calendar: updatedCalendar)
        let beforeChange = date(day: 17, hour: 2, minute: 30)
        let snapshot = oldPolicy.captureForClockRebase(
            nextDue: [.quietPractice: date(day: 17, hour: 11)],
            at: beforeChange
        )

        let restored = updatedPolicy.restoreAfterClockRebase(
            snapshot,
            at: beforeChange
        )
        let localComponents = updatedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: restored[.quietPractice]!
        )

        XCTAssertEqual(localComponents.year, 2026)
        XCTAssertEqual(localComponents.month, 8)
        XCTAssertEqual(localComponents.day, 17)
        XCTAssertEqual(localComponents.hour, 11)
        XCTAssertEqual(localComponents.minute, 0)
    }

    func testCalendarPauseAnchorKeepsCivilHourAcrossTimeZoneChange() throws {
        let target = date(day: 18, hour: 10)
        let anchor = CalendarPauseAnchor(target: target, calendar: calendar)
        var updatedCalendar = calendar
        updatedCalendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!

        let resolved = try XCTUnwrap(anchor.resolve(in: updatedCalendar))
        let localComponents = updatedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: resolved
        )

        XCTAssertEqual(localComponents.year, 2026)
        XCTAssertEqual(localComponents.month, 8)
        XCTAssertEqual(localComponents.day, 18)
        XCTAssertEqual(localComponents.hour, 10)
        XCTAssertEqual(localComponents.minute, 0)
    }

    func testCalendarPauseAnchorDoesNotReinterpretYearAcrossIdentifiers() throws {
        let target = date(day: 18, hour: 10)
        let anchor = CalendarPauseAnchor(target: target, calendar: calendar)
        var buddhistCalendar = Calendar(identifier: .buddhist)
        buddhistCalendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!

        let resolved = try XCTUnwrap(anchor.resolve(in: buddhistCalendar))
        var civilCalendar = Calendar(identifier: .gregorian)
        civilCalendar.timeZone = buddhistCalendar.timeZone
        let civilComponents = civilCalendar.dateComponents(
            [.year, .month, .day, .hour],
            from: resolved
        )

        XCTAssertEqual(civilComponents.year, 2026)
        XCTAssertEqual(civilComponents.month, 8)
        XCTAssertEqual(civilComponents.day, 18)
        XCTAssertEqual(civilComponents.hour, 10)
    }

    func testManualPauseIntentsDistinguishDurationFromCalendarDeadline() throws {
        let beforeJump = date(day: 17, hour: 9)
        let afterJump = date(day: 17, hour: 10)
        let durationDeadline = ManualPauseIntent.duration.rebasedDeadline(
            date(day: 17, hour: 9, minute: 30),
            from: beforeJump,
            to: afterJump,
            calendar: calendar
        )
        XCTAssertEqual(durationDeadline, date(day: 17, hour: 10, minute: 30))

        let calendarTarget = date(day: 18, hour: 10)
        let calendarIntent = ManualPauseIntent.calendar(
            CalendarPauseAnchor(target: calendarTarget, calendar: calendar)
        )
        let calendarDeadline = try XCTUnwrap(
            calendarIntent.rebasedDeadline(
                calendarTarget,
                from: beforeJump,
                to: afterJump,
                calendar: calendar
            )
        )
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour],
            from: calendarDeadline
        )

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(components.hour, 10)
    }

    func testInactivityTrackerRebaseDoesNotCountClockJump() {
        enum Reason: Hashable { case sleep }
        var tracker = SystemInactivityTracker<Reason>()
        let startedAt = date(day: 17, hour: 10)

        tracker.begin(.sleep, at: startedAt)
        tracker.rebaseWallClock(by: 3_600)
        tracker.end(
            .sleep,
            at: startedAt.addingTimeInterval(3_620)
        )

        XCTAssertEqual(tracker.accumulatedDuration, 20)
    }

    func testDetectedJumpDuringInactivityIsNotCountedAsSleep() throws {
        enum Reason: Hashable { case sleep }
        var detector = WallClockJumpDetector(minimumJumpMagnitude: 1)
        var tracker = SystemInactivityTracker<Reason>()
        let instant = ContinuousClock.now
        let startedAt = date(day: 17, hour: 10)

        XCTAssertNil(
            detector.observe(
                wallDate: startedAt,
                continuousInstant: instant
            )
        )
        tracker.begin(.sleep, at: startedAt)

        let wokeAt = startedAt.addingTimeInterval(3_620)
        let offset = try XCTUnwrap(
            detector.observe(
                wallDate: wokeAt,
                continuousInstant: instant.advanced(by: .seconds(20))
            )
        )
        tracker.rebaseWallClock(by: offset)
        tracker.end(.sleep, at: wokeAt)

        XCTAssertEqual(offset, 3_600, accuracy: 0.000_001)
        XCTAssertEqual(tracker.accumulatedDuration, 20)
    }

    private var policy: ReminderSchedulePolicy {
        makePolicy(calendar: calendar)
    }

    private func makePolicy(
        calendar: Calendar
    ) -> ReminderSchedulePolicy {
        ReminderSchedulePolicy(
            configuration: ReminderSchedulePolicy.Configuration(
                eyeInterval: 20 * 60,
                standingInterval: 40 * 60,
                quietDailyCount: 3,
                workdayStartHour: 9,
                workdayEndHour: 17
            ),
            calendar: calendar
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 8,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }
}
