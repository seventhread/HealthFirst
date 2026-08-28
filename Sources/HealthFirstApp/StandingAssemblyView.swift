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

    // Header and safety dock share the 24 pt interaction baseline. Decorative
    // fragments step inward from it so the stage reads as an intentional
    // nested workspace rather than several cards glued to one edge.
    static let titleSourceCenter = CGPoint(x: 107, y: 68)
    static let backingSourceCenter = CGPoint(x: 124, y: 119)
    static let backingSourceSize = CGSize(width: 168, height: 52)
    static let railsSourceCenter = CGPoint(x: 126, y: 119)
    static let railsSourceSize = CGSize(width: 188, height: 136)
    static let ribbonSourceCenter = CGPoint(x: 340, y: 157)

    // Keep the assembled trolley above the fixed 222 pt safety dock. Its
    // handle extends down to the character's low clamp rather than moving the
    // interactive dock or letting decorative artwork sit underneath it.
    static let trolleyCenter = CGPoint(x: 259, y: 150)
    static let trolleySize = CGSize(width: 74, height: 68)
    static let baseDestinationCenter = CGPoint(x: 251, y: 159)
    static let cargoBinCenter = CGPoint(x: 255, y: 143)
    static let chassisCenter = CGPoint(x: 258, y: 160)

    static let reelPoint = CGPoint(x: 350, y: 157)
    static let ribbonKnotPoint = CGPoint(x: 250, y: 118)

    // Completion begins with a visual replica of the live 222 pt safety dock.
    // The clamp meets its right edge, then keeps that exact edge attached as
    // the dock folds into a small trolley card.
    static let completionDockCenter = CGPoint(x: 135, y: 232)
    static let completionDockGrabPoint = CGPoint(x: 246, y: 232)
    static let completionDockDestinationGrabPoint = CGPoint(x: 282, y: 143)
    static let completionCardDestination = CGPoint(x: 255, y: 115)

    // Only after the dock has settled does the hand take the lower edge of the
    // large background. Its source offset from the 420 x 280 card centre is
    // (36, 128), which remains under the clamp throughout non-uniform folding.
    static let completionBackdropGrabPoint = CGPoint(x: 246, y: 268)
    static let completionBackdropDestinationGrabPoint = CGPoint(x: 282, y: 143)
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
            ribbonSource

            StandingTrolleyView(
                assembly: snapshot.assembly,
                reduceMotion: reduceMotion
            )
            .position(StandingStageGeometry.trolleyCenter)
            .offset(y: trolleyCompressionOffset)
            .zIndex(1)

            if let completion {
                completionDock(for: completion)
                packedCompletionCard(for: completion)
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
            .opacity(
                standingPlacementOpacity(
                    snapshot.assembly.chassisProgress
                )
            )
    }

    private var titleSource: some View {
        standingTitleFragment
            .modifier(
                StandingFragmentTransferModifier(
                    progress: snapshot.assembly.baseProgress,
                    sourceCenter: StandingStageGeometry.titleSourceCenter,
                    sourceGripPoint: StandingCollectionGeometry.sourceGrabPoint(
                        for: .title
                    ),
                    destinationCenter: StandingStageGeometry.baseDestinationCenter,
                    destinationGripPoint: StandingCollectionGeometry.destinationGrabPoint(
                        for: .title
                    ),
                    destinationScale: 44.0 / 118.0,
                    reduceMotion: reduceMotion
                )
            )
            .zIndex(2)
    }

    private var backingSource: some View {
        standingBackingFragment
            .modifier(
                StandingFragmentTransferModifier(
                    progress: snapshot.assembly.cargoBinProgress,
                    sourceCenter: StandingStageGeometry.backingSourceCenter,
                    sourceGripPoint: StandingCollectionGeometry.sourceGrabPoint(
                        for: .backing
                    ),
                    destinationCenter: StandingStageGeometry.cargoBinCenter,
                    destinationGripPoint: StandingCollectionGeometry.destinationGrabPoint(
                        for: .backing
                    ),
                    destinationScale: 27.0 / 84.0,
                    reduceMotion: reduceMotion
                )
            )
            .zIndex(2)
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
            .frame(
                width: StandingStageGeometry.railsSourceSize.width,
                height: StandingStageGeometry.railsSourceSize.height
            )
            .modifier(
                StandingFragmentTransferModifier(
                    progress: snapshot.assembly.chassisProgress,
                    sourceCenter: StandingStageGeometry.railsSourceCenter,
                    sourceGripPoint: StandingCollectionGeometry.sourceGrabPoint(
                        for: .rails
                    ),
                    destinationCenter: StandingStageGeometry.chassisCenter,
                    destinationGripPoint: StandingCollectionGeometry.destinationGrabPoint(
                        for: .rails
                    ),
                    destinationScale: 32.0 / 94.0,
                    reduceMotion: reduceMotion
                )
            )
            .zIndex(2)
    }

    private var ribbonSource: some View {
        Capsule()
            .fill(HealthFirstStyle.orange.opacity(0.94))
            .frame(width: 28, height: 5)
            .modifier(
                StandingFragmentTransferModifier(
                    progress: snapshot.assembly.ribbonProgress,
                    sourceCenter: StandingStageGeometry.ribbonSourceCenter,
                    sourceGripPoint: StandingCollectionGeometry.sourceGrabPoint(
                        for: .ribbon
                    ),
                    destinationCenter: StandingStageGeometry.ribbonKnotPoint,
                    destinationGripPoint: StandingCollectionGeometry.destinationGrabPoint(
                        for: .ribbon
                    ),
                    destinationScale: 0.68,
                    reduceMotion: reduceMotion
                )
            )
            .zIndex(2)
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
            .frame(
                width: StandingStageGeometry.backingSourceSize.width,
                height: StandingStageGeometry.backingSourceSize.height
            )
    }

    private func completionDock(for completion: StandingCompletionSnapshot) -> some View {
        let pack = completion.dock
        let travel = eased(pack.transferProgress)
        let fold = standingSmoothedPhase(
            pack.transferProgress,
            from: 0.42,
            to: 1
        )
        let scaleX = interpolate(from: 1, to: 0.16, progress: fold)
        let scaleY = interpolate(from: 1, to: 0.38, progress: fold)
        let grip = interpolate(
            from: StandingStageGeometry.completionDockGrabPoint,
            to: StandingStageGeometry.completionDockDestinationGrabPoint,
            progress: travel
        )
        let sourceGripOffset = CGPoint(
            x: StandingStageGeometry.completionDockGrabPoint.x
                - StandingStageGeometry.completionDockCenter.x,
            y: StandingStageGeometry.completionDockGrabPoint.y
                - StandingStageGeometry.completionDockCenter.y
        )
        let position = CGPoint(
            x: grip.x - sourceGripOffset.x * scaleX,
            y: grip.y - sourceGripOffset.y * scaleY
        )

        return StandingCompletionDock()
            .scaleEffect(
                x: reduceMotion ? 0.16 : scaleX,
                y: reduceMotion ? 0.38 : scaleY
            )
            .rotationEffect(.degrees(reduceMotion ? 0 : 7 * fold))
            .position(position)
            .opacity(
                reduceMotion
                    ? 0
                    : 1 - eased(pack.placementProgress)
            )
            .zIndex(2)
    }

    private func packedCompletionCard(
        for completion: StandingCompletionSnapshot
    ) -> some View {
        StandingCompletionCard()
            .position(StandingStageGeometry.completionCardDestination)
            .offset(y: trolleyCompressionOffset)
            .opacity(
                reduceMotion
                    ? 1
                    : eased(completion.dock.placementProgress)
            )
            .zIndex(2)
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

    private func interpolate(
        from start: Double,
        to end: Double,
        progress: Double
    ) -> CGFloat {
        CGFloat(start + (end - start) * min(max(progress, 0), 1))
    }

    private func eased(_ value: Double) -> Double {
        let value = min(max(value, 0), 1)
        return value * value * (3 - 2 * value)
    }
}

/// The completion card material is a real animated stage prop shared by the
/// live reminder and Motion Lab. It begins at the guide's exact last opacity,
/// then stays still until the countdown dock has already been stored.
struct StandingCompletionBackdropView: View {
    let completion: StandingCompletionSnapshot
    let chromeOpacity: Double
    let reduceMotion: Bool

    var body: some View {
        Color.clear
            .frame(
                width: StandingStageGeometry.size.width,
                height: StandingStageGeometry.size.height
            )
            .healthFirstCard(chromeOpacity: chromeOpacity)
            .modifier(
                StandingBackdropPackModifier(
                    pack: completion.backdrop,
                    reduceMotion: reduceMotion
                )
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Treats the 420 x 280 material as a foldable map. Two non-overlapping folds
/// preserve its lower-edge grip point while it travels into the trolley.
private struct StandingBackdropPackModifier: ViewModifier {
    let pack: StandingPackProgress
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let transfer = eased(pack.transferProgress)
        let firstFold = smoothedPhase(
            pack.transferProgress,
            from: 0.08,
            to: 0.52
        )
        let secondFold = smoothedPhase(
            pack.transferProgress,
            from: 0.48,
            to: 0.92
        )
        let scaleX = 1 - 0.88 * secondFold
        let scaleY = 1 - 0.64 * firstFold - 0.28 * secondFold
        let grip = interpolate(
            from: StandingStageGeometry.completionBackdropGrabPoint,
            to: StandingStageGeometry.completionBackdropDestinationGrabPoint,
            progress: transfer
        )
        let sourceCenter = CGPoint(
            x: StandingStageGeometry.size.width / 2,
            y: StandingStageGeometry.size.height / 2
        )
        let sourceGripOffset = CGPoint(
            x: StandingStageGeometry.completionBackdropGrabPoint.x
                - sourceCenter.x,
            y: StandingStageGeometry.completionBackdropGrabPoint.y
                - sourceCenter.y
        )
        let position = CGPoint(
            x: grip.x - sourceGripOffset.x * scaleX,
            y: grip.y - sourceGripOffset.y * scaleY
        )

        content
            .scaleEffect(
                x: reduceMotion ? 0.12 : scaleX,
                y: reduceMotion ? 0.08 : scaleY
            )
            .rotationEffect(
                .degrees(reduceMotion ? 0 : -6 * secondFold)
            )
            .position(position)
            .opacity(
                reduceMotion
                    ? 0
                    : 1 - eased(pack.placementProgress)
            )
    }

    private func smoothedPhase(
        _ value: Double,
        from start: Double,
        to end: Double
    ) -> Double {
        guard end > start else { return value >= end ? 1 : 0 }
        return eased(min(max((value - start) / (end - start), 0), 1))
    }

    private func eased(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
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

/// One trolley implementation used before, during, and after completion.
private struct StandingTrolleyView: View {
    let assembly: StandingAssembly
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            HealthFirstStyle.lavender.opacity(0.72),
                            Color.primary.opacity(0.34),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Capsule()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                }
                .frame(width: 44, height: 6)
                .position(x: 29, y: 43)
                .opacity(destinationOpacity(assembly.baseProgress))

            StandingTrolleyHandle()
                .stroke(
                    LinearGradient(
                        colors: [
                            HealthFirstStyle.lavender.opacity(0.94),
                            Color.primary.opacity(0.72),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3.7, lineCap: .round, lineJoin: .round)
                )
                .opacity(destinationOpacity(assembly.chassisProgress))

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(HealthFirstStyle.secondarySurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    HealthFirstStyle.lavender.opacity(0.42),
                                    HealthFirstStyle.lavender.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    HealthFirstStyle.lavender.opacity(0.76),
                                    Color.primary.opacity(0.40),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .overlay(alignment: .leading) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.primary.opacity(0.28))
                            .frame(width: 13, height: 12)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(HealthFirstStyle.lavender.opacity(0.48))
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
                            Color.primary.opacity(0.80),
                            HealthFirstStyle.lavender.opacity(0.92),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round)
                )
                .opacity(destinationOpacity(assembly.chassisProgress))

            StandingRibbonKnot()
                .stroke(
                    HealthFirstStyle.orange.opacity(0.92),
                    style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round)
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
        standingPlacementOpacity(progress)
    }
}

private struct StandingFragmentTransferModifier: ViewModifier {
    let progress: Double
    let sourceCenter: CGPoint
    let sourceGripPoint: CGPoint
    let destinationCenter: CGPoint
    let destinationGripPoint: CGPoint
    let destinationScale: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let progress = min(max(progress, 0), 1)
        let pull = standingSmoothedPhase(
            progress,
            from: StandingCollectionTiming.gripEnd,
            to: StandingCollectionTiming.pullEnd
        )
        let gripPosition = interpolate(
            from: sourceGripPoint,
            to: destinationGripPoint,
            progress: pull
        )
        let scale = interpolate(
            from: 1,
            to: destinationScale,
            // Keep the grabbed component recognizable during the pull. It
            // folds down only beside the trolley instead of shrinking under
            // the clamp as soon as the hand starts moving.
            progress: standingSmoothedPhase(
                progress,
                from: 0.60,
                to: StandingCollectionTiming.pullEnd
            )
        )
        let sourceGripOffset = CGPoint(
            x: sourceGripPoint.x - sourceCenter.x,
            y: sourceGripPoint.y - sourceCenter.y
        )
        // SwiftUI scales the fragment around its centre. Derive its rendered
        // grip offset from that exact scale so the visible edge remains under
        // the clamp even while the fragment folds down near the trolley.
        let renderedGripOffset = CGPoint(
            x: sourceGripOffset.x * scale,
            y: sourceGripOffset.y * scale
        )
        let position = CGPoint(
            x: gripPosition.x - renderedGripOffset.x,
            y: gripPosition.y - renderedGripOffset.y
        )

        content
            .scaleEffect(reduceMotion ? 1 : scale)
            .position(reduceMotion ? sourceCenter : position)
            .opacity(1 - standingPlacementOpacity(progress))
            .accessibilityHidden(true)
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

    private func interpolate(
        from start: Double,
        to end: Double,
        progress: Double
    ) -> CGFloat {
        CGFloat(start + (end - start) * progress)
    }
}

private func standingPlacementOpacity(_ progress: Double) -> Double {
    standingSmoothedPhase(
        progress,
        from: StandingCollectionTiming.pullEnd,
        to: StandingCollectionTiming.placeEnd
    )
}

private func standingSmoothedPhase(
    _ value: Double,
    from start: Double,
    to end: Double
) -> Double {
    guard end > start else { return value >= end ? 1 : 0 }
    let phase = min(max((value - start) / (end - start), 0), 1)
    return phase * phase * (3 - 2 * phase)
}

/// Non-interactive last frame of the real standing safety dock. It occupies
/// the same 222 pt footprint and shows the zero-second state, so rebuilding
/// the hosting view at the completion boundary does not swap in a fake prop.
private struct StandingCompletionDock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ProgressView(value: 1)
                .tint(HealthFirstStyle.orange)

            HStack(spacing: 8) {
                Text("还剩 0 秒")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Spacer(minLength: 4)
                Text("先到这里")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 222)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HealthFirstStyle.secondarySurface.opacity(0.94))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

private struct StandingSourceRails: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect.insetBy(dx: 1, dy: 1),
            cornerSize: CGSize(width: 9, height: 9)
        )

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
