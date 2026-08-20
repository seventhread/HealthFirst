import SwiftUI

enum MascotExpression {
    case neutral
    case subtleSmile
}

/// Visual-only mascot states. Business transitions stay with the caller.
enum MascotMotion: Hashable {
    case idle
    case entering
    case agreeing
    case snoozing
    case skipping
    case ignored
    case followUp
    case guidingEye
    case guidingStanding
    case guidingQuiet
    case completed
    case serious
}

struct MascotPlaceholderView: View {
    var expression: MascotExpression = .neutral
    var motion: MascotMotion = .idle
    var progress: Double = 0
    var reduceMotion: Bool = false

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var actionProgress: CGFloat = 1

    private var shouldReduceMotion: Bool {
        reduceMotion || systemReduceMotion
    }

    private var normalizedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    private var displayedExpression: MascotExpression {
        if expression == .subtleSmile || motion == .agreeing || motion == .completed {
            return .subtleSmile
        }
        return .neutral
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let pose = MascotPose(
                motion: motion,
                actionProgress: shouldReduceMotion ? 1 : actionProgress,
                guidanceProgress: shouldReduceMotion && motion == .guidingQuiet
                    ? 1
                    : normalizedProgress
            )

            ZStack {
                backAccessory(in: size, pose: pose)

                ZStack {
                    MascotBodyShape()
                        .fill(
                            LinearGradient(
                                colors: [HealthFirstStyle.lavender.opacity(0.86), HealthFirstStyle.lavender],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            MascotBodyShape()
                                .stroke(
                                    HealthFirstStyle.ink.opacity(0.8),
                                    lineWidth: max(1, size.width * 0.014)
                                )
                        }

                    paperFold(in: size)
                    if pose.showsBack {
                        backSide(in: size)
                    } else {
                        face(in: size, pose: pose)
                    }

                    MascotArmsShape(motion: motion)
                        .stroke(
                            HealthFirstStyle.ink.opacity(0.84),
                            style: StrokeStyle(
                                lineWidth: max(1.5, size.width * 0.022),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )

                    if !pose.showsBack {
                        reel(in: size)
                    }
                    feet(in: size)
                }
                .scaleEffect(pose.scale, anchor: .bottom)
                .scaleEffect(x: pose.horizontalScale, y: 1, anchor: .bottom)
                .rotationEffect(.degrees(pose.rotationDegrees), anchor: .bottom)
                .offset(x: pose.offset.width, y: pose.offset.height)
                .opacity(pose.opacity)

                frontAccessory(in: size, pose: pose)
            }
        }
        .aspectRatio(0.86, contentMode: .fit)
        .animation(
            shouldReduceMotion ? nil : .easeInOut(duration: 0.32),
            value: normalizedProgress
        )
        .task(id: MascotAnimationID(motion: motion, reduceMotion: shouldReduceMotion)) {
            guard !shouldReduceMotion else {
                actionProgress = 1
                return
            }

            actionProgress = 0
            await Task.yield()
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: motion.animationDuration)) {
                actionProgress = 1
            }
        }
        .accessibilityHidden(true)
    }

    private func paperFold(in size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.67, y: size.height * 0.07))
            path.addLine(to: CGPoint(x: size.width * 0.91, y: size.height * 0.28))
            path.addLine(to: CGPoint(x: size.width * 0.73, y: size.height * 0.28))
            path.closeSubpath()
        }
        .fill(HealthFirstStyle.orange)
        .overlay {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.67, y: size.height * 0.07))
                path.addLine(to: CGPoint(x: size.width * 0.91, y: size.height * 0.28))
                path.addLine(to: CGPoint(x: size.width * 0.73, y: size.height * 0.28))
            }
            .stroke(
                HealthFirstStyle.ink.opacity(0.65),
                lineWidth: max(1, size.width * 0.012)
            )
        }
    }

    private func face(in size: CGSize, pose: MascotPose) -> some View {
        ZStack {
            Capsule()
                .fill(HealthFirstStyle.ink)
                .frame(width: size.width * 0.055, height: size.height * 0.09)
                .position(
                    x: size.width * 0.40 + pose.eyeOffset.width,
                    y: size.height * 0.45 + pose.eyeOffset.height
                )

            Capsule()
                .fill(HealthFirstStyle.ink)
                .frame(width: size.width * 0.055, height: size.height * 0.09)
                .position(
                    x: size.width * 0.61 + pose.eyeOffset.width,
                    y: size.height * 0.45 + pose.eyeOffset.height
                )

            MouthShape(expression: displayedExpression)
                .stroke(
                    HealthFirstStyle.ink,
                    style: StrokeStyle(
                        lineWidth: max(1.5, size.width * 0.018),
                        lineCap: .round
                    )
                )
                .frame(width: size.width * 0.18, height: size.height * 0.07)
                .position(x: size.width * 0.505, y: size.height * 0.56)

        }
    }

    private func backSide(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.34, y: size.height * 0.40))
                path.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.51))
                path.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.40))
            }
            .stroke(
                HealthFirstStyle.ink.opacity(0.28),
                style: StrokeStyle(
                    lineWidth: max(1, size.width * 0.012),
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [3, 4]
                )
            )

            Capsule()
                .fill(HealthFirstStyle.orange.opacity(0.66))
                .frame(width: size.width * 0.18, height: max(2, size.height * 0.018))
                .position(x: size.width * 0.50, y: size.height * 0.58)
        }
    }

    private func reel(in size: CGSize) -> some View {
        Circle()
            .fill(HealthFirstStyle.ink.opacity(0.86))
            .frame(width: size.width * 0.20)
            .overlay {
                Circle()
                    .stroke(HealthFirstStyle.orange, lineWidth: max(2, size.width * 0.035))
                    .padding(size.width * 0.035)
            }
            .position(x: size.width * 0.72, y: size.height * 0.76)
    }

    private func feet(in size: CGSize) -> some View {
        HStack(spacing: size.width * 0.18) {
            Capsule()
            Capsule()
        }
        .foregroundStyle(HealthFirstStyle.ink.opacity(0.88))
        .frame(width: size.width * 0.52, height: size.height * 0.10)
        .position(x: size.width * 0.49, y: size.height * 0.94)
    }

    @ViewBuilder
    private func backAccessory(in size: CGSize, pose: MascotPose) -> some View {
        switch motion {
        case .entering:
            HStack(spacing: size.width * 0.035) {
                Capsule().frame(width: size.width * 0.11)
                Capsule().frame(width: size.width * 0.065)
                Circle().frame(width: size.width * 0.025)
            }
            .foregroundStyle(HealthFirstStyle.orange.opacity(0.55))
            .frame(height: max(2, size.height * 0.018))
            .position(x: size.width * 0.10, y: size.height * 0.69)
            .opacity(max(0.35, 1 - pose.actionProgress * 0.65))

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func frontAccessory(in size: CGSize, pose: MascotPose) -> some View {
        switch motion {
        case .idle:
            EmptyView()

        case .entering:
            Image(systemName: "arrow.right")
                .font(.system(size: max(8, size.width * 0.105), weight: .bold))
                .foregroundStyle(HealthFirstStyle.orange.opacity(0.72))
                .position(x: size.width * 0.08, y: size.height * 0.28)
                .opacity(shouldReduceMotion ? 1 : max(0, 1 - pose.actionProgress))

        case .agreeing:
            checkStamp(in: size, scale: 0.82 + pose.actionProgress * 0.18)
                .position(x: size.width * 0.88, y: size.height * 0.69)

        case .snoozing:
            TimeCardView(label: "稍后")
                .frame(width: size.width * 0.32, height: size.height * 0.20)
                .rotationEffect(.degrees(-4 + pose.actionPulse * 3))
                .position(x: size.width * 0.10, y: size.height * 0.28)
                .opacity(0.45 + pose.actionProgress * 0.55)

        case .skipping:
            RoundedRectangle(cornerRadius: size.width * 0.025)
                .fill(HealthFirstStyle.lavender.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: size.width * 0.025)
                        .stroke(
                            HealthFirstStyle.ink.opacity(0.55),
                            lineWidth: max(1, size.width * 0.012)
                        )
                }
                .overlay {
                    Capsule()
                        .fill(HealthFirstStyle.orange)
                        .frame(width: size.width * 0.16, height: max(2, size.height * 0.018))
                }
                .frame(width: size.width * 0.34, height: size.height * 0.10)
                .rotationEffect(.degrees(7 + pose.actionPulse * 8))
                .position(
                    x: size.width * (0.91 + (1 - pose.actionProgress) * 0.10),
                    y: size.height * 0.42
                )

        case .ignored:
            BookmarkView()
                .fill(HealthFirstStyle.lavender)
                .overlay {
                    BookmarkView()
                        .stroke(
                            HealthFirstStyle.ink.opacity(0.55),
                            lineWidth: max(1, size.width * 0.012)
                        )
                }
                .frame(width: size.width * 0.16, height: size.height * 0.24)
                .position(x: size.width * 0.88, y: size.height * 0.18)
                .opacity(0.50 + pose.actionProgress * 0.50)

        case .followUp:
            BookmarkView()
                .fill(.white.opacity(0.94))
                .overlay {
                    VStack(spacing: size.height * 0.018) {
                        Capsule().frame(width: size.width * 0.13, height: 2)
                        Capsule().frame(width: size.width * 0.09, height: 2)
                    }
                    .foregroundStyle(HealthFirstStyle.lavenderDark.opacity(0.42))
                }
                .overlay {
                    BookmarkView()
                        .stroke(
                            HealthFirstStyle.ink.opacity(0.62),
                            lineWidth: max(1, size.width * 0.012)
                        )
                }
                .frame(width: size.width * 0.23, height: size.height * 0.27)
                .rotation3DEffect(
                    .degrees(180 - 180 * Double(pose.actionProgress)),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: shouldReduceMotion ? 0 : 0.35
                )
                .rotationEffect(.degrees(-3 + pose.actionPulse * 3))
                .position(x: size.width * 0.87, y: size.height * 0.17)

        case .guidingEye:
            FarViewCard()
                .frame(width: size.width * 0.38, height: size.height * 0.27)
                .position(x: size.width * 0.87, y: size.height * 0.17)

        case .guidingStanding:
            VStack(spacing: size.height * 0.012) {
                Image(systemName: "arrow.up")
                Text("起")
            }
            .font(.system(size: max(8, size.width * 0.09), weight: .bold, design: .rounded))
            .foregroundStyle(HealthFirstStyle.orange)
            .padding(size.width * 0.045)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: size.width * 0.06))
            .overlay {
                RoundedRectangle(cornerRadius: size.width * 0.06)
                    .stroke(HealthFirstStyle.ink.opacity(0.55), lineWidth: max(1, size.width * 0.01))
            }
            .rotationEffect(.degrees(Double(pose.guidancePulse) * -3))
            .position(x: size.width * 0.08, y: size.height * 0.32)
            .offset(y: -size.height * 0.025 * pose.guidancePulse)

        case .guidingQuiet:
            Image(systemName: "envelope.fill")
                .font(.system(size: max(9, size.width * 0.13), weight: .semibold))
                .foregroundStyle(HealthFirstStyle.lavenderDark)
                .padding(size.width * 0.055)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: size.width * 0.05))
                .position(x: size.width * 0.50, y: size.height * 0.08)

        case .completed:
            checkStamp(in: size, scale: 0.76 + pose.actionProgress * 0.24)
                .position(x: size.width * 0.88, y: size.height * 0.68)

        case .serious:
            RoundedRectangle(cornerRadius: size.width * 0.055)
                .fill(HealthFirstStyle.lavender.opacity(0.82))
                .frame(width: size.width * 0.34, height: size.width * 0.24)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(HealthFirstStyle.orange)
                        .frame(width: size.width * 0.24, height: max(3, size.height * 0.025))
                        .padding(.bottom, size.height * 0.025)
                }
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: size.width * 0.055)
                        .stroke(HealthFirstStyle.ink.opacity(0.5), lineWidth: max(1, size.width * 0.012))
                }
                .rotationEffect(.degrees(-2))
                .position(x: size.width * 0.89, y: size.height * 0.18)
        }
    }

    private func checkStamp(in size: CGSize, scale: CGFloat) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: max(8, size.width * 0.12), weight: .black))
            .foregroundStyle(HealthFirstStyle.orange)
            .frame(width: size.width * 0.28, height: size.width * 0.28)
            .background(.white.opacity(0.94), in: Circle())
            .overlay {
                Circle()
                    .stroke(HealthFirstStyle.orange, lineWidth: max(1.5, size.width * 0.025))
            }
            .rotationEffect(.degrees(-8))
            .scaleEffect(scale)
    }
}

private struct MascotAnimationID: Hashable {
    let motion: MascotMotion
    let reduceMotion: Bool
}

private struct MascotPose {
    let motion: MascotMotion
    let actionProgress: CGFloat
    let guidanceProgress: CGFloat

    var actionPulse: CGFloat {
        sin(actionProgress * .pi)
    }

    var guidancePulse: CGFloat {
        guard motion == .guidingStanding else { return 0 }
        let elapsed = guidanceProgress * 60
        return [8.0, 22.0, 38.0, 52.0]
            .map { milestone in
                let local = (elapsed - milestone) / 0.8
                guard local >= 0, local <= 1 else { return CGFloat(0) }
                return sin(local * .pi)
            }
            .max() ?? 0
    }

    private var quietTurnProgress: CGFloat {
        guard motion == .guidingQuiet else { return 0 }
        // The thirty-second guide uses only its first 0.9 seconds for a
        // single turn. Afterwards the mascot quietly keeps its back turned.
        return min(1, guidanceProgress / CGFloat(0.9 / 30.0))
    }

    var horizontalScale: CGFloat {
        guard motion == .guidingQuiet else { return 1 }
        return max(0.04, abs(1 - quietTurnProgress * 2))
    }

    var showsBack: Bool {
        motion == .guidingQuiet && quietTurnProgress >= 0.5
    }

    var offset: CGSize {
        switch motion {
        case .entering:
            return CGSize(width: (1 - actionProgress) * -14, height: (1 - actionProgress) * 3)
        case .agreeing:
            return CGSize(width: 0, height: -3 * actionPulse)
        case .snoozing:
            return CGSize(width: -2 * actionPulse, height: 1.5 * actionPulse)
        case .skipping:
            return CGSize(width: 4 * actionPulse, height: 0)
        case .ignored:
            return CGSize(width: -2.5 * actionPulse, height: 1.5 * actionPulse)
        case .followUp:
            return CGSize(width: 0, height: -2.5 * actionPulse)
        case .guidingStanding:
            return CGSize(width: 0, height: -2.5 * guidancePulse)
        case .completed:
            return CGSize(width: 0, height: -4 * actionPulse)
        default:
            return .zero
        }
    }

    var rotationDegrees: Double {
        switch motion {
        case .entering:
            return Double((1 - actionProgress) * -3)
        case .agreeing:
            return Double(actionPulse * 2.5)
        case .snoozing:
            return Double(actionPulse * -2)
        case .skipping:
            return Double(actionPulse * 2)
        case .followUp:
            return Double(actionPulse * -2)
        default:
            return 0
        }
    }

    var scale: CGFloat {
        switch motion {
        case .entering:
            return 0.96 + actionProgress * 0.04
        case .completed:
            return 1 + actionPulse * 0.018
        case .serious:
            return 0.985 + actionProgress * 0.015
        default:
            return 1
        }
    }

    var opacity: Double {
        motion == .entering ? Double(0.48 + actionProgress * 0.52) : 1
    }

    var eyeOffset: CGSize {
        switch motion {
        case .guidingEye:
            return CGSize(width: 2.5, height: -1)
        case .ignored:
            return CGSize(width: -2, height: 1)
        case .followUp:
            return CGSize(width: 1, height: -1)
        default:
            return .zero
        }
    }

}

private extension MascotMotion {
    var animationDuration: Double {
        switch self {
        case .idle, .guidingEye, .guidingStanding, .guidingQuiet:
            return 0.35
        case .entering:
            return 0.34
        case .agreeing:
            return 0.36
        case .completed:
            return 0.72
        case .snoozing:
            return 0.60
        case .skipping:
            return 0.50
        case .ignored:
            return 0.36
        case .followUp:
            return 0.65
        case .serious:
            return 0.58
        }
    }
}

private struct MascotBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.29, y: rect.height * 0.04))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.31),
            control: CGPoint(x: rect.width * 0.16, y: rect.height * 0.08)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.82))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.30, y: rect.height * 0.91),
            control: CGPoint(x: rect.width * 0.10, y: rect.height * 0.91)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.76, y: rect.height * 0.91))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.91, y: rect.height * 0.79),
            control: CGPoint(x: rect.width * 0.91, y: rect.height * 0.90)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.91, y: rect.height * 0.29))
        path.addLine(to: CGPoint(x: rect.width * 0.67, y: rect.height * 0.04))
        path.closeSubpath()
        return path
    }
}

private struct MascotArmsShape: Shape {
    let motion: MascotMotion

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let leftShoulder = CGPoint(x: rect.width * 0.14, y: rect.height * 0.57)
        let rightShoulder = CGPoint(x: rect.width * 0.86, y: rect.height * 0.57)

        switch motion {
        case .agreeing:
            addArm(to: &path, from: leftShoulder, elbow: point(0.07, 0.55, in: rect), hand: point(0.03, 0.48, in: rect))
            addArm(to: &path, from: rightShoulder, elbow: point(0.93, 0.48, in: rect), hand: point(0.96, 0.36, in: rect))
        case .snoozing:
            addArm(to: &path, from: leftShoulder, elbow: point(0.08, 0.47, in: rect), hand: point(0.06, 0.36, in: rect))
            addArm(to: &path, from: rightShoulder, elbow: point(0.92, 0.61, in: rect), hand: point(0.96, 0.67, in: rect))
        case .skipping:
            addArm(to: &path, from: leftShoulder, elbow: point(0.07, 0.61, in: rect), hand: point(0.03, 0.67, in: rect))
            addArm(to: &path, from: rightShoulder, elbow: point(0.92, 0.53, in: rect), hand: point(0.98, 0.44, in: rect))
        case .guidingEye:
            addArm(to: &path, from: leftShoulder, elbow: point(0.08, 0.62, in: rect), hand: point(0.04, 0.69, in: rect))
            addArm(to: &path, from: rightShoulder, elbow: point(0.91, 0.45, in: rect), hand: point(0.96, 0.28, in: rect))
        case .guidingStanding:
            addArm(to: &path, from: leftShoulder, elbow: point(0.06, 0.51, in: rect), hand: point(0.03, 0.39, in: rect))
            addArm(to: &path, from: rightShoulder, elbow: point(0.94, 0.51, in: rect), hand: point(0.97, 0.39, in: rect))
        case .guidingQuiet:
            addArm(to: &path, from: leftShoulder, elbow: point(0.24, 0.62, in: rect), hand: point(0.43, 0.66, in: rect))
            addArm(to: &path, from: rightShoulder, elbow: point(0.76, 0.62, in: rect), hand: point(0.57, 0.66, in: rect))
        case .serious:
            addArm(to: &path, from: leftShoulder, elbow: point(0.33, 0.61, in: rect), hand: point(0.70, 0.68, in: rect))
            addArm(to: &path, from: rightShoulder, elbow: point(0.68, 0.61, in: rect), hand: point(0.31, 0.68, in: rect))
        default:
            addArm(to: &path, from: leftShoulder, elbow: point(0.07, 0.61, in: rect), hand: point(0.03, 0.68, in: rect))
            addArm(to: &path, from: rightShoulder, elbow: point(0.93, 0.61, in: rect), hand: point(0.97, 0.68, in: rect))
        }

        return path
    }

    private func addArm(to path: inout Path, from start: CGPoint, elbow: CGPoint, hand: CGPoint) {
        path.move(to: start)
        path.addQuadCurve(to: hand, control: elbow)
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.width * x, y: rect.height * y)
    }
}

private struct MouthShape: Shape {
    let expression: MascotExpression

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch expression {
        case .neutral:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        case .subtleSmile:
            path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.38))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.height * 0.38),
                control: CGPoint(x: rect.midX, y: rect.height * 0.78)
            )
        }
        return path
    }
}

private struct BookmarkView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.78))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TimeCardView: View {
    let label: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: size.width * 0.18, style: .continuous)
                    .fill(.white.opacity(0.95))
                RoundedRectangle(cornerRadius: size.width * 0.18, style: .continuous)
                    .stroke(HealthFirstStyle.ink.opacity(0.65), lineWidth: max(1, size.width * 0.035))
                Text(label)
                    .font(.system(size: max(8, size.height * 0.46), weight: .bold, design: .rounded))
                    .foregroundStyle(HealthFirstStyle.orange)
            }
        }
    }
}

private struct SpeechBubbleView: View {
    let text: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: size.width * 0.22, style: .continuous)
                    .fill(.white.opacity(0.95))
                    .overlay {
                        RoundedRectangle(cornerRadius: size.width * 0.22, style: .continuous)
                            .stroke(HealthFirstStyle.ink.opacity(0.62), lineWidth: max(1, size.width * 0.035))
                    }
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.78))
                    path.addLine(to: CGPoint(x: size.width * 0.07, y: size.height))
                    path.addLine(to: CGPoint(x: size.width * 0.36, y: size.height * 0.83))
                    path.closeSubpath()
                }
                .fill(.white.opacity(0.95))
                Text(text)
                    .font(.system(size: max(9, size.height * 0.48), weight: .black, design: .rounded))
                    .foregroundStyle(HealthFirstStyle.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct FarViewCard: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: size.width * 0.13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [HealthFirstStyle.lavender.opacity(0.72), .white.opacity(0.96)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height * 0.66))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.60),
                        control: CGPoint(x: size.width * 0.46, y: size.height * 0.43)
                    )
                }
                .stroke(HealthFirstStyle.lavenderDark.opacity(0.75), lineWidth: max(1, size.width * 0.025))
                Circle()
                    .fill(HealthFirstStyle.orange)
                    .frame(width: size.width * 0.14)
                    .position(x: size.width * 0.72, y: size.height * 0.28)
                RoundedRectangle(cornerRadius: size.width * 0.13, style: .continuous)
                    .stroke(HealthFirstStyle.ink.opacity(0.65), lineWidth: max(1, size.width * 0.025))
            }
        }
    }
}
