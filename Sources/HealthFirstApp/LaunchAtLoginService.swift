import Combine
import Foundation
import ServiceManagement

/// App-facing states for the macOS login item registration.
///
/// Keeping this type independent from `SMAppService.Status` lets the settings
/// presentation and rollback behavior be tested without registering a real
/// login item from the test process.
enum LaunchAtLoginRegistrationState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

struct LaunchAtLoginPresentation: Equatable {
    let isEnabled: Bool
    let canToggle: Bool
    let detail: String
    let showsSystemSettingsButton: Bool
}

enum LaunchAtLoginPolicy {
    static func presentation(
        for state: LaunchAtLoginRegistrationState
    ) -> LaunchAtLoginPresentation {
        switch state {
        case .disabled:
            LaunchAtLoginPresentation(
                isEnabled: false,
                canToggle: true,
                detail: "开启后，HealthFirst 会在你登录这台 Mac 时自动运行。",
                showsSystemSettingsButton: false
            )

        case .enabled:
            LaunchAtLoginPresentation(
                isEnabled: true,
                canToggle: true,
                detail: "已启用；下次登录这台 Mac 时会自动运行。",
                showsSystemSettingsButton: false
            )

        case .requiresApproval:
            LaunchAtLoginPresentation(
                isEnabled: true,
                canToggle: true,
                detail: "登录项已登记，但 macOS 尚未允许它运行。请在系统设置的“登录项”中允许 HealthFirst。",
                showsSystemSettingsButton: true
            )

        case .unavailable:
            LaunchAtLoginPresentation(
                isEnabled: false,
                canToggle: false,
                detail: "当前运行方式不能管理登录项。请从打包后的 HealthFirst.app 启动后再设置。",
                showsSystemSettingsButton: false
            )
        }
    }

    static func failureMessage(
        attemptedToEnable: Bool,
        error: Error
    ) -> String {
        if let serviceError = error as? LaunchAtLoginServiceError {
            return serviceError.localizedDescription
        }

        let action = attemptedToEnable ? "开启" : "关闭"
        return "无法\(action)登录后自动启动，设置已恢复。请确认 HealthFirst.app 位于“应用程序”文件夹，并检查“系统设置 > 通用 > 登录项”。"
    }
}

enum LaunchAtLoginServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "当前运行方式不能管理登录项，设置已恢复。请从打包后的 HealthFirst.app 启动后再试。"
        }
    }
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
    var state: LaunchAtLoginRegistrationState { get }

    func setRegistrationEnabled(_ isEnabled: Bool) throws
    func openSystemSettings()
}

@MainActor
final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
    private static let healthFirstBundleIdentifier = "app.healthfirst.macos"

    private var isPackagedApplication: Bool {
        Bundle.main.bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
            && Bundle.main.bundleIdentifier == Self.healthFirstBundleIdentifier
    }

    var state: LaunchAtLoginRegistrationState {
        guard isPackagedApplication else { return .unavailable }

        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func setRegistrationEnabled(_ isEnabled: Bool) throws {
        guard isPackagedApplication else {
            throw LaunchAtLoginServiceError.unavailable
        }

        let service = SMAppService.mainApp
        switch (isEnabled, service.status) {
        case (true, .enabled), (true, .requiresApproval),
             (false, .notRegistered), (false, .notFound):
            return
        case (true, .notRegistered), (true, .notFound):
            try service.register()
        case (false, .enabled), (false, .requiresApproval):
            try service.unregister()
        @unknown default:
            throw LaunchAtLoginServiceError.unavailable
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var presentation: LaunchAtLoginPresentation
    @Published private(set) var errorMessage: String?

    private let service: any LaunchAtLoginServicing
    private let store: UserDefaults

    init(
        service: any LaunchAtLoginServicing = SystemLaunchAtLoginService(),
        store: UserDefaults = .standard
    ) {
        self.service = service
        self.store = store
        presentation = LaunchAtLoginPolicy.presentation(for: service.state)
        errorMessage = nil
        synchronizeWithSystem()
    }

    func setEnabled(_ isEnabled: Bool) {
        guard presentation.canToggle, isEnabled != presentation.isEnabled else {
            return
        }

        let previousPresentation = presentation
        errorMessage = nil

        do {
            try service.setRegistrationEnabled(isEnabled)
            synchronizeWithSystem()
        } catch {
            // Keep the visible and persisted setting on its last confirmed
            // value when ServiceManagement rejects the operation.
            presentation = previousPresentation
            store.set(
                previousPresentation.isEnabled,
                forKey: SettingsKey.launchAtLogin
            )
            errorMessage = LaunchAtLoginPolicy.failureMessage(
                attemptedToEnable: isEnabled,
                error: error
            )
        }
    }

    func refresh() {
        errorMessage = nil
        synchronizeWithSystem()
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }

    private func synchronizeWithSystem() {
        let state = service.state
        presentation = LaunchAtLoginPolicy.presentation(for: state)

        // The SwiftPM executable and XCTest runner are not app bundles. Do
        // not overwrite a real app preference while running in those modes.
        guard state != .unavailable else { return }
        store.set(presentation.isEnabled, forKey: SettingsKey.launchAtLogin)
    }
}
