import AppKit

/// Adds subtle hover and press feedback without changing the button's layout frame.
@MainActor
final class AnimatedSettingsButton: NSButton {
    var hoverScale = AppConfiguration.Settings.buttonHoverScale
    var pressedScale = AppConfiguration.Settings.buttonPressedScale

    private var pointerIsInside = false
    private var pointerTrackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isEnabled: Bool {
        didSet {
            if !isEnabled {
                pointerIsInside = false
                updateVisualState(scale: 1, opacity: 1, animated: false)
            }
        }
    }

    override func updateTrackingAreas() {
        if let pointerTrackingArea {
            removeTrackingArea(pointerTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        pointerTrackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        pointerIsInside = true
        guard isEnabled else { return }
        updateVisualState(scale: hoverScale, opacity: 1, animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        pointerIsInside = false
        guard isEnabled else { return }
        updateVisualState(scale: 1, opacity: 1, animated: true)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            super.mouseDown(with: event)
            return
        }
        updateVisualState(scale: pressedScale, opacity: 0.82, animated: true)
        super.mouseDown(with: event)
        updateVisualState(
            scale: pointerIsInside ? hoverScale : 1,
            opacity: 1,
            animated: true
        )
    }

    private func updateVisualState(scale: CGFloat, opacity: Float, animated: Bool) {
        guard let layer else { return }
        let targetTransform = CATransform3DMakeScale(scale, scale, 1)
        let currentTransform = layer.presentation()?.transform ?? layer.transform
        let currentOpacity = layer.presentation()?.opacity ?? layer.opacity

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = targetTransform
        layer.opacity = opacity
        CATransaction.commit()

        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            layer.removeAnimation(forKey: "settings-button-transform")
            layer.removeAnimation(forKey: "settings-button-opacity")
            return
        }

        let timing = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
        let transformAnimation = CABasicAnimation(keyPath: "transform")
        transformAnimation.fromValue = currentTransform
        transformAnimation.toValue = targetTransform
        transformAnimation.duration = AppConfiguration.Settings.buttonAnimationDuration
        transformAnimation.timingFunction = timing
        layer.add(transformAnimation, forKey: "settings-button-transform")

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = currentOpacity
        opacityAnimation.toValue = opacity
        opacityAnimation.duration = AppConfiguration.Settings.buttonAnimationDuration
        opacityAnimation.timingFunction = timing
        layer.add(opacityAnimation, forKey: "settings-button-opacity")
    }
}
