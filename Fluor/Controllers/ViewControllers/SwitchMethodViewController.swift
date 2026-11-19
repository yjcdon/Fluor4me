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
    private let methodControl = NSSegmentedControl()
    private lazy var permissionButton = NSButton(
        title: NSLocalizedString("Ask permission", comment: "Accessibility authorization"),
        target: self, action: #selector(askAccessibilityPermission(_:))
    )

    override func loadView() {
        let title = NSTextField(labelWithString: NSLocalizedString("Trigger", comment: "Menu row"))
        methodControl.segmentStyle = .rounded
        methodControl.trackingMode = .selectOne
        methodControl.controlSize = .small
        methodControl.segmentCount = 3
        methodControl.target = self
        methodControl.action = #selector(changeSwitchMethod(_:))
        methodControl.setAccessibilityLabel(title.stringValue)
        let toolTips = [
            NSLocalizedString("Change mode with the active application", comment: "Trigger option"),
            NSLocalizedString("Set mode for the active application when the fn key is pressed", comment: "Trigger option"),
            NSLocalizedString("Set the default mode when the fn key is pressed", comment: "Trigger option")
        ]
        for (index, icon) in [FluorIcon.activeApplication, .combinedTrigger, .fnKey].enumerated() {
            methodControl.setImage(icon.image(description: toolTips[index]), forSegment: index)
            methodControl.setWidth(32, forSegment: index)
            methodControl.setToolTip(toolTips[index], forSegment: index)
        }
        permissionButton.bezelStyle = .rounded
        permissionButton.controlSize = .small
        view = MenuItemView.row(title: title, controls: [methodControl, permissionButton])
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
