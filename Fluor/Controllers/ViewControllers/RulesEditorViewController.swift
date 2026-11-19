//
//  RulesEditorViewController.swift
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
import UniformTypeIdentifiers

final class RulesEditorViewController: NSViewController, NSTableViewDelegate, BehaviorDidChangeObserver {
    private let itemsArrayController = NSArrayController(content: [])
    private var tableContentAnimator: TableViewContentAnimator<Rule>?
    private lazy var addButton = NSButton(image: FluorIcon.add.image() ?? NSImage(),
                                         target: self, action: #selector(addRule))
    private lazy var removeButton = NSButton(image: FluorIcon.remove.image() ?? NSImage(),
                                            target: self, action: #selector(removeRule))

    override func loadView() {
        let list = ApplicationListView(controls: [addButton, removeButton])
        view = list
        list.searchField.target = self
        list.searchField.action = #selector(filterRules(_:))
        list.tableView.delegate = self
        list.tableView.bind(.selectionIndexes, to: itemsArrayController, withKeyPath: "selectionIndexes")
        removeButton.bind(.enabled, to: itemsArrayController, withKeyPath: "canRemove")

        itemsArrayController.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
        ]
        itemsArrayController.content = Array(AppManager.default.rules)
        tableContentAnimator = TableViewContentAnimator(tableView: list.tableView, arrayController: itemsArrayController)
        refreshLanguage()
        startObservingBehaviorDidChange()
    }

    /// Translate the rule editor's controls without rerunning its search.
    func refreshLanguage() {
        guard isViewLoaded, let list = view as? ApplicationListView else { return }
        for (button, key) in [(addButton, "Add rule"), (removeButton, "Delete selected rule")] {
            let title = AppLanguage.text(key)
            button.toolTip = title
            button.setAccessibilityLabel(title)
            button.image?.accessibilityDescription = title
        }
        list.refreshLanguage(countFormat: "%{value1}@ rules", items: itemsArrayController)
    }

    deinit {
        stopObservingBehaviorDidChange()
        tableContentAnimator = nil
    }

    /// Use the sorted, filtered rules to populate reusable table rows.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let rules = itemsArrayController.arrangedObjects as? [Rule] else { return nil }
        let cell = tableView.makeView(withIdentifier: RuleCellView.cellIdentifier, owner: nil) as? RuleCellView
            ?? RuleCellView(allowsDefault: false)
        cell.display(rules[row])
        return cell
    }

    /// Reload from the saved rules after any of the app's rule controls changes a behavior.
    func behaviorDidChangeForApp(notification: Notification) {
        itemsArrayController.content = Array(AppManager.default.rules)
    }

    /// Filter the current list without changing the saved rules.
    @objc private func filterRules(_ sender: NSSearchField) {
        itemsArrayController.filterPredicate = sender.stringValue.isEmpty
            ? nil
            : NSPredicate(format: "name CONTAINS[cd] %@", sender.stringValue)
    }

    /// Add rules for the applications selected in the open panel.
    @objc private func addRule() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }

        let manager = AppManager.default
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
            let ruleURL = manager.rules.first { $0.id == id }?.url ?? url
            manager.propagate(behavior: .media, forApp: id, at: ruleURL, from: .rule)
        }
    }

    /// Remove the selected rule by returning it to the global default.
    @objc private func removeRule() {
        guard let rules = itemsArrayController.selectedObjects as? [Rule] else { return }
        for rule in rules {
            AppManager.default.propagate(behavior: .inferred, forApp: rule.id, at: rule.url, from: .rule)
        }
    }
}
