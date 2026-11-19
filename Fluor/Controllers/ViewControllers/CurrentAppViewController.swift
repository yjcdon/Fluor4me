//
//  CurrentAppViewController.swift
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

final class CurrentAppViewController: NSViewController, BehaviorDidChangeObserver, ActiveApplicationDidChangeObserver {
    private let appIconView = NSImageView()
    private let appNameLabel = NSTextField(labelWithString: "")
    private let behaviorSegment = NSSegmentedControl()
    private var imageConstraint: NSLayoutConstraint!

    private(set) var currentSwitchMethod = SwitchMethod.window
    
    private var currentAppID: String = ""
    private var currentAppURL: URL?
    private var currentAppName: String?
    
    deinit {
        self.stopObservingBehaviorDidChange()
        self.stopObservingActiveApplicationDidChange()
    }

    override func loadView() {
        let row = MenuItemView(frame: NSRect(x: 0, y: 0, width: 269, height: 72))
        appIconView.image = NSImage(named: NSImage.applicationIconName)
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(appIconView)
        imageConstraint = appIconView.heightAnchor.constraint(equalToConstant: 64)

        appNameLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        appNameLabel.lineBreakMode = .byTruncatingTail
        appNameLabel.allowsExpansionToolTips = true
        behaviorSegment.segmentStyle = .rounded
        behaviorSegment.trackingMode = .selectOne
        behaviorSegment.controlSize = .small
        behaviorSegment.segmentCount = 3
        behaviorSegment.target = self
        behaviorSegment.action = #selector(behaviorChanged(_:))
        refreshLanguage()
        behaviorSegment.selectedSegment = AppBehavior.inferred.rawValue

        let controls = NSStackView(views: [appNameLabel, behaviorSegment])
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = 4
        controls.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(controls)
        NSLayoutConstraint.activate([
            appIconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            appIconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            imageConstraint,
            appIconView.widthAnchor.constraint(equalTo: appIconView.heightAnchor),
            controls.leadingAnchor.constraint(equalTo: appIconView.trailingAnchor, constant: 8),
            controls.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            controls.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        view = row
    }

    /// Translate the rule choices and the fallback for an unnamed application.
    func refreshLanguage() {
        behaviorSegment.setAccessibilityLabel(AppLanguage.text("Current application"))
        for behavior in [AppBehavior.inferred, .media, .function] {
            behaviorSegment.setImage(behavior.icon.image(description: behavior.label), forSegment: behavior.rawValue)
            behaviorSegment.setWidth(32, forSegment: behavior.rawValue)
            behaviorSegment.setToolTip(behavior.label, forSegment: behavior.rawValue)
        }
        if currentAppURL != nil {
            appNameLabel.stringValue = currentAppName ?? AppLanguage.text("An app")
        }
    }
    
    override func viewDidLoad() {
        self.startObservingBehaviorDidChange()
        self.startObservingActiveApplicationDidChange()
        
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            self.setCurrent(app: currentApp)
        }
    }

    /// Prevent rule edits while keyboard management is paused.
    func setControlsEnabled(_ enabled: Bool) {
        appIconView.isEnabled = enabled
        appNameLabel.isEnabled = enabled
        behaviorSegment.isEnabled = enabled
    }

    /// Keep the app name visible when the trigger only changes the global setting.
    func shrinkView() {
        self.currentSwitchMethod = .key
        var newFrame = self.view.frame
        newFrame.size.height = 32
        self.imageConstraint.constant = 24
        self.behaviorSegment.isHidden = true
        self.view.setFrameSize(newFrame.size)
    }

    /// Restore the app-specific mode choices when per-app switching is active.
    func expandView() {
        self.currentSwitchMethod = .window
        var newFrame = self.view.frame
        newFrame.size.height = 72
        self.imageConstraint.constant = 64
        self.behaviorSegment.isHidden = false
        self.view.setFrameSize(newFrame.size)
    }
    
    /// Change the behavior for the current running application.
    /// It makes sure the behavior manager gets notfified of this change.
    ///
    /// - parameter sender: The object that sent the action.
    @objc private func behaviorChanged(_ sender: NSSegmentedControl) {
        guard let behavior = AppBehavior(rawValue: sender.selectedSegment), let url = self.currentAppURL,
              AppManager.default.behaviorForApp(id: currentAppID) != behavior else { return }
        AppManager.default.propagate(behavior: behavior, forApp: self.currentAppID, at: url, from: .mainMenu)
    }
    
    // MARK: - Private functions
    
    /// Change the current running application presented by the view.
    ///
    /// - parameter app:      The running application.
    /// - parameter behavior: The behavior for the application. Either from the rules collection or infered if none.
    private func setCurrent(app: NSRunningApplication) {
        guard let id = app.bundleIdentifier ?? app.executableURL?.lastPathComponent,
            let url = app.bundleURL ?? app.executableURL else { return }
        
        self.currentAppID = id
        self.currentAppURL = url
        currentAppName = app.localizedName
        let behavior = AppManager.default.behaviorForApp(id: id)
        
        behaviorSegment.setSelected(true, forSegment: behavior.rawValue)
        appIconView.image = app.icon
        appNameLabel.stringValue = currentAppName ?? AppLanguage.text("An app")
    }
    
    // MARK: - ActiveApplicationDidChangeObserver
    
    func activeApplicationDidChangw(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        self.setCurrent(app: app)
    }
    
    // MARK: - BehaviorDidChangeObserver
    
    func behaviorDidChangeForApp(notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any], userInfo["source"] as? NotificationSource != .mainMenu else { return }
        guard let id = userInfo["id"] as? String, self.currentAppID == id, let behavior = userInfo["behavior"] as? AppBehavior else { return }
        
        behaviorSegment.setSelected(true, forSegment: behavior.rawValue)
    }
}
