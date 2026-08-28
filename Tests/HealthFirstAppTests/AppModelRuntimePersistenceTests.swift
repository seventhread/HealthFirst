import Foundation
import HealthFirstCore
import XCTest
@testable import HealthFirstApp

@MainActor
final class AppModelRuntimePersistenceTests: XCTestCase {
    func testRestoresSnoozeQueueScheduleAndPause() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        AppSettings.registerDefaults(in: defaults)
        let store = AppRuntimeStateStore(defaults: defaults)
        let now = Date()

        var snoozed = ReminderInstance(
            kind: .eye,
            dueAt: now.addingTimeInterval(-10)
        )
        try snoozed.send(.deadlineReached, at: now.addingTimeInterval(-10))
        try snoozed.send(.snooze(for: 180), at: now.addingTimeInterval(-10))

        let pendingOrigin = now.addingTimeInterval(-400)
        var pending = ReminderInstance(kind: .standing, dueAt: pendingOrigin)
        try pending.send(.deadlineReached, at: pendingOrigin)
        try pending.send(.noResponse, at: pendingOrigin)
        try pending.send(
            .deadlineReached,
            at: pendingOrigin.addingTimeInterval(180)
        )
        try pending.send(
            .noResponse,
            at: pendingOrigin.addingTimeInterval(180)
        )

        let standingDue = now.addingTimeInterval(2_400)
        let pauseEnd = now.addingTimeInterval(600)
        try store.save(
            AppRuntimeSnapshot(
                savedAt: now,
                nextDue: [.standing: standingDue],
                activeReminder: snoozed,
                activeIsManual: false,
                pendingReminders: [pending],
                pausedUntil: pauseEnd
            )
        )

        let model = AppModel(
            settingsStore: defaults,
            runtimeStateStore: store,
            startsTicking: false
        )

        XCTAssertEqual(model.activeReminder?.id, snoozed.id)
        XCTAssertEqual(model.pendingReminders.map(\.id), [pending.id])
        XCTAssertEqual(model.nextDueDate(for: .standing), standingDue)
        XCTAssertNil(model.nextDueDate(for: .eye))
        XCTAssertEqual(model.pausedUntil, pauseEnd)
        XCTAssertTrue(model.isPaused)
    }

    func testUserActionPersistsGuidedReminderImmediately() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        AppSettings.registerDefaults(in: defaults)
        let store = AppRuntimeStateStore(defaults: defaults)
        let model = AppModel(
            settingsStore: defaults,
            runtimeStateStore: store,
            startsTicking: false
        )

        model.triggerPreview(.eye)
        model.startActiveReminder()

        let snapshot = try XCTUnwrap(store.load())
        guard case .guided = snapshot.activeReminder?.state else {
            return XCTFail("expected guided state to be persisted")
        }
        XCTAssertTrue(snapshot.activeIsManual)

        model.endGuidanceEarly()
        model.dismissReceipt()
    }

    func testGuidedCountdownFreezesWhileAppIsNotRunning() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        AppSettings.registerDefaults(in: defaults)
        let store = AppRuntimeStateStore(defaults: defaults)
        let savedAt = Date().addingTimeInterval(-10)

        var guided = ReminderInstance(
            kind: .eye,
            dueAt: savedAt,
            guideDuration: 20
        )
        try guided.send(.deadlineReached, at: savedAt)
        try guided.send(.start, at: savedAt)
        try store.save(
            AppRuntimeSnapshot(
                savedAt: savedAt,
                nextDue: [
                    .standing: savedAt.addingTimeInterval(2_400),
                ],
                activeReminder: guided,
                activeIsManual: true,
                pendingReminders: [],
                pausedUntil: nil
            )
        )

        let model = AppModel(
            settingsStore: defaults,
            runtimeStateStore: store,
            startsTicking: false
        )
        let restored = try XCTUnwrap(model.activeReminder)

        guard case .guided = restored.state else {
            return XCTFail("expected guided reminder to be restored")
        }
        XCTAssertEqual(model.remainingSeconds(for: restored), 20, accuracy: 1)
    }

    func testDisabledKindCannotReturnFromSnapshot() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        AppSettings.registerDefaults(in: defaults)
        defaults.set(false, forKey: SettingsKey.quietReminderEnabled)
        let store = AppRuntimeStateStore(defaults: defaults)
        let now = Date()

        var quiet = ReminderInstance(kind: .quietPractice, dueAt: now)
        try quiet.send(.deadlineReached, at: now)
        try quiet.send(.noResponse, at: now)
        try quiet.send(.deadlineReached, at: now.addingTimeInterval(180))
        try quiet.send(.noResponse, at: now.addingTimeInterval(180))
        try store.save(
            AppRuntimeSnapshot(
                savedAt: now,
                nextDue: [.quietPractice: now.addingTimeInterval(600)],
                activeReminder: quiet,
                activeIsManual: false,
                pendingReminders: [quiet],
                pausedUntil: nil
            )
        )

        let model = AppModel(
            settingsStore: defaults,
            runtimeStateStore: store,
            startsTicking: false
        )

        XCTAssertNil(model.activeReminder)
        XCTAssertFalse(model.pendingReminders.contains { $0.kind == .quietPractice })
        XCTAssertNil(model.nextDueDate(for: .quietPractice))
    }

    func testRestoredPauseKeepsTheRemainingWorkInterval() throws {
        let suiteName = "HealthFirstAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        AppSettings.registerDefaults(in: defaults)
        defaults.set(0, forKey: SettingsKey.workdayStartHour)
        defaults.set(23, forKey: SettingsKey.workdayEndHour)
        let store = AppRuntimeStateStore(defaults: defaults)
        let now = Date()
        let pauseStartedAt = now.addingTimeInterval(-300)
        let remainingAtPauseStart: TimeInterval = 1_200

        try store.save(
            AppRuntimeSnapshot(
                savedAt: now,
                nextDue: [
                    .eye: pauseStartedAt.addingTimeInterval(
                        remainingAtPauseStart
                    ),
                ],
                deferredIntervalRemaining: [
                    .eye: remainingAtPauseStart,
                ],
                activeReminder: nil,
                activeIsManual: false,
                pendingReminders: [],
                pausedUntil: now.addingTimeInterval(300),
                pauseStartedAt: pauseStartedAt
            )
        )
        let model = AppModel(
            settingsStore: defaults,
            runtimeStateStore: store,
            startsTicking: false
        )

        model.resume()

        let restoredDue = try XCTUnwrap(model.nextDueDate(for: .eye))
        XCTAssertEqual(
            restoredDue.timeIntervalSince(model.now),
            remainingAtPauseStart,
            accuracy: 2
        )
    }
}
