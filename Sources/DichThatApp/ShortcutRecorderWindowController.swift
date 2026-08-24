import AppKit
import DichThatCore

@MainActor
final class ShortcutRecorderWindowController: NSWindowController, NSWindowDelegate {
    private let currentShortcutLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "Press your new shortcut")
    private let messageLabel = NSTextField(labelWithString: "")
    private let useButton = NSButton(title: "Use Shortcut", target: nil, action: nil)
    private let captureView = ShortcutCaptureView()
    private let onCommit: @MainActor (KeyboardShortcut) -> String?
    private var recorderState = ShortcutRecorderState()

    init(onCommit: @escaping @MainActor (KeyboardShortcut) -> String?) {
        self.onCommit = onCommit

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Shortcut"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
        configureContent()
        captureView.onKeyDown = { [weak self] event in
            self?.capture(event: event)
        }
        captureView.onModifiersChanged = { [weak self] flags in
            self?.modifierFlagsChanged(flags)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(currentShortcut: KeyboardShortcut) {
        recorderState.reset()
        currentShortcutLabel.stringValue = "Current: \(currentShortcut.displayText)"
        previewLabel.stringValue = "Press your new shortcut"
        messageLabel.stringValue = "Include Command, Option, or Control. Shift alone is not allowed."
        messageLabel.textColor = .secondaryLabelColor
        useButton.isEnabled = false

        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(captureView)
    }

    func windowWillClose(_ notification: Notification) {
        recorderState.reset()
        useButton.isEnabled = false
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "Keyboard Shortcut")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        currentShortcutLabel.font = .systemFont(ofSize: 13)
        previewLabel.font = .monospacedSystemFont(ofSize: 26, weight: .medium)
        previewLabel.alignment = .center
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.maximumNumberOfLines = 2
        messageLabel.lineBreakMode = .byWordWrapping

        captureView.wantsLayer = true
        captureView.layer?.cornerRadius = 8
        captureView.layer?.borderWidth = 1
        captureView.layer?.borderColor = NSColor.separatorColor.cgColor

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        useButton.target = self
        useButton.action = #selector(useShortcut)
        useButton.keyEquivalent = "\r"
        useButton.isEnabled = false

        let buttonRow = NSStackView(views: [cancelButton, useButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let stack = NSStackView(views: [
            titleLabel,
            currentShortcutLabel,
            captureView,
            messageLabel,
            buttonRow,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        captureView.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        captureView.addSubview(previewLabel)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            captureView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            captureView.heightAnchor.constraint(equalToConstant: 58),
            previewLabel.centerXAnchor.constraint(equalTo: captureView.centerXAnchor),
            previewLabel.centerYAnchor.constraint(equalTo: captureView.centerYAnchor),
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])
    }

    private func capture(event: NSEvent) {
        guard !event.isARepeat else { return }
        if event.keyCode == 53 {
            cancel()
            return
        }

        apply(recorderState.keyDown(
            keyCode: UInt32(event.keyCode),
            modifierFlags: Self.captureFlags(from: event.modifierFlags)
        ))
    }

    private func modifierFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        let capturedFlags = Self.captureFlags(from: flags)
        switch recorderState.modifiersChanged(to: capturedFlags) {
        case .idle:
            useButton.isEnabled = false
            previewLabel.stringValue = "Press your new shortcut"
        case let .recording(recordingFlags):
            useButton.isEnabled = false
            previewLabel.stringValue = Self.modifierPreview(recordingFlags)
            messageLabel.stringValue = "Now press a non-modifier key."
            messageLabel.textColor = .secondaryLabelColor
        case let .valid(shortcut):
            previewLabel.stringValue = shortcut.displayText
            useButton.isEnabled = true
        case let .invalid(error):
            previewLabel.stringValue = "Invalid shortcut"
            messageLabel.stringValue = error.recorderMessage
            messageLabel.textColor = .systemRed
            useButton.isEnabled = false
        }
    }

    private func apply(_ result: ShortcutCapture.CaptureResult) {
        switch result {
        case .modifierOnly:
            useButton.isEnabled = false
        case let .valid(shortcut):
            previewLabel.stringValue = shortcut.displayText
            messageLabel.stringValue = "Ready to use this shortcut."
            messageLabel.textColor = .secondaryLabelColor
            useButton.isEnabled = true
        case let .invalid(error):
            previewLabel.stringValue = "Invalid shortcut"
            messageLabel.stringValue = error.recorderMessage
            messageLabel.textColor = .systemRed
            useButton.isEnabled = false
        }
    }

    @objc private func useShortcut() {
        guard let candidate = recorderState.candidate else { return }
        if let errorMessage = onCommit(candidate) {
            messageLabel.stringValue = errorMessage
            messageLabel.textColor = .systemRed
            useButton.isEnabled = true
            window?.makeFirstResponder(captureView)
            return
        }
        recorderState.reset()
        close()
    }

    @objc private func cancel() {
        recorderState.reset()
        close()
    }

    private static func captureFlags(from flags: NSEvent.ModifierFlags) -> ShortcutCapture.ModifierFlags {
        var captured: ShortcutCapture.ModifierFlags = []
        let independent = flags.intersection(.deviceIndependentFlagsMask)
        if independent.contains(.command) { captured.insert(.command) }
        if independent.contains(.option) { captured.insert(.option) }
        if independent.contains(.control) { captured.insert(.control) }
        if independent.contains(.shift) { captured.insert(.shift) }
        return captured
    }

    private static func modifierPreview(_ captured: ShortcutCapture.ModifierFlags) -> String {
        return [
            captured.contains(.control) ? "⌃" : "",
            captured.contains(.option) ? "⌥" : "",
            captured.contains(.shift) ? "⇧" : "",
            captured.contains(.command) ? "⌘" : "",
        ].joined()
    }
}

private extension KeyboardShortcut.ValidationError {
    var recorderMessage: String {
        switch self {
        case .unsupportedModifiers:
            return "This modifier combination is not supported."
        case .requiresCommandControlOrOption:
            return "Include Command, Option, or Control. Shift alone is not allowed."
        case .unusableKeyCode:
            return "Choose a supported non-modifier key."
        }
    }
}

@MainActor
private final class ShortcutCaptureView: NSView {
    var onKeyDown: (@MainActor (NSEvent) -> Void)?
    var onModifiersChanged: (@MainActor (NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        onModifiersChanged?(event.modifierFlags)
    }
}
