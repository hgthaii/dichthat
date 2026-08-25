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
        isRefreshing = false
    }

    private func configureContent() {
        let modifierButtons = [controlButton, optionButton, commandButton, shiftButton]
        let tooltips = ["Control", "Option", "Command", "Shift"]
        for (button, tooltip) in zip(modifierButtons, tooltips) {
            button.target = self
            button.action = #selector(valueChanged)
            button.setButtonType(.pushOnPushOff)
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            button.layer?.borderWidth = 1
            button.toolTip = tooltip
        }
        keyField.placeholderString = "A–Z / 0–9"
        keyField.alignment = .center
        keyField.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
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
        keyFieldContainer.layer?.cornerRadius = 8
        keyFieldContainer.layer?.borderWidth = 1
        keyFieldContainer.addSubview(keyField)
        NSLayoutConstraint.activate([
            keyField.leadingAnchor.constraint(equalTo: keyFieldContainer.leadingAnchor, constant: 6),
            keyField.trailingAnchor.constraint(equalTo: keyFieldContainer.trailingAnchor, constant: -6),
            keyField.centerYAnchor.constraint(equalTo: keyFieldContainer.centerYAnchor),
            keyField.heightAnchor.constraint(equalToConstant: 20),
        ])

        let plusLabels = (0..<modifierButtons.count).map { _ -> NSTextField in
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
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            controlButton.widthAnchor.constraint(equalToConstant: 40),
            controlButton.heightAnchor.constraint(equalToConstant: 32),
            optionButton.widthAnchor.constraint(equalToConstant: 40),
            optionButton.heightAnchor.constraint(equalToConstant: 32),
            commandButton.widthAnchor.constraint(equalToConstant: 40),
            commandButton.heightAnchor.constraint(equalToConstant: 32),
            shiftButton.widthAnchor.constraint(equalToConstant: 40),
            shiftButton.heightAnchor.constraint(equalToConstant: 32),
            keyFieldContainer.widthAnchor.constraint(equalToConstant: 66),
            keyFieldContainer.heightAnchor.constraint(equalToConstant: 32),
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
        keyFieldContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        keyFieldContainer.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    private func refreshModifierAppearance() {
        for button in [controlButton, optionButton, commandButton, shiftButton] {
            let selected = button.state == .on
            let foreground = selected ? NSColor.white : NSColor.labelColor
            button.layer?.backgroundColor = (
                selected ? NSColor.controlAccentColor : NSColor.controlBackgroundColor
            ).cgColor
            button.layer?.borderColor = (
                selected ? NSColor.controlAccentColor : NSColor.separatorColor
            ).cgColor
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
                    .foregroundColor: foreground,
                ]
            )
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
