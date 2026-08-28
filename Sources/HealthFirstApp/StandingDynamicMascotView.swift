import AppKit
import SwiftUI

/// Normalized choreography shared by the dynamic arm and the collected prop.
/// Keeping these boundaries in one place prevents the hand from releasing a
/// fragment before the fragment itself reaches the trolley.
enum StandingCollectionTiming {
    static let reachEnd = 0.32
    static let gripEnd = 0.42
    static let pullEnd = 0.72
    static let placeEnd = 0.84
    static let releaseEnd = 0.90
}

/// Contact geometry for the 420 x 280 standing stage.
///
/// Source points sit on visible material rather than at a fragment's center;
/// destination points are the character-facing contact points on the trolley.
enum StandingCollectionGeometry {
    static let home = CGPoint(x: 290, y: 167)
    static let shoulder = CGPoint(x: 310, y: 139)

    static func sourceGrabPoint(for beat: StandingBeat) -> CGPoint {
        switch beat {
        case .title:
            CGPoint(x: 166, y: 68)
        case .backing:
            CGPoint(x: 208, y: 119)
        case .rails:
            CGPoint(x: 219, y: 119)
        case .ribbon:
            CGPoint(x: 340, y: 157)
        }
    }

    static func destinationGrabPoint(for beat: StandingBeat) -> CGPoint {
        switch beat {
        case .title:
            CGPoint(x: 273, y: 159)
        case .backing:
            CGPoint(x: 282, y: 143)
        case .rails:
            CGPoint(x: 290, y: 160)
        case .ribbon:
            CGPoint(x: 250, y: 118)
        }
    }
}

/// Allows the parent stage to interleave the articulated hose with a moving
/// prop while keeping the body and clamp in front. `.all` preserves the
/// convenient single-view behavior for existing callers and isolated labs.
enum StandingDynamicMascotLayer {
    case back
    case front
    case all
}

/// A single, identity-stable production mascot with one runtime-articulated
/// working arm. The baked viewer-left arm is masked from the approved
/// cart-hold frame; only its simple rubber hose and clamp are reconstructed.
/// The body, face, reel, feet and viewer-right arm remain the original pixels.
@MainActor
struct StandingDynamicMascotView: View {
    let snapshot: StandingGuideSnapshot
    let reduceMotion: Bool
    let completion: StandingCompletionSnapshot?
    let layer: StandingDynamicMascotLayer

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    init(
        snapshot: StandingGuideSnapshot,
        reduceMotion: Bool,
        completion: StandingCompletionSnapshot? = nil,
        layer: StandingDynamicMascotLayer = .all
    ) {
        self.snapshot = snapshot
        self.reduceMotion = reduceMotion
        self.completion = completion
        self.layer = layer
    }

    init(
        snapshot: StandingGuideSnapshot,
        completion: StandingCompletionSnapshot?,
        reduceMotion: Bool,
        layer: StandingDynamicMascotLayer = .all
    ) {
        self.init(
            snapshot: snapshot,
            reduceMotion: reduceMotion,
            completion: completion,
            layer: layer
        )
    }

    private var shouldReduceMotion: Bool {
        reduceMotion || systemReduceMotion
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image = StandingCartHoldImageStore.image {
                dynamicContent(image: image)
            } else if layer != .back {
                let smileProgress = completion?.smileProgress ?? 0
                ProductionMascotView(
                    expression: smileProgress > 0 ? .subtleSmile : .neutral,
                    motion: .guidingStanding,
                    progress: 1,
                    actionProgress: smileProgress,
                    reduceMotion: shouldReduceMotion,
                    acceptanceSide: .viewerLeft,
                    standingBeat: smileProgress > 0 ? .cartHoldSmile : .cartHold
                )
                .frame(
                    width: StandingStageGeometry.roleSlot.width,
                    height: StandingStageGeometry.roleSlot.height
                )
                .position(
                    x: StandingStageGeometry.roleSlot.midX,
                    y: StandingStageGeometry.roleSlot.midY
                )
            }
        }
        .frame(
            width: StandingStageGeometry.size.width,
            height: StandingStageGeometry.size.height,
            alignment: .topLeading
        )
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dynamicContent(image: NSImage) -> some View {
        switch layer {
        case .back:
            articulatedHose

        case .front:
            productionBody(image)
                .zIndex(1)
            shoulderInterface
                .zIndex(2)
            articulatedClaw
                .zIndex(3)

        case .all:
            articulatedHose
                .zIndex(0)
            productionBody(image)
                .zIndex(1)
            shoulderInterface
                .zIndex(2)
            articulatedClaw
                .zIndex(3)
        }
    }

    private func productionBody(_ image: NSImage) -> some View {
        ZStack {
            productionBodyImage(image)
                .opacity(1 - smileProgress)

            if let smileImage = StandingCartHoldImageStore.smileImage {
                productionBodyImage(smileImage)
                    .opacity(smileProgress)
            }
        }
    }

    private func productionBodyImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(
                width: StandingStageGeometry.roleSlot.width,
                height: StandingStageGeometry.roleSlot.height
            )
            .mask {
                StandingCartHoldBodyMask()
            }
            .position(
                x: StandingStageGeometry.roleSlot.midX,
                y: StandingStageGeometry.roleSlot.midY
            )
    }

    private var smileProgress: Double {
        guard StandingCartHoldImageStore.smileImage != nil else { return 0 }
        return clamped(completion?.smileProgress ?? 0)
    }

    private var articulatedHose: some View {
        ZStack {
            StandingHosePath(
                start: StandingCollectionGeometry.shoulder,
                end: handPoint
            )
            .stroke(
                HealthFirstStyle.lavender.opacity(0.24),
                style: StrokeStyle(lineWidth: 7.2, lineCap: .round, lineJoin: .round)
            )

            StandingHosePath(
                start: StandingCollectionGeometry.shoulder,
                end: handPoint
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.15, blue: 0.17),
                        Color(red: 0.27, green: 0.26, blue: 0.30),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: 5.6, lineCap: .round, lineJoin: .round)
            )

            StandingHosePath(
                start: StandingCollectionGeometry.shoulder,
                end: handPoint
            )
            .stroke(
                Color.white.opacity(0.09),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
            )
            .offset(y: -0.6)
        }
        .frame(
            width: StandingStageGeometry.size.width,
            height: StandingStageGeometry.size.height,
            alignment: .topLeading
        )
        .shadow(color: .black.opacity(0.16), radius: 1.2, y: 1)
    }

    private var shoulderInterface: some View {
        ZStack {
            Circle()
                .fill(HealthFirstStyle.lavender.opacity(0.50))
                .frame(width: 10, height: 10)

            Circle()
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                .frame(width: 6.5, height: 6.5)

            Circle()
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                .frame(width: 5, height: 5)
                .offset(x: -0.6, y: -0.6)
        }
        .position(StandingCollectionGeometry.shoulder)
        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
    }

    private var articulatedClaw: some View {
        StandingCClampView(closure: clawClosure)
            .frame(width: 18, height: 18)
            .rotationEffect(clawRotation)
            .position(handPoint)
            .shadow(color: .black.opacity(0.18), radius: 0.6, y: 0.6)
    }

    private var handPoint: CGPoint {
        guard !shouldReduceMotion else {
            return StandingCollectionGeometry.home
        }

        if let completion {
            return completionHandPoint(for: completion)
        }

        guard let beat = snapshot.activeBeat else {
            return StandingCollectionGeometry.home
        }

        let progress = clamped(snapshot.progress(for: beat))
        let source = StandingCollectionGeometry.sourceGrabPoint(for: beat)
        let destination = StandingCollectionGeometry.destinationGrabPoint(for: beat)

        switch progress {
        case ..<StandingCollectionTiming.reachEnd:
            return interpolate(
                from: StandingCollectionGeometry.home,
                to: source,
                progress: eased(
                    phase(progress, from: 0, to: StandingCollectionTiming.reachEnd)
                )
            )
        case ..<StandingCollectionTiming.gripEnd:
            return source
        case ..<StandingCollectionTiming.pullEnd:
            return interpolate(
                from: source,
                to: destination,
                progress: eased(
                    phase(
                        progress,
                        from: StandingCollectionTiming.gripEnd,
                        to: StandingCollectionTiming.pullEnd
                    )
                )
            )
        case ..<StandingCollectionTiming.releaseEnd:
            return destination
        default:
            return interpolate(
                from: destination,
                to: StandingCollectionGeometry.home,
                progress: eased(
                    phase(
                        progress,
                        from: StandingCollectionTiming.releaseEnd,
                        to: 1
                    )
                )
            )
        }
    }

    private var clawClosure: Double {
        guard !shouldReduceMotion else { return 0 }

        if let completion {
            guard let pack = activeCompletionPack(for: completion) else {
                return 0
            }
            if pack.reachProgress < 1 { return 0 }
            if pack.gripProgress < 1 {
                return eased(pack.gripProgress)
            }
            if pack.placementProgress < 1 { return 1 }
            return 1 - eased(pack.releaseProgress)
        }

        guard let beat = snapshot.activeBeat else { return 0 }
        let progress = clamped(snapshot.progress(for: beat))

        switch progress {
        case ..<StandingCollectionTiming.reachEnd:
            return 0
        case ..<StandingCollectionTiming.gripEnd:
            return eased(
                phase(
                    progress,
                    from: StandingCollectionTiming.reachEnd,
                    to: StandingCollectionTiming.gripEnd
                )
            )
        case ..<StandingCollectionTiming.placeEnd:
            return 1
        case ..<StandingCollectionTiming.releaseEnd:
            return 1 - eased(
                phase(
                    progress,
                    from: StandingCollectionTiming.placeEnd,
                    to: StandingCollectionTiming.releaseEnd
                )
            )
        default:
            return 0
        }
    }

    private var clawRotation: Angle {
        guard !shouldReduceMotion else { return .zero }

        if let completion,
           let beat = completion.activeBeat,
           let pack = activeCompletionPack(for: completion) {
            let hold = eased(pack.gripProgress)
                * (1 - eased(pack.releaseProgress))
            return .degrees(
                (beat == .dock ? 8 : -16) * hold
            )
        }

        return completion == nil && snapshot.activeBeat == .ribbon
            ? .degrees(180)
            : .zero
    }

    private func completionHandPoint(
        for completion: StandingCompletionSnapshot
    ) -> CGPoint {
        guard let beat = completion.activeBeat,
              let pack = activeCompletionPack(for: completion) else {
            return StandingCollectionGeometry.home
        }

        let source: CGPoint
        let destination: CGPoint
        switch beat {
        case .dock:
            source = StandingStageGeometry.completionDockGrabPoint
            destination = StandingStageGeometry.completionDockDestinationGrabPoint
        case .backdrop:
            source = StandingStageGeometry.completionBackdropGrabPoint
            destination = StandingStageGeometry.completionBackdropDestinationGrabPoint
        }

        if pack.reachProgress < 1 {
            return interpolate(
                from: StandingCollectionGeometry.home,
                to: source,
                progress: eased(pack.reachProgress)
            )
        }
        if pack.gripProgress < 1 {
            return source
        }
        if pack.transferProgress < 1 {
            return interpolate(
                from: source,
                to: destination,
                progress: eased(pack.transferProgress)
            )
        }
        if pack.placementProgress < 1 {
            return destination
        }
        return interpolate(
            from: destination,
            to: StandingCollectionGeometry.home,
            progress: eased(pack.releaseProgress)
        )
    }

    private func activeCompletionPack(
        for completion: StandingCompletionSnapshot
    ) -> StandingPackProgress? {
        switch completion.activeBeat {
        case .dock:
            completion.dock
        case .backdrop:
            completion.backdrop
        case nil:
            nil
        }
    }

    private func phase(
        _ value: Double,
        from start: Double,
        to end: Double
    ) -> Double {
        guard end > start else { return value >= end ? 1 : 0 }
        return clamped((value - start) / (end - start))
    }

    private func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    private func eased(_ value: Double) -> Double {
        let value = clamped(value)
        return value * value * (3 - 2 * value)
    }

    private func interpolate(
        from start: CGPoint,
        to end: CGPoint,
        progress: Double
    ) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }
}

/// The approved square artwork is fitted into a 106 x 124 role slot, leaving
/// nine points of vertical letterboxing. In that fitted coordinate system the
/// body begins at x ~= 29 while the viewer-left arm and claw occupy x < 27.
/// Keeping the right 79 points removes the working limb without repainting any
/// of the character's identity-bearing pixels. The shoulder socket covers the
/// small, deliberately retained attachment seam.
private struct StandingCartHoldBodyMask: View {
    var body: some View {
        GeometryReader { proxy in
            let cut: CGFloat = 27
            Rectangle()
                .fill(.white)
                .frame(
                    width: max(0, proxy.size.width - cut),
                    height: proxy.size.height
                )
                .position(
                    x: cut + max(0, proxy.size.width - cut) / 2,
                    y: proxy.size.height / 2
                )
        }
    }
}

private struct StandingHosePath: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        let distance = hypot(end.x - start.x, end.y - start.y)
        let sag = min(16, max(4, distance * 0.10))

        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(
                x: start.x + (end.x - start.x) * 0.30,
                y: start.y + (end.y - start.y) * 0.18 + sag
            ),
            control2: CGPoint(
                x: start.x + (end.x - start.x) * 0.72,
                y: start.y + (end.y - start.y) * 0.78 + sag
            )
        )
        return path
    }
}

private struct StandingCClampView: View {
    let closure: Double

    var body: some View {
        ZStack {
            StandingCClampShape(closure: closure)
                .stroke(
                    HealthFirstStyle.lavender.opacity(0.92),
                    style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
                )

            StandingCClampShape(closure: closure)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.16, blue: 0.18),
                            Color(red: 0.31, green: 0.30, blue: 0.34),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

            Circle()
                .fill(Color(red: 0.17, green: 0.17, blue: 0.19))
                .overlay {
                    Circle().stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                }
                .frame(width: 5.5, height: 5.5)
                .offset(x: 6)
        }
    }
}

private struct StandingCClampShape: Shape {
    let closure: Double

    func path(in rect: CGRect) -> Path {
        let amount = min(max(closure, 0), 1)
        let openGap = rect.height * (0.22 - 0.13 * amount)
        let wrist = CGPoint(x: rect.maxX - 3, y: rect.midY)
        let upperTip = CGPoint(x: rect.minX + 2.5, y: rect.midY - openGap)
        let lowerTip = CGPoint(x: rect.minX + 2.5, y: rect.midY + openGap)

        var path = Path()
        path.move(to: wrist)
        path.addCurve(
            to: upperTip,
            control1: CGPoint(x: rect.maxX - 3, y: rect.minY + 2),
            control2: CGPoint(x: rect.midX - 3, y: rect.minY + 1.5)
        )
        path.move(to: wrist)
        path.addCurve(
            to: lowerTip,
            control1: CGPoint(x: rect.maxX - 3, y: rect.maxY - 2),
            control2: CGPoint(x: rect.midX - 3, y: rect.maxY - 1.5)
        )
        return path
    }
}

@MainActor
private enum StandingCartHoldImageStore {
    private static let moduleBundleName = "HealthFirst_HealthFirstApp.bundle"
    private static let resourceName = "mascot-standing-cart-hold-viewer-left-v1"
    private static let smileResourceName = "mascot-standing-cart-hold-viewer-left-smile-v1"

    static let image: NSImage? = {
        guard let url = resourceURL(named: resourceName) else { return nil }
        return NSImage(contentsOf: url)
    }()

    static let smileImage: NSImage? = {
        guard let url = resourceURL(named: smileResourceName) else { return nil }
        return NSImage(contentsOf: url)
    }()

    private static func resourceURL(named resourceName: String) -> URL? {
        var candidateURLs: [URL] = [
            Bundle.main.bundleURL
                .appendingPathComponent(moduleBundleName, isDirectory: true),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources", isDirectory: true)
                .appendingPathComponent(moduleBundleName, isDirectory: true),
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
        for bundleURL in candidateURLs where visitedPaths.insert(bundleURL.path).inserted {
            guard let bundle = Bundle(url: bundleURL) else { continue }
            if let url = bundle.url(
                forResource: resourceName,
                withExtension: "png",
                subdirectory: "runtime"
            ) ?? bundle.url(forResource: resourceName, withExtension: "png") {
                return url
            }
        }
        return nil
    }
}
