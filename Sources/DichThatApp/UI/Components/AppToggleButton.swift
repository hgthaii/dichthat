import AppKit

/// A compact macOS-style toggle implemented without NSSwitch, whose runtime
/// callbacks previously conflicted with the app's compatibility mode.
@MainActor
final class AppToggleButton: NSButton {
    private let trackLayer = CALayer()
    private let thumbLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        isBordered = false
        setButtonType(.toggle)
        setAccessibilityRole(.checkBox)
        wantsLayer = true
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(thumbLayer)
        thumbLayer.shadowOffset = CGSize(width: 0, height: -0.5)
        thumbLayer.shadowRadius = 1.5
        thumbLayer.shadowOpacity = 0.24
        updateAppearance(animated: false)
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

    override var state: NSControl.StateValue {
        didSet {
            updateAppearance(animated: oldValue != state && window?.isVisible == true)
        }
    }

    override var isEnabled: Bool {
        didSet { updateAppearance(animated: false) }
    }

    override func layout() {
        super.layout()
        updateAppearance(animated: false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)
    }

    private func updateAppearance(animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let appearance = effectiveAppearance
        let trackFrame = bounds.insetBy(dx: 0.5, dy: 0.5)
        let inset = AppConfiguration.Settings.toggleInset
        let diameter = bounds.height - inset * 2
        let thumbX = state == .on ? bounds.maxX - inset - diameter : bounds.minX + inset
        let thumbFrame = CGRect(x: thumbX, y: inset, width: diameter, height: diameter)
        let trackColor: NSColor
        if !isEnabled {
            trackColor = SettingsAppearance.toggleDisabled
        } else if state == .on {
            trackColor = .controlAccentColor
        } else {
            trackColor = SettingsAppearance.toggleOff
        }
        let targetTrackColor = SettingsAppearance.resolved(trackColor, for: appearance)
        let targetThumbColor = SettingsAppearance.resolved(
            SettingsAppearance.toggleThumb,
            for: appearance
        )
        let targetBorderColor = SettingsAppearance.resolved(
            isEnabled ? SettingsAppearance.toggleBorder : NSColor.separatorColor,
            for: appearance
        )
        let previousThumbPosition = thumbLayer.presentation()?.position ?? thumbLayer.position
        let previousTrackColor = trackLayer.presentation()?.backgroundColor
            ?? trackLayer.backgroundColor

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = trackFrame
        trackLayer.cornerRadius = trackFrame.height / 2
        trackLayer.backgroundColor = targetTrackColor
        trackLayer.borderColor = targetBorderColor
        trackLayer.borderWidth = 1
        thumbLayer.frame = thumbFrame
        thumbLayer.cornerRadius = diameter / 2
        thumbLayer.backgroundColor = targetThumbColor
        thumbLayer.borderColor = NSColor.black.withAlphaComponent(isEnabled ? 0.12 : 0.05).cgColor
        thumbLayer.borderWidth = 0.5
        thumbLayer.shadowOpacity = isEnabled ? 0.24 : 0.08
        CATransaction.commit()

        guard animated else { return }

        let timing = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
        let positionAnimation = CABasicAnimation(keyPath: "position")
        positionAnimation.fromValue = previousThumbPosition
        positionAnimation.toValue = thumbLayer.position
        positionAnimation.duration = 0.24
        positionAnimation.timingFunction = timing
        thumbLayer.add(positionAnimation, forKey: "smooth-position")

        let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
        colorAnimation.fromValue = previousTrackColor
        colorAnimation.toValue = targetTrackColor
        colorAnimation.duration = 0.24
        colorAnimation.timingFunction = timing
        trackLayer.add(colorAnimation, forKey: "smooth-color")
    }
}
