import AppKit

enum FluorIcon: String {
    case mediaKeys = "sun.max"
    case functionKeys = "keyboard"
    case paused = "pause.circle"
    case defaultMode = "arrow.uturn.backward"
    case activeApplication = "macwindow"
    case combinedTrigger = "arrow.left.arrow.right"
    case fnKey = "keyboard.chevron.compact.down"
    case rules = "list.bullet"
    case runningApps = "square.stack"
    case settings = "gearshape"
    case advanced = "slider.horizontal.3"
    case about = "info.circle"
    case quit = "power"
    case service = "gearshape.2"
    case add = "plus"
    case remove = "minus"

    /// Use the system symbol as a template so AppKit handles appearance and selection.
    func image(size: CGFloat = 13, description: String? = nil) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let image = NSImage(systemSymbolName: rawValue, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}

extension FKeyMode {
    var icon: FluorIcon { self == .media ? .mediaKeys : .functionKeys }
}

extension AppBehavior {
    var icon: FluorIcon {
        switch self {
        case .inferred: return .defaultMode
        case .media: return .mediaKeys
        case .function: return .functionKeys
        }
    }
}
