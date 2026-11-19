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
    private let aboutController = AboutViewController()
    private var languageUpdates: [() -> Void] = []
    private lazy var restoreStartup = checkbox("Restore startup mode", checked: preferences.shouldRestorePreviousState,
                                               action: #selector(changeRestoreStartup(_:)))
    private lazy var quitMode = modeControl(preferences.onQuitState, action: #selector(changeQuitMode(_:)))

    override func viewDidLoad() {
        super.viewDidLoad()
        tabStyle = .toolbar
        canPropagateSelectedChildViewControllerTitle = false
        addTab("General", icon: .settings, controller: generalPane())
        addTab("Advanced", icon: .advanced, controller: advancedPane())
        addTab("About", icon: .about, controller: aboutController)
    }

    private func addTab(_ title: String, icon: FluorIcon, controller: NSViewController) {
        let item = NSTabViewItem(viewController: controller)
        localize { item.label = AppLanguage.text(title) }
        item.image = icon.image(size: 17)
        addTabViewItem(item)
    }

    /// Keep the selected tab and controls, refreshing only their display text.
    func refreshLanguage() {
        languageUpdates.forEach { $0() }
        aboutController.refreshLanguage()
    }

    private func localize(_ update: @escaping () -> Void) {
        update()
        languageUpdates.append(update)
    }

    private func generalPane() -> NSViewController {
        let startAtLogin = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        localize { startAtLogin.title = AppLanguage.text("Start Fluor at login") }
        startAtLogin.bind(.value, to: loginController, withKeyPath: #keyPath(LaunchAtLoginController.launchAtLogin))

        let startupLabel = NSTextField(labelWithString: "")
        let startup = modeControl(preferences.defaultFKeyMode, action: nil)
        startup.bind(.selectedIndex, to: NSUserDefaultsController.shared, withKeyPath: "values.DefaultKeyboardMode",
                     options: [.nullPlaceholder: FKeyMode.media.rawValue])
        localize {
            startupLabel.stringValue = AppLanguage.text("Default mode on launch")
            startup.setAccessibilityLabel(startupLabel.stringValue)
        }
        let startupRow = NSStackView(views: [startupLabel, startup])
        startupRow.orientation = .horizontal
        startupRow.alignment = .centerY

        let resetOnQuit = checkbox("Reset mode on quit", checked: preferences.shouldRestoreStateOnQuit,
                                   action: #selector(changeResetOnQuit(_:)))
        let quitMode = self.quitMode
        localize { quitMode.setAccessibilityLabel(AppLanguage.text("Reset mode on quit")) }
        updateQuitControls()
        return pane([languageRow(), startAtLogin, startupRow, resetOnQuit, restoreStartup, quitMode])
    }

    private func languageRow() -> NSView {
        let title = NSTextField(labelWithString: "")
        let popup = NSPopUpButton()
        for language in AppLanguage.allCases {
            popup.addItem(withTitle: language.name)
        }
        localize {
            title.stringValue = AppLanguage.text("Language")
            popup.setAccessibilityLabel(title.stringValue)
            popup.selectItem(withTitle: AppLanguage.current.name)
        }
        popup.target = self
        popup.action = #selector(changeLanguage(_:))

        let row = NSStackView(views: [title, popup])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    /// Apply the chosen language immediately and remember it for future launches.
    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard let language = AppLanguage.allCases.first(where: { $0.name == sender.titleOfSelectedItem }) else { return }
        AppLanguage.select(language)
    }

    private func advancedPane() -> NSViewController {
        let processes = checkbox("Always show all running processes", checked: preferences.showAllRunningProcesses,
                                 action: #selector(changeShowAll(_:)))
        let trigger = checkbox("Hide the trigger method selection section", checked: preferences.hideSwitchMethod,
                               action: #selector(changeTriggerSectionVisibility(_:)))

        let delayLabel = NSTextField(labelWithString: "")
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
        localize {
            delayLabel.stringValue = AppLanguage.text("Fn key release maximum delay")
            delay.setAccessibilityLabel(delayLabel.stringValue)
        }
        delay.widthAnchor.constraint(equalToConstant: 58).isActive = true

        let delayRow = NSStackView(views: [delayLabel, delay, NSTextField(labelWithString: "ms")])
        delayRow.orientation = .horizontal
        delayRow.alignment = .centerY
        return pane([processes, trigger, delayRow])
    }

    private func modeControl(_ selection: FKeyMode, action: Selector?) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: [FKeyMode.media.label, FKeyMode.function.label], trackingMode: .selectOne, target: self, action: action
        )
        localize {
            control.setLabel(FKeyMode.media.label, forSegment: FKeyMode.media.rawValue)
            control.setLabel(FKeyMode.function.label, forSegment: FKeyMode.function.rawValue)
        }
        control.selectedSegment = selection.rawValue
        return control
    }

    private func checkbox(_ title: String, checked: Bool, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: "", target: self, action: action)
        localize { button.title = AppLanguage.text(title) }
        button.state = checked ? .on : .off
        return button
    }

    private func pane(_ controls: [NSView]) -> NSViewController {
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
        let controller = NSViewController()
        controller.view = view
        return controller
    }

    /// Show the fixed mode only when it will apply on quit.
    private func updateQuitControls() {
        restoreStartup.isEnabled = preferences.shouldRestoreStateOnQuit
        quitMode.isHidden = !preferences.shouldRestoreStateOnQuit || preferences.shouldRestorePreviousState
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
