import Cocoa
import Carbon.HIToolbox
import IOKit.hidsystem
import os.log

/// Replaces Spotlight on the built-in keyboard while Chrome is active.
final class ChromeF4Shortcut {
    static let chromeID = "com.google.Chrome"

    private typealias KeyMapping = [String: UInt64]
    private static let mappingKey = "UserKeyMapping" as CFString
    private static let selectionQueue = DispatchQueue(label: "com.yjcdon.Fluor4me.selection")
    private static let recoveryKey = "ChromeF4MappingNeedsCleanup"
    private static let sourceKey = "HIDKeyboardModifierMappingSrc"
    private static let mapping: KeyMapping = [
        sourceKey: 0xC00000221, // Consumer AC Search, emitted by F4 in media mode.
        "HIDKeyboardModifierMappingDst": 0x70000006D // Keyboard F18.
    ]

    // Services borrow the client connection, including when used to restore a mapping.
    private lazy var hidClient = IOHIDEventSystemClientCreateSimpleClient(nil)
    private var tap: CFMachPort?
    private var keyboard: IOHIDServiceClient?

    /// Installs the single-key mapping once Fluor can read the Chrome selection.
    func activate() {
        guard keyboard == nil, AXIsProcessTrusted(), installEventTap() else { return }
        guard let service = findKeyboard() else { return }

        let mappings = readMappings(on: service)
        guard !mappings.contains(where: { $0[Self.sourceKey] == Self.mapping[Self.sourceKey] }) else { return }
        UserDefaults.standard.set(true, forKey: Self.recoveryKey)
        if IOHIDServiceClientSetProperty(service, Self.mappingKey, (mappings + [Self.mapping]) as NSArray) {
            keyboard = service
        } else {
            UserDefaults.standard.removeObject(forKey: Self.recoveryKey)
            os_log("Could not enable Chrome F4 mapping", type: .error)
        }
    }

    /// Removes Fluor's mapping while preserving the keyboard's other mappings.
    func deactivate() {
        guard let service = keyboard else { return }
        let mappings = readMappings(on: service)
        let remaining = mappings.filter { $0 != Self.mapping }
        if remaining == mappings ||
            IOHIDServiceClientSetProperty(service, Self.mappingKey, remaining as NSArray) {
            keyboard = nil
            UserDefaults.standard.removeObject(forKey: Self.recoveryKey)
        } else {
            os_log("Could not remove Chrome F4 mapping", type: .error)
        }
    }

    /// Cleans up a mapping left behind if Fluor was forced to quit.
    func recoverIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Self.recoveryKey) else { return }
        keyboard = findKeyboard()
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
                let shortcut = Unmanaged<ChromeF4Shortcut>.fromOpaque(context).takeUnretainedValue()
                return shortcut.handleEvent(type: type, event: event)
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
        guard keyboard != nil,
              event.getIntegerValueField(.keyboardEventKeycode) == kVK_F18,
              let chrome = NSWorkspace.shared.frontmostApplication,
              chrome.bundleIdentifier == Self.chromeID else {
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            // AX requests can wait for Chrome. Keep them out of the event-tap callback.
            Self.selectionQueue.async { Self.openSelection(in: chrome) }
        }
        return nil
    }

    /// Opens the result in the source browsing mode, using direct requests when Chrome can route them.
    private static func openSelection(in chrome: NSRunningApplication) {
        let app = AXUIElementCreateApplication(chrome.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard chrome.isActive, let window = element(attribute(kAXFocusedWindowAttribute, of: app)),
              let selection = readSelection(in: app) else { return }

        let switches = directOpenSwitches(for: window, page: selection.area, app: app, chrome: chrome)
        guard chrome.isActive, element(attribute(kAXFocusedWindowAttribute, of: app)) == window else { return }
        if let switches, let executable = chrome.executableURL {
            openDirectly(selection.text, with: executable, switches: switches)
        } else {
            submitInWindow(selection.text, window: window, app: app, chrome: chrome)
        }
    }

    /// Uses explicit Incognito routing only when Chrome's singleton and profile identify the source session.
    private static func directOpenSwitches(for window: AXUIElement, page: AXUIElement,
                                           app: AXUIElement, chrome: NSRunningApplication) -> [String]? {
        guard let pageTitle = attribute(kAXTitleAttribute, of: page) as? String, !pageTitle.isEmpty,
              let title = attribute(kAXTitleAttribute, of: window) as? String else { return nil }
        let regularTitle = pageTitle + " - Google Chrome"
        if title == regularTitle { return [] }

        let incognitoLabels = [" (Incognito)", "（无痕）", "（無痕）"]
        guard incognitoLabels.contains(where: { title == regularTitle + $0 }),
              canRouteIncognito(in: app) else { return nil }

        let files = FileManager.default
        let dataDirectory = files.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        let lock = dataDirectory.appendingPathComponent("SingletonLock")
        guard let lockTarget = try? files.destinationOfSymbolicLink(atPath: lock.path),
              Int32(lockTarget.split(separator: "-").last ?? "") == chrome.processIdentifier else { return nil }

        // Chrome reuses the most recently active Incognito window in its current profile.
        return ["--user-data-dir=" + dataDirectory.path, "--incognito"]
    }

    /// Checks the current profile and Incognito availability from Chrome's own menus.
    private static func canRouteIncognito(in app: AXUIElement) -> Bool {
        guard let menuBar = element(attribute(kAXMenuBarAttribute, of: app)) else { return false }
        func children(of item: AXUIElement) -> [AXUIElement] {
            attribute(kAXChildrenAttribute, of: item) as? [AXUIElement] ?? []
        }
        let items = children(of: menuBar).flatMap(children).flatMap(children)
        let profiles = items.filter {
            attribute(kAXIdentifierAttribute, of: $0) as? String == "switchToProfileFromMenu:"
        }
        guard profiles.count == 1, let profile = profiles.first,
              let mark = attribute(kAXMenuItemMarkCharAttribute, of: profile) as? String,
              !mark.isEmpty else { return false }

        // In AX menu modifiers, Command is implicit and the low bit represents Shift.
        let commandShift = 1
        return items.contains { item in
            (attribute(kAXMenuItemCmdCharAttribute, of: item) as? String)?.lowercased() == "n" &&
                attribute(kAXMenuItemCmdModifiersAttribute, of: item) as? Int == commandShift &&
                attribute(kAXEnabledAttribute, of: item) as? Bool == true
        }
    }

    /// Sends one URL or search argument to the running Chrome session without focusing its address bar.
    private static func openDirectly(_ text: String, with executable: URL, switches: [String]) {
        let request = Process()
        request.executableURL = executable
        // Chrome accepts "? <terms>" as an explicit search.
        request.arguments = switches + ["--", webAddress(in: text)?.absoluteString ?? "? " + text]
        request.standardOutput = FileHandle.nullDevice
        request.standardError = FileHandle.nullDevice
        do {
            try request.run()
        } catch {
            os_log("Could not send the F4 selection to Chrome: %{public}@", type: .error, error.localizedDescription)
        }
    }

    /// Uses the source window's own address bar so Chrome keeps its mode and search settings.
    private static func submitInWindow(_ text: String, window: AXUIElement, app: AXUIElement,
                                       chrome: NSRunningApplication) {
        guard postKey(kVK_ANSI_L, flags: .maskCommand, to: chrome) else { return }
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while chrome.isActive && ProcessInfo.processInfo.systemUptime < deadline {
            guard element(attribute(kAXFocusedWindowAttribute, of: app)) == window else { return }
            if let field = element(attribute(kAXFocusedUIElementAttribute, of: app)),
               let classes = attribute("AXDOMClassList", of: field) as? [String],
               classes.contains("OmniboxViewViews"), enclosingArea(of: field) == window {
                // AX writes bypass Chrome's protection for pasted script URLs.
                let schemeText = text.components(separatedBy: .controlCharacters).joined().lowercased()
                let input = schemeText.hasPrefix("javascript:") ? "? " + text :
                    webAddress(in: text)?.absoluteString ?? text
                guard AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, input as CFString) == .success,
                      element(attribute(kAXFocusedUIElementAttribute, of: app)) == field else { return }
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
