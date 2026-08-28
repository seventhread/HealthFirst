import Foundation

/// The four one-shot prop handoffs used during the sixty-second standing guide.
///
/// The names describe the source fragment. Their final trolley roles are:
/// title -> base, backing -> cargo bin, rails -> frame/handle, ribbon -> tie.
enum StandingBeat: String, CaseIterable, Equatable, Sendable {
    case title
    case backing
    case rails
    case ribbon

    /// Long enough to read as reach → grip → pull → place at the live card
    /// size, while remaining a compact one-shot milestone.
    static let duration: TimeInterval = 2.0

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
    let baseProgress: Double
    let cargoBinProgress: Double
    let chassisProgress: Double
    let ribbonProgress: Double

    static let empty = StandingAssembly(
        baseProgress: 0,
        cargoBinProgress: 0,
        chassisProgress: 0,
        ribbonProgress: 0
    )

    static let completed = StandingAssembly(
        baseProgress: 1,
        cargoBinProgress: 1,
        chassisProgress: 1,
        ribbonProgress: 1
    )

    func progress(for beat: StandingBeat) -> Double {
        switch beat {
        case .title:
            baseProgress
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
        1 - placementProgress(for: beat)
    }

    /// The source fragment remains fully present while the character reaches
    /// and pulls it. Only the final placement phase dissolves it into the
    /// permanent trolley part.
    func placementProgress(for beat: StandingBeat) -> Double {
        let progress = progress(for: beat)
        let duration = StandingCollectionTiming.placeEnd
            - StandingCollectionTiming.pullEnd
        guard duration > 0 else {
            return progress >= StandingCollectionTiming.placeEnd ? 1 : 0
        }
        return clamp(
            (progress - StandingCollectionTiming.pullEnd) / duration
        )
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
            baseProgress: phase(for: .title, elapsed: elapsed),
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

enum StandingCompletionBeat: String, Equatable, Sendable {
    case dock
    case backdrop
}

/// One object's reach → grip → transfer → placement → release state. Keeping
/// all five phases explicit makes it impossible for the backdrop to start
/// while the countdown dock is still travelling.
struct StandingPackProgress: Equatable, Sendable {
    let reachProgress: Double
    let gripProgress: Double
    let transferProgress: Double
    let placementProgress: Double
    let releaseProgress: Double

    var isPlaced: Bool {
        placementProgress >= 1
    }
}

/// The two-step finish after the sixty-second guide.
///
/// Completion remains a business-state boundary at exactly sixty seconds.
/// This snapshot only choreographs the non-blocking visual epilogue: the
/// character first packs the real countdown-dock silhouette, pauses, and then
/// folds the large card backdrop into the same trolley before smiling.
struct StandingCompletionSnapshot: Equatable, Sendable {
    let elapsed: TimeInterval
    let activeBeat: StandingCompletionBeat?
    let dock: StandingPackProgress
    let backdrop: StandingPackProgress
    let trolleyCompressionProgress: Double
    let smileProgress: Double
    let receiptRevealProgress: Double

    var isAnimating: Bool {
        elapsed < StandingCompletionTimeline.duration
    }

    var isReadyForReceipt: Bool {
        receiptRevealProgress >= 1
    }

    static var initial: StandingCompletionSnapshot {
        StandingCompletionTimeline.snapshot(elapsed: 0)
    }

    static var completed: StandingCompletionSnapshot {
        StandingCompletionTimeline.snapshot(elapsed: StandingCompletionTimeline.duration)
    }
}

enum StandingCompletionTimeline {
    static let dockReleaseEnd: TimeInterval = 1.32
    static let backdropStart: TimeInterval = 1.42
    static let backdropReleaseEnd: TimeInterval = 3.08
    static let receiptRevealStart: TimeInterval = 3.30
    static let duration: TimeInterval = 3.60

    static func snapshot(elapsed rawElapsed: TimeInterval) -> StandingCompletionSnapshot {
        let elapsed = clampedElapsed(rawElapsed, duration: duration)
        let dock = packProgress(
            elapsed: elapsed,
            reach: 0...0.28,
            grip: 0.28...0.42,
            transfer: 0.42...1.12,
            placement: 0.98...1.12,
            release: 1.12...dockReleaseEnd
        )
        let backdrop = packProgress(
            elapsed: elapsed,
            reach: backdropStart...1.72,
            grip: 1.72...1.86,
            transfer: 1.86...2.78,
            placement: 2.60...2.78,
            release: 2.78...backdropReleaseEnd
        )

        let activeBeat: StandingCompletionBeat?
        if elapsed < dockReleaseEnd {
            activeBeat = .dock
        } else if elapsed >= backdropStart,
                  elapsed < backdropReleaseEnd {
            activeBeat = .backdrop
        } else {
            activeBeat = nil
        }

        let dockCompression = triangularPhase(
            from: 1.12,
            peak: 1.27,
            to: 1.42,
            elapsed: elapsed
        )
        let backdropCompression = triangularPhase(
            from: 2.78,
            peak: 2.93,
            to: backdropReleaseEnd,
            elapsed: elapsed
        )

        return StandingCompletionSnapshot(
            elapsed: elapsed,
            activeBeat: activeBeat,
            dock: dock,
            backdrop: backdrop,
            trolleyCompressionProgress: max(
                dockCompression,
                backdropCompression
            ),
            smileProgress: phase(from: 3.08, to: 3.36, elapsed: elapsed),
            receiptRevealProgress: phase(
                from: receiptRevealStart,
                to: 3.58,
                elapsed: elapsed
            )
        )
    }

    private static func packProgress(
        elapsed: TimeInterval,
        reach: ClosedRange<TimeInterval>,
        grip: ClosedRange<TimeInterval>,
        transfer: ClosedRange<TimeInterval>,
        placement: ClosedRange<TimeInterval>,
        release: ClosedRange<TimeInterval>
    ) -> StandingPackProgress {
        StandingPackProgress(
            reachProgress: phase(
                from: reach.lowerBound,
                to: reach.upperBound,
                elapsed: elapsed
            ),
            gripProgress: phase(
                from: grip.lowerBound,
                to: grip.upperBound,
                elapsed: elapsed
            ),
            transferProgress: phase(
                from: transfer.lowerBound,
                to: transfer.upperBound,
                elapsed: elapsed
            ),
            placementProgress: phase(
                from: placement.lowerBound,
                to: placement.upperBound,
                elapsed: elapsed
            ),
            releaseProgress: phase(
                from: release.lowerBound,
                to: release.upperBound,
                elapsed: elapsed
            )
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
