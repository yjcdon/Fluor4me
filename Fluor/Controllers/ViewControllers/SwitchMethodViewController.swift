//
//  SwitchModeViewController.swift
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

final class SwitchMethodViewController: NSViewController, SwitchMethodDidChangePoster {
    private let titleLabel = NSTextField(labelWithString: "")
    private let methodControl = NSSegmentedControl()
    private lazy var permissionButton = NSButton(
        title: "", target: self, action: #selector(askAccessibilityPermission(_:))
    )

    override func loadView() {
        methodControl.segmentStyle = .rounded
        methodControl.trackingMode = .selectOne
        methodControl.controlSize = .small
        methodControl.segmentCount = 3
        methodControl.target = self
        methodControl.action = #selector(changeSwitchMethod(_:))
        permissionButton.bezelStyle = .rounded
        permissionButton.controlSize = .small
        refreshLanguage()
        view = MenuItemView.row(title: titleLabel, controls: [methodControl, permissionButton])
    }

    /// Translate the trigger choices and permission action.
    func refreshLanguage() {
        titleLabel.stringValue = AppLanguage.text("Trigger")
        methodControl.setAccessibilityLabel(titleLabel.stringValue)
        permissionButton.title = AppLanguage.text("Ask permission")
        let toolTips = [
            AppLanguage.text("Change mode with the active application"),
            AppLanguage.text("Set mode for the active application when the fn key is pressed"),
            AppLanguage.text("Set the default mode when the fn key is pressed")
        ]
        for (index, icon) in [FluorIcon.activeApplication, .combinedTrigger, .fnKey].enumerated() {
            methodControl.setImage(icon.image(description: toolTips[index]), forSegment: index)
            methodControl.setWidth(32, forSegment: index)
            methodControl.setToolTip(toolTips[index], forSegment: index)
        }
    }

    /// Show permission recovery until macOS grants access for the Fn shortcut.
    func updateAccessibility(canSwitch: Bool) {
        methodControl.isHidden = !canSwitch
        permissionButton.isHidden = canSwitch
    }

    /// Reflect the saved trigger when changed by another window.
    func selectMethod(_ method: SwitchMethod) {
        methodControl.selectedSegment = method.rawValue
    }

    /// Persist the trigger so menu and keyboard observers use the same value.
    @objc private func changeSwitchMethod(_ sender: NSSegmentedControl) {
        guard let method = SwitchMethod(rawValue: sender.selectedSegment) else { return }
        AppManager.default.switchMethod = method
        postSwitchMethodDidChangeNotification(method: method)
    }

    /// Close the menu before requesting permission through the system.
    @objc private func askAccessibilityPermission(_ sender: Any) {
        view.enclosingMenuItem?.menu?.cancelTracking()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
