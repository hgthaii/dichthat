import AppKit
import DichThatCore

@MainActor
final class SelectionIconPanelController {
    private final class IconPanel: NSPanel {
        nonisolated override var canBecomeKey: Bool { false }
        nonisolated override var canBecomeMain: Bool { false }
    }

    private let panel: NSPanel
    private let onClick: @MainActor () -> Void

    init(onClick: @escaping @MainActor () -> Void) {
        self.onClick = onClick
        let size = NSSize(
            width: AppConfiguration.SelectionIcon.size,
            height: AppConfiguration.SelectionIcon.size
        )
        let panel = IconPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        self.panel = panel

        let button = NSButton(frame: NSRect(origin: .zero, size: size))
        button.bezelStyle = .circular
        button.image = NSImage(systemSymbolName: "character.book.closed", accessibilityDescription: "Translate selection")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(clicked)
        button.setAccessibilityLabel("Translate selected text")
        panel.contentView = button
    }

    func show(presentation: SelectionIconPresentation) {
        guard let resolution = ScreenGeometryResolver.resolve(anchor: presentation.anchor) else {
            return
        }
        let screen = resolution.screen
        let mainHeight = resolution.mainDisplayHeight
        let visible = screen.visibleFrame
        let origin = SelectionIconGeometry.iconOrigin(
            anchor: presentation.anchor,
            mainDisplayHeight: mainHeight,
            iconSize: AppConfiguration.SelectionIcon.size,
            offset: AppConfiguration.SelectionIcon.anchorOffset,
            visibleFrame: CaptureBounds(
                x: visible.origin.x,
                y: visible.origin.y,
                width: visible.width,
                height: visible.height
            )
        )
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    @objc private func clicked() {
        onClick()
    }
}
