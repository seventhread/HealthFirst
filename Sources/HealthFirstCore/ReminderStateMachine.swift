import Foundation

public enum ReminderPresentationStage: String, Codable, Sendable {
    case first
    case followUp
    case serious
}

/// The complete lifecycle state of one reminder occurrence.
public enum ReminderState: Equatable, Codable, Sendable {
    case scheduled(dueAt: Date)
    case firstPresented(at: Date)
    case retryPending(retryAt: Date)
    case followUpPresented(at: Date)
    case pendingInMenuBar(since: Date)
    case seriousPresented(at: Date)
    case guided(startedAt: Date, endsAt: Date)
    case completed(at: Date)
    case snoozed(until: Date, resume: ReminderPresentationStage)
    case skipped(at: Date)
    case emergencySkip(at: Date)

    public var nextDeadline: Date? {
        switch self {
        case .scheduled(let dueAt):
            dueAt
        case .retryPending(let retryAt):
            retryAt
        case .snoozed(let until, _):
            until
        case .guided(_, let endsAt):
            endsAt
        case .firstPresented,
             .followUpPresented,
             .pendingInMenuBar,
             .seriousPresented,
             .completed,
             .skipped,
             .emergencySkip:
            nil
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .skipped, .emergencySkip:
            true
        default:
            false
        }
    }
}

/// Events are deliberately semantic. No animation callback is represented as
/// an event, so presentation cannot become a source of business state.
public enum ReminderEvent: Equatable, Sendable {
    case deadlineReached
    case start
    case snooze(for: TimeInterval)
    case skip
    case noResponse
    case countdownCompleted
    case earlyEnd
    case emergencySkip
    /// Moves every clock-based boundary forward while the app is globally
    /// paused. Presentation code still decides whether a panel is visible.
    case delay(by: TimeInterval)
    /// Rebases every wall-clock anchor after the system clock jumps. Unlike a
    /// pause delay, this offset may be negative and terminal occurrence dates
    /// also move so calendar-based expiry remains stable.
    case wallClockAdjusted(by: TimeInterval)
}

public enum ReminderTransitionError: Error, Equatable, Sendable {
    case eventNotAllowed(event: ReminderEvent, state: ReminderState)
    case deadlineNotReached(required: Date, received: Date)
    case countdownNotFinished(required: Date, received: Date)
    case invalidSnoozeDuration(TimeInterval)
    case invalidDelayDuration(TimeInterval)
    case invalidWallClockAdjustment(TimeInterval)
}

/// A value-type state machine for one reminder occurrence. It never calls
/// `Date()`; every transition is driven by an event and a caller-supplied date.
public struct ReminderInstance: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let kind: ReminderKind
    public let mode: ReminderMode
    public let retryDelay: TimeInterval
    public let guideDuration: TimeInterval
    public private(set) var state: ReminderState

    public init(
        id: UUID = UUID(),
        kind: ReminderKind,
        dueAt: Date,
        mode: ReminderMode = .standard,
        retryDelay: TimeInterval = 3 * 60,
        guideDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.kind = kind
        self.mode = mode
        self.retryDelay = retryDelay
        self.guideDuration = Self.resolvedGuideDuration(
            guideDuration,
            fallback: kind.guideDuration
        )
        self.state = .scheduled(dueAt: dueAt)
    }

    public init(
        id: UUID = UUID(),
        kind: ReminderKind,
        dueAt: Date,
        configuration: HealthFirstConfiguration
    ) {
        self.init(
            id: id,
            kind: kind,
            dueAt: dueAt,
            mode: configuration.mode,
            retryDelay: configuration.retryDelay,
            guideDuration: nil
        )
    }

    /// Applies one event atomically and returns the resulting state.
    @discardableResult
    public mutating func send(
        _ event: ReminderEvent,
        at date: Date
    ) throws -> ReminderState {
        let nextState = try ReminderStateMachine.transition(
            from: state,
            kind: kind,
            mode: mode,
            retryDelay: retryDelay,
            guideDuration: guideDuration,
            event: event,
            at: date
        )
        state = nextState
        return nextState
    }

    /// Compatibility spelling for call sites that model events as handlers.
    @discardableResult
    public mutating func handle(
        _ event: ReminderEvent,
        at date: Date
    ) throws -> ReminderState {
        try send(event, at: date)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case mode
        case retryDelay
        case guideDuration
        case state
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ReminderKind.self, forKey: .kind)
        mode = try container.decode(ReminderMode.self, forKey: .mode)
        retryDelay = try container.decode(TimeInterval.self, forKey: .retryDelay)
        guideDuration = Self.resolvedGuideDuration(
            try container.decodeIfPresent(TimeInterval.self, forKey: .guideDuration),
            fallback: kind.guideDuration
        )
        state = try container.decode(ReminderState.self, forKey: .state)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(mode, forKey: .mode)
        try container.encode(retryDelay, forKey: .retryDelay)
        try container.encode(guideDuration, forKey: .guideDuration)
        try container.encode(state, forKey: .state)
    }

    private static func resolvedGuideDuration(
        _ duration: TimeInterval?,
        fallback: TimeInterval
    ) -> TimeInterval {
        guard let duration, duration.isFinite, duration > 0 else {
            return fallback
        }
        return duration
    }
}

public enum ReminderStateMachine {
    public static func transition(
        from state: ReminderState,
        kind: ReminderKind,
        mode: ReminderMode,
        retryDelay: TimeInterval,
        guideDuration: TimeInterval? = nil,
        event: ReminderEvent,
        at date: Date
    ) throws -> ReminderState {
        switch (state, event) {
        case let (current, .wallClockAdjusted(by: offset)):
            guard offset.isFinite else {
                throw ReminderTransitionError.invalidWallClockAdjustment(offset)
            }
            return rebased(current, by: offset)

        case let (current, .delay(by: duration)) where !current.isTerminal:
            guard duration >= 0, duration.isFinite else {
                throw ReminderTransitionError.invalidDelayDuration(duration)
            }
            return delayed(current, by: duration)

        case (.scheduled(let dueAt), .deadlineReached):
            try require(date, toReach: dueAt)
            return .firstPresented(at: date)

        case (.retryPending(let retryAt), .deadlineReached):
            try require(date, toReach: retryAt)
            return .followUpPresented(at: date)

        case (.snoozed(let until, let resume), .deadlineReached):
            try require(date, toReach: until)
            return presentedState(for: resume, at: date)

        case (.firstPresented, .noResponse):
            return .retryPending(retryAt: date.addingTimeInterval(retryDelay))

        case (.followUpPresented, .noResponse):
            if mode == .serious {
                return .seriousPresented(at: date)
            }
            return .pendingInMenuBar(since: date)

        case (.seriousPresented, .noResponse):
            return .pendingInMenuBar(since: date)

        case (.firstPresented, .start),
             (.followUpPresented, .start),
             (.pendingInMenuBar, .start),
             (.seriousPresented, .start):
            return .guided(
                startedAt: date,
                endsAt: date.addingTimeInterval(
                    resolvedGuideDuration(guideDuration, for: kind)
                )
            )

        case (.firstPresented, .snooze(let duration)):
            return try snoozedState(
                duration: duration,
                at: date,
                resume: .first
            )

        case (.followUpPresented, .snooze(let duration)):
            return try snoozedState(
                duration: duration,
                at: date,
                resume: .followUp
            )

        case (.firstPresented, .skip),
             (.followUpPresented, .skip),
             (.pendingInMenuBar, .skip):
            return .skipped(at: date)

        case (.guided(_, let endsAt), .countdownCompleted):
            guard date >= endsAt else {
                throw ReminderTransitionError.countdownNotFinished(
                    required: endsAt,
                    received: date
                )
            }
            return .completed(at: date)

        case (.guided, .earlyEnd):
            return .skipped(at: date)

        case (.seriousPresented, .emergencySkip):
            return .emergencySkip(at: date)

        case (.guided, .emergencySkip) where mode == .serious:
            return .emergencySkip(at: date)

        default:
            throw ReminderTransitionError.eventNotAllowed(
                event: event,
                state: state
            )
        }
    }

    private static func require(_ received: Date, toReach required: Date) throws {
        guard received >= required else {
            throw ReminderTransitionError.deadlineNotReached(
                required: required,
                received: received
            )
        }
    }

    private static func resolvedGuideDuration(
        _ duration: TimeInterval?,
        for kind: ReminderKind
    ) -> TimeInterval {
        guard let duration, duration.isFinite, duration > 0 else {
            return kind.guideDuration
        }
        return duration
    }

    private static func snoozedState(
        duration: TimeInterval,
        at date: Date,
        resume: ReminderPresentationStage
    ) throws -> ReminderState {
        guard duration > 0, duration.isFinite else {
            throw ReminderTransitionError.invalidSnoozeDuration(duration)
        }
        return .snoozed(
            until: date.addingTimeInterval(duration),
            resume: resume
        )
    }

    private static func presentedState(
        for stage: ReminderPresentationStage,
        at date: Date
    ) -> ReminderState {
        switch stage {
        case .first:
            .firstPresented(at: date)
        case .followUp:
            .followUpPresented(at: date)
        case .serious:
            .seriousPresented(at: date)
        }
    }

    private static func delayed(
        _ state: ReminderState,
        by duration: TimeInterval
    ) -> ReminderState {
        switch state {
        case .scheduled(let dueAt):
            .scheduled(dueAt: dueAt.addingTimeInterval(duration))
        case .firstPresented(let at):
            .firstPresented(at: at.addingTimeInterval(duration))
        case .retryPending(let retryAt):
            .retryPending(retryAt: retryAt.addingTimeInterval(duration))
        case .followUpPresented(let at):
            .followUpPresented(at: at.addingTimeInterval(duration))
        case .pendingInMenuBar(let since):
            .pendingInMenuBar(since: since.addingTimeInterval(duration))
        case .seriousPresented(let at):
            .seriousPresented(at: at.addingTimeInterval(duration))
        case .guided(let startedAt, let endsAt):
            .guided(
                startedAt: startedAt.addingTimeInterval(duration),
                endsAt: endsAt.addingTimeInterval(duration)
            )
        case .snoozed(let until, let resume):
            .snoozed(
                until: until.addingTimeInterval(duration),
                resume: resume
            )
        case .completed, .skipped, .emergencySkip:
            state
        }
    }

    private static func rebased(
        _ state: ReminderState,
        by offset: TimeInterval
    ) -> ReminderState {
        switch state {
        case .completed(let at):
            .completed(at: at.addingTimeInterval(offset))
        case .skipped(let at):
            .skipped(at: at.addingTimeInterval(offset))
        case .emergencySkip(let at):
            .emergencySkip(at: at.addingTimeInterval(offset))
        default:
            delayed(state, by: offset)
        }
    }
}
