import SwiftUI

@main
@MainActor
struct HealthFirstApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
                .accessibilityLabel(model.menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }

#if DEBUG
        Window("动作实验室", id: "motion-lab") {
            MotionLabView()
        }
        .defaultSize(width: 800, height: 740)
#endif
    }
}
