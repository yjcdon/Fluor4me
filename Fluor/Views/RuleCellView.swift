//
//  RuleCellView.swift
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

final class RuleCellView: NSTableCellView {
    static let cellIdentifier = NSUserInterfaceItemIdentifier("ApplicationCell")

    private let modeControl = NSSegmentedControl()
    private let kindImageView = NSImageView()
    private let behaviors: [AppBehavior]
    private var behaviorObservation: NSKeyValueObservation?

    /// Show an app icon, name and its allowed keyboard modes.
    init(allowsDefault: Bool) {
        behaviors = allowsDefault ? [.inferred, .media, .function] : [.media, .function]
        super.init(frame: .zero)
        identifier = Self.cellIdentifier

        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        imageView = icon
        let name = NSTextField(labelWithString: "")
        name.lineBreakMode = .byTruncatingTail
        textField = name
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        modeControl.segmentCount = behaviors.count
        modeControl.trackingMode = .selectOne
        modeControl.target = self
        modeControl.action = #selector(changeMode(_:))
        for (index, behavior) in behaviors.enumerated() {
            if let image = behavior.icon.image(description: behavior.label) {
                modeControl.setImage(image, forSegment: index)
            } else {
                modeControl.setLabel(behavior.label, forSegment: index)
            }
            modeControl.setToolTip(behavior.label, forSegment: index)
        }
        modeControl.setContentCompressionResistancePriority(.required, for: .horizontal)

        var views: [NSView] = [icon, name, modeControl]
        if allowsDefault { views.append(kindImageView) }
        let row = NSStackView(views: views)
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalTo: icon.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Refresh a reused row and track edits from the other rule entry points.
    func display(_ item: Item) {
        objectValue = item
        imageView?.image = item.icon
        toolTip = item.url.path
        textField?.stringValue = item.name
        if let runningApp = item as? RunningApp {
            kindImageView.image = (runningApp.isApp ? FluorIcon.activeApplication : .service).image()
        }
        modeControl.selectedSegment = behaviors.firstIndex(of: item.behavior) ?? -1
        behaviorObservation = item.observe(\.behavior) { [weak self] item, _ in
            guard let self else { return }
            self.modeControl.selectedSegment = self.behaviors.firstIndex(of: item.behavior) ?? -1
        }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            textField?.textColor = backgroundStyle == .emphasized ? .selectedMenuItemTextColor : .textColor
        }
    }

    /// Apply the selection through the same rules store as the menu.
    @objc private func changeMode(_ sender: NSSegmentedControl) {
        guard let item = objectValue as? Item, behaviors.indices.contains(sender.selectedSegment) else { return }
        let behavior = behaviors[sender.selectedSegment]
        guard item.behavior != behavior else { return }
        let url = AppManager.default.rules.first { $0.id == item.id }?.url ?? item.url
        AppManager.default.propagate(behavior: behavior, forApp: item.id, at: url, from: item.notificationSource)
    }
}
