//
//  RunningAppsViewController.swift
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

final class RunningAppsViewController: NSViewController, NSTableViewDelegate {
    private let itemsArrayController = NSArrayController(content: [])
    private var tableContentAnimator: TableViewContentAnimator<RunningApp>?
    private var runningApps: [RunningApp] = [] {
        didSet { itemsArrayController.content = runningApps }
    }
    private var showAll = AppManager.default.showAllRunningProcesses
    private lazy var showAllButton = NSButton(title: "", target: self, action: #selector(toggleShowAll(_:)))

    override func loadView() {
        let list = ApplicationListView(controls: [showAllButton])
        view = list
        list.searchField.target = self
        list.searchField.action = #selector(filterApps(_:))
        list.tableView.delegate = self

        itemsArrayController.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
        ]
        reloadData()
        tableContentAnimator = TableViewContentAnimator(tableView: list.tableView, arrayController: itemsArrayController)
        refreshLanguage()
        let notifications = NSWorkspace.shared.notificationCenter
        notifications.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        notifications.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        tableContentAnimator = nil
    }

    private var showAllTitle: String {
        AppLanguage.text(showAll ? "Hide services" : "Show all")
    }

    /// Translate the running-app controls while preserving the current filters.
    func refreshLanguage() {
        guard isViewLoaded, let list = view as? ApplicationListView else { return }
        showAllButton.title = showAllTitle
        list.refreshLanguage(countFormat: "%{value1}@ running", items: itemsArrayController)
    }

    /// Show apps and background services or restrict the list to regular apps.
    @objc private func toggleShowAll(_ sender: NSButton) {
        showAll.toggle()
        sender.title = showAllTitle
        reloadData()
    }

    /// Filter the running-app list by its displayed names.
    @objc private func filterApps(_ sender: NSSearchField) {
        itemsArrayController.filterPredicate = sender.stringValue.isEmpty
            ? nil
            : NSPredicate(format: "name CONTAINS[cd] %@", sender.stringValue)
    }

    /// Include newly launched apps that match the current display option.
    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let item = makeRunningApp(app) else { return }
        runningApps.append(item)
    }

    /// Drop exited processes from the running list.
    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let index = runningApps.firstIndex(where: { $0.pid == app.processIdentifier }) else { return }
        runningApps.remove(at: index)
    }

    /// Refresh the list from the workspace using the current app/service filter.
    private func reloadData() {
        runningApps = NSWorkspace.shared.runningApplications.compactMap(makeRunningApp(_:))
    }

    private func makeRunningApp(_ app: NSRunningApplication) -> RunningApp? {
        guard let id = app.bundleIdentifier ?? app.executableURL?.lastPathComponent,
              let url = app.bundleURL ?? app.executableURL else { return nil }
        let isApp = app.activationPolicy == .regular
        guard showAll || isApp else { return nil }
        let behavior = AppManager.default.behaviorForApp(id: id)
        return RunningApp(id: id, url: url, behavior: behavior, pid: app.processIdentifier, isApp: isApp)
    }

    /// Populate a row that can change the app's rule without selecting the row.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let apps = itemsArrayController.arrangedObjects as? [RunningApp] else { return nil }
        let cell = tableView.makeView(withIdentifier: RuleCellView.cellIdentifier, owner: nil) as? RuleCellView
            ?? RuleCellView(allowsDefault: true)
        cell.display(apps[row])
        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
}
