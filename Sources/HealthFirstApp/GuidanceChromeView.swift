import HealthFirstCore
import SwiftUI

/// A progress-driven decorative layer for the guided reminder card.
///
/// This view intentionally owns no timers, gestures, copy, or safety actions.
/// Put it behind the card's interactive content. The caller remains responsible
/// for the visible progress and the early-end action.
struct GuidanceChromeView: View {
    let kind: ReminderKind
    let progress: Double
    let guideDuration: TimeInterval
    let reduceMotion: Bool

    init(
        kind: ReminderKind,
        progress: Double,
        guideDuration: TimeInterval? = nil,
        reduceMotion: Bool
    ) {
        self.kind = kind
        self.progress = progress
        self.guideDuration = guideDuration ?? kind.guideDuration
        self.reduceMotion = reduceMotion
    }

    var body: some View {
        ZStack {
            switch kind {
            case .eye:
                eyeChrome
            case .standing:
                standingChrome
            case .quietPractice:
                quietPracticeChrome
            }
        }
        .frame(width: 420, height: 280)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Eye rest

    /// Once the mascot has stored the start card, the abstract title and body
    /// sheets roll toward the card edge. They never stand in for real,
    /// readable content.
    private var eyeChrome: some View {
        let handoff = timedPhase(
            startSeconds: 0.56,
            endSeconds: 1.10,
            totalSeconds: guideDuration
        )
        let settled = eased(handoff)

        return ZStack {
            eyeTitleStrip
                .modifier(
                    EyePaperHandoffModifier(
                        completion: settled,
                        destination: CGSize(width: 122, height: -55),
                        rotation: 10,
                        reduceMotion: reduceMotion
                    )
                )
                .offset(x: 34, y: -58)

            eyeBodySheet
                .modifier(
                    EyePaperHandoffModifier(
                        completion: settled,
                        destination: CGSize(width: 105, height: -28),
                        rotation: -8,
                        reduceMotion: reduceMotion
                    )
                )
                .offset(x: 35, y: -14)

            eyeDistantTag
                .offset(
                    x: reduceMotion ? 34 : 155,
                    y: reduceMotion ? -28 : -99
                )
                .scaleEffect(reduceMotion ? 1 : 0.88 + 0.12 * settled)
                .opacity(settled)
        }
    }

    private var eyeTitleStrip: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(HealthFirstStyle.lavender.opacity(0.18))
            .overlay {
                HStack(spacing: 5) {
                    Circle()
                        .fill(HealthFirstStyle.orange.opacity(0.52))
                        .frame(width: 5, height: 5)
                    Capsule()
                        .fill(HealthFirstStyle.lavenderDark.opacity(0.24))
                        .frame(width: 62, height: 3)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.1))
            }
            .frame(width: 126, height: 17)
    }

    private var eyeBodySheet: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(HealthFirstStyle.secondarySurface.opacity(0.34))
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().frame(width: 132, height: 3)
                    Capsule().frame(width: 104, height: 3)
                    Capsule().frame(width: 119, height: 3)
                }
                .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.13))
                .padding(.leading, 16)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.09))
            }
            .frame(width: 170, height: 51)
    }

    private var eyeDistantTag: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        HealthFirstStyle.lavenderDark.opacity(0.22),
                        lineWidth: 1
                    )
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(HealthFirstStyle.orange.opacity(0.72))
                    .frame(width: 4, height: 4)
            }

            HStack(alignment: .bottom, spacing: 2) {
                ChromeTriangle()
                    .fill(HealthFirstStyle.lavender.opacity(0.22))
                    .frame(width: 11, height: 7)
                ChromeTriangle()
                    .fill(HealthFirstStyle.lavenderDark.opacity(0.13))
                    .frame(width: 15, height: 10)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(HealthFirstStyle.lavender.opacity(0.12))
                .overlay {
                    Capsule()
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.1))
                }
        )
    }

    // MARK: - Standing

    /// Four familiar card fragments are put away only at their milestones.
    /// Their settled counterparts build a small trolley in the lower-right
    /// corner; nothing moves between milestones.
    private var standingChrome: some View {
        let title = milestonePhase(
            atSeconds: 8,
            totalSeconds: guideDuration
        )
        let backing = milestonePhase(
            atSeconds: 22,
            totalSeconds: guideDuration
        )
        let rails = milestonePhase(
            atSeconds: 38,
            totalSeconds: guideDuration
        )
        let ribbon = milestonePhase(
            atSeconds: 52,
            totalSeconds: guideDuration
        )

        return ZStack {
            standingSourceTitle(completion: title)
            standingSourceBacking(completion: backing)
            standingSourceRails(completion: rails)
            standingSourceRibbon(completion: ribbon)

            standingTrolley(
                titleCompletion: title,
                backingCompletion: backing,
                railsCompletion: rails,
                ribbonCompletion: ribbon
            )
            .offset(x: 155, y: 96)
        }
    }

    private func standingSourceTitle(completion: Double) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(HealthFirstStyle.lavender.opacity(0.18))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(HealthFirstStyle.lavenderDark.opacity(0.2))
                    .frame(width: 64, height: 3)
                    .padding(.leading, 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.1))
            }
            .frame(width: 118, height: 18)
            .modifier(
                ChromeTransferModifier(
                    completion: eased(completion),
                    destination: CGSize(width: 127, height: 169),
                    scale: 0.29,
                    rotation: -7,
                    reduceMotion: reduceMotion
                )
            )
            .offset(x: 27, y: -73)
    }

    private func standingSourceBacking(completion: Double) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(HealthFirstStyle.secondarySurface.opacity(0.29))
            .overlay(alignment: .leading) {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(HealthFirstStyle.orange.opacity(0.48))
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().frame(width: 108, height: 3)
                        Capsule().frame(width: 82, height: 3)
                    }
                    .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.12))
                }
                .padding(.leading, 16)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.08))
            }
            .frame(width: 176, height: 52)
            .modifier(
                ChromeTransferModifier(
                    completion: eased(completion),
                    destination: CGSize(width: 115, height: 119),
                    scale: 0.25,
                    rotation: 8,
                    reduceMotion: reduceMotion
                )
            )
            .offset(x: 37, y: -22)
    }

    private func standingSourceRails(completion: Double) -> some View {
        ChromeCardRails()
            .stroke(
                HealthFirstStyle.lavenderDark.opacity(0.12),
                style: StrokeStyle(lineWidth: 1.3, lineCap: .round)
            )
            .frame(width: 226, height: 148)
            .modifier(
                ChromeTransferModifier(
                    completion: eased(completion),
                    destination: CGSize(width: 93, height: 101),
                    scale: 0.23,
                    rotation: -9,
                    reduceMotion: reduceMotion
                )
            )
            .offset(x: 41, y: -10)
    }

    private func standingSourceRibbon(completion: Double) -> some View {
        HStack(spacing: 4) {
            Capsule()
                .fill(HealthFirstStyle.orange.opacity(0.36))
                .frame(width: 72, height: 4)
            Circle()
                .stroke(HealthFirstStyle.orange.opacity(0.42), lineWidth: 2)
                .frame(width: 12, height: 12)
        }
        .modifier(
            ChromeTransferModifier(
                completion: eased(completion),
                destination: CGSize(width: 79, height: 25),
                scale: 0.42,
                rotation: 16,
                reduceMotion: reduceMotion
            )
        )
        .offset(x: 55, y: 76)
    }

    private func standingTrolley(
        titleCompletion: Double,
        backingCompletion: Double,
        railsCompletion: Double,
        ribbonCompletion: Double
    ) -> some View {
        ZStack {
            // The first title strip becomes the trolley's quiet base.
            Capsule()
                .fill(HealthFirstStyle.lavender.opacity(0.42))
                .frame(width: 42, height: 5)
                .offset(y: 13)
                .opacity(eased(titleCompletion))

            // The read backing settles into the basket.
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(HealthFirstStyle.secondarySurface.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.16))
                }
                .frame(width: 32, height: 21)
                .rotationEffect(.degrees(-5))
                .offset(x: -1, y: -2)
                .opacity(eased(backingCompletion))

            // Rails become the frame, handle, and wheels.
            ChromeTrolleyFrame()
                .stroke(
                    HealthFirstStyle.lavenderDark.opacity(0.52),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 58, height: 45)
                .opacity(eased(railsCompletion))

            // The measuring ribbon is tied to the trolley handle last.
            ChromeRibbonKnot()
                .stroke(
                    HealthFirstStyle.orange.opacity(0.72),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 24, height: 17)
                .offset(x: 24, y: -20)
                .opacity(eased(ribbonCompletion))
        }
        .frame(width: 64, height: 54)
    }

    // MARK: - Quiet practice

    /// A blank backing folds once into an unlabelled envelope after the
    /// mascot has stored the start card, then remains completely still.
    private var quietPracticeChrome: some View {
        let firstFold = timedPhase(
            startSeconds: 0.56,
            endSeconds: 0.90,
            totalSeconds: guideDuration
        )
        let secondFold = timedPhase(
            startSeconds: 0.80,
            endSeconds: 1.20,
            totalSeconds: guideDuration
        )
        let sealed = timedPhase(
            startSeconds: 1.12,
            endSeconds: 1.46,
            totalSeconds: guideDuration
        )

        return ZStack {
            quietBackingPanel(
                firstFold: firstFold,
                secondFold: secondFold,
                sealed: sealed
            )

            quietEnvelope
                .scaleEffect(
                    reduceMotion ? 1 : 0.82 + 0.18 * eased(sealed)
                )
                .offset(
                    x: reduceMotion ? 34 : 150,
                    y: reduceMotion ? 2 : 80
                )
                .opacity(eased(sealed))
        }
    }

    private func quietBackingPanel(
        firstFold: Double,
        secondFold: Double,
        sealed: Double
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(HealthFirstStyle.secondarySurface.opacity(0.3))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.09))
                }

            VStack(spacing: 0) {
                Rectangle()
                    .fill(HealthFirstStyle.lavender.opacity(0.13))
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : 76 * eased(firstFold)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.34
                    )
                Rectangle()
                    .fill(HealthFirstStyle.lavender.opacity(0.08))
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : -76 * eased(secondFold)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.34
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .frame(width: 182, height: 74)
        .scaleEffect(
            x: reduceMotion ? 1 : 1 - 0.54 * eased(secondFold),
            y: reduceMotion ? 1 : 1 - 0.48 * eased(firstFold)
        )
        .rotationEffect(.degrees(reduceMotion ? 0 : 5 * eased(secondFold)))
        .offset(
            x: reduceMotion ? 34 : 34 + 116 * eased(sealed),
            y: reduceMotion ? 2 : 2 + 78 * eased(sealed)
        )
        .opacity(1 - eased(sealed))
    }

    private var quietEnvelope: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(HealthFirstStyle.lavender.opacity(0.23))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.22))
                }

            ChromeEnvelopeFlap()
                .stroke(
                    HealthFirstStyle.lavenderDark.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )

            Circle()
                .fill(HealthFirstStyle.lavenderDark.opacity(0.42))
                .frame(width: 5, height: 5)
                .offset(y: 2)
        }
        .frame(width: 52, height: 35)
    }

    // MARK: - Progress helpers

    private var normalizedProgress: Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    private func milestonePhase(
        atSeconds seconds: Double,
        totalSeconds: Double
    ) -> Double {
        timedPhase(
            startSeconds: seconds,
            endSeconds: seconds + StandingBeat.duration,
            totalSeconds: totalSeconds
        )
    }

    private func timedPhase(
        startSeconds: Double,
        endSeconds: Double,
        totalSeconds: Double
    ) -> Double {
        guard totalSeconds > 0, endSeconds > startSeconds else { return 1 }
        let start = startSeconds / totalSeconds
        let end = endSeconds / totalSeconds
        return min(max((normalizedProgress - start) / (end - start), 0), 1)
    }

    private func eased(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

private struct EyePaperHandoffModifier: ViewModifier {
    let completion: Double
    let destination: CGSize
    let rotation: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                reduceMotion ? 1 : 1 - 0.74 * completion,
                anchor: .trailing
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : 74 * completion),
                axis: (x: 0, y: 1, z: 0),
                anchor: .trailing,
                perspective: reduceMotion ? 0 : 0.34
            )
            .rotationEffect(.degrees(reduceMotion ? 0 : rotation * completion))
            .offset(
                x: reduceMotion ? 0 : destination.width * completion,
                y: reduceMotion ? 0 : destination.height * completion
            )
            .opacity(1 - completion)
    }
}

private struct ChromeTransferModifier: ViewModifier {
    let completion: Double
    let destination: CGSize
    let scale: Double
    let rotation: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : 1 + (scale - 1) * completion)
            .rotationEffect(.degrees(reduceMotion ? 0 : rotation * completion))
            .offset(
                x: reduceMotion ? 0 : destination.width * completion,
                y: reduceMotion ? 0 : destination.height * completion
            )
            .opacity(1 - completion)
    }
}

private struct ChromeTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ChromeCardRails: Shape {
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
        return path
    }
}

private struct ChromeTrolleyFrame: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + 5, y: rect.minY + 5))
        path.addLine(to: CGPoint(x: rect.minX + 13, y: rect.minY + 5))
        path.addLine(to: CGPoint(x: rect.minX + 19, y: rect.maxY - 12))
        path.addLine(to: CGPoint(x: rect.maxX - 7, y: rect.maxY - 12))

        path.move(to: CGPoint(x: rect.minX + 16, y: rect.minY + 13))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 13))
        path.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.maxY - 17))
        path.addLine(to: CGPoint(x: rect.minX + 19, y: rect.maxY - 17))

        path.addEllipse(
            in: CGRect(
                x: rect.minX + 20,
                y: rect.maxY - 9,
                width: 6,
                height: 6
            )
        )
        path.addEllipse(
            in: CGRect(
                x: rect.maxX - 17,
                y: rect.maxY - 9,
                width: 6,
                height: 6
            )
        )
        return path
    }
}

private struct ChromeRibbonKnot: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        path.move(to: center)
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 2, y: rect.minY + 3),
            control: CGPoint(x: rect.minX + 2, y: rect.midY)
        )
        path.addQuadCurve(
            to: center,
            control: CGPoint(x: rect.midX - 3, y: rect.minY)
        )

        path.move(to: center)
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.minY + 3),
            control: CGPoint(x: rect.maxX - 2, y: rect.midY)
        )
        path.addQuadCurve(
            to: center,
            control: CGPoint(x: rect.midX + 3, y: rect.minY)
        )

        path.move(to: center)
        path.addLine(to: CGPoint(x: rect.midX - 4, y: rect.maxY - 1))
        path.move(to: center)
        path.addLine(to: CGPoint(x: rect.midX + 5, y: rect.maxY - 2))
        return path
    }
}

private struct ChromeEnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 2))

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.midX - 8, y: rect.midY + 3))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.midX + 8, y: rect.midY + 3))
        return path
    }
}
