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
    private static let languageKey = "AppleLanguages"
    private static let languageAtLaunch = Bundle.main.preferredLocalizations.first ?? "en"

    private let preferences = AppManager.default
    private let loginController = LaunchAtLoginController()
    private lazy var restoreStartup = checkbox("Restore startup mode", checked: preferences.shouldRestorePreviousState,
                                               action: #selector(changeRestoreStartup(_:)))
    private lazy var quitMode = modeControl(preferences.onQuitState, action: #selector(changeQuitMode(_:)))
    private lazy var languageRestartHint: NSTextField = {
        let text = NSLocalizedString("Quit and reopen Fluor4me to apply.", comment: "Language setting")
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        tabStyle = .toolbar
        canPropagateSelectedChildViewControllerTitle = false
        addTab("General", icon: .settings, controller: generalPane())
        addTab("Advanced", icon: .advanced, controller: advancedPane())
        addTab("About", icon: .about, controller: AboutViewController())
    }

    private func addTab(_ title: String, icon: FluorIcon, controller: NSViewController) {
        let item = NSTabViewItem(viewController: controller)
        item.label = NSLocalizedString(title, comment: "Settings tab")
        item.image = icon.image(size: 17)
        addTabViewItem(item)
    }

    private func generalPane() -> NSViewController {
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
        return pane([languageRow(), languageRestartHint, startAtLogin, startupRow, resetOnQuit, restoreStartup, quitMode])
    }

    private func languageRow() -> NSView {
        let title = NSLocalizedString("Language", comment: "Language setting")
        let popup = NSPopUpButton()
        for (identifier, name) in [("zh-Hans", "简体中文"), ("en", "English")] {
            popup.addItem(withTitle: name)
            popup.lastItem?.representedObject = identifier
        }
        let preferred = UserDefaults.standard.stringArray(forKey: Self.languageKey)?.first
        let preferredItem = popup.itemArray.first { ($0.representedObject as? String) == preferred }
        let currentItem = popup.itemArray.first { ($0.representedObject as? String) == Self.languageAtLaunch }
        popup.select(preferredItem ?? currentItem)
        popup.setAccessibilityLabel(title)
        popup.target = self
        popup.action = #selector(changeLanguage(_:))
        languageRestartHint.isHidden = popup.selectedItem == currentItem

        let row = NSStackView(views: [NSTextField(labelWithString: title), popup])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    /// Set the bundle's language for the next launch without changing the system language.
    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard let identifier = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set([identifier], forKey: Self.languageKey)
        languageRestartHint.isHidden = identifier == Self.languageAtLaunch
    }

    private func advancedPane() -> NSViewController {
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
