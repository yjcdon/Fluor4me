import AppKit
import ServiceManagement

@objc(LaunchAtLoginController)
final class LaunchAtLoginController: NSObject {
    private let service = SMAppService.mainApp

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh(_:)), name: NSApplication.didBecomeActiveNotification, object: nil
        )
    }

    /// Read and update the system login item from General preferences.
    @objc dynamic var launchAtLogin: Bool {
        get { service.status == .enabled }
        set {
            guard newValue != launchAtLogin else { return }

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

    /// Refresh the checkbox when returning from System Settings.
    @objc private func refresh(_ notification: Notification) {
        willChangeValue(forKey: #keyPath(LaunchAtLoginController.launchAtLogin))
        didChangeValue(forKey: #keyPath(LaunchAtLoginController.launchAtLogin))
    }
}
