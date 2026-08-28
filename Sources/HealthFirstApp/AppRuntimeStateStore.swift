import Foundation
import HealthFirstCore

/// The small amount of scheduler state that must survive an app restart.
///
/// Visual-only details (hover, animation frames and receipt toasts) are
/// intentionally excluded. Persisting business state keeps a snooze, pause or
/// queued reminder reliable without reviving a half-finished animation.
struct AppRuntimeSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let savedAt: Date
    let nextDue: [ReminderKind: Date]
    let deferredIntervalRemaining: [ReminderKind: TimeInterval]
    let activeReminder: ReminderInstance?
    let activeIsManual: Bool
    let pendingReminders: [ReminderInstance]
    let pausedUntil: Date?
    let pauseStartedAt: Date?

    init(
        savedAt: Date,
        nextDue: [ReminderKind: Date],
        deferredIntervalRemaining: [ReminderKind: TimeInterval] = [:],
        activeReminder: ReminderInstance?,
        activeIsManual: Bool,
        pendingReminders: [ReminderInstance],
        pausedUntil: Date?,
        pauseStartedAt: Date? = nil
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.savedAt = savedAt
        self.nextDue = nextDue
        self.deferredIntervalRemaining = deferredIntervalRemaining
        self.activeReminder = activeReminder
        self.activeIsManual = activeIsManual
        self.pendingReminders = pendingReminders
        self.pausedUntil = pausedUntil
        self.pauseStartedAt = pauseStartedAt
    }

    func representsSameBusinessState(as other: AppRuntimeSnapshot) -> Bool {
        nextDue == other.nextDue
            && deferredIntervalRemaining == other.deferredIntervalRemaining
            && activeReminder == other.activeReminder
            && activeIsManual == other.activeIsManual
            && pendingReminders == other.pendingReminders
            && pausedUntil == other.pausedUntil
            && pauseStartedAt == other.pauseStartedAt
    }
}

/// A deliberately tiny UserDefaults-backed store. The encoded value is a
/// single versioned blob so a future schema can be migrated or discarded
/// atomically instead of leaving partially updated keys behind.
final class AppRuntimeStateStore {
    static let storageKey = "runtime.schedulerSnapshot.v1"

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func load() -> AppRuntimeSnapshot? {
        guard let data = defaults.data(forKey: Self.storageKey),
              let snapshot = try? decoder.decode(
                AppRuntimeSnapshot.self,
                from: data
              ),
              snapshot.schemaVersion == AppRuntimeSnapshot.currentSchemaVersion else {
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: AppRuntimeSnapshot) throws {
        defaults.set(try encoder.encode(snapshot), forKey: Self.storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
