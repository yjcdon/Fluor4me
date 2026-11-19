//
//  AppDelegate.swift
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

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusMenuController = StatusMenuController()

    /// Start the menu bar application without loading a main nib.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.mainMenu = makeMainMenu()
        app.run()
        withExtendedLifetime(delegate) {}
    }

    /// Route Command-W through AppKit to the front window, including for a menu bar app.
    private static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let fileMenu = NSMenu()
        let fileItem = NSMenuItem()
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)
        fileMenu.addItem(
            withTitle: NSLocalizedString("Close Window", comment: ""),
            action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"
        )
        return mainMenu
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        migratePreferences()
        // Check accessibility
        if !AXIsProcessTrusted() && !AppManager.default.hasAlreadyAnsweredAccessibility {
            let options : NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
            AXIsProcessTrustedWithOptions(options)
            AppManager.default.hasAlreadyAnsweredAccessibility = true
        }
        
        statusMenuController.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusMenuController.behaviorController.performTerminationCleaning()
    }

    /// Import preferences once after the menu bar registration changes bundle identifiers.
    private func migratePreferences() {
        let defaults = UserDefaults.standard
        let migrationKey = "MigratedFluor4mePreferences"
        guard let identifier = Bundle.main.bundleIdentifier,
              identifier == "io.github.yjcdon.Fluor4me",
              !defaults.bool(forKey: migrationKey) else { return }

        var current = defaults.persistentDomain(forName: identifier) ?? [:]
        let previous = defaults.persistentDomain(forName: "com.yjcdon.Fluor4me") ?? [:]
        for (key, value) in previous where current[key] == nil &&
            !key.hasPrefix("NSStatusItem ") && key != "HasAlreadyRefusedAccessibility" {
            current[key] = value
        }
        current[migrationKey] = true
        defaults.setPersistentDomain(current, forName: identifier)
    }

}
