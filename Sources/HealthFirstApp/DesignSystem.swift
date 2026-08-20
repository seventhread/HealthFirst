import SwiftUI

enum HealthFirstStyle {
    static let lavender = Color(red: 0.72, green: 0.70, blue: 0.82)
    static let lavenderDark = Color(red: 0.36, green: 0.34, blue: 0.44)
    static let orange = Color(red: 0.92, green: 0.48, blue: 0.16)
    static let ink = Color(red: 0.16, green: 0.16, blue: 0.18)
    static let surface = Color(nsColor: .windowBackgroundColor)
    static let secondarySurface = Color(nsColor: .controlBackgroundColor)

    static let cardCornerRadius: CGFloat = 20
    static let compactSpacing: CGFloat = 10
}

struct HealthFirstCardModifier: ViewModifier {
    var chromeOpacity: Double = 1
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let opacity = min(1, max(0, chromeOpacity))

        content
            .background(
                RoundedRectangle(cornerRadius: HealthFirstStyle.cardCornerRadius, style: .continuous)
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(HealthFirstStyle.surface)
                            : AnyShapeStyle(.regularMaterial)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: HealthFirstStyle.cardCornerRadius, style: .continuous)
                            .strokeBorder(.primary.opacity(0.08))
                    }
                    .shadow(
                        color: .black.opacity(0.16 * opacity),
                        radius: 24,
                        y: 10
                    )
                    .opacity(opacity)
            )
    }
}

extension View {
    func healthFirstCard(chromeOpacity: Double = 1) -> some View {
        modifier(HealthFirstCardModifier(chromeOpacity: chromeOpacity))
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HealthFirstStyle.orange.opacity(configuration.isPressed ? 0.78 : 1))
            )
            .scaleEffect(
                reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1)
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}
