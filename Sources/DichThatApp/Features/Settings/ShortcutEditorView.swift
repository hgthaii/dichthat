import AppKit
import DichThatCore

@MainActor
final class ShortcutEditorView: NSView, NSTextFieldDelegate {
    var onCommit: ((KeyboardShortcut) -> String?)?

    private let controlButton = NSButton(title: "⌃", target: nil, action: nil)
    private let optionButton = NSButton(title: "⌥", target: nil, action: nil)
    private let commandButton = NSButton(title: "⌘", target: nil, action: nil)
    private let shiftButton = NSButton(title: "⇧", target: nil, action: nil)
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

    private func configureContent() {
        let buttons = [controlButton, optionButton, commandButton, shiftButton]
        let tooltips = ["Control", "Option", "Command", "Shift"]
        for (button, tooltip) in zip(buttons, tooltips) {
            button.target = self
            button.action = #selector(valueChanged)
            button.setButtonType(.pushOnPushOff)
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 6
            button.layer?.borderWidth = 1
            button.toolTip = tooltip
        }
        keyField.placeholderString = "KEY"
        keyField.alignment = .center
        keyField.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
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
        keyFieldContainer.layer?.cornerRadius = 6
        keyFieldContainer.layer?.borderWidth = 1
        keyFieldContainer.addSubview(keyField)
        NSLayoutConstraint.activate([
            keyField.leadingAnchor.constraint(equalTo: keyFieldContainer.leadingAnchor, constant: 6),
            keyField.trailingAnchor.constraint(equalTo: keyFieldContainer.trailingAnchor, constant: -6),
            keyField.centerYAnchor.constraint(equalTo: keyFieldContainer.centerYAnchor),
            keyField.heightAnchor.constraint(equalToConstant: 20),
        ])

        let plusLabels = (0..<buttons.count).map { _ -> NSTextField in
            let label = NSTextField(labelWithString: "+")
            label.textColor = .tertiaryLabelColor
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.alignment = .center
            return label
        }
        let row = NSStackView(views: [
            controlButton, plusLabels[0], optionButton, plusLabels[1],
            commandButton, plusLabels[2], shiftButton, plusLabels[3], keyFieldContainer,
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            controlButton.widthAnchor.constraint(equalToConstant: 48),
            controlButton.heightAnchor.constraint(equalToConstant: 42),
            optionButton.widthAnchor.constraint(equalToConstant: 48),
            optionButton.heightAnchor.constraint(equalToConstant: 42),
            commandButton.widthAnchor.constraint(equalToConstant: 48),
            commandButton.heightAnchor.constraint(equalToConstant: 42),
            shiftButton.widthAnchor.constraint(equalToConstant: 48),
            shiftButton.heightAnchor.constraint(equalToConstant: 42),
            keyFieldContainer.widthAnchor.constraint(equalToConstant: 40),
            keyFieldContainer.heightAnchor.constraint(equalToConstant: 42),
        ])
        for label in plusLabels {
            label.widthAnchor.constraint(equalToConstant: 10).isActive = true
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
        keyFieldContainer.layer?.backgroundColor = SettingsAppearance.controlBackground.cgColor
        keyFieldContainer.layer?.borderColor = (
            keyField.stringValue.isEmpty ? SettingsAppearance.border : SettingsAppearance.active
        ).cgColor
        keyField.textColor = keyField.stringValue.isEmpty ? .secondaryLabelColor : SettingsAppearance.active
    }

    private func refreshModifierAppearance() {
        for item in modifierButtons {
            let button = item.button
            let selected = button.state == .on
            let foreground = selected ? SettingsAppearance.active : NSColor.secondaryLabelColor
            button.layer?.backgroundColor = SettingsAppearance.controlBackground.cgColor
            button.layer?.borderColor = (
                selected ? SettingsAppearance.active : SettingsAppearance.border
            ).cgColor
            let title = NSMutableAttributedString(
                string: item.symbol,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: foreground,
                ]
            )
            title.append(NSAttributedString(
                string: "\n\(item.label)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 7, weight: .medium),
                    .foregroundColor: selected ? foreground : NSColor.tertiaryLabelColor,
                ]
            ))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.minimumLineHeight = 12
            paragraph.maximumLineHeight = 12
            title.addAttribute(
                .paragraphStyle,
                value: paragraph,
                range: NSRange(location: 0, length: title.length)
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
