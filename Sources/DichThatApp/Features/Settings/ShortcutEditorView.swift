import AppKit
import DichThatCore

@MainActor
final class ShortcutEditorView: NSView, NSTextFieldDelegate {
    var onCommit: ((KeyboardShortcut) -> String?)?

    private let controlButton = AnimatedSettingsButton(title: "⌃", target: nil, action: nil)
    private let optionButton = AnimatedSettingsButton(title: "⌥", target: nil, action: nil)
    private let commandButton = AnimatedSettingsButton(title: "⌘", target: nil, action: nil)
    private let shiftButton = AnimatedSettingsButton(title: "⇧", target: nil, action: nil)
    private let keyField = NSTextField()
    private let keyFieldContainer = NSView()
    private var isRefreshing = false

    private var modifierButtons: [(button: NSButton, symbol: String, label: String)] {
        [
            (controlButton, "⌃", "CTRL"),
            (optionButton, "⌥", "OPT"),
            (commandButton, "⌘", "CMD"),
            (shiftButton, "⇧", "SHIFT"),
        ]
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateCurrentShortcut(_ display: String) {
        isRefreshing = true
        controlButton.state = display.contains("⌃") ? .on : .off
        optionButton.state = display.contains("⌥") ? .on : .off
        commandButton.state = display.contains("⌘") ? .on : .off
        shiftButton.state = display.contains("⇧") ? .on : .off
        let key = display.last.map(String.init) ?? ""
        keyField.stringValue = KeyboardShortcut.keyCode(forAlphanumeric: key) == nil ? "" : key
        refreshModifierAppearance()
        refreshKeyFieldAppearance()
        isRefreshing = false
    }

    func setControlsEnabled(_ isEnabled: Bool) {
        for item in modifierButtons {
            item.button.isEnabled = isEnabled
        }
        keyField.isEnabled = isEnabled
        alphaValue = isEnabled ? 1 : 0.45
    }

    private func configureContent() {
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        let buttons = [controlButton, optionButton, commandButton, shiftButton]
        let tooltips = ["Control", "Option", "Command", "Shift"]
        for (button, tooltip) in zip(buttons, tooltips) {
            button.target = self
            button.action = #selector(valueChanged)
            button.setButtonType(.pushOnPushOff)
            button.isBordered = false
            button.toolTip = tooltip
        }
        keyField.placeholderString = AppText.Settings.shortcutKeyPlaceholder
        keyField.alignment = .center
        keyField.font = .monospacedSystemFont(ofSize: 9, weight: .semibold)
        keyField.controlSize = .small
        keyField.focusRingType = .none
        keyField.isBezeled = false
        keyField.drawsBackground = false
        keyField.alignment = .center
        keyField.usesSingleLineMode = true
        keyField.cell?.alignment = .center
        keyField.cell?.isScrollable = true
        keyField.cell?.wraps = false
        keyField.delegate = self
        keyField.setAccessibilityLabel(AppText.Settings.shortcutKeyAccessibility)
        keyField.translatesAutoresizingMaskIntoConstraints = false
        keyFieldContainer.wantsLayer = true
        keyFieldContainer.addSubview(keyField)
        NSLayoutConstraint.activate([
            keyField.leadingAnchor.constraint(equalTo: keyFieldContainer.leadingAnchor),
            keyField.trailingAnchor.constraint(equalTo: keyFieldContainer.trailingAnchor),
            keyField.centerYAnchor.constraint(
                equalTo: keyFieldContainer.centerYAnchor,
                constant: AppConfiguration.Settings.shortcutKeyVerticalOffset
            ),
            keyField.heightAnchor.constraint(equalToConstant: 18),
        ])

        let plusLabels = (0..<buttons.count).map { _ -> NSTextField in
            let label = NSTextField(labelWithString: "+")
            label.textColor = .tertiaryLabelColor
            label.font = .monospacedSystemFont(ofSize: 9, weight: .medium)
            label.alignment = .center
            return label
        }
        let row = NSStackView(views: [
            controlButton, plusLabels[0], optionButton, plusLabels[1],
            commandButton, plusLabels[2], shiftButton, plusLabels[3], keyFieldContainer,
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 2
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            controlButton.widthAnchor.constraint(equalToConstant: 32),
            controlButton.heightAnchor.constraint(equalToConstant: 26),
            optionButton.widthAnchor.constraint(equalToConstant: 32),
            optionButton.heightAnchor.constraint(equalToConstant: 26),
            commandButton.widthAnchor.constraint(equalToConstant: 32),
            commandButton.heightAnchor.constraint(equalToConstant: 26),
            shiftButton.widthAnchor.constraint(equalToConstant: 32),
            shiftButton.heightAnchor.constraint(equalToConstant: 26),
            keyFieldContainer.widthAnchor.constraint(equalToConstant: 32),
            keyFieldContainer.heightAnchor.constraint(equalToConstant: 26),
        ])
        for label in plusLabels {
            label.widthAnchor.constraint(equalToConstant: 6).isActive = true
        }
        refreshModifierAppearance()
        refreshKeyFieldAppearance()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard !isRefreshing, notification.object as? NSTextField === keyField else { return }
        keyField.currentEditor()?.alignment = .center
        let filtered = keyField.stringValue.uppercased().filter {
            $0.isASCII && ($0.isLetter || $0.isNumber)
        }
        let normalized = String(filtered.prefix(1))
        if keyField.stringValue != normalized {
            keyField.stringValue = normalized
        }
        refreshKeyFieldAppearance()
        commitIfPossible()
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === keyField else { return }
        keyField.currentEditor()?.alignment = .center
    }

    @objc private func valueChanged() {
        guard !isRefreshing else { return }
        refreshModifierAppearance()
        commitIfPossible()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshModifierAppearance()
        refreshKeyFieldAppearance()
    }

    private func refreshKeyFieldAppearance() {
        layer?.backgroundColor = SettingsAppearance.resolved(
            SettingsAppearance.cardBackground,
            for: effectiveAppearance
        )
        layer?.borderColor = SettingsAppearance.resolved(
            SettingsAppearance.cardBorder,
            for: effectiveAppearance
        )
        keyField.textColor = keyField.stringValue.isEmpty ? .secondaryLabelColor : SettingsAppearance.active
    }

    private func refreshModifierAppearance() {
        for item in modifierButtons {
            let button = item.button
            let selected = button.state == .on
            let foreground = selected ? SettingsAppearance.active : NSColor.secondaryLabelColor
            let title = NSAttributedString(
                string: item.label.capitalized,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold),
                    .foregroundColor: foreground,
                ]
            )
            button.attributedTitle = title
        }
    }

    private func commitIfPossible() {
        guard let keyCode = KeyboardShortcut.keyCode(forAlphanumeric: keyField.stringValue) else {
            return
        }
        var modifiers: KeyboardShortcut.Modifiers = []
        if controlButton.state == .on { modifiers.insert(.control) }
        if optionButton.state == .on { modifiers.insert(.option) }
        if commandButton.state == .on { modifiers.insert(.command) }
        if shiftButton.state == .on { modifiers.insert(.shift) }
        guard !modifiers.intersection(.activation).isEmpty else { return }
        _ = onCommit?(KeyboardShortcut(keyCode: keyCode, modifiers: modifiers))
    }
}
