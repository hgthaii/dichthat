import AppKit

/// A compact macOS-style toggle implemented without NSSwitch, whose runtime
/// callbacks previously conflicted with the app's macOS 13 compatibility mode.
@MainActor
final class AppToggleButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        isBordered = false
        setButtonType(.toggle)
        setAccessibilityRole(.checkBox)
    }

    convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: AppConfiguration.Settings.toggleWidth,
            height: AppConfiguration.Settings.toggleHeight
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = bounds
        let radius = track.height / 2
        let trackColor: NSColor = state == .on
            ? SettingsAppearance.active
            : .separatorColor
        trackColor.setFill()
        NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius).fill()

        let inset = AppConfiguration.Settings.toggleInset
        let diameter = track.height - inset * 2
        let x = state == .on ? track.maxX - inset - diameter : track.minX + inset
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: inset, width: diameter, height: diameter)).fill()
    }
}
