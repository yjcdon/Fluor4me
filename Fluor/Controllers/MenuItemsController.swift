//
//  MenuItemsController.swift
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

final class MenuItemsController: NSObject, SwitchMethodDidChangeObserver, TriggerSectionVisibilityDidChangeObserver {
    private weak var menu: NSMenu?
    private let switchMethodViewController = SwitchMethodViewController()
    private let currentAppViewController = CurrentAppViewController()
    private let defaultModeViewController = DefaultModeViewController()

    init(menu: NSMenu, behaviorController: BehaviorController) {
        self.menu = menu
        super.init()
        defaultModeViewController.delegate = behaviorController
        startObservingSwitchMethodDidChange()
        startObservingTriggerSectionVisibilityDidChange()
    }

    deinit {
        stopObservingSwitchMethodDidChange()
        stopObservingTriggerSectionVisibilityDidChange()
    }

    /// Install the custom rows and restore the saved trigger presentation.
    func setupController() {
        menu?.item(withTag: 1)?.view = switchMethodViewController.view
        menu?.item(withTag: 3)?.view = defaultModeViewController.view
        menu?.item(withTag: 5)?.view = currentAppViewController.view
        setTriggerVisible(!AppManager.default.hideSwitchMethod)
        updateSwitchMethod(AppManager.default.switchMethod)
    }

    /// Update the custom menu rows in place.
    func refreshLanguage() {
        switchMethodViewController.refreshLanguage()
        currentAppViewController.refreshLanguage()
        defaultModeViewController.refreshLanguage()
    }

    /// Read preferences when the menu opens so edits from other windows are visible.
    func refreshControls(isEnabled: Bool, canSwitch: Bool) {
        updateSwitchMethod(AppManager.default.switchMethod)
        switchMethodViewController.updateAccessibility(canSwitch: canSwitch)
        defaultModeViewController.refreshControls(isEnabled: isEnabled)
        currentAppViewController.setControlsEnabled(isEnabled)
    }

    func switchMethodDidChange(notification: Notification) {
        guard let method = notification.userInfo?["method"] as? SwitchMethod else { return }
        updateSwitchMethod(method)
    }

    func triggerSectionVisibilityDidChange(notification: Notification) {
        guard let visible = notification.userInfo?["visible"] as? Bool else { return }
        setTriggerVisible(visible)
    }

    /// Keep the current-application row compact in global Fn mode.
    private func updateSwitchMethod(_ method: SwitchMethod) {
        switchMethodViewController.selectMethod(method)
        let compact = method == .key
        guard compact != (currentAppViewController.currentSwitchMethod == .key) else { return }
        if compact {
            currentAppViewController.shrinkView()
        } else {
            currentAppViewController.expandView()
        }
    }

    /// Hide the section and its accompanying divider together.
    private func setTriggerVisible(_ visible: Bool) {
        menu?.item(withTag: 1)?.isHidden = !visible
        menu?.item(withTag: 2)?.isHidden = !visible
    }
}

extension MenuItemView {
    /// Lay out a menu title with its controls at the trailing edge.
    static func row(title: NSTextField, controls: [NSControl]) -> MenuItemView {
        let row = MenuItemView(frame: NSRect(x: 0, y: 0, width: 269, height: 27))
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(title)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            title.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        for control in controls {
            control.translatesAutoresizingMaskIntoConstraints = false
            control.setContentCompressionResistancePriority(.required, for: .horizontal)
            row.addSubview(control)
            NSLayoutConstraint.activate([
                control.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 8),
                control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
                control.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])
        }
        return row
    }
}
