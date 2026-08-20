import AppKit
import SwiftUI

/// Which side of the mascot receives the work card. The approved raster
/// artwork is directional: callers must select a matching pose instead of
/// mirroring the character (which would also mirror its permanent reel).
enum AcceptanceSide: Hashable {
    case viewerRight
    case viewerLeft
}

/// Visual-only key poses for the sixty-second standing assembly. Short beats
/// use `actionProgress` as their local 0...1 entrance/exit timeline; the cart
/// hold poses enter and remain held. Business timing remains with the caller.
enum StandingMascotBeat: Hashable {
    case idle
    case inspect
    case lift
    case carry
    case cartHold
    /// Completion-only handoff: keep holding the existing trolley, reuse the
    /// lift pose for the check card, then return to the same cart grip.
    case completionLift
    case cartHoldSmile
}

/// Runtime bridge between the approved raster character poses and the
/// existing SwiftUI mascot. It intentionally mirrors `MascotPlaceholderView`
/// so callers can migrate one surface at a time without touching business
/// state.
struct ProductionMascotView: View {
    var expression: MascotExpression = .neutral
    var motion: MascotMotion = .idle
    var progress: Double = 0
    /// Optional short-action timeline. Existing callers can keep using
    /// `progress`; reminder surfaces with a longer business timeline should
    /// pass an independent 0...1 entrance/acceptance progress here.
    var actionProgress: Double? = nil
    var reduceMotion: Bool = false
    var acceptanceSide: AcceptanceSide = .viewerRight
    var standingBeat: StandingMascotBeat? = nil

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var shouldReduceMotion: Bool {
        reduceMotion || systemReduceMotion
    }

    private var wantsSmile: Bool {
        expression == .subtleSmile
    }

    private var normalizedActionProgress: CGFloat {
        CGFloat(min(max(actionProgress ?? progress, 0), 1))
    }

    private var easedEntranceProgress: CGFloat {
        guard !shouldReduceMotion else { return 1 }
        return ramp(normalizedActionProgress, from: 0.12, to: 0.58)
    }

    private var entranceCompression: CGFloat {
        guard !shouldReduceMotion else { return 0 }
        let phase = ramp(normalizedActionProgress, from: 0.58, to: 0.82)
        return sin(phase * .pi) * 0.018
    }

    private var staticFrame: ProductionMascotFrame {
        switch motion {
        case .idle:
            return wantsSmile ? .smile : .neutral
        case .agreeing:
            return .acceptStore
        case .completed:
            return .smile
        case .guidingEye, .skipping, .ignored:
            return .folded
        case .guidingQuiet:
            return .back
        default:
            return .neutral
        }
    }

    /// A missing optional pose must not send the entire character back to the
    /// placeholder. Resolve only the frames needed by the current pose and
    /// use the placeholder solely when none of those frames can be rendered.
    private var canRenderCurrentPose: Bool {
        ProductionMascotFrame.allCases.contains { requestedFrame in
            frameOpacity(requestedFrame) > 0.0001
                && ProductionMascotImageStore.resolvedFrame(for: requestedFrame) != nil
        }
    }

    var body: some View {
        Group {
            if canRenderCurrentPose {
                ZStack {
                    if motion == .entering && !shouldReduceMotion {
                        entranceRibbon
                    }

                    ForEach(ProductionMascotFrame.allCases, id: \.self) { frame in
                        if let image = ProductionMascotImageStore.image(for: frame) {
                            productionImage(image)
                                .opacity(resolvedOpacity(for: frame))
                        }
                    }
                }
            } else {
                MascotPlaceholderView(
                    expression: expression,
                    motion: motion,
                    progress: progress,
                    reduceMotion: reduceMotion
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func productionImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .opacity(
                motion == .entering
                    ? 0.42 + 0.58 * Double(easedEntranceProgress)
                    : 1
            )
            .scaleEffect(
                x: motion == .entering ? 1 + entranceCompression * 0.32 : 1,
                y: motion == .entering ? 1 - entranceCompression : 1,
                anchor: .bottom
            )
            .offset(
                x: 0,
                y: motion == .entering ? -24 * (1 - easedEntranceProgress) : 0
            )
            .accessibilityHidden(true)
    }

    private var entranceRibbon: some View {
        GeometryReader { proxy in
            let reveal = ramp(normalizedActionProgress, from: 0, to: 0.12)
            let retract = ramp(normalizedActionProgress, from: 0.72, to: 1)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [HealthFirstStyle.orange.opacity(0.96), HealthFirstStyle.orange.opacity(0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: max(2.5, proxy.size.width * 0.026), height: proxy.size.height * 0.58 * reveal)
                .position(x: proxy.size.width * 0.68, y: proxy.size.height * 0.29 * reveal)
                .opacity(1 - Double(retract))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func frameOpacity(_ frame: ProductionMascotFrame) -> Double {
        if standingBeat != nil || motion == .guidingStanding {
            return standingOpacity(for: frame)
        }

        if motion == .guidingEye {
            return eyeHandoffOpacity(for: frame, progress: normalizedActionProgress)
        }

        if motion == .guidingQuiet {
            return quietHandoffOpacity(for: frame, progress: normalizedActionProgress)
        }

        if shouldReduceMotion {
            if motion == .agreeing {
                return reducedAgreeingOpacity(for: frame, progress: normalizedActionProgress)
            }
            return frame == staticFrame ? 1 : 0
        }

        switch motion {
        case .agreeing:
            return agreeingOpacity(for: frame, progress: normalizedActionProgress)
        default:
            return frame == staticFrame ? 1 : 0
        }
    }

    /// Sums requested pose weights after per-frame fallback resolution. This
    /// keeps a missing key pose from making the character disappear while
    /// avoiding duplicate copies of the same fallback image during a dissolve.
    private func resolvedOpacity(for renderedFrame: ProductionMascotFrame) -> Double {
        let total = ProductionMascotFrame.allCases.reduce(0.0) { partial, requestedFrame in
            guard ProductionMascotImageStore.resolvedFrame(for: requestedFrame) == renderedFrame else {
                return partial
            }
            return partial + frameOpacity(requestedFrame)
        }
        return min(1, total)
    }

    /// Neutral -> catch -> store -> smile -> neutral. Every dissolve is
    /// derived from progress, so
    /// recreating the hosting view or jumping the clock is deterministic.
    private func agreeingOpacity(
        for frame: ProductionMascotFrame,
        progress: CGFloat
    ) -> Double {
        // The short dissolves are deliberate: the approved poses are full
        // body bitmaps, so long blends read as duplicate arms rather than
        // continuous movement. The independent work-card layer supplies the
        // smooth physical trajectory between these key poses.
        let neutralToCatch = ramp(progress, from: 0.07, to: 0.13)
        let catchToStore = ramp(progress, from: 0.18, to: 0.24)
        let storeToSmile = ramp(progress, from: 0.32, to: 0.36)
        let smileToNeutral = ramp(progress, from: 0.94, to: 1)

        if frame == .neutral {
            return Double(max(1 - neutralToCatch, smileToNeutral))
        }
        if frame == acceptingCatchFrame {
            return Double(neutralToCatch * (1 - catchToStore))
        }
        if frame == acceptingStoreFrame {
            return Double(catchToStore * (1 - storeToSmile))
        }
        if frame == .smile {
            return Double(storeToSmile * (1 - smileToNeutral))
        }
        return 0
    }

    private func reducedAgreeingOpacity(
        for frame: ProductionMascotFrame,
        progress: CGFloat
    ) -> Double {
        let storeToSmile = ramp(progress, from: 0.32, to: 0.36)
        let smileToNeutral = ramp(progress, from: 0.90, to: 0.96)

        if frame == acceptingStoreFrame {
            return Double(1 - storeToSmile)
        }
        if frame == .smile {
            return Double(storeToSmile * (1 - smileToNeutral))
        }
        if frame == .neutral {
            return Double(smileToNeutral)
        }
        return 0
    }

    private var acceptingCatchFrame: ProductionMascotFrame {
        acceptanceSide == .viewerLeft ? .acceptLeftCatch : .acceptCatch
    }

    private var acceptingStoreFrame: ProductionMascotFrame {
        acceptanceSide == .viewerLeft ? .acceptLeftStore : .acceptStore
    }

    /// When no explicit beat is supplied, retain a useful backwards-compatible
    /// sixty-second performance derived entirely from guidance `progress`.
    /// Explicit callers can instead pass a beat plus local `actionProgress`.
    private var effectiveStandingBeat: (beat: StandingMascotBeat, progress: CGFloat) {
        if let standingBeat {
            let localProgress = actionProgress.map {
                CGFloat(min(max($0, 0), 1))
            } ?? 1
            return (standingBeat, localProgress)
        }

        let elapsed = CGFloat(min(max(progress, 0), 1)) * 60
        switch elapsed {
        case ..<0.35:
            return (.inspect, min(0.5, elapsed / 0.7))
        case ..<7.75:
            return (.inspect, 0.5)
        case ..<8:
            return (.inspect, 0.5 + (elapsed - 7.75) * 2)
        case ..<8.6:
            return (.lift, (elapsed - 8) / 0.6)
        case ..<22:
            return (.idle, 1)
        case ..<22.6:
            return (.carry, (elapsed - 22) / 0.6)
        case ..<38:
            return (.idle, 1)
        case ..<38.6:
            return (.carry, (elapsed - 38) / 0.6)
        case ..<52:
            return (.idle, 1)
        case ..<52.6:
            return (.cartHold, (elapsed - 52) / 0.6)
        default:
            // Guidance stays neutral through the deadline. The completion
            // receipt owns the one-shot smile after the final card is placed.
            return (.cartHold, 1)
        }
    }

    private func standingOpacity(for frame: ProductionMascotFrame) -> Double {
        let standing = effectiveStandingBeat

        if shouldReduceMotion {
            return frame == standingStaticFrame(for: standing.beat) ? 1 : 0
        }

        switch standing.beat {
        case .idle:
            return frame == .neutral ? 1 : 0

        case .inspect:
            return shortBeatOpacity(
                for: frame,
                pose: .standingInspect,
                base: .neutral,
                progress: standing.progress
            )

        case .lift:
            return splitBeatOpacity(
                for: frame,
                pose: .standingLift,
                enterBase: .standingInspect,
                exitBase: .neutral,
                progress: standing.progress
            )

        case .carry:
            return shortBeatOpacity(
                for: frame,
                pose: .standingCarry,
                base: .neutral,
                progress: standing.progress
            )

        case .cartHold:
            let enter = ramp(standing.progress, from: 0, to: 0.28)
            if frame == .neutral { return Double(1 - enter) }
            if frame == .standingCartHold { return Double(enter) }
            return 0

        case .completionLift:
            let lift = ramp(standing.progress, from: 0, to: 0.18)
            // Start returning only after the completion card has landed.
            // The final 16% is about 80 ms of the 0.5 s lift timeline, short
            // enough to avoid a visible duplicate full-body raster.
            let returnToCart = ramp(standing.progress, from: 0.84, to: 1)
            if frame == .standingCartHold {
                return Double(max(1 - lift, returnToCart))
            }
            if frame == .standingLift {
                return Double(lift * (1 - returnToCart))
            }
            return 0

        case .cartHoldSmile:
            let smile = ramp(standing.progress, from: 0.10, to: 0.52)
            if frame == .standingCartHold { return Double(1 - smile) }
            if frame == .standingCartHoldSmile { return Double(smile) }
            return 0
        }
    }

    private func standingStaticFrame(for beat: StandingMascotBeat) -> ProductionMascotFrame {
        switch beat {
        case .idle: .neutral
        case .inspect: .standingInspect
        case .lift: .standingLift
        case .carry: .standingCarry
        case .cartHold: .standingCartHold
        case .completionLift: .standingCartHold
        case .cartHoldSmile: .standingCartHoldSmile
        }
    }

    private func shortBeatOpacity(
        for frame: ProductionMascotFrame,
        pose: ProductionMascotFrame,
        base: ProductionMascotFrame,
        progress: CGFloat
    ) -> Double {
        // The standing milestones last 0.6 s. Limit full-body dissolves to
        // roughly 84 ms so they read as a single motion-blur beat instead of
        // leaving two independent sets of hose arms on screen.
        let enter = ramp(progress, from: 0, to: 0.14)
        let exit = ramp(progress, from: 0.86, to: 1)
        if frame == base { return Double(max(1 - enter, exit)) }
        if frame == pose { return Double(enter * (1 - exit)) }
        return 0
    }

    private func splitBeatOpacity(
        for frame: ProductionMascotFrame,
        pose: ProductionMascotFrame,
        enterBase: ProductionMascotFrame,
        exitBase: ProductionMascotFrame,
        progress: CGFloat
    ) -> Double {
        let enter = ramp(progress, from: 0, to: 0.14)
        let exit = ramp(progress, from: 0.86, to: 1)
        if frame == enterBase { return Double(1 - enter) }
        if frame == pose { return Double(enter * (1 - exit)) }
        if frame == exitBase { return Double(exit) }
        return 0
    }

    /// Once the card reaches the reel, the eye reminder folds the mascot and
    /// clears the screen. A brief smile is already visible when the work card
    /// reaches the reel, so fast-clearing reminders still acknowledge the
    /// user's choice before the folding key poses take over.
    private func eyeHandoffOpacity(
        for frame: ProductionMascotFrame,
        progress: CGFloat
    ) -> Double {
        let uprightToHalf = ramp(progress, from: 0, to: 0.28)
        let halfToFold = ramp(progress, from: 0.72, to: 1)
        switch frame {
        case .smile:
            return Double(1 - uprightToHalf)
        case .halfFolded:
            return Double(uprightToHalf * (1 - halfToFold))
        case .folded:
            return Double(halfToFold)
        default:
            return 0
        }
    }

    /// Quiet practice uses one real three-quarter pose between the front and
    /// back artwork. Each full-body dissolve is kept under roughly 90 ms by
    /// the caller's 260 ms handoff timeline.
    private func quietHandoffOpacity(
        for frame: ProductionMascotFrame,
        progress: CGFloat
    ) -> Double {
        let frontToTurn = ramp(progress, from: 0, to: 0.34)
        let turnToBack = ramp(progress, from: 0.66, to: 1)

        switch frame {
        case .smile:
            return Double(1 - frontToTurn)
        case .turningAway:
            return Double(frontToTurn * (1 - turnToBack))
        case .back:
            return Double(turnToBack)
        default:
            return 0
        }
    }

    private func ramp(_ value: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        let normalized = min(max((value - start) / (end - start), 0), 1)
        return normalized * normalized * (3 - 2 * normalized)
    }
}

private enum ProductionMascotFrame: String, Hashable, CaseIterable {
    case neutral = "mascot-neutral-v1"
    case acceptCatch = "mascot-accept-catch-v1"
    case acceptStore = "mascot-accept-store-v1"
    case acceptLeftCatch = "mascot-accept-left-catch-v1"
    case acceptLeftStore = "mascot-accept-left-store-v1"
    case smile = "mascot-smile-v1"
    case turningAway = "mascot-turning-away-v1"
    case back = "mascot-back-v1"
    case halfFolded = "mascot-half-folded-v1"
    case folded = "mascot-folded-v1"
    case standingInspect = "mascot-standing-inspect-viewer-left-v1"
    case standingLift = "mascot-standing-lift-viewer-left-v1"
    case standingCarry = "mascot-standing-carry-viewer-left-v1"
    case standingCartHold = "mascot-standing-cart-hold-viewer-left-v1"
    case standingCartHoldSmile = "mascot-standing-cart-hold-viewer-left-smile-v1"
}

@MainActor
private enum ProductionMascotImageStore {
    private static let moduleBundleName = "HealthFirst_HealthFirstApp.bundle"

    /// Avoid the generated `Bundle.module` accessor because it traps when the
    /// resource bundle was not copied into a custom app package. Searching
    /// known app and SwiftPM locations lets a missing bundle reach the
    /// placeholder path instead of crashing on first render.
    private static let resourceBundle: Bundle? = {
        var candidateURLs: [URL] = [
            Bundle.main.bundleURL
                .appendingPathComponent(moduleBundleName, isDirectory: true),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources", isDirectory: true)
                .appendingPathComponent(moduleBundleName, isDirectory: true)
        ]
        if let resourceURL = Bundle.main.resourceURL {
            candidateURLs.append(
                resourceURL.appendingPathComponent(moduleBundleName, isDirectory: true)
            )
        }
        if let executableURL = Bundle.main.executableURL {
            candidateURLs.append(
                executableURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(moduleBundleName, isDirectory: true)
            )
        }
        candidateURLs.append(
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent(moduleBundleName, isDirectory: true)
        )

        var visitedPaths = Set<String>()
        for url in candidateURLs where visitedPaths.insert(url.path).inserted {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()

    private static let images: [ProductionMascotFrame: NSImage] = {
        Dictionary(uniqueKeysWithValues: ProductionMascotFrame.allCases.compactMap { frame in
            guard let url = resourceURL(for: frame),
                  let image = NSImage(contentsOf: url) else {
                return nil
            }
            return (frame, image)
        })
    }()

    static func image(for frame: ProductionMascotFrame) -> NSImage? {
        images[frame]
    }

    /// Resolve a single missing pose locally. Directional left-side poses
    /// intentionally never fall back to mirrored right-side artwork.
    static func resolvedFrame(for frame: ProductionMascotFrame) -> ProductionMascotFrame? {
        let candidates: [ProductionMascotFrame]
        switch frame {
        case .acceptLeftCatch:
            candidates = [.acceptLeftCatch, .neutral, .smile]
        case .acceptLeftStore:
            candidates = [.acceptLeftStore, .smile, .neutral]
        case .acceptCatch:
            candidates = [.acceptCatch, .neutral, .smile]
        case .acceptStore:
            candidates = [.acceptStore, .smile, .neutral]
        case .smile, .standingCartHoldSmile:
            candidates = [frame, .smile, .neutral]
        case .neutral:
            candidates = [.neutral, .smile]
        default:
            candidates = [frame, .neutral, .smile]
        }
        return candidates.first { images[$0] != nil }
    }

    private static func resourceURL(for frame: ProductionMascotFrame) -> URL? {
        resourceBundle?.url(forResource: frame.rawValue, withExtension: "png")
            ?? resourceBundle?.url(
                forResource: frame.rawValue,
                withExtension: "png",
                subdirectory: "runtime"
            )
    }
}
