//
//  DefaultModeViewController.swift
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

protocol DefaultModeViewControllerDelegate: AnyObject {
    func defaultModeController(_ controller: DefaultModeViewController, didChangeModeTo mode: FKeyMode)
}

final class DefaultModeViewController: NSViewController {
    weak var delegate: DefaultModeViewControllerDelegate?

    private let titleLabel = NSTextField(labelWithString: NSLocalizedString("Default mode", comment: "Menu row"))
    private let modeControl = NSSegmentedControl()

    override func loadView() {
        modeControl.segmentStyle = .rounded
        modeControl.trackingMode = .selectOne
        modeControl.controlSize = .small
        modeControl.segmentCount = 2
        modeControl.target = self
        modeControl.action = #selector(changeMode(_:))
        modeControl.setAccessibilityLabel(titleLabel.stringValue)
        for (mode, image) in [(FKeyMode.media, "AppleMode"), (.function, "OtherMode")] {
            if let icon = FluorImage.named(image) {
                modeControl.setImage(icon, forSegment: mode.rawValue)
                modeControl.setWidth(32, forSegment: mode.rawValue)
            } else {
                modeControl.setLabel(mode.label, forSegment: mode.rawValue)
            }
            modeControl.setToolTip(mode.label, forSegment: mode.rawValue)
        }
        view = MenuItemView.row(title: titleLabel, controls: [modeControl])
    }

    /// Show the saved fallback mode and disable editing while keyboard management is paused.
    func refreshControls(isEnabled: Bool) {
        titleLabel.isEnabled = isEnabled
        modeControl.isEnabled = isEnabled
        modeControl.selectedSegment = AppManager.default.defaultFKeyMode.rawValue
    }

    /// Persist the default keyboard mode before asking the keyboard controller to apply it.
    @objc private func changeMode(_ sender: NSSegmentedControl) {
        guard let mode = FKeyMode(rawValue: sender.selectedSegment) else { return }
        AppManager.default.defaultFKeyMode = mode
        delegate?.defaultModeController(self, didChangeModeTo: mode)
    }
}
