//
//  StatusMenuController.swift
//
//  Fluor
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import Cocoa

final class StatusMenuController: NSObject, NSMenuDelegate, NSWindowDelegate, MenuControlObserver {
    private let statusMenu = NSMenu()
    private let loginController = LaunchAtLoginController()
    private var menuItemsController: MenuItemsController!
    let behaviorController = BehaviorController()

    private var rulesController: RulesEditorWindowController?
    private var aboutController: AboutWindowController?
    private var preferencesController: PreferencesWindowController?
    private var runningAppsController: RunningAppWindowController?
    
    private lazy var rulesItem = makeItem("Manage rules...", #selector(editRules(_:)), icon: .rules)
    private lazy var runningAppsItem = makeItem("Running applications...", #selector(showRunningApps(_:)), icon: .runningApps)
    private lazy var loginItem = makeItem("Start Fluor at login", #selector(toggleLaunchAtLogin(_:)))
    private lazy var disabledItem = makeItem("Disabled", #selector(toggleApplicationState(_:)))

    private(set) var statusItem: NSStatusItem!

    /// Connect the status menu before the keyboard controller starts.
    func start() {
        setupStatusMenu()
        menuItemsController = MenuItemsController(menu: statusMenu, behaviorController: behaviorController)
        menuItemsController.setupController()
        behaviorController.statusMenuController = self
        behaviorController.setupController()
        startObservingMenuControlNotification()
        menuWillOpen(statusMenu)
    }
    
    deinit {
        stopObservingSwitchMenuControlNotification()
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let object = notification.object as? NSWindow else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: object)
        if object.isEqual(rulesController?.window) {
            rulesController = nil
        } else if object.isEqual(aboutController?.window) {
            aboutController = nil
        } else if object.isEqual(preferencesController?.window) {
            preferencesController = nil
        } else if object.isEqual(runningAppsController?.window) {
            runningAppsController = nil
        }
    }
    
    // MARK: - Private functions
    
    /// Register the menu bar item and let macOS 27 manage visibility through System Settings.
    private func setupStatusMenu() {
        statusMenu.delegate = self
        statusMenu.autoenablesItems = false
        for (index, title) in ["Switch method", "", "Default mode", "", "Current application", ""].enumerated() {
            let item = title.isEmpty ? NSMenuItem.separator() : NSMenuItem(
                title: NSLocalizedString(title, comment: "Menu section"),
                action: nil, keyEquivalent: ""
            )
            item.tag = index + 1
            statusMenu.addItem(item)
        }
        statusMenu.addItem(rulesItem)
        statusMenu.addItem(runningAppsItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(makeItem("Preferences...", #selector(showPreferences(_:)), key: ",", icon: .settings))
        statusMenu.addItem(loginItem)
        statusMenu.addItem(disabledItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(makeItem("About Fluor4me", #selector(showAbout(_:)), icon: .about))
        statusMenu.addItem(makeItem("Quit", #selector(quitApplication(_:)), key: "q", icon: .quit))

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.autosaveName = "Fluor4me"
        if #available(macOS 27, *) {
            // Clear any item-level hide saved by an older build. The system still applies its per-app switch.
            self.statusItem.isVisible = true
        } else {
            self.statusItem.behavior = .removalAllowed
        }
        self.statusItem.menu = statusMenu
    }

    /// Use system icons and command shortcuts for native menu actions.
    private func makeItem(_ title: String, _ action: Selector, key: String = "", icon: FluorIcon? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString(title, comment: "Menu item"), action: action, keyEquivalent: key)
        item.target = self
        item.image = icon?.image()
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        behaviorController.adaptToAccessibilityTrust()
        loginItem.state = loginController.launchAtLogin ? .on : .off
        refreshManagementItems()
    }

    /// Refresh controls from the same preferences used to apply keyboard behavior.
    private func refreshManagementItems() {
        let disabled = AppManager.default.isDisabled
        disabledItem.state = disabled ? .on : .off
        rulesItem.isEnabled = !disabled
        runningAppsItem.isEnabled = !disabled
        menuItemsController.refreshControls(
            isEnabled: !disabled,
            canSwitch: behaviorController.isKeySwitchCapable
        )
    }
    
    // MARK: - MenuControlObserver
    
    func menuNeedsToOpen(notification: Notification) { }
    
    func menuNeedsToClose(notification: Notification) {
        if let userInfo = notification.userInfo, let animated = userInfo["animated"] as? Bool, !animated {
            self.statusMenu.cancelTrackingWithoutAnimation()
        } else {
            self.statusMenu.cancelTracking()
        }
    }
    
    // MARK: - Menu Actions
    
    /// Open or restore the rules editor from the status menu.
    @objc func editRules(_ sender: AnyObject) {
        rulesController = rulesController ?? .instantiate()
        showWindow(rulesController)
    }

    /// Open or restore the About window from the status menu.
    @objc func showAbout(_ sender: AnyObject) {
        aboutController = aboutController ?? .instantiate()
        showWindow(aboutController)
    }

    /// Open or restore settings from the status menu.
    @objc func showPreferences(_ sender: AnyObject) {
        preferencesController = preferencesController ?? .instantiate()
        showWindow(preferencesController)
    }

    /// Open or restore the running applications window from the status menu.
    @objc func showRunningApps(_ sender: AnyObject) {
        runningAppsController = runningAppsController ?? .instantiate()
        showWindow(runningAppsController)
    }

    /// Give a user-invoked window focus and restore it if it was minimized.
    private func showWindow(_ controller: NSWindowController?) {
        guard let window = controller?.window else { return }
        window.delegate = self
        NSApp.activate()
        if window.isMiniaturized {
            window.deminiaturize(self)
        }
        window.makeKeyAndOrderFront(self)
    }

    /// Enable or disable Fluor fn keys management. 
    /// If disabled the keyboard behaviour is set as its behaviour before app launch.
    ///
    /// - Parameter sender: The object that sent the action.
    @objc func toggleApplicationState(_ sender: NSMenuItem) {
        let enabled = AppManager.default.isDisabled
        AppManager.default.isDisabled = !enabled
        behaviorController.setApplicationIsEnabled(enabled)
        refreshManagementItems()
    }

    /// The operating system remains the source of truth for login registration.
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        loginController.launchAtLogin.toggle()
        sender.state = loginController.launchAtLogin ? .on : .off
    }
    
    /// Terminate the application.
    ///
    /// - parameter sender: The object that sent the action.
    @objc func quitApplication(_ sender: AnyObject) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NSApp.terminate(self)
    }
}
