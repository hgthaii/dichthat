import AppKit

enum AdaptiveAppIcon {
    static func systemAppearance(fallback: NSAppearance) -> NSAppearance {
        let isDark = UserDefaults.standard
            .string(forKey: "AppleInterfaceStyle")?
            .caseInsensitiveCompare("Dark") == .orderedSame
        let name: NSAppearance.Name = isDark ? .darkAqua : .aqua
        return NSAppearance(named: name) ?? standardAppearance(for: fallback)
    }

    static func standardAppearance(for appearance: NSAppearance) -> NSAppearance {
        let name: NSAppearance.Name = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .darkAqua
            : .aqua
        return NSAppearance(named: name) ?? appearance
    }

    static func image(for appearance: NSAppearance) -> NSImage? {
        let isDark = systemAppearance(fallback: appearance).name == .darkAqua
        let name = isDark
            ? AppConfiguration.Resources.darkAppIconName
            : AppConfiguration.Resources.lightAppIconName
        return Bundle.main.url(
            forResource: name,
            withExtension: AppConfiguration.Resources.adaptiveAppIconExtension
        ).flatMap(NSImage.init(contentsOf:))
    }
}

@MainActor
final class AdaptiveAppIconView: NSImageView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshImage()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshImage()
    }

    private func refreshImage() {
        image = AdaptiveAppIcon.image(for: effectiveAppearance)
    }
}
