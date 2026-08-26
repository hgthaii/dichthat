import AppKit

enum SettingsAppearance {
    static let controlBackground = adaptiveColor(darkWhite: 0.055, lightWhite: 0.93)
    static let selectedControlBackground = adaptiveColor(darkWhite: 0.16, lightWhite: 0.84)
    static let active = adaptiveColor(darkWhite: 0.72, lightWhite: 0.38)
    static let border = adaptiveColor(darkWhite: 0.145, lightWhite: 0.78)
    static let divider = adaptiveColor(darkWhite: 0.105, lightWhite: 0.84)

    static func resolved(_ color: NSColor, for appearance: NSAppearance) -> CGColor {
        var result = color.cgColor
        appearance.performAsCurrentDrawingAppearance {
            result = color.cgColor
        }
        return result
    }

    private static func adaptiveColor(darkWhite: CGFloat, lightWhite: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(calibratedWhite: isDark ? darkWhite : lightWhite, alpha: 1)
        }
    }
}
