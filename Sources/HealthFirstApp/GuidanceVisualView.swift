import HealthFirstCore
import SwiftUI

/// A quiet, progress-driven decoration for guided reminders.
///
/// The view deliberately owns no timers or gestures. Its layout is fixed so
/// that changing the visual never moves the reminder window or its controls.
struct GuidanceVisualView: View {
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
            switch kind {
            case .eye:
                eyeRestVisual
            case .standing:
                standingVisual
            case .quietPractice:
                quietPracticeVisual
            }
        }
        .frame(width: 276, height: 82)
        .clipped()
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.18)
                : .linear(duration: 0.25),
            value: normalizedProgress
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Eye rest

    /// The little screen is handed off during the first 1.1 seconds of a
    /// twenty-second eye break. Afterwards only a still, distant point stays.
    private var eyeRestVisual: some View {
        let handoff = timedPhase(
            startSeconds: 0,
            endSeconds: 1.1,
            totalSeconds: 20
        )
        let screenOpacity = 1.0 - eased(min(1, handoff * 1.28))

        return ZStack {
            EyeHorizonShape()
                .stroke(
                    HealthFirstStyle.lavenderDark.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 5])
                )
                .frame(width: 194, height: 34)
                .offset(x: 18, y: 4)

            Circle()
                .fill(HealthFirstStyle.orange.opacity(0.82))
                .frame(width: 7, height: 7)
                .overlay {
                    Circle()
                        .stroke(HealthFirstStyle.orange.opacity(0.18), lineWidth: 6)
                }
                .offset(x: 104, y: -15)

            distantLandscape
                .offset(x: 70, y: 20)

            smallScreen
                .scaleEffect(reduceMotion ? 1 : 1 - 0.66 * handoff)
                .offset(
                    x: reduceMotion ? -91 : -91 + 172 * eased(handoff),
                    y: reduceMotion ? 17 : 17 - 28 * eased(handoff)
                )
                .opacity(screenOpacity)
        }
    }

    private var smallScreen: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(HealthFirstStyle.lavender.opacity(0.32))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(HealthFirstStyle.lavenderDark.opacity(0.4), lineWidth: 1)
                }
                .frame(width: 45, height: 28)

            Capsule()
                .fill(HealthFirstStyle.lavenderDark.opacity(0.3))
                .frame(width: 18, height: 2)
        }
    }

    private var distantLandscape: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(HealthFirstStyle.lavender.opacity(0.16))
                .frame(width: 70, height: 2)

            HStack(alignment: .bottom, spacing: 3) {
                Triangle()
                    .fill(HealthFirstStyle.lavender.opacity(0.2))
                    .frame(width: 20, height: 12)
                Triangle()
                    .fill(HealthFirstStyle.lavenderDark.opacity(0.13))
                    .frame(width: 29, height: 18)
            }
        }
        .frame(width: 74, height: 22, alignment: .bottom)
    }

    // MARK: - Standing

    /// Four ordinary UI fragments are put away at sparse milestones: button
    /// block, paper, frame rails, then measuring tape. The reel remains as a
    /// quiet anchor between those moments instead of moving continuously.
    private var standingVisual: some View {
        let buttonPhase = milestonePhase(atSeconds: 8, totalSeconds: 60)
        let paperPhase = milestonePhase(atSeconds: 22, totalSeconds: 60)
        let railPhase = milestonePhase(atSeconds: 38, totalSeconds: 60)
        let tapePhase = milestonePhase(atSeconds: 52, totalSeconds: 60)

        return ZStack {
            standingRails(completion: railPhase)

            buttonBlock
                .scaleEffect(reduceMotion ? 1 : 1 - 0.7 * eased(buttonPhase))
                .offset(
                    x: reduceMotion ? -76 : -76 + 164 * eased(buttonPhase),
                    y: reduceMotion ? 22 : 22 - 17 * eased(buttonPhase)
                )
                .opacity(1 - eased(buttonPhase))

            textPaper
                .rotationEffect(.degrees(reduceMotion ? 0 : 9 * paperPhase))
                .scaleEffect(reduceMotion ? 1 : 1 - 0.72 * eased(paperPhase))
                .offset(
                    x: reduceMotion ? -25 : -25 + 116 * eased(paperPhase),
                    y: reduceMotion ? -7 : -7 + 10 * eased(paperPhase)
                )
                .opacity(1 - eased(paperPhase))

            Capsule()
                .fill(HealthFirstStyle.orange.opacity(0.46))
                .frame(width: 72, height: 4)
                .scaleEffect(x: reduceMotion ? 1 : 1 - tapePhase, anchor: .trailing)
                .opacity(1 - eased(tapePhase))
                .offset(x: 65, y: 21)

            reel
                .offset(x: 105, y: 7)

            HStack(spacing: 7) {
                Circle().frame(width: 3, height: 3)
                Circle().frame(width: 3, height: 3)
                Circle().frame(width: 3, height: 3)
            }
            .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.18))
            .offset(x: -100, y: -28)
        }
    }

    private var buttonBlock: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(HealthFirstStyle.orange.opacity(0.74))
            .frame(width: 52, height: 19)
            .overlay {
                HStack(spacing: 4) {
                    Capsule().frame(width: 14, height: 2)
                    Circle().frame(width: 3, height: 3)
                }
                .foregroundStyle(.white.opacity(0.75))
            }
    }

    private var textPaper: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(HealthFirstStyle.lavender.opacity(0.2))
            .frame(width: 72, height: 32)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().frame(width: 42, height: 2)
                    Capsule().frame(width: 29, height: 2)
                    Capsule().frame(width: 36, height: 2)
                }
                .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.32))
                .padding(.leading, 10)
            }
    }

    private func standingRails(completion: Double) -> some View {
        return ZStack {
            HStack {
                Capsule()
                    .frame(width: reduceMotion ? 68 : 68 * (1 - completion), height: 2)
                Spacer(minLength: 0)
                Capsule()
                    .frame(width: reduceMotion ? 68 : 68 * (1 - completion), height: 2)
            }
            .frame(width: 210)
            .offset(y: -31)

            HStack {
                Capsule()
                    .frame(width: 2, height: reduceMotion ? 42 : 42 * (1 - completion))
                Spacer(minLength: 0)
                Capsule()
                    .frame(width: 2, height: reduceMotion ? 42 : 42 * (1 - completion))
            }
            .frame(width: 226)
        }
        .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.17))
        .opacity(1 - eased(completion))
    }

    private var reel: some View {
        ZStack {
            Circle()
                .fill(HealthFirstStyle.lavender.opacity(0.28))
                .frame(width: 35, height: 35)
            Circle()
                .stroke(HealthFirstStyle.lavenderDark.opacity(0.28), lineWidth: 1.5)
                .frame(width: 24, height: 24)
            Circle()
                .fill(HealthFirstStyle.orange.opacity(0.74))
                .frame(width: 7, height: 7)
        }
    }

    // MARK: - Quiet practice

    /// An abstract paper ribbon folds once into a sealed envelope, then stays
    /// still. It deliberately avoids anatomical or breathing-like imagery.
    private var quietPracticeVisual: some View {
        let sealPhase = timedPhase(
            startSeconds: 0.52,
            endSeconds: 0.9,
            totalSeconds: 30
        )

        return ZStack {
            Capsule()
                .fill(HealthFirstStyle.lavenderDark.opacity(0.1))
                .frame(width: 204, height: 2)

            ForEach(0..<3, id: \.self) { index in
                ribbonPanel(
                    index: index,
                    completion: quietFoldPhase(index: index)
                )
            }

            Image(systemName: "envelope.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.7))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(HealthFirstStyle.orange.opacity(0.82))
                        .frame(width: 5, height: 5)
                        .offset(x: 3, y: -2)
                }
                .scaleEffect(0.82 + 0.18 * eased(sealPhase))
                .opacity(eased(sealPhase))
        }
    }

    private func ribbonPanel(index: Int, completion: Double) -> some View {
        let startX = Double(index - 1) * 65
        let destinationX = Double(index - 1) * 9
        let horizontalScale = 1 - 0.7 * eased(completion)
        let angle = (index.isMultiple(of: 2) ? -1.0 : 1.0) * 68 * completion

        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(
                index.isMultiple(of: 2)
                    ? HealthFirstStyle.lavender.opacity(0.3)
                    : HealthFirstStyle.lavender.opacity(0.19)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(HealthFirstStyle.lavenderDark.opacity(0.17), lineWidth: 1)
            }
            .overlay {
                Capsule()
                    .fill(HealthFirstStyle.lavenderDark.opacity(0.18))
                    .frame(width: 26, height: 2)
            }
            .frame(width: 58, height: 35)
            .scaleEffect(
                x: reduceMotion ? 1 : horizontalScale,
                y: reduceMotion ? 1 : 1 - 0.13 * completion
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: reduceMotion ? 0 : 0.35
            )
            .offset(
                x: reduceMotion
                    ? startX
                    : startX + (destinationX - startX) * eased(completion),
                y: reduceMotion ? 0 : Double(index) * 2 * completion
            )
            .opacity(reduceMotion ? 1 - eased(completion) : 1)
            .zIndex(Double(3 - index))
    }

    // MARK: - Progress helpers

    private var normalizedProgress: Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    /// A standing action occupies only a short window around its milestone.
    /// Once complete, the fragment stays put away for the rest of the guide.
    private func milestonePhase(
        atSeconds seconds: Double,
        totalSeconds: Double
    ) -> Double {
        timedPhase(
            startSeconds: seconds,
            endSeconds: seconds + 0.55,
            totalSeconds: totalSeconds
        )
    }

    private func quietFoldPhase(index: Int) -> Double {
        switch index {
        case 0:
            timedPhase(startSeconds: 0, endSeconds: 0.34, totalSeconds: 30)
        case 1:
            timedPhase(startSeconds: 0.20, endSeconds: 0.60, totalSeconds: 30)
        default:
            timedPhase(startSeconds: 0.45, endSeconds: 0.84, totalSeconds: 30)
        }
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

    /// Returns a segment-local progress. Reduce Motion turns continuous
    /// transforms into a small set of settled, static illustrations.
    private func phase(index: Int, count: Int) -> Double {
        let start = Double(index) / Double(count)
        let end = Double(index + 1) / Double(count)

        if reduceMotion {
            return normalizedProgress >= end ? 1 : 0
        }

        return min(max((normalizedProgress - start) / (end - start), 0), 1)
    }

    private func eased(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

private struct EyeHorizonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.midY + 8)
        )
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
