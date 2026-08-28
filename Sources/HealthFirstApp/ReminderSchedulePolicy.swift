import Foundation
import HealthFirstCore

/// Pure calendar policy shared by the live scheduler and its suspension tests.
/// It owns no timers, settings storage, UI, or reminder-state transitions.
struct ReminderSchedulePolicy: Sendable {
    struct Configuration: Equatable, Sendable {
        let eyeInterval: TimeInterval
        let standingInterval: TimeInterval
        let quietDailyCount: Int
        let workdayStartHour: Int
        let workdayEndHour: Int

        init(
            eyeInterval: TimeInterval,
            standingInterval: TimeInterval,
            quietDailyCount: Int,
            workdayStartHour: Int,
            workdayEndHour: Int
        ) {
            self.eyeInterval = max(60, eyeInterval)
            self.standingInterval = max(60, standingInterval)
            self.quietDailyCount = max(1, quietDailyCount)
            self.workdayStartHour = workdayStartHour
            self.workdayEndHour = workdayEndHour
        }
    }

    struct ScheduleSnapshot: Equatable, Sendable {
        fileprivate let deadlines: [ReminderKind: SuspendedDeadline]
        fileprivate let capturedAt: Date
        fileprivate let context: CaptureContext
    }

    /// Captures the semantic identity of live deadlines immediately before a
    /// wall-clock or calendar-environment change. Interval reminders retain
    /// active-work remaining, while a future quiet-practice occurrence remains
    /// tied to the user's calendar cadence. A quiet occurrence that was already
    /// overdue remains overdue instead of being silently replaced by a slot.
    struct ClockRebaseSnapshot: Equatable, Sendable {
        fileprivate let deadlines: [ReminderKind: ClockRebaseDeadline]
    }

    static let naturalEyeRestThreshold: TimeInterval = 20

    let configuration: Configuration
    let calendar: Calendar

    init(
        configuration: Configuration,
        calendar: Calendar = .current
    ) {
        self.configuration = configuration
        self.calendar = calendar
    }

    func captureForSuspension(
        nextDue: [ReminderKind: Date],
        deferredIntervalRemaining: [ReminderKind: TimeInterval] = [:],
        at date: Date
    ) -> ScheduleSnapshot {
        capture(
            nextDue: nextDue,
            deferredIntervalRemaining: deferredIntervalRemaining,
            at: date,
            context: .suspension
        )
    }

    func captureForGuidance(
        nextDue: [ReminderKind: Date],
        deferredIntervalRemaining: [ReminderKind: TimeInterval] = [:],
        at date: Date
    ) -> ScheduleSnapshot {
        capture(
            nextDue: nextDue,
            deferredIntervalRemaining: deferredIntervalRemaining,
            at: date,
            context: .guidance
        )
    }

    func captureForClockRebase(
        nextDue: [ReminderKind: Date],
        deferredIntervalRemaining: [ReminderKind: TimeInterval] = [:],
        at date: Date
    ) -> ClockRebaseSnapshot {
        let deadlines = nextDue.reduce(
            into: [ReminderKind: ClockRebaseDeadline]()
        ) { snapshot, entry in
            let (kind, due) = entry
            switch kind {
            case .eye, .standing:
                snapshot[kind] = .intervalRemaining(
                    activeWorkRemaining(
                        for: kind,
                        dueAt: due,
                        at: date,
                        deferredRemaining: deferredIntervalRemaining[kind]
                    )
                )
            case .quietPractice where due <= date:
                snapshot[kind] = .overdueOccurrence(
                    relativeToCapture: due.timeIntervalSince(date)
                )
            case .quietPractice:
                snapshot[kind] = .quietCadence
            }
        }
        return ClockRebaseSnapshot(deadlines: deadlines)
    }

    func restoreAfterClockRebase(
        _ snapshot: ClockRebaseSnapshot,
        at date: Date
    ) -> [ReminderKind: Date] {
        snapshot.deadlines.reduce(into: [:]) { restored, entry in
            let (kind, deadline) = entry
            switch deadline {
            case .intervalRemaining(let remaining):
                restored[kind] = nextDate(
                    afterActiveWork: remaining,
                    resumingAt: date
                )
            case .overdueOccurrence(let relativeToCapture):
                restored[kind] = date.addingTimeInterval(relativeToCapture)
            case .quietCadence:
                restored[kind] = nextQuietDate(after: date)
            }
        }
    }

    private func capture(
        nextDue: [ReminderKind: Date],
        deferredIntervalRemaining: [ReminderKind: TimeInterval],
        at date: Date,
        context: CaptureContext
    ) -> ScheduleSnapshot {
        let deadlines: [ReminderKind: SuspendedDeadline] = nextDue.reduce(
            into: [:]
        ) { snapshot, entry in
            let (kind, due) = entry
            if due <= date {
                snapshot[kind] = .overdue(due)
                return
            }

            switch kind {
            case .eye, .standing:
                snapshot[kind] = .activeWorkRemaining(
                    activeWorkRemaining(
                        for: kind,
                        dueAt: due,
                        at: date,
                        deferredRemaining: deferredIntervalRemaining[kind]
                    )
                )
            case .quietPractice:
                let isCurrentWorkPeriod = isWithinWorkday(date)
                    && isWithinWorkday(due)
                    && calendar.isDate(due, inSameDayAs: date)
                snapshot[kind] = context == .guidance && isCurrentWorkPeriod
                    ? .activeWorkRemaining(due.timeIntervalSince(date))
                    : .quietCadence
            }
        }
        return ScheduleSnapshot(
            deadlines: deadlines,
            capturedAt: date,
            context: context
        )
    }

    /// Restores only kinds captured at suspension start. `current` may already
    /// contain replacement occurrences created while stale active UI was being
    /// expired, and those unrelated entries remain intact.
    func restore(
        _ snapshot: ScheduleSnapshot,
        preserving current: [ReminderKind: Date],
        at date: Date,
        systemInactivity: TimeInterval
    ) -> [ReminderKind: Date] {
        let naturalEyeRest = isNaturalEyeRest(systemInactivity)
        var restored = current

        for (kind, deadline) in snapshot.deadlines {
            switch deadline {
            case .overdue(let originalDue):
                if kind == .eye, naturalEyeRest,
                   let fullInterval = intervalDuration(for: kind) {
                    restored[kind] = nextDate(
                        afterActiveWork: fullInterval,
                        resumingAt: date
                    )
                } else if kind == .quietPractice,
                          (!calendar.isDate(originalDue, inSameDayAs: date)
                              || !isWithinWorkday(date)) {
                    restored[kind] = nextQuietDate(after: date)
                } else {
                    restored[kind] = nextDate(
                        afterActiveWork: 0,
                        resumingAt: date
                    )
                }

            case .activeWorkRemaining(let remaining):
                if kind == .quietPractice,
                   (!calendar.isDate(snapshot.capturedAt, inSameDayAs: date)
                        || !isWithinWorkday(date)) {
                    restored[kind] = nextQuietDate(after: date)
                    continue
                }

                let effectiveRemaining: TimeInterval
                if kind == .eye, naturalEyeRest {
                    effectiveRemaining = intervalDuration(for: kind) ?? remaining
                } else {
                    effectiveRemaining = remaining
                }
                restored[kind] = nextDate(
                    afterActiveWork: effectiveRemaining,
                    resumingAt: date
                )

            case .quietCadence:
                restored[kind] = nextQuietDate(after: date)
            }
        }

        return restored
    }

    /// A system-inactive break of at least twenty seconds satisfies the eye
    /// rest. If another reminder is guiding, its frozen eye deadline must also
    /// be reset or it would reintroduce the pre-rest remainder when guidance
    /// finishes.
    func resettingEyeCycle(
        in snapshot: ScheduleSnapshot
    ) -> ScheduleSnapshot {
        guard snapshot.deadlines[.eye] != nil,
              let fullInterval = intervalDuration(for: .eye) else {
            return snapshot
        }

        var deadlines = snapshot.deadlines
        deadlines[.eye] = .activeWorkRemaining(fullInterval)
        return ScheduleSnapshot(
            deadlines: deadlines,
            capturedAt: snapshot.capturedAt,
            context: snapshot.context
        )
    }

    /// Removes a disabled reminder from a frozen schedule so a later guidance
    /// or suspension restore cannot resurrect it.
    func removing(
        _ kind: ReminderKind,
        from snapshot: ScheduleSnapshot
    ) -> ScheduleSnapshot {
        var deadlines = snapshot.deadlines
        deadlines[kind] = nil
        return ScheduleSnapshot(
            deadlines: deadlines,
            capturedAt: snapshot.capturedAt,
            context: snapshot.context
        )
    }

    func intervalRemaining(
        in snapshot: ClockRebaseSnapshot
    ) -> [ReminderKind: TimeInterval] {
        snapshot.deadlines.reduce(into: [:]) { remaining, entry in
            let (kind, deadline) = entry
            guard case .intervalRemaining(let duration) = deadline else {
                return
            }
            remaining[kind] = duration
        }
    }

    func intervalRemaining(
        in snapshot: ScheduleSnapshot,
        systemInactivity: TimeInterval
    ) -> [ReminderKind: TimeInterval] {
        let naturalEyeRest = isNaturalEyeRest(systemInactivity)
        return snapshot.deadlines.reduce(into: [:]) { remaining, entry in
            let (kind, deadline) = entry
            guard kind == .eye || kind == .standing else { return }

            if kind == .eye, naturalEyeRest,
               let fullInterval = intervalDuration(for: kind) {
                remaining[kind] = fullInterval
                return
            }

            switch deadline {
            case .overdue:
                remaining[kind] = 0
            case .activeWorkRemaining(let duration):
                remaining[kind] = duration
            case .quietCadence:
                break
            }
        }
    }

    /// Moves the wall-clock identity of a frozen snapshot without changing
    /// any captured remaining-work duration. This keeps nested suspension and
    /// guidance freezes stable when Date jumps but continuous time does not.
    func rebasing(
        _ snapshot: ScheduleSnapshot,
        by offset: TimeInterval
    ) -> ScheduleSnapshot {
        guard offset.isFinite, offset != 0 else { return snapshot }

        let deadlines: [ReminderKind: SuspendedDeadline] = snapshot.deadlines
            .mapValues { deadline -> SuspendedDeadline in
                switch deadline {
                case .overdue(let due):
                    return .overdue(due.addingTimeInterval(offset))
                case .activeWorkRemaining, .quietCadence:
                    return deadline
                }
            }
        return ScheduleSnapshot(
            deadlines: deadlines,
            capturedAt: snapshot.capturedAt.addingTimeInterval(offset),
            context: snapshot.context
        )
    }

    func isNaturalEyeRest(_ systemInactivity: TimeInterval) -> Bool {
        systemInactivity >= Self.naturalEyeRestThreshold
    }

    func replacementForStaleQuietDeadline(
        _ currentDue: Date,
        at date: Date
    ) -> Date? {
        guard currentDue <= date,
              !calendar.isDate(currentDue, inSameDayAs: date) else {
            return nil
        }
        return nextQuietDate(after: date)
    }

    func intervalDuration(for kind: ReminderKind) -> TimeInterval? {
        switch kind {
        case .eye:
            configuration.eyeInterval
        case .standing:
            configuration.standingInterval
        case .quietPractice:
            nil
        }
    }

    private func activeWorkRemaining(
        for kind: ReminderKind,
        dueAt due: Date,
        at date: Date,
        deferredRemaining: TimeInterval?
    ) -> TimeInterval {
        guard due > date else { return 0 }
        let isCurrentWorkPeriod = isWithinWorkday(date)
            && isWithinWorkday(due)
            && calendar.isDate(due, inSameDayAs: date)
        return isCurrentWorkPeriod
            ? due.timeIntervalSince(date)
            : deferredRemaining ?? intervalDuration(for: kind) ?? 0
    }

    func nextDate(
        afterActiveWork remaining: TimeInterval,
        resumingAt date: Date
    ) -> Date {
        let base = isWithinWorkday(date)
            ? date
            : nextWorkdayStart(after: date, includeTodayIfBeforeStart: true)
        let safeRemaining = max(0, remaining)
        let candidate = base.addingTimeInterval(safeRemaining)
        let workdayEnd = calendar.date(
            bySettingHour: configuration.workdayEndHour,
            minute: 0,
            second: 0,
            of: base
        ) ?? candidate

        if candidate < workdayEnd {
            return candidate
        }

        return nextWorkdayStart(
            after: base,
            includeTodayIfBeforeStart: false
        ).addingTimeInterval(safeRemaining)
    }

    func nextQuietDate(after date: Date) -> Date {
        var day = calendar.startOfDay(for: date)

        for _ in 0..<8 {
            if !calendar.isDateInWeekend(day),
               let start = calendar.date(
                    bySettingHour: configuration.workdayStartHour,
                    minute: 0,
                    second: 0,
                    of: day
               ),
               let end = calendar.date(
                    bySettingHour: configuration.workdayEndHour,
                    minute: 0,
                    second: 0,
                    of: day
               ),
               start < end {
                let spacing = end.timeIntervalSince(start)
                    / Double(configuration.quietDailyCount + 1)
                for index in 1...configuration.quietDailyCount {
                    let slot = start.addingTimeInterval(spacing * Double(index))
                    if slot > date {
                        return slot
                    }
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)
                ?? day.addingTimeInterval(86_400)
        }

        return date.addingTimeInterval(3 * 3_600)
    }

    /// Re-homes an already-started automatic occurrence after it crosses the
    /// workday boundary. Interval reminders remain the same occurrence and are
    /// therefore due at the next start; quiet practice follows its calendar
    /// cadence so it does not bunch up with the morning interval reminders.
    func deferredOccurrenceDate(
        for kind: ReminderKind,
        after date: Date
    ) -> Date {
        switch kind {
        case .eye, .standing:
            nextDate(afterActiveWork: 0, resumingAt: date)
        case .quietPractice:
            nextQuietDate(after: date)
        }
    }

    func isWithinWorkday(_ date: Date) -> Bool {
        guard !calendar.isDateInWeekend(date) else { return false }
        let start = configuration.workdayStartHour
        let end = configuration.workdayEndHour
        guard start < end else { return false }
        let hour = calendar.component(.hour, from: date)
        return hour >= start && hour < end
    }

    func nextWorkdayStart(
        after date: Date,
        includeTodayIfBeforeStart: Bool
    ) -> Date {
        var day = calendar.startOfDay(for: date)

        for offset in 0..<8 {
            if offset > 0 {
                day = calendar.date(byAdding: .day, value: 1, to: day)
                    ?? day.addingTimeInterval(86_400)
            }
            guard !calendar.isDateInWeekend(day) else { continue }
            guard let start = calendar.date(
                bySettingHour: configuration.workdayStartHour,
                minute: 0,
                second: 0,
                of: day
            ) else { continue }

            if offset > 0 || (includeTodayIfBeforeStart && date < start) {
                return start
            }
        }

        return date.addingTimeInterval(86_400)
    }
}

fileprivate enum SuspendedDeadline: Equatable, Sendable {
    case overdue(Date)
    case activeWorkRemaining(TimeInterval)
    case quietCadence
}

fileprivate enum ClockRebaseDeadline: Equatable, Sendable {
    case intervalRemaining(TimeInterval)
    case overdueOccurrence(relativeToCapture: TimeInterval)
    case quietCadence
}

fileprivate enum CaptureContext: Equatable, Sendable {
    case suspension
    case guidance
}

/// Counts the union of overlapping system-inactivity reasons. Manual pause is
/// intentionally not represented here, so it cannot accidentally qualify as
/// the twenty-second natural eye rest.
struct SystemInactivityTracker<Reason: Hashable> {
    private var activeReasons: Set<Reason> = []
    private var intervalStartedAt: Date?
    private(set) var accumulatedDuration: TimeInterval = 0

    var isInactive: Bool {
        !activeReasons.isEmpty
    }

    func contains(_ reason: Reason) -> Bool {
        activeReasons.contains(reason)
    }

    @discardableResult
    mutating func begin(_ reason: Reason, at date: Date) -> Bool {
        guard activeReasons.insert(reason).inserted else { return false }
        if activeReasons.count == 1 {
            intervalStartedAt = date
        }
        return true
    }

    @discardableResult
    mutating func end(_ reason: Reason, at date: Date) -> Bool {
        guard activeReasons.remove(reason) != nil else { return false }
        if activeReasons.isEmpty, let intervalStartedAt {
            accumulatedDuration += max(
                0,
                date.timeIntervalSince(intervalStartedAt)
            )
            self.intervalStartedAt = nil
        }
        return true
    }

    mutating func reset() {
        activeReasons.removeAll()
        intervalStartedAt = nil
        accumulatedDuration = 0
    }

    mutating func rebaseWallClock(by offset: TimeInterval) {
        guard offset.isFinite, offset != 0 else { return }
        intervalStartedAt = intervalStartedAt?.addingTimeInterval(offset)
    }
}

/// Detects discontinuities in wall time by comparing Date with a monotonic
/// continuous clock. It intentionally makes no assumption about observation
/// cadence, so a delayed 250 ms tick is ordinary elapsed time rather than a
/// false clock jump.
struct WallClockJumpDetector {
    private var previousWallDate: Date?
    private var previousContinuousInstant: ContinuousClock.Instant?
    let minimumJumpMagnitude: TimeInterval

    init(minimumJumpMagnitude: TimeInterval = 1) {
        self.minimumJumpMagnitude = max(0, minimumJumpMagnitude)
    }

    mutating func observe(
        wallDate: Date,
        continuousInstant: ContinuousClock.Instant
    ) -> TimeInterval? {
        defer {
            previousWallDate = wallDate
            previousContinuousInstant = continuousInstant
        }

        guard let previousWallDate,
              let previousContinuousInstant else { return nil }

        let wallElapsed = wallDate.timeIntervalSince(previousWallDate)
        let duration = previousContinuousInstant.duration(to: continuousInstant)
        let components = duration.components
        let continuousElapsed = Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
        let offset = wallElapsed - continuousElapsed

        guard offset.isFinite,
              abs(offset) >= minimumJumpMagnitude else { return nil }
        return offset
    }
}

/// Stores a calendar pause as Gregorian civil components rather than as an
/// absolute Date. Resolving those components with the current time zone keeps
/// “tomorrow at 10:00” at 10:00 after a clock, time-zone, or calendar change.
struct CalendarPauseAnchor: Equatable, Sendable {
    private let era: Int?
    private let year: Int?
    private let month: Int?
    private let day: Int?
    private let hour: Int?
    private let minute: Int?
    private let second: Int?

    init(target: Date, calendar: Calendar) {
        let civilCalendar = Self.civilCalendar(
            timeZone: calendar.timeZone
        )
        let components = civilCalendar.dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second],
            from: target
        )
        era = components.era
        year = components.year
        month = components.month
        day = components.day
        hour = components.hour
        minute = components.minute
        second = components.second
    }

    func resolve(in calendar: Calendar) -> Date? {
        let civilCalendar = Self.civilCalendar(
            timeZone: calendar.timeZone
        )
        var components = DateComponents()
        components.calendar = civilCalendar
        components.timeZone = civilCalendar.timeZone
        components.era = era
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return civilCalendar.date(from: components)
    }

    private static func civilCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}

enum ManualPauseIntent: Equatable, Sendable {
    case duration
    case calendar(CalendarPauseAnchor)

    func rebasedDeadline(
        _ deadline: Date?,
        from dateBeforeChange: Date,
        to dateAfterChange: Date,
        calendar: Calendar
    ) -> Date? {
        guard let deadline else { return nil }

        switch self {
        case .duration:
            return dateAfterChange.addingTimeInterval(
                max(0, deadline.timeIntervalSince(dateBeforeChange))
            )
        case .calendar(let anchor):
            return anchor.resolve(in: calendar)
                ?? deadline.addingTimeInterval(
                    dateAfterChange.timeIntervalSince(dateBeforeChange)
                )
        }
    }
}
