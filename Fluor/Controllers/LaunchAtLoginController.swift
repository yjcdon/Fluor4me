import AppKit
import ServiceManagement

@objc(LaunchAtLoginController)
final class LaunchAtLoginController: NSObject {
    private static let loginItemDidChange = Notification.Name("Fluor4meLoginItemDidChange")
    private let service = SMAppService.mainApp

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh(_:)), name: Self.loginItemDidChange, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refresh(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
    }

    /// Read and update the system setting shared by the menu and preferences.
    @objc dynamic var launchAtLogin: Bool {
        get { service.status == .enabled }
        set {
            guard newValue != launchAtLogin else { return }
            defer { NotificationCenter.default.post(name: Self.loginItemDidChange, object: self) }

            do {
                if newValue {
                    if service.status != .requiresApproval {
                        try service.register()
                    }
                    if service.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                } else {
                    try service.unregister()
                }
            } catch {
                AppErrorManager.showError(withReason: error.localizedDescription)
            }
        }
    }

    /// Refresh bindings after another control or System Settings changes the service.
    @objc private func refresh(_ notification: Notification) {
        guard (notification.object as? LaunchAtLoginController) !== self else { return }
        willChangeValue(forKey: #keyPath(LaunchAtLoginController.launchAtLogin))
        didChangeValue(forKey: #keyPath(LaunchAtLoginController.launchAtLogin))
    }
}
