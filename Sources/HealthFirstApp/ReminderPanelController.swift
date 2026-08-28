import AppKit
import SwiftUI

enum ReminderPanelPresentation {
    case compact
    case serious
}

@MainActor
final class ReminderPanelController {
    private var panel: InteractiveReminderPanel?
    private var currentPresentation = ReminderPanelPresentation.compact
    private var currentCompactSize = CGSize(width: 420, height: 280)
    private var screenObserver: NSObjectProtocol?
    private var keyStateHandler: (@MainActor (Bool) -> Void)?
    private var previouslyFrontmostApplication: NSRunningApplication?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionVisiblePanel()
            }
        }
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func setKeyStateHandler(
        _ handler: @escaping @MainActor (Bool) -> Void
    ) {
        keyStateHandler = handler
        panel?.onKeyStateChanged = handler
    }

    func show<Content: View>(
        presentation: ReminderPanelPresentation = .compact,
        userInitiated: Bool = false,
        allowsMouseInteraction: Bool = true,
        compactSize: CGSize = CGSize(width: 420, height: 280),
        seriousEmergencyAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        let panel = panel ?? makePanel()
        let frame = panelFrame(
            presentation: presentation,
            compactSize: compactSize,
            screen: targetScreen()
        )
        let renderedContent = content()
        let rootView: AnyView

        switch presentation {
        case .compact:
            rootView = AnyView(renderedContent)
        case .serious:
            rootView = AnyView(
                ZStack {
                    SeriousOverlayBackground()
                    renderedContent

                    VStack {
                        HStack {
                            Spacer()
                            Button("紧急跳过") {
                                seriousEmergencyAction?()
                            }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.cancelAction)
                            .padding(24)
                        }
                        Spacer()
                    }
                }
                .frame(width: frame.width, height: frame.height)
            )
        }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: frame.size)
        panel.contentView = hostingView
        panel.setFrame(frame, display: true)
        panel.becomesKeyOnlyIfNeeded = !userInitiated
        // Receipt bubbles are visual acknowledgements, not modal controls.
        // Let clicks reach the app underneath while preserving the hosting
        // view and its accessibility tree.
        panel.ignoresMouseEvents = !allowsMouseInteraction

        currentPresentation = presentation
        currentCompactSize = compactSize
        self.panel = panel

        if userInitiated {
            rememberFrontmostApplicationIfNeeded()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func dismiss() {
        guard panel != nil else { return }
        panel?.ignoresMouseEvents = false
        panel?.orderOut(nil)
        // Release the hosted view so it cannot retain AppModel while hidden.
        panel?.contentView = nil
        restoreFrontmostApplicationIfNeeded()
    }

    private func rememberFrontmostApplicationIfNeeded() {
        guard previouslyFrontmostApplication == nil else { return }
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        previouslyFrontmostApplication = frontmost
    }

    private func restoreFrontmostApplicationIfNeeded() {
        defer { previouslyFrontmostApplication = nil }
        guard NSApp.isActive,
              let previous = previouslyFrontmostApplication else { return }

        let hasAnotherVisibleHealthFirstWindow = NSApp.windows.contains { window in
            window !== panel && window.isVisible
        }
        guard !hasAnotherVisibleHealthFirstWindow else { return }

        previous.activate(options: [.activateIgnoringOtherApps])
    }

    private func makePanel() -> InteractiveReminderPanel {
        let panel = InteractiveReminderPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.onKeyStateChanged = keyStateHandler
        return panel
    }

    private func repositionVisiblePanel() {
        guard let panel, panel.isVisible else { return }
        let frame = panelFrame(
            presentation: currentPresentation,
            compactSize: currentCompactSize,
            screen: targetScreen()
        )
        panel.setFrame(frame, display: true, animate: false)
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func panelFrame(
        presentation: ReminderPanelPresentation,
        compactSize: CGSize,
        screen: NSScreen?
    ) -> CGRect {
        guard let screen else {
            return CGRect(origin: .zero, size: compactSize)
        }

        switch presentation {
        case .serious:
            // Cover the usable workspace while keeping the escape control out
            // from under the menu bar, Dock, notch, and other reserved areas.
            return screen.visibleFrame
        case .compact:
            let visible = screen.visibleFrame
            let inset: CGFloat = 12
            let width = min(compactSize.width, max(220, visible.width - inset * 2))
            let height = min(compactSize.height, max(180, visible.height - inset * 2))
            let x = min(
                max(visible.maxX - width - 24, visible.minX + inset),
                visible.maxX - width - inset
            )
            let y = min(
                max(visible.maxY - height - 18, visible.minY + inset),
                visible.maxY - height - inset
            )
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
}

private struct SeriousOverlayBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isVisible = false

    var body: some View {
        Group {
            if reduceTransparency {
                HealthFirstStyle.surface
                    .overlay(HealthFirstStyle.lavender.opacity(0.32))
            } else {
                HealthFirstStyle.lavenderDark.opacity(0.22)
            }
        }
        .ignoresSafeArea()
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.20)) {
                    isVisible = true
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private final class InteractiveReminderPanel: NSPanel {
    var onKeyStateChanged: (@MainActor (Bool) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func becomeKey() {
        super.becomeKey()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            // Programmatic makeKey is not user interaction. Only an actual
            // keystroke pauses an automatic timeout.
            onKeyStateChanged?(true)
        }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        onKeyStateChanged?(false)
    }
}
