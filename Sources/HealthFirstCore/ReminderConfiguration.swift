import Foundation

/// The reminder categories supported by the first HealthFirst release.
public enum ReminderKind: String, CaseIterable, Codable, Sendable {
    case eye
    case standing
    case quietPractice

    /// The recommended guided-session duration for this reminder category.
    /// Individual reminder instances may snapshot a user-selected duration.
    public var guideDuration: TimeInterval {
        switch self {
        case .eye:
            20
        case .standing:
            60
        case .quietPractice:
            30
        }
    }
}

/// Describes how a reminder is normally scheduled.
public enum ReminderCadence: Equatable, Codable, Sendable {
    case interval(seconds: TimeInterval)
    case dailyOccurrences(count: Int)
}

public struct ReminderPolicy: Equatable, Codable, Sendable {
    public var isEnabled: Bool
    public var cadence: ReminderCadence

    public init(isEnabled: Bool, cadence: ReminderCadence) {
        self.isEnabled = isEnabled
        self.cadence = cadence
    }
}

public enum ReminderMode: String, Codable, Sendable {
    case standard
    case serious
}

/// App-level defaults. Scheduling daily occurrences is intentionally left to
/// the app layer; the core exposes the policy without reading a clock itself.
public struct HealthFirstConfiguration: Equatable, Codable, Sendable {
    public var policies: [ReminderKind: ReminderPolicy]
    public var retryDelay: TimeInterval
    public var mode: ReminderMode

    public init(
        policies: [ReminderKind: ReminderPolicy],
        retryDelay: TimeInterval = 3 * 60,
        mode: ReminderMode = .standard
    ) {
        self.policies = policies
        self.retryDelay = retryDelay
        self.mode = mode
    }

    public func policy(for kind: ReminderKind) -> ReminderPolicy? {
        policies[kind]
    }

    public static let `default` = HealthFirstConfiguration(
        policies: [
            .eye: ReminderPolicy(
                isEnabled: true,
                cadence: .interval(seconds: 20 * 60)
            ),
            .standing: ReminderPolicy(
                isEnabled: true,
                cadence: .interval(seconds: 40 * 60)
            ),
            .quietPractice: ReminderPolicy(
                isEnabled: false,
                cadence: .dailyOccurrences(count: 3)
            ),
        ]
    )
}
