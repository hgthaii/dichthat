import AppKit

enum SettingsAppearance {
    static let windowBackground = adaptiveColor(darkWhite: 0.075, lightWhite: 0.98)
    static let controlBackground = adaptiveColor(darkWhite: 0.115, lightWhite: 0.93)
    static let selectedControlBackground = adaptiveColor(darkWhite: 0.055, lightWhite: 1)
    static let active = NSColor.systemBlue
    static let border = adaptiveColor(darkWhite: 0.19, lightWhite: 0.80)
    static let divider = adaptiveColor(darkWhite: 0.16, lightWhite: 0.86)
    static let cardBackground = adaptiveColor(darkWhite: 0.105, lightWhite: 0.965)
    static let cardBorder = adaptiveColor(darkWhite: 0.19, lightWhite: 0.82)
    static let permissionBackground = NSColor.systemOrange.withAlphaComponent(0.10)
    static let permissionBorder = NSColor.systemOrange
    static let updateCardBackground = cardBackground
    static let updateCardBorder = cardBorder
    static let toggleOff = adaptiveColor(darkWhite: 0.24, lightWhite: 0.72)
    static let toggleDisabled = adaptiveColor(darkWhite: 0.13, lightWhite: 0.88)
    static let toggleBorder = adaptiveColor(darkWhite: 0.34, lightWhite: 0.64)
    static let toggleThumb = adaptiveColor(darkWhite: 0.94, lightWhite: 1)
    static let comingSoonStamp = adaptiveColor(darkWhite: 0.48, lightWhite: 0.48)

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
