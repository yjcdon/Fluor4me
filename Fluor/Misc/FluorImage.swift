import AppKit

enum FluorImage {
    private static let templates: [String: Bool] = {
        guard let url = Bundle.main.url(forResource: "ImageTemplates", withExtension: "plist"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? PropertyListDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }()

    /// Load the existing artwork as AppKit image representations at their original point size.
    static func named(_ name: String) -> NSImage? {
        let appearance = NSAppearance.currentDrawing()
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let template = templates[name] == true
        let artwork = isDark && !template && resource(name + "-dark") != nil ? name + "-dark" : name
        guard let normal = bitmap(artwork) else {
            return NSImage(named: name)
        }
        let image = NSImage(size: normal.size)
        image.addRepresentation(normal)
        if let retina = bitmap(artwork + "@2x") {
            retina.size = normal.size
            image.addRepresentation(retina)
        }
        image.isTemplate = template
        return image
    }

    private static func resource(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Images")
    }

    private static func bitmap(_ name: String) -> NSBitmapImageRep? {
        guard let url = resource(name), let data = try? Data(contentsOf: url) else { return nil }
        return NSBitmapImageRep(data: data)
    }
}
