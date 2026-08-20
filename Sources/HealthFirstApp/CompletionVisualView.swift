import HealthFirstCore
import SwiftUI

/// A small, one-shot finishing ritual for a completed guided reminder.
///
/// The caller owns time and supplies `progress`. This view intentionally has
/// no timers, gestures, or looping animation, and always occupies the same
/// amount of space as `GuidanceVisualView`.
struct CompletionVisualView: View {
    let kind: ReminderKind
    let progress: Double
    let reduceMotion: Bool

    init(kind: ReminderKind, progress: Double, reduceMotion: Bool) {
        self.kind = kind
        self.progress = progress
        self.reduceMotion = reduceMotion
    }

    var body: some View {
        Group {
            if reduceMotion {
                ZStack {
                    visual(for: kind, at: 0)
                        .opacity(1 - reducedMotionCrossfade)

                    visual(for: kind, at: 1)
                        .opacity(reducedMotionCrossfade)
                }
            } else {
                visual(for: kind, at: normalizedProgress)
            }
        }
        .frame(width: 276, height: 82)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func visual(for kind: ReminderKind, at completion: Double) -> some View {
        switch kind {
        case .eye:
            eyeRollVisual(at: completion)
        case .standing:
            standingCartVisual(at: completion)
        case .quietPractice:
            quietEnvelopeVisual(at: completion)
        }
    }

    // MARK: - Eye rest

    /// The eye-rest mat is rolled from both ends, tied, then receives one
    /// quiet check. The check does not burst, bounce, or repeat.
    private func eyeRollVisual(at completion: Double) -> some View {
        let roll = eased(phase(from: 0, to: 0.56, value: completion))
        let tie = eased(phase(from: 0.38, to: 0.78, value: completion))
        let check = eased(phase(from: 0.72, to: 1, value: completion))
        let matWidth = 122 - 45 * roll

        return ZStack {
            Capsule()
                .fill(HealthFirstStyle.lavenderDark.opacity(0.09))
                .frame(width: 154, height: 2)
                .offset(y: 25)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HealthFirstStyle.lavender.opacity(0.25))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.24), lineWidth: 1)
                }
                .overlay {
                    HStack(spacing: 5) {
                        Capsule().frame(width: 24, height: 2)
                        Circle().frame(width: 3, height: 3)
                        Capsule().frame(width: 16, height: 2)
                    }
                    .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.22 * (1 - roll)))
                }
                .frame(width: matWidth, height: 34 - 5 * roll)
                .offset(y: 3 * roll)

            rollEnd
                .offset(x: -48 + 10 * roll, y: 3 * roll)
                .opacity(0.12 + 0.88 * roll)

            rollEnd
                .offset(x: 48 - 10 * roll, y: 3 * roll)
                .opacity(0.12 + 0.88 * roll)

            VStack(spacing: -1) {
                Capsule()
                    .fill(HealthFirstStyle.orange.opacity(0.72))
                    .frame(width: 12, height: 31)

                HStack(spacing: 4) {
                    Capsule()
                        .frame(width: 12, height: 3)
                        .rotationEffect(.degrees(28))
                    Capsule()
                        .frame(width: 12, height: 3)
                        .rotationEffect(.degrees(-28))
                }
                .foregroundStyle(HealthFirstStyle.orange.opacity(0.66))
            }
            .scaleEffect(x: 1, y: 0.72 + 0.28 * tie, anchor: .top)
            .opacity(tie)
            .offset(y: 4)

            ZStack {
                Circle()
                    .fill(HealthFirstStyle.secondarySurface)
                Circle()
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.18), lineWidth: 1)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(HealthFirstStyle.orange)
            }
            .frame(width: 23, height: 23)
            .scaleEffect(0.82 + 0.18 * check)
            .opacity(check)
            .offset(x: 55, y: -19)
        }
    }

    private var rollEnd: some View {
        ZStack {
            Circle()
                .fill(HealthFirstStyle.lavender.opacity(0.34))
            Circle()
                .stroke(HealthFirstStyle.lavenderDark.opacity(0.28), lineWidth: 1)
            Circle()
                .stroke(HealthFirstStyle.lavenderDark.opacity(0.18), lineWidth: 1)
                .frame(width: 13, height: 13)
        }
        .frame(width: 27, height: 27)
    }

    // MARK: - Standing

    /// A finished UI card is placed on a small trolley. Only the trolley body
    /// compresses, by three points, before returning to its resting position.
    private func standingCartVisual(at completion: Double) -> some View {
        let placement = eased(phase(from: 0, to: 0.58, value: completion))
        let settle = trolleyCompression(at: completion)
        let steady = eased(phase(from: 0.74, to: 1, value: completion))

        return ZStack {
            Capsule()
                .fill(HealthFirstStyle.lavenderDark.opacity(0.1))
                .frame(width: 190, height: 2)
                .offset(y: 33)

            trolleyBody
                .offset(y: settle)

            completionCard
                .rotationEffect(.degrees(-7 * (1 - placement)))
                .offset(
                    x: -10 * (1 - placement),
                    y: -53 + 35 * placement + settle
                )

            Capsule()
                .fill(HealthFirstStyle.orange.opacity(0.56))
                .frame(width: 18, height: 3)
                .rotationEffect(.degrees(-34 + 34 * steady), anchor: .leading)
                .offset(x: 75, y: -3 + settle)
                .opacity(steady)
        }
    }

    private var trolleyBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(HealthFirstStyle.lavender.opacity(0.23))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.24), lineWidth: 1)
                }
                .frame(width: 132, height: 34)
                .overlay(alignment: .leading) {
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(HealthFirstStyle.lavenderDark.opacity(0.15))
                            .frame(width: 25, height: 16)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(HealthFirstStyle.lavenderDark.opacity(0.10))
                            .frame(width: 34, height: 16)
                    }
                    .padding(.leading, 17)
                }

            HStack(spacing: 80) {
                Circle()
                Circle()
            }
            .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.46))
            .frame(height: 10)
            .offset(y: 21)

            Path { path in
                path.move(to: CGPoint(x: 64, y: 5))
                path.addLine(to: CGPoint(x: 73, y: -17))
                path.addLine(to: CGPoint(x: 91, y: -17))
            }
            .stroke(
                HealthFirstStyle.lavenderDark.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 182, height: 50)
        }
        .offset(y: 8)
    }

    private var completionCard: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(HealthFirstStyle.secondarySurface)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.24), lineWidth: 1)
            }
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(HealthFirstStyle.orange.opacity(0.88))
            }
            .frame(width: 48, height: 29)
    }

    /// A triangular, non-oscillating three-point compression.
    private func trolleyCompression(at completion: Double) -> Double {
        if completion <= 0.52 || completion >= 0.78 {
            return 0
        }

        if completion <= 0.64 {
            return 3 * phase(from: 0.52, to: 0.64, value: completion)
        }

        return 3 * (1 - phase(from: 0.64, to: 0.78, value: completion))
    }

    // MARK: - Quiet practice

    /// The private-practice envelope closes and gains a subtle, wordless
    /// imprint. Nothing pulses and the sealed result remains still.
    private func quietEnvelopeVisual(at completion: Double) -> some View {
        let tuck = eased(phase(from: 0, to: 0.34, value: completion))
        let close = eased(phase(from: 0.22, to: 0.72, value: completion))
        let imprint = eased(phase(from: 0.68, to: 1, value: completion))

        return ZStack {
            Capsule()
                .fill(HealthFirstStyle.lavenderDark.opacity(0.09))
                .frame(width: 154, height: 2)
                .offset(y: 29)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(HealthFirstStyle.lavender.opacity(0.14))
                .frame(width: 68, height: 32)
                .overlay {
                    VStack(spacing: 4) {
                        Capsule().frame(width: 35, height: 2)
                        Capsule().frame(width: 25, height: 2)
                    }
                    .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.15))
                }
                .offset(y: -18 + 19 * tuck)

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(HealthFirstStyle.lavender.opacity(0.24))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.24), lineWidth: 1)
                }
                .frame(width: 112, height: 48)
                .offset(y: 5)

            CompletionEnvelopeSideFolds()
                .fill(HealthFirstStyle.lavender.opacity(0.20))
                .frame(width: 110, height: 46)
                .offset(y: 5)

            CompletionEnvelopeFlap(closedness: close)
                .fill(HealthFirstStyle.lavender.opacity(0.36))
                .overlay {
                    CompletionEnvelopeFlap(closedness: close)
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.2), lineWidth: 1)
                }
                .frame(width: 110, height: 50)
                .offset(y: -13)

            CompletionQuietImprint()
                .stroke(
                    HealthFirstStyle.lavenderDark.opacity(0.52),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 17, height: 17)
                .scaleEffect(0.9 + 0.1 * imprint)
                .opacity(imprint)
                .offset(y: 11)
        }
    }

    // MARK: - Progress helpers

    private var normalizedProgress: Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    private var reducedMotionCrossfade: Double {
        eased(phase(from: 0.12, to: 0.7, value: normalizedProgress))
    }

    private func phase(from start: Double, to end: Double, value: Double) -> Double {
        guard end > start else { return value >= end ? 1 : 0 }
        return min(max((value - start) / (end - start), 0), 1)
    }

    private func eased(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

/// The envelope flap changes its tip rather than rotating in 3D, keeping the
/// paper-like gesture legible at the reminder's small size.
private struct CompletionEnvelopeFlap: Shape {
    var closedness: Double

    var animatableData: Double {
        get { closedness }
        set { closedness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let amount = min(max(closedness, 0), 1)
        let cornerY = rect.minY + rect.height * 0.28
        let openTipY = rect.minY + rect.height * 0.02
        let closedTipY = rect.minY + rect.height * 0.88
        let tipY = openTipY + (closedTipY - openTipY) * amount

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: cornerY))
        path.addLine(to: CGPoint(x: rect.maxX, y: cornerY))
        path.addLine(to: CGPoint(x: rect.midX, y: tipY))
        path.closeSubpath()
        return path
    }
}

private struct CompletionEnvelopeSideFolds: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + 7))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A wordless seal: a small circle with one quiet folded-paper stroke.
private struct CompletionQuietImprint: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect.insetBy(dx: 1, dy: 1))
        path.move(to: CGPoint(x: rect.minX + 5, y: rect.midY + 1))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 5, y: rect.midY - 2),
            control: CGPoint(x: rect.midX, y: rect.maxY - 4)
        )
        return path
    }
}
