import AppKit
import DichThatCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private enum Layout {
        static let windowSize = NSSize(width: 480, height: 270)
        static let contentInset: CGFloat = 24
        static let sectionSpacing: CGFloat = 18
        static let rowSpacing: CGFloat = 12
    }

    private let permissionStatusLabel = NSTextField(labelWithString: "")
    private let grantPermissionButton = NSButton(
        title: "Grant Access…",
        target: nil,
        action: nil
    )
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let shortcutErrorLabel = NSTextField(labelWithString: "")
    private let selectionStatusLabel = NSTextField(labelWithString: "")
    private let selectionIconToggle = NSButton(
        checkboxWithTitle: "Show translation icon when text is selected",
        target: nil,
        action: nil
    )
    private let onGrantPermission: @MainActor () -> Void
    private let onOpenPermissionSettings: @MainActor () -> Void
    private let onSetShortcut: @MainActor () -> Void
    private let onToggleSelectionIcon: @MainActor (Bool) -> Void

    init(
        onGrantPermission: @escaping @MainActor () -> Void,
        onOpenPermissionSettings: @escaping @MainActor () -> Void,
        onSetShortcut: @escaping @MainActor () -> Void,
        onToggleSelectionIcon: @escaping @MainActor (Bool) -> Void
    ) {
        self.onGrantPermission = onGrantPermission
        self.onOpenPermissionSettings = onOpenPermissionSettings
        self.onSetShortcut = onSetShortcut
        self.onToggleSelectionIcon = onToggleSelectionIcon

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dịch Thật Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(state: SettingsState) {
        refresh(state: state)
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func refresh(state: SettingsState) {
        permissionStatusLabel.stringValue = state.accessibilityGranted
            ? "Accessibility access granted"
            : "Accessibility access required"
        permissionStatusLabel.textColor = state.accessibilityGranted
            ? .secondaryLabelColor
            : .systemOrange
        grantPermissionButton.isEnabled = !state.accessibilityGranted
        shortcutLabel.stringValue = "Current shortcut: \(state.shortcutDisplay)"
        shortcutErrorLabel.stringValue = state.shortcutError ?? ""
        shortcutErrorLabel.isHidden = state.shortcutError == nil
        selectionIconToggle.state = state.showSelectionIcon ? .on : .off
        switch state.selectionIconStatus {
        case .monitoring:
            selectionStatusLabel.stringValue = "Selection monitoring active"
            selectionStatusLabel.textColor = .secondaryLabelColor
        case .permissionRequired:
            selectionStatusLabel.stringValue = "Accessibility access is required for the selection icon"
            selectionStatusLabel.textColor = .systemOrange
        case .monitorUnavailable:
            selectionStatusLabel.stringValue = "Selection monitoring is unavailable"
            selectionStatusLabel.textColor = .systemRed
        case .disabled:
            selectionStatusLabel.stringValue = "Selection icon disabled; keyboard shortcut remains active"
            selectionStatusLabel.textColor = .secondaryLabelColor
        }
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let permissionTitle = sectionTitle("Accessibility")
        permissionStatusLabel.setAccessibilityLabel("Accessibility permission status")
        grantPermissionButton.target = self
        grantPermissionButton.action = #selector(grantPermission)
        grantPermissionButton.setAccessibilityLabel("Grant Accessibility access")
        let openSettingsButton = NSButton(
            title: "Open System Settings…",
            target: self,
            action: #selector(openPermissionSettings)
        )
        openSettingsButton.setAccessibilityLabel("Open Accessibility settings")
        let permissionButtons = NSStackView(views: [grantPermissionButton, openSettingsButton])
        permissionButtons.orientation = .horizontal
        permissionButtons.spacing = Layout.rowSpacing

        let shortcutTitle = sectionTitle("Keyboard Shortcut")
        shortcutLabel.setAccessibilityLabel("Current keyboard shortcut")
        let setShortcutButton = NSButton(
            title: "Set Shortcut…",
            target: self,
            action: #selector(setShortcut)
        )
        let shortcutRow = NSStackView(views: [shortcutLabel, NSView(), setShortcutButton])
        shortcutRow.orientation = .horizontal
        shortcutRow.alignment = .centerY
        shortcutErrorLabel.textColor = .systemRed
        shortcutErrorLabel.maximumNumberOfLines = 2

        let selectionTitle = sectionTitle("Selection")
        selectionIconToggle.target = self
        selectionIconToggle.action = #selector(toggleSelectionIcon)
        selectionIconToggle.setAccessibilityLabel(
            "Show translation icon when text is selected"
        )
        selectionStatusLabel.setAccessibilityLabel("Selection icon status")

        let stack = NSStackView(views: [
            permissionTitle,
            permissionStatusLabel,
            permissionButtons,
            shortcutTitle,
            shortcutRow,
            shortcutErrorLabel,
            selectionTitle,
            selectionIconToggle,
            selectionStatusLabel,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.rowSpacing
        stack.setCustomSpacing(Layout.sectionSpacing, after: permissionButtons)
        stack.setCustomSpacing(Layout.sectionSpacing, after: shortcutErrorLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.contentInset
            ),
            stack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.contentInset
            ),
            stack.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.contentInset
            ),
            shortcutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutErrorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func sectionTitle(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        return label
    }

    @objc private func grantPermission() {
        onGrantPermission()
    }

    @objc private func openPermissionSettings() {
        onOpenPermissionSettings()
    }

    @objc private func setShortcut() {
        onSetShortcut()
    }

    @objc private func toggleSelectionIcon() {
        onToggleSelectionIcon(selectionIconToggle.state == .on)
    }
}
