//
//  BehaviorController.swift
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
import os.log

class BehaviorController: NSObject, BehaviorDidChangeObserver, DefaultModeViewControllerDelegate, SwitchMethodDidChangeObserver, ActiveApplicationDidChangeObserver {
    weak var statusMenuController: StatusMenuController!
    
    private(set) var isKeySwitchCapable: Bool = false
    private var globalEventManager: Any?
    private var fnDownTimestamp: TimeInterval? = nil
    private var shouldHandleFNKey: Bool = false
    
    private let chromeF4Shortcut = ChromeF4Shortcut()
    private var sessionIsActive = true
    private var appliedKeyboardMode: FKeyMode = .media
    private var currentMode: FKeyMode = .media
    private var onLaunchKeyboardMode: FKeyMode = .media
    private var currentAppID: String = ""
    private var currentAppURL: URL?
    private var currentBehavior: AppBehavior = .inferred
    private var switchMethod: SwitchMethod = .window
    
    func setupController() {
        self.chromeF4Shortcut.recoverIfNeeded()
        self.onLaunchKeyboardMode = AppManager.default.getCurrentFKeyMode()
        self.currentMode = self.onLaunchKeyboardMode
        self.appliedKeyboardMode = self.onLaunchKeyboardMode
        self.switchMethod = AppManager.default.switchMethod
        
        self.applyAsObserver()
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appMustSleep(notification:)), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appMustSleep(notification:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appMustWake(notification:)), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appMustWake(notification:)), name: NSWorkspace.didWakeNotification, object: nil)
        
        if let app = NSWorkspace.shared.frontmostApplication {
            self.updateActiveApplication(app)
        }
        if AppManager.default.isDisabled {
            self.statusMenuController.statusItem.button?.image = MenuBarIcon.paused.image
        } else {
            self.showKeyboardMode(self.appliedKeyboardMode)
        }
    }

    /// Pause or resume keyboard management and update the menu bar icon.
    func setApplicationIsEnabled(_ enabled: Bool) {
        if enabled {
            self.adaptModeForApp(withId: self.currentAppID)
        } else {
            self.shouldHandleFNKey = false
            self.fnDownTimestamp = nil
            self.chromeF4Shortcut.deactivate()
            do {
                try FKeyManager.setCurrentFKeyMode(self.onLaunchKeyboardMode)
                self.appliedKeyboardMode = self.onLaunchKeyboardMode
            }
            catch { AppErrorManager.terminateApp(withReason: error.localizedDescription) }
            self.statusMenuController.statusItem.button?.image = MenuBarIcon.paused.image
        }
    }
    
    func performTerminationCleaning() {
        self.chromeF4Shortcut.deactivate()
        if AppManager.default.shouldRestoreStateOnQuit {
            let state: FKeyMode
            if AppManager.default.shouldRestorePreviousState {
                state = self.onLaunchKeyboardMode
            } else {
                state = AppManager.default.onQuitState
            }
            
            do { try FKeyManager.setCurrentFKeyMode(state) }
            catch { fatalError() }
        }
    }
    
    func adaptToAccessibilityTrust() {
        if AXIsProcessTrusted() {
            self.isKeySwitchCapable = true
            self.ensureMonitoringFlagKey()
        } else {
            self.isKeySwitchCapable = false
            self.stopMonitoringFlagKey()
        }
    }
    
    // MARK: - ActiveApplicationDidChangeObserver
    
    func activeApplicationDidChangw(notification: Notification) {
        self.adaptToAccessibilityTrust()
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        self.updateActiveApplication(app)
    }

    private func updateActiveApplication(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier ?? app.executableURL?.lastPathComponent else { return }
        self.currentAppID = id
        self.currentAppURL = app.bundleURL
        if !AppManager.default.isDisabled {
            self.adaptModeForApp(withId: id)
        }
    }
    
    // MARK: - BehaviorDidChangeObserver
    
    /// React to the change of the function keys behavior for one app.
    ///
    /// - parameter notification: The notification.
    func behaviorDidChangeForApp(notification: Notification) {
        guard let id = notification.userInfo?["id"] as? String else { return }
        
        if id == self.currentAppID {
            self.adaptModeForApp(withId: id)
        }
    }
    
    // MARK: - SwitchMethodDidChangeObserver
    
    func switchMethodDidChange(notification: Notification) {
        guard let userInfo = notification.userInfo, let method = userInfo["method"] as? SwitchMethod else { return }
        self.switchMethod = method
        switch method {
        case .window, .hybrid:
            self.startObservingBehaviorDidChange()
            self.adaptModeForApp(withId: self.currentAppID)
        case .key:
            self.stopObservingBehaviorDidChange()
            self.currentMode = AppManager.default.defaultFKeyMode
            self.changeKeyboard(mode: currentMode)
        }
    }
    
    // MARK: - DefaultModeViewControllerDelegate
    
    func defaultModeController(_ controller: DefaultModeViewController, didChangeModeTo mode: FKeyMode) {
        switch self.switchMethod {
        case .window, .hybrid:
            self.adaptModeForApp(withId: self.currentAppID)
        case .key:
            self.changeKeyboard(mode: mode)
            self.currentMode = mode
        }
    }
    
    // MARK: - Private functions
    
    /// Disable this session's Fluor instance in order to prevent it from messing when potential other sessions' ones.
    ///
    /// - Parameter notification: The notification.
    @objc private func appMustSleep(notification: Notification) {
        guard self.sessionIsActive else { return }
        self.sessionIsActive = false
        self.chromeF4Shortcut.deactivate()
        do {
            try FKeyManager.setCurrentFKeyMode(self.onLaunchKeyboardMode)
            self.appliedKeyboardMode = self.onLaunchKeyboardMode
        } catch {
            os_log("Unable to reset FKey mode to pre-launch mode", type: .error)
        }
        self.resignAsObserver()
    }
    
    
    /// Reenable this session's Fluor instance.
    ///
    /// - Parameter notification: The notification.
    @objc private func appMustWake(notification: Notification) {
        guard !self.sessionIsActive else { return }
        self.sessionIsActive = true
        self.applyAsObserver()
        if let app = NSWorkspace.shared.frontmostApplication {
            self.updateActiveApplication(app)
        }
    }
    
    /// Register self as an observer for some notifications.
    private func applyAsObserver() {
        if self.switchMethod != .key { self.startObservingBehaviorDidChange() }
        self.startObservingSwitchMethodDidChange()
        self.startObservingActiveApplicationDidChange()
        
        self.adaptToAccessibilityTrust()
    }
    
    /// Unregister self as an observer for some notifications.
    private func resignAsObserver() {
        if self.switchMethod != .key { self.stopObservingBehaviorDidChange() }
        self.stopObservingSwitchMethodDidChange()
        self.stopObservingActiveApplicationDidChange()
        
        self.stopMonitoringFlagKey()
    }
    
    /// Set the function keys' behavior for the given app.
    ///
    /// - parameter id: The app's bundle id.
    private func adaptModeForApp(withId id: String) {
        if self.switchMethod != .key {
            let behavior = AppManager.default.behaviorForApp(id: id)
            self.currentMode = AppManager.default.keyboardStateFor(behavior: behavior)
        }
        self.changeKeyboard(mode: self.currentMode)
    }

    /// Use Apple media keys in Chrome while its single-key Spotlight mapping is active.
    private func changeKeyboard(mode requestedMode: FKeyMode) {
        guard self.sessionIsActive, !AppManager.default.isDisabled else { return }
        let isChrome = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ChromeF4Shortcut.chromeID
        if !isChrome { self.chromeF4Shortcut.deactivate() }
        let mode: FKeyMode = isChrome ? .media : requestedMode
        if mode != self.appliedKeyboardMode {
            do { try FKeyManager.setCurrentFKeyMode(mode) }
            catch { AppErrorManager.terminateApp(withReason: error.localizedDescription) }
            self.appliedKeyboardMode = mode
        }
        self.showKeyboardMode(self.appliedKeyboardMode)
        if isChrome { self.chromeF4Shortcut.activate() }
    }

    /// Show the keyboard mode already applied by macOS.
    private func showKeyboardMode(_ mode: FKeyMode) {
        self.statusMenuController.statusItem.button?.image = mode == .media ? MenuBarIcon.media.image : MenuBarIcon.function.image
    }
    
    private func manageKeyPress(event: NSEvent) {
        guard !AppManager.default.isDisabled, self.switchMethod != .window else { return }
        if event.type == .flagsChanged {
            if event.modifierFlags.contains(.function) {
                if event.keyCode == 63 {
                    self.fnDownTimestamp = event.timestamp
                    self.shouldHandleFNKey = true
                } else {
                    self.fnDownTimestamp = nil
                    self.shouldHandleFNKey = false
                }
            } else {
                if self.shouldHandleFNKey, let timestamp = self.fnDownTimestamp {
                    let delta = (event.timestamp - timestamp) * 1000
                    self.shouldHandleFNKey = false
                    if event.keyCode == 63, delta <= AppManager.default.fnKeyMaximumDelay {
                        switch self.switchMethod {
                        case .key:
                            self.fnKeyPressedImpactsGlobal()
                        case .hybrid:
                            self.fnKeyPressedImpactsApp()
                        default:
                            return
                        }
                    }
                }
            }
        } else if self.shouldHandleFNKey {
            self.shouldHandleFNKey = false
            self.fnDownTimestamp = nil
        }
    }
    
    private func fnKeyPressedImpactsGlobal() {
        let mode = self.currentMode.counterPart
        AppManager.default.defaultFKeyMode = mode
        self.changeKeyboard(mode: mode)
        self.currentMode = mode
    }
    
    private func fnKeyPressedImpactsApp() {
        guard let url = self.currentAppURL else { AppErrorManager.terminateApp(withReason: "An unexpected error occured") }
        let appBehavior = AppManager.default.behaviorForApp(id: self.currentAppID)
        let defaultBehavior = AppManager.default.defaultFKeyMode.behavior
        
        let newAppBehavior: AppBehavior
        
        switch appBehavior {
        case .inferred:
            newAppBehavior = defaultBehavior.counterPart
        case defaultBehavior.counterPart:
            newAppBehavior = defaultBehavior
        case defaultBehavior:
            newAppBehavior = .inferred
        default:
            newAppBehavior = .inferred
        }
        
        AppManager.default.propagate(behavior: newAppBehavior, forApp: self.currentAppID , at: url, from: .fnKey)
    }
    
    private func ensureMonitoringFlagKey() {
        guard self.isKeySwitchCapable && self.globalEventManager == nil else { return }
        self.globalEventManager = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: manageKeyPress)
    }
    
    private func stopMonitoringFlagKey() {
        guard let gem = self.globalEventManager else { return }
        NSEvent.removeMonitor(gem)
        if self.globalEventManager != nil {
            self.globalEventManager = nil
        }
    }
}
