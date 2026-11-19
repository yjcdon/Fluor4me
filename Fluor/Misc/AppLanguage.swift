import Foundation

enum AppLanguage: String, CaseIterable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    static let didChange = Notification.Name("Fluor4meLanguageDidChange")
    private static let preferenceKey = "AppleLanguages"
    private static let launchLanguage = Bundle.main.preferredLocalizations.first.flatMap(Self.init(rawValue:)) ?? .english
    private static let bundles = Dictionary(uniqueKeysWithValues: allCases.compactMap { language in
        Bundle.main.url(forResource: language.rawValue, withExtension: "lproj")
            .flatMap(Bundle.init(url:)).map { (language, $0) }
    })

    var name: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }

    static var current: Self {
        UserDefaults.standard.stringArray(forKey: preferenceKey)?.first.flatMap(Self.init(rawValue:)) ?? launchLanguage
    }

    /// Save the choice in the app's preferences and refresh its current interface.
    static func select(_ language: Self) {
        guard language != current else { return }
        UserDefaults.standard.set([language.rawValue], forKey: preferenceKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func text(_ key: String) -> String {
        bundles[current]?.localizedString(forKey: key, value: key, table: nil) ?? key
    }
}
