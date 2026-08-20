import Foundation

/// The four one-shot prop handoffs used during the sixty-second standing guide.
///
/// The names describe both the source fragment and its final trolley role:
/// title -> handle, backing -> cargo bin, rails -> chassis, ribbon -> tie.
enum StandingBeat: String, CaseIterable, Equatable, Sendable {
    case title
    case backing
    case rails
    case ribbon

    static let duration: TimeInterval = 0.6

    var startSeconds: TimeInterval {
        switch self {
        case .title:
            8
        case .backing:
            22
        case .rails:
            38
        case .ribbon:
            52
        }
    }

    var endSeconds: TimeInterval {
        startSeconds + Self.duration
    }
}

/// Progress for the four parts of the single shared standing trolley.
/// Every value is clamped to `0...1` and is derived from elapsed time only.
struct StandingAssembly: Equatable, Sendable {
    let handleProgress: Double
    let cargoBinProgress: Double
    let chassisProgress: Double
    let ribbonProgress: Double

    static let empty = StandingAssembly(
        handleProgress: 0,
        cargoBinProgress: 0,
        chassisProgress: 0,
        ribbonProgress: 0
    )

    static let completed = StandingAssembly(
        handleProgress: 1,
        cargoBinProgress: 1,
        chassisProgress: 1,
        ribbonProgress: 1
    )

    func progress(for beat: StandingBeat) -> Double {
        switch beat {
        case .title:
            handleProgress
        case .backing:
            cargoBinProgress
        case .rails:
            chassisProgress
        case .ribbon:
            ribbonProgress
        }
    }
}

/// A deterministic visual snapshot of the standing guide at one elapsed time.
struct StandingGuideSnapshot: Equatable, Sendable {
    let elapsed: TimeInterval
    let activeBeat: StandingBeat?
    let assembly: StandingAssembly

    var isAnimating: Bool {
        activeBeat != nil
    }

    func progress(for beat: StandingBeat) -> Double {
        assembly.progress(for: beat)
    }

    func sourceOpacity(for beat: StandingBeat) -> Double {
        1 - progress(for: beat)
    }

    static var initial: StandingGuideSnapshot {
        StandingGuideTimeline.snapshot(elapsed: 0)
    }

    static var completed: StandingGuideSnapshot {
        StandingGuideTimeline.snapshot(elapsed: StandingGuideTimeline.duration)
    }
}

/// Pure time-to-state mapping for the standing guide.
///
/// This type deliberately owns no clock or timer. A caller may sample it at
/// display cadence only inside an animation window and otherwise jump between
/// the sparse boundaries exposed by `animationBoundaries`.
enum StandingGuideTimeline {
    static let duration: TimeInterval = 60

    static let animationBoundaries: [TimeInterval] = StandingBeat.allCases
        .flatMap { [$0.startSeconds, $0.endSeconds] }

    static func snapshot(elapsed rawElapsed: TimeInterval) -> StandingGuideSnapshot {
        let elapsed = clampedElapsed(rawElapsed, duration: duration)
        let assembly = StandingAssembly(
            handleProgress: phase(for: .title, elapsed: elapsed),
            cargoBinProgress: phase(for: .backing, elapsed: elapsed),
            chassisProgress: phase(for: .rails, elapsed: elapsed),
            ribbonProgress: phase(for: .ribbon, elapsed: elapsed)
        )

        let activeBeat = StandingBeat.allCases.first { beat in
            elapsed >= beat.startSeconds && elapsed < beat.endSeconds
        }

        return StandingGuideSnapshot(
            elapsed: elapsed,
            activeBeat: activeBeat,
            assembly: assembly
        )
    }

    static func isAnimating(at elapsed: TimeInterval) -> Bool {
        snapshot(elapsed: elapsed).isAnimating
    }

    static func nextAnimationBoundary(after rawElapsed: TimeInterval) -> TimeInterval? {
        guard rawElapsed.isFinite else { return animationBoundaries.first }
        return animationBoundaries.first { $0 > rawElapsed }
    }

    private static func phase(for beat: StandingBeat, elapsed: TimeInterval) -> Double {
        clamp((elapsed - beat.startSeconds) / StandingBeat.duration)
    }
}

/// The short, one-shot finish after the sixty-second guide.
///
/// The card is first collected from the safety dock, then placed on the same
/// trolley assembled by `StandingGuideTimeline`. The trolley performs one
/// three-point load response before the character settles into a smile.
struct StandingCompletionSnapshot: Equatable, Sendable {
    let elapsed: TimeInterval
    let cardPickupProgress: Double
    let cardPlacementProgress: Double
    let trolleyCompressionProgress: Double
    let smileProgress: Double
    let settleProgress: Double

    var isAnimating: Bool {
        elapsed < StandingCompletionTimeline.duration
    }

    var cardIsPlaced: Bool {
        cardPlacementProgress >= 1
    }

    static var initial: StandingCompletionSnapshot {
        StandingCompletionTimeline.snapshot(elapsed: 0)
    }

    static var completed: StandingCompletionSnapshot {
        StandingCompletionTimeline.snapshot(elapsed: StandingCompletionTimeline.duration)
    }
}

enum StandingCompletionTimeline {
    static let duration: TimeInterval = 1.05

    static func snapshot(elapsed rawElapsed: TimeInterval) -> StandingCompletionSnapshot {
        let elapsed = clampedElapsed(rawElapsed, duration: duration)

        return StandingCompletionSnapshot(
            elapsed: elapsed,
            cardPickupProgress: phase(from: 0, to: 0.16, elapsed: elapsed),
            cardPlacementProgress: phase(from: 0.16, to: 0.42, elapsed: elapsed),
            trolleyCompressionProgress: triangularPhase(
                from: 0.52,
                peak: 0.65,
                to: 0.78,
                elapsed: elapsed
            ),
            smileProgress: phase(from: 0.50, to: 0.86, elapsed: elapsed),
            settleProgress: phase(from: 0.86, to: duration, elapsed: elapsed)
        )
    }

    private static func triangularPhase(
        from start: TimeInterval,
        peak: TimeInterval,
        to end: TimeInterval,
        elapsed: TimeInterval
    ) -> Double {
        guard elapsed > start, elapsed < end else { return 0 }
        if elapsed <= peak {
            return phase(from: start, to: peak, elapsed: elapsed)
        }
        return 1 - phase(from: peak, to: end, elapsed: elapsed)
    }
}

private func phase(
    from start: TimeInterval,
    to end: TimeInterval,
    elapsed: TimeInterval
) -> Double {
    guard end > start else { return elapsed >= end ? 1 : 0 }
    return clamp((elapsed - start) / (end - start))
}

private func clampedElapsed(_ elapsed: TimeInterval, duration: TimeInterval) -> TimeInterval {
    guard elapsed.isFinite else { return 0 }
    return min(max(elapsed, 0), duration)
}

private func clamp(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(max(value, 0), 1)
}
