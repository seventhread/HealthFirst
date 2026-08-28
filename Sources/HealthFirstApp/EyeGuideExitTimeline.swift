import Foundation

/// Deterministic opening choreography for eye guidance.
///
/// The timer starts immediately, but the mascot deliberately stays present
/// long enough for the user's acceptance to read as a response rather than a
/// sudden disappearance. It then folds into a small desktop companion instead
/// of fading away.
enum EyeGuideExitTimeline {
    static let cardClearStart: TimeInterval = 0.56
    static let cardClearDuration: TimeInterval = 0.54
    static let agreementEnd: TimeInterval = 0.95
    static let handoffStart: TimeInterval = 3.00
    static let handoffDuration: TimeInterval = 1.10
    static let companionSettleDuration: TimeInterval = 1.00
    static let decorativeFadeDuration: TimeInterval = 0.75

    static var handoffEnd: TimeInterval {
        handoffStart + handoffDuration
    }

    static var cardClearEnd: TimeInterval {
        cardClearStart + cardClearDuration
    }

    static var companionSettleStart: TimeInterval {
        handoffEnd
    }

    static var companionSettleEnd: TimeInterval {
        companionSettleStart + companionSettleDuration
    }

    static var decorativeFadeEnd: TimeInterval {
        companionSettleStart + decorativeFadeDuration
    }

    static func handoffProgress(at elapsed: TimeInterval) -> Double {
        normalized((elapsed - handoffStart) / handoffDuration)
    }

    static func cardChromeOpacity(at elapsed: TimeInterval) -> Double {
        1 - normalized((elapsed - cardClearStart) / cardClearDuration)
    }

    static func companionProgress(
        at elapsed: TimeInterval,
        reduceMotion: Bool
    ) -> Double {
        if reduceMotion {
            return elapsed >= companionSettleStart ? 1 : 0
        }

        return eased(
            normalized(
                (elapsed - companionSettleStart) / companionSettleDuration
            )
        )
    }

    static func decorativeOpacity(at elapsed: TimeInterval) -> Double {
        1 - eased(
            normalized(
                (elapsed - companionSettleStart) / decorativeFadeDuration
            )
        )
    }

    static func mascotOpacity(
        at _: TimeInterval,
        reduceMotion _: Bool
    ) -> Double {
        // The folded character is the long-lived eye-rest companion. Keeping
        // it fully opaque also prevents a blank interval between the large
        // pose and its small settled form.
        1
    }

    static func isMascotTimelineActive(
        at elapsed: TimeInterval,
        reduceMotion: Bool
    ) -> Bool {
        elapsed < (reduceMotion ? companionSettleStart : companionSettleEnd)
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return value.sign == .minus ? 0 : 1 }
        return min(1, max(0, value))
    }

    private static func eased(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}
