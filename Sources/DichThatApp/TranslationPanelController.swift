import AppKit
import DichThatCore

@MainActor
final class TranslationPanelController {
    private final class ResultPanel: NSPanel {
        var onEscape: (() -> Void)?
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
        override func cancelOperation(_ sender: Any?) { onEscape?() }
    }

    private final class DocumentView: NSView {
        override var isFlipped: Bool { true }
    }

    private let panel: ResultPanel
    private let effect = NSVisualEffectView()
    private let scroll = NSScrollView()
    private let document = DocumentView()
    private let stack = NSStackView()
    private let onDismiss: @MainActor () -> Void
    private let onSpeak: @MainActor (TranslationSpeechContent) -> Void
    private var sourceSpeech: TranslationSpeechContent?

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
        effect.layer?.cornerRadius = AppConfiguration.TranslationPanel.cornerRadius
        effect.layer?.masksToBounds = true
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
            scroll.topAnchor.constraint(equalTo: effect.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.onEscape = { [weak self] in self?.dismiss() }
    }

    func showLoading(anchor: SelectionAnchor) {
        sourceSpeech = nil
        rebuild([
            header("Dịch Thật"),
            textLabel(
                "Translating…",
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
            let meanings = enrichment.groups.filter { $0.definition != nil || $0.example != nil }
            if !meanings.isEmpty {
                views.append(sectionLabel("Meanings"))
                views.append(contentsOf: meanings.map(meaningView))
            }
            let translations = enrichment.groups.filter { !$0.translations.isEmpty }
            if !translations.isEmpty {
                views.append(sectionLabel("Translations"))
                views.append(contentsOf: translations.map(translationsView))
            }
        }
        if !sourceVoiceAvailable {
            views.append(textLabel(
                "Pronunciation unavailable",
                font: .systemFont(
                    ofSize: AppConfiguration.TranslationPanel.unavailableVoiceFontSize
                ),
                color: .tertiaryLabelColor
            ))
        }
        rebuild(views)
        showPanel(anchor: anchor)
    }

    func showFailure(_ message: String, anchor: SelectionAnchor) {
        sourceSpeech = nil
        rebuild([
            header("Couldn’t translate"),
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
        panel.orderOut(nil)
        clearContent()
    }

    private func dismiss() {
        hide()
        onDismiss()
    }

    private func rebuild(_ views: [NSView]) {
        clearContent()
        for view in views {
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
                accessibility: "Close translation",
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
            rowViews.append(sourceSpeakerButton(accessibility: "Pronounce source word"))
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
            rowViews.append(sourceSpeakerButton(accessibility: "Pronounce source text"))
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
            action: #selector(sourceSpeechClicked),
            accessibility: accessibility,
            enabled: true
        )
    }

    private func meaningView(_ group: TranslationMeaningGroup) -> NSView {
        let badge = posBadge(group.partOfSpeech)
        var views: [NSView] = [badge]
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
        let result = NSStackView(views: views)
        result.orientation = .vertical
        result.alignment = .leading
        result.spacing = AppConfiguration.TranslationPanel.meaningSpacing
        result.setAccessibilityLabel("\(group.partOfSpeech) meaning")
        for view in views where view !== badge {
            view.widthAnchor.constraint(equalTo: result.widthAnchor).isActive = true
        }
        return result
    }

    private func translationsView(_ group: TranslationMeaningGroup) -> NSView {
        let badge = posBadge(group.partOfSpeech)
        let translations = textLabel(
            group.translations.joined(separator: " · "),
            font: .systemFont(ofSize: AppConfiguration.TranslationPanel.translationFontSize),
            color: .labelColor,
            selectable: true
        )
        let result = NSStackView(views: [badge, translations])
        result.orientation = .vertical
        result.alignment = .leading
        result.spacing = AppConfiguration.TranslationPanel.translationSpacing
        result.setAccessibilityLabel("\(group.partOfSpeech) translations")
        translations.widthAnchor.constraint(equalTo: result.widthAnchor).isActive = true
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

        let divider = NSBox()
        divider.boxType = .separator
        divider.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [label, divider])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = AppConfiguration.TranslationPanel.sectionDividerSpacing
        return row
    }

    private func posBadge(_ value: String) -> NSView {
        let display = localizedPartOfSpeech(value)
        let label = NSTextField(labelWithString: display)
        label.font = .systemFont(
            ofSize: AppConfiguration.TranslationPanel.badgeFontSize,
            weight: .semibold
        )
        label.textColor = .controlAccentColor
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byClipping
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        let pill = NSStackView(views: [label])
        pill.orientation = .horizontal
        pill.alignment = .centerY
        pill.edgeInsets = NSEdgeInsets(
            top: AppConfiguration.TranslationPanel.badgeVerticalInset,
            left: AppConfiguration.TranslationPanel.badgeHorizontalInset,
            bottom: AppConfiguration.TranslationPanel.badgeVerticalInset,
            right: AppConfiguration.TranslationPanel.badgeHorizontalInset
        )
        pill.wantsLayer = true
        pill.layer?.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(0.14)
            .cgColor
        pill.layer?.cornerRadius = AppConfiguration.TranslationPanel.badgeCornerRadius
        pill.setContentHuggingPriority(.required, for: .horizontal)
        pill.setContentCompressionResistancePriority(.required, for: .horizontal)
        pill.heightAnchor.constraint(
            greaterThanOrEqualToConstant: AppConfiguration.TranslationPanel.badgeMinimumHeight
        ).isActive = true
        pill.setAccessibilityLabel("Part of speech: \(value); displayed as \(display)")
        return pill
    }

    private func localizedPartOfSpeech(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "noun": return "danh từ"
        case "adjective": return "tính từ"
        case "verb": return "động từ"
        case "adverb": return "trạng từ"
        case "pronoun": return "đại từ"
        case "preposition": return "giới từ"
        case "conjunction": return "liên từ"
        case "interjection", "exclamation": return "thán từ"
        case "determiner": return "từ hạn định"
        case "article": return "mạo từ"
        case "numeral": return "số từ"
        default: return value
        }
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
        button.isEnabled = enabled
        button.toolTip = enabled ? accessibility : "System voice unavailable"
        button.setAccessibilityLabel(accessibility)
        if !enabled { button.setAccessibilityHelp("System voice unavailable") }
        return button
    }

    private func showPanel(anchor: SelectionAnchor) {
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
        let maximumHeight = min(
            AppConfiguration.TranslationPanel.maximumHeight,
            visible.height - AppConfiguration.TranslationPanel.screenMargin
        )
        panel.setContentSize(NSSize(width: width, height: maximumHeight))
        effect.layoutSubtreeIfNeeded()
        let documentHeight = layoutDocument(width: scroll.contentView.bounds.width)
        let height = min(
            max(documentHeight, AppConfiguration.TranslationPanel.minimumHeight),
            maximumHeight
        )
        panel.setContentSize(NSSize(width: width, height: height))
        effect.layoutSubtreeIfNeeded()
        _ = layoutDocument(width: scroll.contentView.bounds.width)
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        let desired = NSPoint(
            x: reference.x + AppConfiguration.TranslationPanel.anchorOffset,
            y: reference.y - height - AppConfiguration.TranslationPanel.anchorOffset
        )
        panel.setFrameOrigin(NSPoint(
            x: min(max(desired.x, visible.minX), visible.maxX - width),
            y: min(max(desired.y, visible.minY), visible.maxY - height)
        ))
        panel.orderFrontRegardless()
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

    @objc private func sourceSpeechClicked() {
        guard let sourceSpeech else { return }
        onSpeak(sourceSpeech)
    }
}
