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
            Self.selectionQueue.async { Self.searchSelection(in: chrome) }
        }
        return nil
    }

    /// Searches only text selected in the focused Chrome web page.
    static func searchSelection(in chrome: NSRunningApplication) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == chrome.processIdentifier,
              let text = readSelection(in: chrome), let bundleURL = chrome.bundleURL else { return }
        var search = URLComponents()
        search.scheme = "https"
        search.host = "www.google.com"
        search.path = "/search"
        search.queryItems = [URLQueryItem(name: "q", value: text)]
        search.percentEncodedQuery = search.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = search.url,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == chrome.processIdentifier else { return }
        if #available(macOS 10.15, *) {
            NSWorkspace.shared.open([url], withApplicationAt: bundleURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        } else {
            _ = try? NSWorkspace.shared.open([url], withApplicationAt: bundleURL, options: [], configuration: [:])
        }
    }

    /// Reads the focused element or its containing web area, excluding browser UI and secure fields.
    static func readSelection(in chrome: NSRunningApplication) -> String? {
        let app = AXUIElementCreateApplication(chrome.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let focused = element(attribute(kAXFocusedUIElementAttribute, of: app)) else { return nil }
        let focusedRole = attribute(kAXRoleAttribute, of: focused) as? String
        var current = focused
        for _ in 0..<32 {
            if attribute(kAXSubroleAttribute, of: current) as? String == kAXSecureTextFieldSubrole {
                return nil
            }
            if attribute(kAXRoleAttribute, of: current) as? String == "AXWebArea" {
                let target = focusedRole == kAXTextFieldRole || focusedRole == kAXTextAreaRole ? focused : current
                let text = (attribute(kAXSelectedTextAttribute, of: target) as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return text?.isEmpty == false ? text : nil
            }
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
