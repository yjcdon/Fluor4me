import Cocoa
import Carbon.HIToolbox
import IOKit.hidsystem
import os.log

/// Handles the built-in keyboard's Chrome shortcuts while Chrome is active.
final class ChromeShortcuts {
    static let chromeID = "com.google.Chrome"

    private typealias KeyMapping = [String: UInt64]
    private static let mappingKey = "UserKeyMapping" as CFString
    private static let shortcutQueue = DispatchQueue(label: "com.yjcdon.Fluor4me.chromeShortcuts")
    private static let shortcutSlot = DispatchSemaphore(value: 1)
    private static let sourceKey = "HIDKeyboardModifierMappingSrc"
    private static let destinationKey = "HIDKeyboardModifierMappingDst"

    private struct Shortcut {
        let keyCode: Int
        let mapping: KeyMapping
        let recoveryKey: String
        let run: (NSRunningApplication, DispatchTime) -> Void
    }

    private static let shortcuts = [
        Shortcut(keyCode: kVK_F18, mapping: [sourceKey: 0xC00000221, destinationKey: 0x70000006D],
                 recoveryKey: "ChromeF4MappingNeedsCleanup", run: openSelection), // Spotlight.
        Shortcut(keyCode: kVK_F19, mapping: [sourceKey: 0xC000000CF, destinationKey: 0x70000006E],
                 recoveryKey: "ChromeF5MappingNeedsCleanup", run: duplicateTab) // Dictation.
    ]

    // Services borrow the client connection, including when used to restore a mapping.
    private lazy var hidClient = IOHIDEventSystemClientCreateSimpleClient(nil)
    private var tap: CFMachPort?
    private var keyboard: IOHIDServiceClient?
    private var mappedShortcuts: [Shortcut] = []

    /// Installs the available shortcuts while preserving existing mappings for the same keys.
    func activate() {
        guard keyboard == nil, AXIsProcessTrusted(), installEventTap(), let service = findKeyboard() else { return }

        let mappings = readMappings(on: service)
        let available = Self.shortcuts.filter { shortcut in
            let source = shortcut.mapping[Self.sourceKey]
            return !mappings.contains { $0[Self.sourceKey] == source }
        }
        guard !available.isEmpty else { return }

        for shortcut in available { UserDefaults.standard.set(true, forKey: shortcut.recoveryKey) }
        if IOHIDServiceClientSetProperty(service, Self.mappingKey, (mappings + available.map(\.mapping)) as NSArray) {
            keyboard = service
            mappedShortcuts = available
        } else {
            for shortcut in available { UserDefaults.standard.removeObject(forKey: shortcut.recoveryKey) }
            os_log("Could not enable Chrome shortcut mappings", type: .error)
        }
    }

    /// Removes Fluor's mappings while preserving the keyboard's other mappings.
    func deactivate() {
        guard let service = keyboard else { return }
        let mappings = readMappings(on: service)
        let owned = mappedShortcuts.map(\.mapping)
        let remaining = mappings.filter { !owned.contains($0) }
        if remaining == mappings ||
            IOHIDServiceClientSetProperty(service, Self.mappingKey, remaining as NSArray) {
            keyboard = nil
            for shortcut in mappedShortcuts { UserDefaults.standard.removeObject(forKey: shortcut.recoveryKey) }
            mappedShortcuts = []
        } else {
            os_log("Could not remove Chrome shortcut mappings", type: .error)
        }
    }

    /// Cleans up mappings left behind if Fluor was forced to quit, including by older versions.
    func recoverIfNeeded() {
        let pending = Self.shortcuts.filter { UserDefaults.standard.bool(forKey: $0.recoveryKey) }
        guard !pending.isEmpty, let service = findKeyboard() else { return }
        keyboard = service
        mappedShortcuts = pending
        deactivate()
    }

    private func findKeyboard() -> IOHIDServiceClient? {
        let services = IOHIDEventSystemClientCopyServices(hidClient) as? [IOHIDServiceClient] ?? []
        return services.first {
            IOHIDServiceClientConformsTo($0, 1, 6) != 0 &&
                IOHIDServiceClientCopyProperty($0, "Product" as CFString) as? String ==
                "Apple Internal Keyboard / Trackpad"
        }
    }

    private func readMappings(on service: IOHIDServiceClient) -> [KeyMapping] {
        IOHIDServiceClientCopyProperty(service, Self.mappingKey) as? [KeyMapping] ?? []
    }

    private func installEventTap() -> Bool {
        if let tap = tap { return CGEvent.tapIsEnabled(tap: tap) }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context = context else { return Unmanaged.passUnretained(event) }
                let shortcuts = Unmanaged<ChromeShortcuts>.fromOpaque(context).takeUnretainedValue()
                return shortcuts.handleEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else { return false }

        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard let shortcut = mappedShortcuts.first(where: { $0.keyCode == keyCode }),
              let chrome = NSWorkspace.shared.frontmostApplication,
              chrome.bundleIdentifier == Self.chromeID else {
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            Self.enqueue(shortcut, in: chrome)
        }
        return nil
    }

    /// Accepts one Chrome shortcut at a time. Busy presses are discarded at the event tap.
    private static func enqueue(_ shortcut: Shortcut, in chrome: NSRunningApplication) {
        guard shortcutSlot.wait(timeout: .now()) == .success else { return }
        let deadline = DispatchTime.now() + .seconds(1)
        shortcutQueue.async {
            defer { shortcutSlot.signal() }
            shortcut.run(chrome, deadline)
        }
    }

    /// Runs Chrome's own Duplicate Tab command in the focused regular or Incognito window.
    private static func duplicateTab(in chrome: NSRunningApplication, before deadline: DispatchTime) {
        let app = AXUIElementCreateApplication(chrome.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let menuBar = element(attribute(kAXMenuBarAttribute, of: app)) else { return }
        let commandTitles = ["Tab": "Duplicate Tab", "标签页": "复制标签", "分頁": "複製分頁"]
        for item in children(of: menuBar) {
            guard let title = attribute(kAXTitleAttribute, of: item) as? String,
                  let commandTitle = commandTitles[title] else { continue }
            let command = children(of: item).flatMap(children).first { command in
                attribute(kAXTitleAttribute, of: command) as? String == commandTitle &&
                    attribute(kAXIdentifierAttribute, of: command) as? String == "commandDispatch:"
            }
            if let command, attribute(kAXEnabledAttribute, of: command) as? Bool == true,
               chrome.isActive, DispatchTime.now() < deadline {
                AXUIElementPerformAction(command, kAXPressAction as CFString)
            }
            return
        }
    }

    private static func children(of item: AXUIElement) -> [AXUIElement] {
        attribute(kAXChildrenAttribute, of: item) as? [AXUIElement] ?? []
    }

    /// Opens a fresh selection in the source browsing mode.
    private static func openSelection(in chrome: NSRunningApplication, before deadline: DispatchTime) {
        let app = AXUIElementCreateApplication(chrome.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard DispatchTime.now() < deadline, chrome.isActive,
              let window = element(attribute(kAXFocusedWindowAttribute, of: app)),
              let selection = readSelection(in: app), DispatchTime.now() < deadline else { return }

        let switches = directOpenSwitches(for: window, page: selection.area, app: app, before: deadline)
        guard chrome.isActive, element(attribute(kAXFocusedWindowAttribute, of: app)) == window,
              DispatchTime.now() < deadline else { return }
        if let switches {
            // Chrome accepts "? <terms>" as a search using the selected profile's engine.
            let argument = webAddress(in: selection.text)?.absoluteString ?? "? " + selection.text
            if ChromeOpenRequest.send(argument, switches: switches, to: chrome, before: deadline) {
                return
            }
        }
        submitInWindow(selection.text, window: window, app: app, chrome: chrome, before: deadline)
    }

    /// Opens directly when the running Chrome instance can receive the request in the source mode.
    private static func directOpenSwitches(for window: AXUIElement, page: AXUIElement,
                                           app: AXUIElement, before deadline: DispatchTime) -> [String]? {
        guard let pageTitle = attribute(kAXTitleAttribute, of: page) as? String, !pageTitle.isEmpty,
              let title = attribute(kAXTitleAttribute, of: window) as? String else { return nil }
        let regularTitle = pageTitle + " - Google Chrome"
        if title == regularTitle { return [] }

        let incognitoLabels = [" (Incognito)", "（无痕）", "（無痕）"]
        guard incognitoLabels.contains(where: { title == regularTitle + $0 }),
              canRouteIncognito(in: app, before: deadline) else { return nil }

        // Chrome reuses the most recently active Incognito window in its current profile.
        return ["--incognito"]
    }

    /// Checks the current profile and Incognito availability from Chrome's own menus.
    private static func canRouteIncognito(in app: AXUIElement, before deadline: DispatchTime) -> Bool {
        guard DispatchTime.now() < deadline,
              let menuBar = element(attribute(kAXMenuBarAttribute, of: app)) else { return false }
        func currentChildren(of item: AXUIElement) -> [AXUIElement] {
            DispatchTime.now() < deadline ? children(of: item) : []
        }
        let items = currentChildren(of: menuBar).flatMap(currentChildren).flatMap(currentChildren)
        let profiles = items.filter {
            DispatchTime.now() < deadline &&
                attribute(kAXIdentifierAttribute, of: $0) as? String == "switchToProfileFromMenu:"
        }
        guard profiles.count == 1, let profile = profiles.first,
              let mark = attribute(kAXMenuItemMarkCharAttribute, of: profile) as? String,
              !mark.isEmpty else { return false }

        // In AX menu modifiers, Command is implicit and the low bit represents Shift.
        let commandShift = 1
        return items.contains { item in
            DispatchTime.now() < deadline &&
                (attribute(kAXMenuItemCmdCharAttribute, of: item) as? String)?.lowercased() == "n" &&
                attribute(kAXMenuItemCmdModifiersAttribute, of: item) as? Int == commandShift &&
                attribute(kAXEnabledAttribute, of: item) as? Bool == true
        }
    }

    /// Uses the source window's own address bar so Chrome keeps its mode and search settings.
    private static func submitInWindow(_ text: String, window: AXUIElement, app: AXUIElement,
                                       chrome: NSRunningApplication, before deadline: DispatchTime) {
        guard DispatchTime.now() < deadline, postKey(kVK_ANSI_L, flags: .maskCommand, to: chrome) else { return }
        while chrome.isActive && DispatchTime.now() < deadline {
            guard element(attribute(kAXFocusedWindowAttribute, of: app)) == window else { return }
            if let field = element(attribute(kAXFocusedUIElementAttribute, of: app)),
               let classes = attribute("AXDOMClassList", of: field) as? [String],
               classes.contains("OmniboxViewViews"), enclosingArea(of: field) == window {
                // AX writes bypass Chrome's protection for pasted script URLs.
                let schemeText = text.components(separatedBy: .controlCharacters).joined().lowercased()
                let input = schemeText.hasPrefix("javascript:") ? "? " + text :
                    webAddress(in: text)?.absoluteString ?? text
                guard DispatchTime.now() < deadline,
                      AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, input as CFString) == .success,
                      element(attribute(kAXFocusedUIElementAttribute, of: app)) == field,
                      DispatchTime.now() < deadline else { return }
                _ = postKey(kVK_Return, flags: .maskAlternate, to: chrome)
                return
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    /// Delivers an address-bar shortcut to the foreground Chrome process.
    private static func postKey(_ key: Int, flags: CGEventFlags, to chrome: NSRunningApplication) -> Bool {
        guard chrome.isActive,
              let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key), keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key), keyDown: false) else { return false }
        down.flags = flags
        up.flags = flags
        down.postToPid(chrome.processIdentifier)
        up.postToPid(chrome.processIdentifier)
        return true
    }

    /// Accepts a whole web address, including a bare domain, while leaving ordinary phrases to Chrome.
    static func webAddress(in text: String) -> URL? {
        guard text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        let explicit = text.lowercased().hasPrefix("https://") || text.lowercased().hasPrefix("http://")
        guard let parts = URLComponents(string: explicit ? text : "https://" + text),
              let host = parts.host, !host.isEmpty, parts.user == nil || explicit,
              explicit || host.contains(".") || host == "localhost" || host.hasPrefix("["),
              let url = parts.url else { return nil }
        return url
    }

    /// Reads the focused element or its containing web area, excluding browser UI and secure fields.
    private static func readSelection(in app: AXUIElement) -> (text: String, area: AXUIElement)? {
        guard let focused = element(attribute(kAXFocusedUIElementAttribute, of: app)),
              let area = enclosingArea(of: focused),
              attribute(kAXRoleAttribute, of: area) as? String == "AXWebArea" else { return nil }
        let role = attribute(kAXRoleAttribute, of: focused) as? String
        let target = role == kAXTextFieldRole || role == kAXTextAreaRole ? focused : area
        guard let selection = attribute(kAXSelectedTextAttribute, of: target) as? String else { return nil }
        let text = selection.components(separatedBy: .newlines.union(CharacterSet(charactersIn: "\t")))
            .joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return text.isEmpty ? nil : (text, area)
    }

    /// Distinguishes page content from native window controls, excluding secure fields.
    private static func enclosingArea(of field: AXUIElement) -> AXUIElement? {
        var current = field
        for _ in 0..<32 {
            if attribute(kAXSubroleAttribute, of: current) as? String == kAXSecureTextFieldSubrole { return nil }
            let role = attribute(kAXRoleAttribute, of: current) as? String
            if role == "AXWebArea" || role == kAXWindowRole { return current }
            guard let parent = element(attribute(kAXParentAttribute, of: current)) else { return nil }
            current = parent
        }
        return nil
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    deinit {
        deactivate()
        if let tap = tap { CFMachPortInvalidate(tap) }
    }
}
