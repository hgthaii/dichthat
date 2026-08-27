import AppKit
import DichThatCore

private struct PopupMouseSnapshot: Sendable {
    let point: CapturePoint

    init() {
        let location = NSEvent.mouseLocation
        point = CapturePoint(x: location.x, y: location.y)
    }
}

private enum PopupMouseMonitorBridge {
    static func installGlobal(
        handler: @escaping @MainActor @Sendable (PopupMouseSnapshot) -> Void
    ) -> Any? {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            let snapshot = PopupMouseSnapshot()
            DispatchQueue.main.async { handler(snapshot) }
        }
    }

    static func installLocal(
        handler: @escaping @MainActor @Sendable (PopupMouseSnapshot) -> Void
    ) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            let snapshot = PopupMouseSnapshot()
            DispatchQueue.main.async { handler(snapshot) }
            return event
        }
    }

    static func remove(_ token: Any) {
        NSEvent.removeMonitor(token)
    }
}

@MainActor
final class TranslationPanelController: NSObject, NSTextFieldDelegate {
    private final class AccentBadgeView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            refreshAppearance()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            refreshAppearance()
        }

        private func refreshAppearance() {
            layer?.backgroundColor = SettingsAppearance.resolved(
                NSColor.controlAccentColor.withAlphaComponent(0.14),
                for: effectiveAppearance
            )
        }
    }

    private final class ResultPanel: NSPanel, @unchecked Sendable {
        var onEscape: (@MainActor () -> Void)?
        nonisolated override var canBecomeKey: Bool { true }
        nonisolated override var canBecomeMain: Bool { false }
        nonisolated override func cancelOperation(_ sender: Any?) {
            DispatchQueue.main.async { [weak self] in
                self?.onEscape?()
            }
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers == .command,
               event.charactersIgnoringModifiers?.lowercased() == "a" {
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          let editor = self.fieldEditor(false, for: nil) as? NSTextView
                    else { return }
                    editor.selectAll(nil)
                }
                return true
            }
            return super.performKeyEquivalent(with: event)
        }
    }

    private final class DocumentView: NSView {
        nonisolated override var isFlipped: Bool { true }
    }

    private let panel: ResultPanel
    private let effect = NSVisualEffectView()
    private let bubbleMask = CAShapeLayer()
    private let scroll = NSScrollView()
    private let document = DocumentView()
    private let stack = NSStackView()
    private let inputField = NSTextField()
    private let inputContainer = NSVisualEffectView()
    private let onDismiss: @MainActor () -> Void
    private let onSpeak: @MainActor (TranslationSpeechContent) -> Void
    private var sourceSpeech: TranslationSpeechContent?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var isInputMode = false
    private var onInputChanged: (@MainActor (String) -> Void)?
    private var inputSelectionRange = NSRange(location: 0, length: 0)

    var isVisible: Bool { panel.isVisible }

    func updateAppearance(_ appearance: NSAppearance) {
        panel.appearance = AdaptiveAppIcon.systemAppearance(fallback: appearance)
    }

    init(
        onDismiss: @escaping @MainActor () -> Void,
        onSpeak: @escaping @MainActor (TranslationSpeechContent) -> Void
    ) {
        self.onDismiss = onDismiss
        self.onSpeak = onSpeak
        panel = ResultPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: AppConfiguration.TranslationPanel.initialWidth,
                height: AppConfiguration.TranslationPanel.initialHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear

        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.mask = bubbleMask
        panel.contentView = effect

        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(scroll)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = AppConfiguration.TranslationPanel.contentSpacing
        let contentInset = AppConfiguration.TranslationPanel.contentInset
        stack.edgeInsets = NSEdgeInsets(
            top: contentInset,
            left: contentInset,
            bottom: contentInset,
            right: contentInset
        )
        stack.translatesAutoresizingMaskIntoConstraints = true
        document.translatesAutoresizingMaskIntoConstraints = true
        document.addSubview(stack)
        scroll.documentView = document
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            scroll.topAnchor.constraint(
                equalTo: effect.topAnchor,
                constant: AppConfiguration.TranslationPanel.tailHeight
            ),
            scroll.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.onEscape = { [weak self] in self?.dismiss() }

        inputField.placeholderString = AppText.Translation.inputPlaceholder
        inputField.delegate = self
        inputField.font = .systemFont(ofSize: AppConfiguration.TranslationPanel.inputFontSize)
        inputField.focusRingType = .none
        inputField.isBezeled = false
        inputField.drawsBackground = false
        inputField.translatesAutoresizingMaskIntoConstraints = false

        let searchIcon = NSImageView(image: NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: nil
        ) ?? NSImage())
        searchIcon.contentTintColor = .secondaryLabelColor
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.material = .contentBackground
        inputContainer.blendingMode = .withinWindow
        inputContainer.state = .active
        inputContainer.wantsLayer = true
        inputContainer.layer?.cornerRadius = 7
        inputContainer.layer?.masksToBounds = true
        inputContainer.addSubview(searchIcon)
        inputContainer.addSubview(inputField)
        NSLayoutConstraint.activate([
            inputContainer.heightAnchor.constraint(
            equalToConstant: AppConfiguration.TranslationPanel.inputHeight
            ),
            searchIcon.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 8),
            searchIcon.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 14),
            searchIcon.heightAnchor.constraint(equalToConstant: 14),
            inputField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 6),
            inputField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
            inputField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    func showInput(
        anchor: SelectionAnchor,
        onTextChanged: @escaping @MainActor (String) -> Void
    ) {
        isInputMode = true
        panel.hidesOnDeactivate = true
        self.onInputChanged = onTextChanged
        sourceSpeech = nil
        inputField.stringValue = ""
        inputSelectionRange = NSRange(location: 0, length: 0)
        rebuildPresentation([])
        showPanel(anchor: anchor)
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        focusInputPreservingSelection()
    }

    func showInputPrompt(anchor: SelectionAnchor) {
        guard isInputMode else { return }
        sourceSpeech = nil
        rebuildPresentation([])
        showPanel(anchor: anchor)
    }

    func prepareForQuickTranslation() {
        isInputMode = false
        panel.hidesOnDeactivate = false
        onInputChanged = nil
    }

    func showLoading(anchor: SelectionAnchor) {
        sourceSpeech = nil
        rebuildPresentation([
            header(AppIdentity.productName),
            textLabel(
                AppText.Translation.loading,
                font: .systemFont(ofSize: AppConfiguration.TranslationPanel.loadingFontSize),
                color: .secondaryLabelColor
            ),
        ])
        showPanel(anchor: anchor)
    }

    func show(
        output: TranslationOutput,
        anchor: SelectionAnchor,
        sourceVoiceAvailable: Bool
    ) {
        sourceSpeech = TranslationSpeechContent(text: output.sourceText, language: output.source)
        var views: [NSView] = [header("\(output.source.displayName) → \(output.target.displayName)")]
        if let enrichment = output.enrichment {
            views.append(sourceWordView(
                text: output.sourceText,
                phonetic: enrichment.phonetic,
                voiceAvailable: sourceVoiceAvailable
            ))
        } else {
            views.append(sourceSpeechRow(
                text: output.sourceText,
                font: .systemFont(
                    ofSize: AppConfiguration.TranslationPanel.compactSourceFontSize
                ),
                color: .secondaryLabelColor,
                voiceAvailable: sourceVoiceAvailable
            ))
        }
        views.append(textLabel(
            output.text,
            font: .systemFont(
                ofSize: output.enrichment == nil
                    ? AppConfiguration.TranslationPanel.compactResultFontSize
                    : AppConfiguration.TranslationPanel.enrichedResultFontSize,
                weight: .medium
            ),
            color: .labelColor,
            selectable: true
        ))

        if let enrichment = output.enrichment {
            let meanings = enrichment.groups.filter {
                !$0.translations.isEmpty || $0.definition != nil || $0.example != nil || !$0.synonyms.isEmpty
            }
            if !meanings.isEmpty {
                views.append(sectionLabel(AppText.Translation.meanings))
                views.append(contentsOf: meanings.map(meaningView))
            }
        }
        if !sourceVoiceAvailable {
            views.append(textLabel(
                AppText.Translation.pronunciationUnavailable,
                font: .systemFont(
                    ofSize: AppConfiguration.TranslationPanel.unavailableVoiceFontSize
                ),
                color: .tertiaryLabelColor
            ))
        }
        rebuildPresentation(views)
        showPanel(anchor: anchor)
    }

    func showFailure(_ message: String, anchor: SelectionAnchor) {
        sourceSpeech = nil
        rebuildPresentation([
            header(AppText.Translation.failureTitle),
            textLabel(
                message,
                font: .systemFont(ofSize: AppConfiguration.TranslationPanel.failureFontSize),
                color: .secondaryLabelColor
            ),
        ])
        showPanel(anchor: anchor)
    }

    func hide() {
        sourceSpeech = nil
        isInputMode = false
        panel.hidesOnDeactivate = false
        onInputChanged = nil
        removeMouseMonitors()
        panel.orderOut(nil)
        clearContent()
    }

    private func dismiss() {
        hide()
        onDismiss()
    }

    private func rebuildPresentation(_ views: [NSView]) {
        captureInputSelection()
        clearContent()
        let presentedViews = isInputMode ? [inputContainer] + views : views
        for view in presentedViews {
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(
                equalTo: stack.widthAnchor,
                constant: -AppConfiguration.TranslationPanel.contentWidthInsets
            ).isActive = true
        }
    }

    private func clearContent() {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func header(_ title: String) -> NSView {
        let row = NSStackView(views: [
            textLabel(
                title,
                font: .systemFont(
                    ofSize: AppConfiguration.TranslationPanel.headerFontSize,
                    weight: .semibold
                ),
                color: .secondaryLabelColor
            ),
            NSView(),
            symbolButton(
                "xmark",
                action: #selector(closeClicked),
                accessibility: AppText.Translation.closeAccessibility,
                enabled: true
            ),
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    private func sourceWordView(text: String, phonetic: String?, voiceAvailable: Bool) -> NSView {
        let labels = NSStackView(views: [
            textLabel(
                text,
                font: .systemFont(
                    ofSize: AppConfiguration.TranslationPanel.sourceWordFontSize,
                    weight: .semibold
                ),
                color: .labelColor
            ),
        ])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = AppConfiguration.TranslationPanel.sourceWordSpacing
        if let phonetic {
            labels.addArrangedSubview(textLabel(
                phonetic,
                font: .systemFont(ofSize: AppConfiguration.TranslationPanel.phoneticFontSize),
                color: .secondaryLabelColor
            ))
        }
        var rowViews: [NSView] = [labels, NSView()]
        if voiceAvailable {
            rowViews.append(sourceSpeakerButton(
                accessibility: AppText.Translation.sourceWordSpeechAccessibility
            ))
        }
        let row = NSStackView(views: rowViews)
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    private func sourceSpeechRow(
        text: String,
        font: NSFont,
        color: NSColor,
        voiceAvailable: Bool
    ) -> NSView {
        let label = textLabel(text, font: font, color: color, selectable: true)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        var rowViews: [NSView] = [label]
        if voiceAvailable {
            rowViews.append(sourceSpeakerButton(
                accessibility: AppText.Translation.sourceTextSpeechAccessibility
            ))
        }
        let row = NSStackView(views: rowViews)
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = AppConfiguration.TranslationPanel.sourceRowSpacing
        return row
    }

    private func sourceSpeakerButton(accessibility: String) -> NSButton {
        symbolButton(
            "speaker.wave.2",
            action: #selector(sourceSpeechClicked(_:)),
            accessibility: accessibility,
            enabled: true
        )
    }

    private func meaningView(_ group: TranslationMeaningGroup) -> NSView {
        let badge = posBadge(group.partOfSpeech)
        var headingViews: [NSView] = [badge]
        if !group.translations.isEmpty {
            headingViews.append(textLabel(
                group.translations.joined(separator: " · "),
                font: .systemFont(ofSize: AppConfiguration.TranslationPanel.translationFontSize),
                color: .labelColor,
                selectable: true
            ))
        }
        let heading = NSStackView(views: headingViews)
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.spacing = 7
        var views: [NSView] = [heading]
        if let definition = group.definition {
            views.append(textLabel(
                definition,
                font: .systemFont(ofSize: AppConfiguration.TranslationPanel.meaningFontSize),
                color: .labelColor,
                selectable: true
            ))
        }
        if let example = group.example {
            views.append(textLabel(
                "“\(example)”",
                font: .systemFont(ofSize: AppConfiguration.TranslationPanel.exampleFontSize),
                color: .secondaryLabelColor,
                selectable: true
            ))
        }
        if !group.synonyms.isEmpty {
            views.append(textLabel(
                AppText.Translation.englishSynonyms + "  " + group.synonyms.joined(separator: " · "),
                font: .systemFont(ofSize: AppConfiguration.TranslationPanel.synonymFontSize),
                color: .secondaryLabelColor,
                selectable: true
            ))
        }
        let result = NSStackView(views: views)
        result.orientation = .vertical
        result.alignment = .leading
        result.spacing = AppConfiguration.TranslationPanel.meaningSpacing
        result.setAccessibilityLabel("\(group.partOfSpeech) meaning")
        for view in views {
            view.widthAnchor.constraint(equalTo: result.widthAnchor).isActive = true
        }
        return result
    }

    private func sectionLabel(_ value: String) -> NSView {
        let label = textLabel(
            value,
            font: .systemFont(
                ofSize: AppConfiguration.TranslationPanel.sectionFontSize,
                weight: .semibold
            ),
            color: .secondaryLabelColor
        )
        label.setAccessibilityLabel(value)
        label.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [label, NSView()])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 0
        return row
    }

    private func posBadge(_ value: String) -> NSView {
        let display = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = NSTextField(labelWithString: display)
        label.font = .systemFont(
            ofSize: AppConfiguration.TranslationPanel.badgeFontSize,
            weight: .semibold
        )
        label.textColor = .controlAccentColor
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byClipping
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        let badge = AccentBadgeView()
        badge.layer?.cornerRadius = AppConfiguration.TranslationPanel.badgeCornerRadius
        badge.addSubview(label)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(
                equalToConstant: ceil(label.intrinsicContentSize.width)
                    + AppConfiguration.TranslationPanel.badgeHorizontalInset * 2
            ),
            badge.heightAnchor.constraint(
                equalToConstant: AppConfiguration.TranslationPanel.badgeMinimumHeight
            ),
            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])
        label.setAccessibilityLabel("Part of speech: \(display)")
        return badge
    }

    private func textLabel(
        _ value: String,
        font: NSFont,
        color: NSColor,
        selectable: Bool = false
    ) -> NSTextField {
        let result = NSTextField(wrappingLabelWithString: value)
        result.font = font
        result.textColor = color
        result.isSelectable = selectable
        result.maximumNumberOfLines = 0
        return result
    }

    private func symbolButton(
        _ symbol: String,
        action: Selector,
        accessibility: String,
        enabled: Bool
    ) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibility)!
        let button = NSButton(image: image, target: self, action: action)
        button.bezelStyle = .inline
        button.imageScaling = .scaleProportionallyDown
        button.wantsLayer = true
        button.isEnabled = enabled
        button.toolTip = enabled ? accessibility : AppText.Translation.voiceUnavailable
        button.setAccessibilityLabel(accessibility)
        if !enabled { button.setAccessibilityHelp(AppText.Translation.voiceUnavailable) }
        return button
    }

    private func showPanel(anchor: SelectionAnchor) {
        updateAppearance(NSApplication.shared.effectiveAppearance)
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let reference: NSPoint
        switch anchor {
        case let .bounds(bounds):
            let converted = SelectionIconGeometry.appKitBounds(fromQuartz: bounds, mainDisplayHeight: mainHeight)
            reference = NSPoint(x: converted.x, y: converted.y)
        case let .mouse(point):
            reference = NSPoint(x: point.x, y: point.y)
        }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(reference) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let width = min(
            AppConfiguration.TranslationPanel.maximumWidth,
            max(
                AppConfiguration.TranslationPanel.minimumWidth,
                visible.width - AppConfiguration.TranslationPanel.screenMargin
            )
        )
        let maximumHeight = visible.height - AppConfiguration.TranslationPanel.screenMargin
        panel.setContentSize(NSSize(width: width, height: maximumHeight))
        effect.layoutSubtreeIfNeeded()
        let documentHeight = layoutDocument(width: scroll.contentView.bounds.width)
        let height = min(
            max(
                documentHeight + AppConfiguration.TranslationPanel.tailHeight,
                isInputMode
                    ? AppConfiguration.TranslationPanel.minimumInputHeight
                    : AppConfiguration.TranslationPanel.minimumHeight
            ),
            maximumHeight
        )
        panel.setContentSize(NSSize(width: width, height: height))
        effect.layoutSubtreeIfNeeded()
        _ = layoutDocument(width: scroll.contentView.bounds.width)
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        let placement = TranslationPopupGeometry.placement(
            anchor: anchor,
            mainDisplayHeight: mainHeight,
            visibleFrame: CaptureBounds(
                x: visible.minX, y: visible.minY,
                width: visible.width, height: visible.height
            ),
            popupWidth: width,
            popupHeight: height,
            tailInset: AppConfiguration.TranslationPanel.tailInset
        )
        panel.setFrameOrigin(NSPoint(x: placement.origin.x, y: placement.origin.y))
        updateBubbleMask(side: placement.tailSide, width: width, height: height)
        panel.orderFrontRegardless()
        if isInputMode {
            panel.makeKeyAndOrderFront(nil)
            focusInputPreservingSelection()
        }
        installMouseMonitorsIfNeeded()
    }

    private func captureInputSelection() {
        guard isInputMode,
              let editor = panel.fieldEditor(false, for: inputField) as? NSTextView,
              panel.firstResponder === editor
        else { return }
        inputSelectionRange = editor.selectedRange()
    }

    private func focusInputPreservingSelection() {
        let currentEditor = panel.fieldEditor(false, for: inputField) as? NSTextView
        if panel.firstResponder !== currentEditor {
            panel.makeFirstResponder(inputField)
        }
        guard let editor = panel.fieldEditor(false, for: inputField) as? NSTextView else { return }
        let textLength = (inputField.stringValue as NSString).length
        let location = min(inputSelectionRange.location, textLength)
        let length = min(inputSelectionRange.length, textLength - location)
        editor.setSelectedRange(NSRange(location: location, length: length))
    }

    private func updateBubbleMask(side: TranslationPopupTailSide, width: CGFloat, height: CGFloat) {
        let tailHeight = AppConfiguration.TranslationPanel.tailHeight
        let top = max(1, height - tailHeight)
        let radius = min(AppConfiguration.TranslationPanel.cornerRadius, top / 2)
        let path = CGMutablePath()
        let centerX = side == .left
            ? AppConfiguration.TranslationPanel.tailInset
            : width - AppConfiguration.TranslationPanel.tailInset
        let halfTail = AppConfiguration.TranslationPanel.tailHalfWidth

        path.move(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: width - radius, y: 0))
        path.addQuadCurve(to: CGPoint(x: width, y: radius), control: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: top - radius))
        path.addQuadCurve(
            to: CGPoint(x: width - radius, y: top),
            control: CGPoint(x: width, y: top)
        )
        path.addLine(to: CGPoint(x: centerX + halfTail, y: top))
        path.addLine(to: CGPoint(x: centerX, y: height))
        path.addLine(to: CGPoint(x: centerX - halfTail, y: top))
        path.addLine(to: CGPoint(x: radius, y: top))
        path.addQuadCurve(to: CGPoint(x: 0, y: top - radius), control: CGPoint(x: 0, y: top))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        bubbleMask.frame = CGRect(x: 0, y: 0, width: width, height: height)
        bubbleMask.path = path
    }

    private func installMouseMonitorsIfNeeded() {
        if globalMouseMonitor == nil {
            globalMouseMonitor = PopupMouseMonitorBridge.installGlobal { [weak self] snapshot in
                self?.dismissIfOutside(snapshot.point)
            }
        }
        if localMouseMonitor == nil {
            localMouseMonitor = PopupMouseMonitorBridge.installLocal { [weak self] snapshot in
                self?.dismissIfOutside(snapshot.point)
            }
        }
    }

    private func dismissIfOutside(_ point: CapturePoint) {
        guard panel.isVisible,
              !panel.frame.contains(NSPoint(x: point.x, y: point.y))
        else { return }
        dismiss()
    }

    private func removeMouseMonitors() {
        if let globalMouseMonitor { PopupMouseMonitorBridge.remove(globalMouseMonitor) }
        if let localMouseMonitor { PopupMouseMonitorBridge.remove(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
    }

    @discardableResult
    private func layoutDocument(width: CGFloat) -> CGFloat {
        let resolvedWidth = max(width, 1)
        stack.frame = NSRect(x: 0, y: 0, width: resolvedWidth, height: 1)
        stack.layoutSubtreeIfNeeded()
        let resolvedHeight = ceil(max(stack.fittingSize.height, 1))
        document.frame = NSRect(x: 0, y: 0, width: resolvedWidth, height: resolvedHeight)
        stack.frame = document.bounds
        stack.layoutSubtreeIfNeeded()
        return resolvedHeight
    }

    @objc private func closeClicked() { dismiss() }

    @objc private func sourceSpeechClicked(_ sender: NSButton) {
        guard let sourceSpeech else { return }
        animateAudioFeedback(sender)
        onSpeak(sourceSpeech)
    }

    private func animateAudioFeedback(_ button: NSButton) {
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1, 0.78, 1]
        scale.keyTimes = [0, 0.38, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1, 0.5, 1]
        opacity.keyTimes = scale.keyTimes
        let feedback = CAAnimationGroup()
        feedback.animations = [scale, opacity]
        feedback.duration = 0.22
        feedback.timingFunction = CAMediaTimingFunction(name: .easeOut)
        button.layer?.add(feedback, forKey: "audio-click-feedback")
    }
}

extension TranslationPanelController {
    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as? NSTextField === inputField else { return }
        captureInputSelection()
        onInputChanged?(inputField.stringValue)
    }
}
