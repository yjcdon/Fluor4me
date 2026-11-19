//
//  PreferencesTabViewController.swift
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


import AppKit

final class PreferencesTabViewController: NSTabViewController, TriggerSectionVisibilityDidChangePoster, SwitchMethodDidChangePoster {
    private let preferences = AppManager.default
    private let loginController = LaunchAtLoginController()
    private lazy var restoreStartup = checkbox("Restore startup mode", checked: preferences.shouldRestorePreviousState,
                                               action: #selector(changeRestoreStartup(_:)))
    private lazy var quitMode = modeControl(preferences.onQuitState, action: #selector(changeQuitMode(_:)))

    override func viewDidLoad() {
        super.viewDidLoad()
        tabStyle = .toolbar
        canPropagateSelectedChildViewControllerTitle = false
        addTab(label: NSLocalizedString("General", comment: ""), image: NSImage.preferencesGeneralName, content: generalPane())
        addTab(label: NSLocalizedString("Advanced", comment: ""), image: NSImage.advancedName, content: advancedPane())
    }

    private func addTab(label: String, image: NSImage.Name, content: NSView) {
        let controller = NSViewController()
        controller.view = content
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(named: image)
        addTabViewItem(item)
    }

    private func generalPane() -> NSView {
        let startAtLogin = NSButton(
            checkboxWithTitle: NSLocalizedString("Start Fluor at login", comment: ""), target: nil, action: nil
        )
        startAtLogin.bind(.value, to: loginController, withKeyPath: #keyPath(LaunchAtLoginController.launchAtLogin))

        let startupLabel = NSLocalizedString("Default mode on launch", comment: "")
        let startup = modeControl(preferences.defaultFKeyMode, action: nil)
        startup.bind(.selectedIndex, to: NSUserDefaultsController.shared, withKeyPath: "values.DefaultKeyboardMode",
                     options: [.nullPlaceholder: FKeyMode.media.rawValue])
        startup.setAccessibilityLabel(startupLabel)
        let startupRow = NSStackView(views: [NSTextField(labelWithString: startupLabel), startup])
        startupRow.orientation = .horizontal
        startupRow.alignment = .centerY

        let resetOnQuit = checkbox("Reset mode on quit", checked: preferences.shouldRestoreStateOnQuit,
                                   action: #selector(changeResetOnQuit(_:)))
        quitMode.setAccessibilityLabel(NSLocalizedString("Reset mode on quit", comment: ""))
        updateQuitControls()
        return pane([startAtLogin, startupRow, resetOnQuit, restoreStartup, quitMode])
    }

    private func advancedPane() -> NSView {
        let processes = checkbox("Always show all running processes", checked: preferences.showAllRunningProcesses,
                                 action: #selector(changeShowAll(_:)))
        let trigger = checkbox("Hide the trigger method selection section", checked: preferences.hideSwitchMethod,
                               action: #selector(changeTriggerSectionVisibility(_:)))

        let delayLabel = NSLocalizedString("Fn key release maximum delay", comment: "")
        let delay = NSTextField()
        let format = NumberFormatter()
        format.numberStyle = .decimal
        format.usesGroupingSeparator = false
        format.minimum = 5
        format.maximum = 650
        delay.formatter = format
        delay.doubleValue = preferences.fnKeyMaximumDelay
        delay.target = self
        delay.action = #selector(changeFnDelay(_:))
        (delay.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = true
        delay.setAccessibilityLabel(delayLabel)
        delay.widthAnchor.constraint(equalToConstant: 58).isActive = true

        let delayRow = NSStackView(views: [NSTextField(labelWithString: delayLabel), delay, NSTextField(labelWithString: "ms")])
        delayRow.orientation = .horizontal
        delayRow.alignment = .centerY
        return pane([processes, trigger, delayRow])
    }

    private func modeControl(_ selection: FKeyMode, action: Selector?) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: [FKeyMode.media.label, FKeyMode.function.label], trackingMode: .selectOne, target: self, action: action
        )
        control.selectedSegment = selection.rawValue
        return control
    }

    private func checkbox(_ title: String, checked: Bool, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: NSLocalizedString(title, comment: ""), target: self, action: action)
        button.state = checked ? .on : .off
        return button
    }

    private func pane(_ controls: [NSView]) -> NSView {
        let view = NSView()
        let stack = NSStackView(views: controls)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
        return view
    }

    /// Enable the quit mode only when a specific mode will be restored.
    private func updateQuitControls() {
        restoreStartup.isEnabled = preferences.shouldRestoreStateOnQuit
        quitMode.isEnabled = preferences.shouldRestoreStateOnQuit && !preferences.shouldRestorePreviousState
    }

    /// Select whether quitting restores a keyboard mode.
    @objc private func changeResetOnQuit(_ sender: NSButton) {
        preferences.shouldRestoreStateOnQuit = sender.state == .on
        updateQuitControls()
    }

    /// Select whether quitting restores the mode that was active before launch.
    @objc private func changeRestoreStartup(_ sender: NSButton) {
        preferences.shouldRestorePreviousState = sender.state == .on
        updateQuitControls()
    }

    /// Store the explicit mode to restore on quit.
    @objc private func changeQuitMode(_ sender: NSSegmentedControl) {
        guard let mode = FKeyMode(rawValue: sender.selectedSegment) else { return }
        preferences.onQuitState = mode
    }

    /// Set the default filter for the running applications window.
    @objc private func changeShowAll(_ sender: NSButton) {
        preferences.showAllRunningProcesses = sender.state == .on
    }

    /// Hide or show the menu section and restore application switching when hidden.
    @objc private func changeTriggerSectionVisibility(_ sender: NSButton) {
        let hidden = sender.state == .on
        preferences.hideSwitchMethod = hidden
        if hidden {
            preferences.switchMethod = .window
            postSwitchMethodDidChangeNotification(method: .window)
        }
        postTriggerSectionVisibilityDidChange(visible: !hidden)
    }

    /// Store the Fn tap cutoff after the field's formatter accepts the value.
    @objc private func changeFnDelay(_ sender: NSTextField) {
        guard let value = sender.objectValue as? NSNumber else {
            sender.doubleValue = preferences.fnKeyMaximumDelay
            return
        }
        preferences.fnKeyMaximumDelay = value.doubleValue
    }
}
