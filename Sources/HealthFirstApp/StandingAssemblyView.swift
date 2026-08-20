import SwiftUI

/// Shared geometry for the standing guide's 420 x 280 visual stage.
///
/// All coordinates use the stage's top-left as origin. The right-hand role
/// slot remains clear for `ProductionMascotView`; source UI and the trolley
/// stay to its left. These anchors are also available to the character layer
/// so its hand poses can meet the same props without duplicated magic numbers.
enum StandingStageGeometry {
    static let size = CGSize(width: 420, height: 280)

    static let roleSlot = CGRect(x: 280, y: 78, width: 106, height: 124)
    // Pose-specific contact points measured after the 650 px artwork is
    // rendered through the production 106 x 124 pt role slot. Keeping these
    // separate is more accurate than asking differently shaped arms to share
    // one conceptual middle anchor.
    static let highHandPoint = CGPoint(x: 290, y: 100)
    static let middleHandPoint = CGPoint(x: 289, y: 132)
    static let carryHandPoint = CGPoint(x: 298, y: 140)
    static let lowHandPoint = CGPoint(x: 290, y: 167)

    static let titleSourceCenter = CGPoint(x: 95, y: 67)
    static let backingSourceCenter = CGPoint(x: 113, y: 116)
    static let railsSourceCenter = CGPoint(x: 126, y: 111)

    // Keep the assembled trolley above the fixed 222 pt safety dock. Its
    // handle extends down to the character's low clamp rather than moving the
    // interactive dock or letting decorative artwork sit underneath it.
    static let trolleyCenter = CGPoint(x: 259, y: 150)
    static let trolleySize = CGSize(width: 74, height: 68)
    static let trolleyHandlePoint = lowHandPoint
    static let cargoBinCenter = CGPoint(x: 255, y: 143)
    static let chassisCenter = CGPoint(x: 258, y: 160)

    static let reelPoint = CGPoint(x: 350, y: 157)
    static let ribbonKnotPoint = CGPoint(x: 250, y: 118)

    static let completionCardDockPoint = CGPoint(x: 206, y: 244)
    static let completionCardPickupPoint = highHandPoint
    static let completionCardDestination = CGPoint(x: 255, y: 115)
}

/// Decorative standing-session stage shared by guided and completed states.
///
/// `snapshot` supplies the four assembled trolley parts. Passing `completion`
/// adds the finishing card placement and a single three-point load response;
/// it does not swap to a second trolley implementation.
struct StandingAssemblyView: View {
    let snapshot: StandingGuideSnapshot
    let completion: StandingCompletionSnapshot?
    let reduceMotion: Bool

    init(
        snapshot: StandingGuideSnapshot,
        completion: StandingCompletionSnapshot? = nil,
        reduceMotion: Bool
    ) {
        self.snapshot = snapshot
        self.completion = completion
        self.reduceMotion = reduceMotion
    }

    init(
        elapsed: TimeInterval,
        completionElapsed: TimeInterval? = nil,
        reduceMotion: Bool
    ) {
        snapshot = StandingGuideTimeline.snapshot(elapsed: elapsed)
        completion = completionElapsed.map(StandingCompletionTimeline.snapshot(elapsed:))
        self.reduceMotion = reduceMotion
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            standingGround

            titleSource
            backingSource
            railsSource

            ribbonExtension

            StandingTrolleyView(
                assembly: snapshot.assembly,
                reduceMotion: reduceMotion
            )
            .position(StandingStageGeometry.trolleyCenter)
            .offset(y: trolleyCompressionOffset)

            if let completion {
                completionCard(for: completion)
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

    private var standingGround: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.18),
                        HealthFirstStyle.lavender.opacity(0.38),
                        Color.primary.opacity(0.18),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 88, height: 2)
            .position(x: StandingStageGeometry.trolleyCenter.x, y: 181)
            .opacity(snapshot.assembly.chassisProgress)
    }

    private var titleSource: some View {
        standingTitleFragment
            .modifier(
                StandingFragmentTransferModifier(
                    progress: snapshot.assembly.handleProgress,
                    source: StandingStageGeometry.titleSourceCenter,
                    waypoint: StandingStageGeometry.highHandPoint,
                    destination: StandingStageGeometry.trolleyHandlePoint,
                    destinationScale: 0.31,
                    rotation: -7,
                    reduceMotion: reduceMotion
                )
            )
    }

    private var backingSource: some View {
        standingBackingFragment
            .modifier(
                StandingFragmentTransferModifier(
                    progress: snapshot.assembly.cargoBinProgress,
                    source: StandingStageGeometry.backingSourceCenter,
                    waypoint: StandingStageGeometry.carryHandPoint,
                    destination: StandingStageGeometry.cargoBinCenter,
                    destinationScale: 0.31,
                    rotation: 5,
                    reduceMotion: reduceMotion
                )
            )
    }

    private var railsSource: some View {
        StandingSourceRails()
            .stroke(
                LinearGradient(
                    colors: [
                        HealthFirstStyle.lavender.opacity(0.72),
                        Color.primary.opacity(0.34),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 1.9, lineCap: .round)
            )
            .frame(width: 226, height: 148)
            .modifier(
                StandingFragmentTransferModifier(
                    progress: snapshot.assembly.chassisProgress,
                    source: StandingStageGeometry.railsSourceCenter,
                    waypoint: StandingStageGeometry.carryHandPoint,
                    destination: StandingStageGeometry.chassisCenter,
                    destinationScale: 0.25,
                    rotation: -8,
                    reduceMotion: reduceMotion
                )
            )
    }

    private var ribbonExtension: some View {
        StandingRibbonPath(
            start: StandingStageGeometry.reelPoint,
            end: CGPoint(
                x: StandingStageGeometry.ribbonKnotPoint.x,
                y: StandingStageGeometry.ribbonKnotPoint.y + trolleyCompressionOffset
            )
        )
        .trim(
            from: 0,
            to: reduceMotion ? 1 : eased(snapshot.assembly.ribbonProgress)
        )
        .stroke(
            HealthFirstStyle.orange.opacity(0.63),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
        .opacity(
            reduceMotion
                ? eased(snapshot.assembly.ribbonProgress)
                : 1
        )
    }

    private var standingTitleFragment: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(HealthFirstStyle.lavender.opacity(0.18))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(HealthFirstStyle.lavenderDark.opacity(0.20))
                    .frame(width: 64, height: 3)
                    .padding(.leading, 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.10), lineWidth: 1)
            }
            .frame(width: 118, height: 18)
    }

    private var standingBackingFragment: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        HealthFirstStyle.lavender.opacity(0.22),
                        Color.primary.opacity(0.055),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .leading) {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(HealthFirstStyle.orange.opacity(0.48))

                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().frame(width: 108, height: 3)
                        Capsule().frame(width: 82, height: 3)
                    }
                    .foregroundStyle(Color.primary.opacity(0.18))
                }
                .padding(.leading, 16)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                HealthFirstStyle.lavender.opacity(0.42),
                                Color.primary.opacity(0.16),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .frame(width: 176, height: 52)
    }

    @ViewBuilder
    private func completionCard(for completion: StandingCompletionSnapshot) -> some View {
        let position = completionCardPosition(for: completion)
        let rotation = -7 * (1 - eased(completion.cardPlacementProgress))
        let cardOpacity = reduceMotion
            ? eased(completion.cardPlacementProgress)
            : min(1, completion.elapsed / 0.08)

        StandingCompletionCard()
            .rotationEffect(.degrees(reduceMotion ? 0 : rotation))
            .position(position)
            .offset(
                y: completion.cardIsPlaced
                    ? trolleyCompressionOffset
                    : 0
            )
            .opacity(cardOpacity)
    }

    private func completionCardPosition(
        for completion: StandingCompletionSnapshot
    ) -> CGPoint {
        guard !reduceMotion else {
            return StandingStageGeometry.completionCardDestination
        }

        if completion.cardPickupProgress < 1 {
            return interpolate(
                from: StandingStageGeometry.completionCardDockPoint,
                to: StandingStageGeometry.completionCardPickupPoint,
                progress: eased(completion.cardPickupProgress)
            )
        }

        return interpolate(
            from: StandingStageGeometry.completionCardPickupPoint,
            to: StandingStageGeometry.completionCardDestination,
            progress: eased(completion.cardPlacementProgress)
        )
    }

    private var trolleyCompressionOffset: CGFloat {
        guard !reduceMotion, let completion else { return 0 }
        return 3 * CGFloat(eased(completion.trolleyCompressionProgress))
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

    private func eased(_ value: Double) -> Double {
        let value = min(max(value, 0), 1)
        return value * value * (3 - 2 * value)
    }
}

/// One trolley implementation used before, during, and after completion.
private struct StandingTrolleyView: View {
    let assembly: StandingAssembly
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            StandingTrolleyHandle()
                .stroke(
                    HealthFirstStyle.lavender.opacity(0.66),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )
                .opacity(destinationOpacity(assembly.handleProgress))

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            HealthFirstStyle.secondarySurface.opacity(0.88),
                            HealthFirstStyle.lavender.opacity(0.22),
                            Color.primary.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    HealthFirstStyle.lavender.opacity(0.52),
                                    Color.primary.opacity(0.24),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
                .overlay(alignment: .leading) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.primary.opacity(0.18))
                            .frame(width: 13, height: 12)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(HealthFirstStyle.lavender.opacity(0.32))
                            .frame(width: 18, height: 12)
                    }
                    .padding(.leading, 9)
                }
                .frame(width: 54, height: 28)
                .position(x: 33, y: 27)
                .opacity(destinationOpacity(assembly.cargoBinProgress))

            StandingTrolleyChassis()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.58),
                            HealthFirstStyle.lavender.opacity(0.72),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .opacity(destinationOpacity(assembly.chassisProgress))

            StandingRibbonKnot()
                .stroke(
                    HealthFirstStyle.orange.opacity(0.72),
                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 19, height: 14)
                .position(x: 28, y: 2)
                .opacity(destinationOpacity(assembly.ribbonProgress))
        }
        .frame(
            width: StandingStageGeometry.trolleySize.width,
            height: StandingStageGeometry.trolleySize.height,
            alignment: .topLeading
        )
    }

    private func destinationOpacity(_ progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        if reduceMotion {
            return smoothstep(progress)
        }
        return smoothstep(min(max((progress - 0.70) / 0.30, 0), 1))
    }

    private func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

private struct StandingFragmentTransferModifier: ViewModifier {
    let progress: Double
    let source: CGPoint
    let waypoint: CGPoint
    let destination: CGPoint
    let destinationScale: Double
    let rotation: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let progress = min(max(progress, 0), 1)
        let easedProgress = smoothstep(progress)
        let position = transferPosition(progress: easedProgress)
        let travelOpacity = 1 - smoothstep(
            min(max((progress - 0.72) / 0.28, 0), 1)
        )

        content
            .scaleEffect(
                reduceMotion
                    ? 1
                    : 1 + (destinationScale - 1) * easedProgress
            )
            .rotationEffect(
                .degrees(reduceMotion ? 0 : rotation * easedProgress)
            )
            .position(reduceMotion ? source : position)
            .opacity(reduceMotion ? 1 - smoothstep(progress) : travelOpacity)
    }

    private func transferPosition(progress: Double) -> CGPoint {
        if progress < 0.58 {
            return interpolate(
                from: source,
                to: waypoint,
                progress: progress / 0.58
            )
        }

        return interpolate(
            from: waypoint,
            to: destination,
            progress: (progress - 0.58) / 0.42
        )
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

    private func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

private struct StandingCompletionCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(HealthFirstStyle.secondarySurface)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.24), lineWidth: 1)
            }
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HealthFirstStyle.orange.opacity(0.88))
            }
            .frame(width: 44, height: 27)
    }
}

private struct StandingRibbonPath: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x - 20, y: start.y - 7),
            control2: CGPoint(x: end.x + 24, y: end.y + 10)
        )
        return path
    }
}

private struct StandingSourceRails: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 3
        let cornerLength: CGFloat = 28

        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY + inset))

        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + cornerLength))

        path.move(to: CGPoint(x: rect.minX + inset, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY - inset))

        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - cornerLength))

        // A short joining rail crosses the transfer anchor. Without it the
        // four decorative corners have an empty center, so the carry pose's
        // clamp would visibly close around air at the hand waypoint.
        path.move(to: CGPoint(x: rect.midX - 20, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX + 20, y: rect.midY))
        return path
    }
}

private struct StandingTrolleyHandle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 49, y: 27))
        path.addLine(to: CGPoint(x: 61, y: 51))
        path.addLine(to: CGPoint(x: 68, y: 51))
        return path
    }
}

private struct StandingTrolleyChassis: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7, y: 44))
        path.addLine(to: CGPoint(x: 59, y: 44))
        path.addLine(to: CGPoint(x: 64, y: 49))

        path.addEllipse(in: CGRect(x: 12, y: 49, width: 10, height: 10))
        path.addEllipse(in: CGRect(x: 48, y: 49, width: 10, height: 10))
        return path
    }
}

private struct StandingRibbonKnot: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + 2),
            control1: CGPoint(x: rect.midX - 3, y: rect.midY - 4),
            control2: CGPoint(x: rect.minX + 3, y: rect.minY)
        )
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 3),
            control1: CGPoint(x: rect.midX + 3, y: rect.midY - 4),
            control2: CGPoint(x: rect.maxX - 3, y: rect.minY)
        )
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX - 5, y: rect.maxY))
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX + 6, y: rect.maxY - 1))
        return path
    }
}
