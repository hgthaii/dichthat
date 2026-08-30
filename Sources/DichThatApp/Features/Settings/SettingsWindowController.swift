import AppKit
import DichThatCore

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private final class SettingsWindow: NSWindow {
        override func cancelOperation(_ sender: Any?) {
            performClose(sender)
        }
    }

    private final class AppearanceView: NSView {
        var onAppearanceChange: (() -> Void)?

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            onAppearanceChange?()
        }
    }

    private enum Page: Int { case general, about, dataSources }
    private enum SetupAction { case accessibility, translationLanguages }

    private let rootView = AppearanceView()
    private let generalTab = NSButton()
    private let aboutTab = NSButton()
    private let dataSourcesTab = NSButton()
    private let tabBackground = NSView()
    private let headerSeparator = NSView()
    private let shortcutSeparator = NSView()
    private let contentHost = NSView()
    private let generalView = NSView()
    private let aboutView = NSView()
    private let dataSourcesView = NSView()
    private let setupCard = NSVisualEffectView()
    private let setupIcon = NSImageView()
    private let setupTitleLabel = NSTextField(labelWithString: "")
    private let setupDetailLabel = NSTextField(labelWithString: "")
    private let setupProgress = NSProgressIndicator()
    private let setupActionButton = NSButton()
    private let shortcutEditor = ShortcutEditorView()
    private let shortcutErrorLabel = NSTextField(labelWithString: "")
    private let startupErrorLabel = NSTextField(labelWithString: "")
    private let launchAtLoginToggle = AppToggleButton()
    private let updateCard = NSVisualEffectView()
    private let updateDetailLabel = NSTextField(labelWithString: "")
    private let updateMetadataLabel = NSTextField(labelWithString: "")
    private let updateProgress = NSProgressIndicator()
    private let updateButton = NSButton()
    private let reportBugButton = NSButton()
    private let dataSourcesCard = NSVisualEffectView()
    private let dataSourcesTextView = NSTextView()
    private var isPresented = false
    private var currentShortcutDisplay = ""
    private var launchAtLoginEnabled = false
    private var selectedPage = Page.general
    private var updateState = UpdateState()
    private var setupAction = SetupAction.accessibility
    private var translationFeaturesEnabled = false
    private var isPreparingTranslationLanguages = false
    private let appVersion: String

    private let onGrantPermission: @MainActor () -> Void
    private let onPrepareTranslationLanguages: @MainActor () -> Void
    private let onCommitShortcut: @MainActor (KeyboardShortcut) -> String?
    private let onToggleLaunchAtLogin: @MainActor (Bool) -> Void
    private let onCheckForUpdates: @MainActor () -> Void
    private let onInstallUpdate: @MainActor () -> Void
    private let onDismiss: @MainActor () -> Void

    var translationPreparationHostView: NSView { rootView }

    init(
        onGrantPermission: @escaping @MainActor () -> Void,
        onPrepareTranslationLanguages: @escaping @MainActor () -> Void,
        appVersion: String,
        onCommitShortcut: @escaping @MainActor (KeyboardShortcut) -> String?,
        onToggleSelectionIcon: @escaping @MainActor (Bool) -> Void,
        onToggleLaunchAtLogin: @escaping @MainActor (Bool) -> Void,
        onCheckForUpdates: @escaping @MainActor () -> Void,
        onInstallUpdate: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.onGrantPermission = onGrantPermission
        self.onPrepareTranslationLanguages = onPrepareTranslationLanguages
        self.appVersion = appVersion
        self.onCommitShortcut = onCommitShortcut
        _ = onToggleSelectionIcon
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onCheckForUpdates = onCheckForUpdates
        self.onInstallUpdate = onInstallUpdate
        self.onDismiss = onDismiss

        let window = SettingsWindow(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(
                    width: AppConfiguration.Settings.windowWidth,
                    height: AppConfiguration.Settings.windowHeight
                )
            ),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = AppText.Settings.windowTitle
        window.titlebarAppearsTransparent = true
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(
        state: SettingsState,
        updateState: UpdateState,
        showAbout: Bool = false
    ) {
        isPresented = true
        refresh(state: state)
        refresh(updateState: updateState)
        let requestedPage: Page = showAbout ? .about : selectedPage
        show(page: translationFeaturesEnabled ? requestedPage : .general)
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func refresh(state: SettingsState) {
        translationFeaturesEnabled = state.translationLanguagesReady
        isPreparingTranslationLanguages = state.isPreparingTranslationLanguages
        refreshSetupCard(state: state)
        currentShortcutDisplay = state.shortcutDisplay
        launchAtLoginEnabled = state.launchAtLoginEnabled
        shortcutEditor.updateCurrentShortcut(state.shortcutDisplay)
        shortcutErrorLabel.stringValue = state.shortcutError ?? ""
        shortcutErrorLabel.isHidden = state.shortcutError == nil
        launchAtLoginToggle.state = state.launchAtLoginEnabled ? .on : .off
        launchAtLoginToggle.needsDisplay = true
        startupErrorLabel.stringValue = state.launchAtLoginError ?? ""
        startupErrorLabel.isHidden = state.launchAtLoginError == nil
        shortcutEditor.setControlsEnabled(translationFeaturesEnabled)
        launchAtLoginToggle.isEnabled = translationFeaturesEnabled
        launchAtLoginToggle.alphaValue = translationFeaturesEnabled ? 1 : 0.45
        aboutTab.isEnabled = translationFeaturesEnabled
        dataSourcesTab.isEnabled = translationFeaturesEnabled
        reportBugButton.isEnabled = translationFeaturesEnabled
        if !translationFeaturesEnabled, selectedPage != .general {
            show(page: .general)
        }
        refresh(updateState: updateState)
    }

    func refresh(updateState: UpdateState) {
        self.updateState = updateState
        updateProgress.isHidden = !updateState.isChecking
        if updateState.isChecking {
            updateProgress.startAnimation(nil)
        } else {
            updateProgress.stopAnimation(nil)
        }

        switch updateState.phase {
        case .idle:
            updateButton.title = AppText.Updates.checkForUpdates
            updateButton.isEnabled = true
        case .checking:
            updateButton.title = AppText.Updates.checking
            updateButton.isEnabled = false
        case .upToDate, .failed:
            updateButton.title = AppText.Updates.checkForUpdates
            updateButton.isEnabled = true
        case .available:
            updateButton.title = AppText.Updates.updateNow
            updateButton.isEnabled = true
        }
        updateButton.isEnabled = translationFeaturesEnabled && updateButton.isEnabled
        let detail = updateDetail(for: updateState)
        updateDetailLabel.stringValue = detail.status
        updateMetadataLabel.stringValue = detail.metadata
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if isPreparingTranslationLanguages, NSApplication.shared.isActive {
                return
            }
            window?.orderOut(nil)
            finishPresentation()
        }
    }

    func windowWillClose(_ notification: Notification) { finishPresentation() }

    private func finishPresentation() {
        guard isPresented else { return }
        isPresented = false
        onDismiss()
    }

    private func configureContent() {
        guard let window else { return }
        rootView.wantsLayer = true
        rootView.onAppearanceChange = { [weak self] in self?.refreshAppearance() }
        window.contentView = rootView
        configureTab(generalTab, title: AppText.Settings.general, action: #selector(showGeneral))
        configureTab(aboutTab, title: AppText.Settings.about, action: #selector(showAbout))
        configureTab(
            dataSourcesTab,
            title: AppText.Settings.dataSourcesTab,
            action: #selector(showDataSources)
        )
        let tabs = NSStackView(views: [generalTab, aboutTab, dataSourcesTab])
        tabs.orientation = .horizontal
        tabs.spacing = 0
        tabs.translatesAutoresizingMaskIntoConstraints = false

        tabBackground.wantsLayer = true
        tabBackground.layer?.cornerRadius = 7
        tabBackground.layer?.borderWidth = 1
        tabBackground.translatesAutoresizingMaskIntoConstraints = false
        tabBackground.addSubview(tabs)

        headerSeparator.wantsLayer = true
        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        contentHost.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(tabBackground)
        rootView.addSubview(headerSeparator)
        rootView.addSubview(contentHost)
        NSLayoutConstraint.activate([
            tabBackground.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 36),
            tabBackground.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            tabs.leadingAnchor.constraint(equalTo: tabBackground.leadingAnchor, constant: 1),
            tabs.trailingAnchor.constraint(equalTo: tabBackground.trailingAnchor, constant: -1),
            tabs.topAnchor.constraint(equalTo: tabBackground.topAnchor, constant: 1),
            tabs.bottomAnchor.constraint(equalTo: tabBackground.bottomAnchor, constant: -1),
            generalTab.widthAnchor.constraint(equalToConstant: AppConfiguration.Settings.tabWidth),
            generalTab.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.tabHeight),
            aboutTab.widthAnchor.constraint(equalToConstant: AppConfiguration.Settings.tabWidth),
            aboutTab.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.tabHeight),
            dataSourcesTab.widthAnchor.constraint(equalToConstant: AppConfiguration.Settings.tabWidth),
            dataSourcesTab.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.tabHeight),
            headerSeparator.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            headerSeparator.topAnchor.constraint(
                equalTo: rootView.topAnchor,
                constant: AppConfiguration.Settings.headerHeight
            ),
            headerSeparator.heightAnchor.constraint(equalToConstant: 1),
            contentHost.leadingAnchor.constraint(
                equalTo: rootView.leadingAnchor,
                constant: AppConfiguration.Settings.contentInset
            ),
            contentHost.trailingAnchor.constraint(
                equalTo: rootView.trailingAnchor,
                constant: -AppConfiguration.Settings.contentInset
            ),
            contentHost.topAnchor.constraint(equalTo: headerSeparator.bottomAnchor),
            contentHost.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -16),
        ])

        configureGeneralView()
        configureAboutView()
        configureDataSourcesView()
        for view in [generalView, aboutView, dataSourcesView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentHost.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentHost.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
            ])
        }
        show(page: .general)
        refreshAppearance()
    }

    private func configureGeneralView() {
        shortcutEditor.onCommit = { [weak self] shortcut in self?.onCommitShortcut(shortcut) }
        launchAtLoginToggle.target = self
        launchAtLoginToggle.action = #selector(toggleLaunchAtLogin)
        configureErrorLabel(shortcutErrorLabel)
        configureErrorLabel(startupErrorLabel)
        configureSetupCard()

        let shortcutSection = makeShortcutSection()
        let loginSection = makeLoginSection()
        let arranged = [
            setupCard, shortcutSection, shortcutErrorLabel, loginSection, startupErrorLabel,
        ]
        let stack = NSStackView(views: arranged)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = AppConfiguration.Settings.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        generalView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: generalView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: generalView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: generalView.topAnchor, constant: 18),
        ] + arranged.map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
    }

    private func configureSetupCard() {
        styleCard(setupCard)
        setupIcon.imageScaling = .scaleProportionallyDown
        setupTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        setupDetailLabel.font = .systemFont(ofSize: 11)
        setupDetailLabel.textColor = .secondaryLabelColor
        setupDetailLabel.lineBreakMode = .byTruncatingTail
        let labels = NSStackView(views: [setupTitleLabel, setupDetailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        setupActionButton.target = self
        setupActionButton.action = #selector(performSetupAction)
        setupProgress.style = .spinning
        setupProgress.controlSize = .small
        setupProgress.isDisplayedWhenStopped = false
        let row = NSStackView(views: [
            setupIcon, labels, NSView(), setupProgress, setupActionButton,
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false
        setupCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: setupCard.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: setupCard.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: setupCard.centerYAnchor),
            setupCard.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.permissionHeight),
            setupIcon.widthAnchor.constraint(equalToConstant: 16),
            setupIcon.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private func refreshSetupCard(state: SettingsState) {
        if !state.translationLanguagesReady {
            setupCard.isHidden = false
            setupAction = .translationLanguages
            setupIcon.image = symbol("arrow.down.circle.fill")
            setupIcon.contentTintColor = .systemBlue
            setupTitleLabel.stringValue = AppText.Settings.translationLanguagesTitle
            if state.isPreparingTranslationLanguages {
                setupDetailLabel.stringValue = AppText.Settings.downloadingTranslationLanguages
                setupProgress.startAnimation(nil)
            } else {
                setupDetailLabel.stringValue = state.translationLanguagesError
                    ?? AppText.Settings.translationLanguagesDescription
                setupProgress.stopAnimation(nil)
            }
            setupActionButton.title = AppText.Settings.downloadTranslationLanguages
            setupActionButton.isHidden = state.isPreparingTranslationLanguages
            setupActionButton.isEnabled = !state.isPreparingTranslationLanguages
        } else if !state.accessibilityGranted {
            setupProgress.stopAnimation(nil)
            setupCard.isHidden = false
            setupAction = .accessibility
            setupIcon.image = symbol("lock.fill")
            setupIcon.contentTintColor = .systemOrange
            setupTitleLabel.stringValue = AppText.Settings.accessibilityTitle
            setupDetailLabel.stringValue = AppText.Settings.accessibilityDescription
            setupActionButton.title = AppText.Settings.grantAccess
            setupActionButton.isHidden = false
            setupActionButton.isEnabled = true
        } else {
            setupProgress.stopAnimation(nil)
            setupCard.isHidden = true
        }
    }

    private func makeShortcutSection() -> NSView {
        let section = NSView()
        let title = NSTextField(labelWithString: AppText.Settings.shortcutTitle)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        let subtitle = NSTextField(labelWithString: AppText.Settings.shortcutSubtitle)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        let heading = NSStackView(views: [title, subtitle])
        heading.orientation = .vertical
        heading.alignment = .leading
        heading.spacing = 1
        heading.translatesAutoresizingMaskIntoConstraints = false
        shortcutEditor.translatesAutoresizingMaskIntoConstraints = false
        shortcutSeparator.wantsLayer = true
        shortcutSeparator.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(heading)
        section.addSubview(shortcutEditor)
        section.addSubview(shortcutSeparator)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            heading.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            heading.topAnchor.constraint(equalTo: section.topAnchor),
            shortcutEditor.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            shortcutEditor.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 10),
            shortcutEditor.widthAnchor.constraint(equalToConstant: 320),
            shortcutEditor.heightAnchor.constraint(equalToConstant: 42),
            shortcutSeparator.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            shortcutSeparator.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            shortcutSeparator.bottomAnchor.constraint(equalTo: section.bottomAnchor),
            shortcutSeparator.heightAnchor.constraint(equalToConstant: 1),
            section.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.shortcutHeight),
        ])
        return section
    }

    private func makeLoginSection() -> NSView {
        let section = NSView()
        let title = NSTextField(labelWithString: AppText.Settings.launchAtLoginTitle)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        let subtitle = NSTextField(labelWithString: AppText.Settings.launchAtLoginSubtitle)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        let row = NSStackView(views: [labels, NSView(), launchAtLoginToggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            row.topAnchor.constraint(equalTo: section.topAnchor, constant: 3),
            section.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.rowHeight),
        ])
        return section
    }

    private func configureAboutView() {
        let icon = AdaptiveAppIconView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        let name = NSTextField(labelWithString: AppIdentity.productName)
        name.font = .systemFont(ofSize: 16, weight: .semibold)
        let version = NSTextField(labelWithString: "\(AppText.Settings.versionPrefix) \(appVersion)")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor
        configureUpdateCard()
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        updateButton.controlSize = .small
        updateButton.font = .systemFont(ofSize: 12)
        reportBugButton.title = AppText.Settings.reportABug
        reportBugButton.target = self
        reportBugButton.action = #selector(reportBug)
        reportBugButton.controlSize = .small
        reportBugButton.font = .systemFont(ofSize: 12)
        let copyright = NSTextField(labelWithString: AppIdentity.copyright)
        copyright.font = .systemFont(ofSize: 10)
        copyright.textColor = .tertiaryLabelColor
        let stack = NSStackView(views: [
            icon, name, version, updateCard, reportBugButton, copyright,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 2
        stack.setCustomSpacing(8, after: icon)
        stack.setCustomSpacing(2, after: name)
        stack.setCustomSpacing(18, after: version)
        stack.setCustomSpacing(12, after: updateCard)
        stack.setCustomSpacing(14, after: reportBugButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        aboutView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: aboutView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: aboutView.centerYAnchor, constant: -2),
            updateCard.widthAnchor.constraint(
                equalToConstant: AppConfiguration.Settings.updateCardWidth
            ),
            icon.widthAnchor.constraint(equalToConstant: AppConfiguration.Settings.aboutIconSize),
            icon.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.aboutIconSize),
        ])
        refresh(updateState: updateState)
    }

    private func configureDataSourcesView() {
        let title = NSTextField(labelWithString: AppText.Settings.dataSources)
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        styleCard(dataSourcesCard)
        dataSourcesCard.layer?.borderWidth = AppConfiguration.Settings.cardBorderWidth
        dataSourcesCard.translatesAutoresizingMaskIntoConstraints = false

        dataSourcesTextView.isEditable = false
        dataSourcesTextView.isSelectable = true
        dataSourcesTextView.isAutomaticLinkDetectionEnabled = true
        dataSourcesTextView.drawsBackground = false
        dataSourcesTextView.font = .systemFont(ofSize: 11)
        dataSourcesTextView.textColor = .secondaryLabelColor
        dataSourcesTextView.textContainerInset = NSSize(width: 0, height: 4)
        dataSourcesTextView.isVerticallyResizable = true
        dataSourcesTextView.isHorizontallyResizable = false
        dataSourcesTextView.autoresizingMask = [.width]
        dataSourcesTextView.textContainer?.widthTracksTextView = true
        dataSourcesTextView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        dataSourcesTextView.string = dataSourcesText()

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = dataSourcesTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        dataSourcesCard.addSubview(scrollView)

        dataSourcesView.addSubview(title)
        dataSourcesView.addSubview(dataSourcesCard)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: dataSourcesView.leadingAnchor),
            title.topAnchor.constraint(equalTo: dataSourcesView.topAnchor, constant: 18),
            dataSourcesCard.leadingAnchor.constraint(equalTo: dataSourcesView.leadingAnchor),
            dataSourcesCard.trailingAnchor.constraint(equalTo: dataSourcesView.trailingAnchor),
            dataSourcesCard.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            dataSourcesCard.bottomAnchor.constraint(equalTo: dataSourcesView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: dataSourcesCard.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: dataSourcesCard.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: dataSourcesCard.topAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: dataSourcesCard.bottomAnchor, constant: -10),
        ])
    }

    private func dataSourcesText() -> String {
        guard let url = Bundle.main.url(
            forResource: "ATTRIBUTIONS",
            withExtension: "txt",
            subdirectory: "ThirdPartyNotices"
        ), let text = try? String(contentsOf: url, encoding: .utf8)
        else { return AppText.Settings.dataSourcesUnavailable }
        var lines = text.components(separatedBy: .newlines)
        if lines.count > 1, lines[1].allSatisfy({ $0 == "=" }) {
            lines.removeFirst(2)
        }
        while lines.first?.isEmpty == true {
            lines.removeFirst()
        }
        return lines.joined(separator: "\n")
    }

    private func configureUpdateCard() {
        styleCard(updateCard)
        updateCard.layer?.borderWidth = AppConfiguration.Settings.cardBorderWidth
        updateDetailLabel.font = .systemFont(ofSize: 12, weight: .medium)
        updateDetailLabel.textColor = .labelColor
        updateDetailLabel.lineBreakMode = .byTruncatingTail
        updateMetadataLabel.font = .systemFont(ofSize: 11)
        updateMetadataLabel.textColor = .secondaryLabelColor
        updateMetadataLabel.lineBreakMode = .byTruncatingTail
        updateProgress.style = .spinning
        updateProgress.controlSize = .small
        updateProgress.isDisplayedWhenStopped = false
        updateProgress.isHidden = true
        let labels = NSStackView(views: [updateDetailLabel, updateMetadataLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        let row = NSStackView(views: [labels, NSView(), updateProgress, updateButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        updateCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: updateCard.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: updateCard.trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: updateCard.centerYAnchor),
            updateCard.heightAnchor.constraint(
                equalToConstant: AppConfiguration.Settings.updateCardHeight
            ),
            updateProgress.widthAnchor.constraint(equalToConstant: 16),
            updateProgress.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private func updateDetail(for state: UpdateState) -> (status: String, metadata: String) {
        switch state.phase {
        case .idle:
            return (AppText.Updates.title, lastCheckedText(state.lastCheckedAt))
        case .checking:
            return (AppText.Updates.checkingDetail, lastCheckedText(state.lastCheckedAt))
        case .upToDate:
            return (AppText.Updates.upToDate, lastCheckedText(state.lastCheckedAt))
        case let .available(version):
            return (AppText.Updates.available(version: version), lastCheckedText(state.lastCheckedAt))
        case let .failed(message):
            let metadata = message.isEmpty ? lastCheckedText(state.lastCheckedAt) : message
            return (AppText.Updates.failed, metadata)
        }
    }

    private func lastCheckedText(_ date: Date?) -> String {
        guard let date else { return AppText.Updates.lastCheckedNever }
        if abs(date.timeIntervalSinceNow) < 60 {
            return AppText.Updates.lastCheckedJustNow
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: AppLanguage.current.localeIdentifier)
        formatter.unitsStyle = .full
        return "\(AppText.Updates.lastCheckedPrefix) \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func styleCard(_ card: NSVisualEffectView) {
        card.material = .contentBackground
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = AppConfiguration.Settings.cardRadius
        card.layer?.masksToBounds = true
    }

    private func configureErrorLabel(_ label: NSTextField) {
        label.font = .systemFont(ofSize: 11)
        label.textColor = .systemRed
        label.maximumNumberOfLines = 2
        label.isHidden = true
    }

    private func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }

    private func configureTab(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.target = self
        button.action = action
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
    }

    private func show(page: Page) {
        guard page == .general || translationFeaturesEnabled else { return }
        selectedPage = page
        generalView.isHidden = page != .general
        aboutView.isHidden = page != .about
        dataSourcesView.isHidden = page != .dataSources
        updateTabAppearance(generalTab, selected: page == .general)
        updateTabAppearance(aboutTab, selected: page == .about)
        updateTabAppearance(dataSourcesTab, selected: page == .dataSources)
    }

    private func updateTabAppearance(_ button: NSButton, selected: Bool) {
        button.layer?.backgroundColor = (
            SettingsAppearance.resolved(
                selected ? SettingsAppearance.selectedControlBackground : NSColor.clear,
                for: rootView.effectiveAppearance
            )
        )
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: selected ? NSColor.labelColor : NSColor.secondaryLabelColor,
            ]
        )
    }

    private func refreshAppearance() {
        let appearance = rootView.effectiveAppearance
        let windowBackground = SettingsAppearance.resolved(
            NSColor.windowBackgroundColor,
            for: appearance
        )
        rootView.layer?.backgroundColor = windowBackground
        window?.backgroundColor = NSColor.windowBackgroundColor
        tabBackground.layer?.backgroundColor = SettingsAppearance.resolved(
            SettingsAppearance.controlBackground,
            for: appearance
        )
        tabBackground.layer?.borderColor = SettingsAppearance.resolved(
            SettingsAppearance.border,
            for: appearance
        )
        let divider = SettingsAppearance.resolved(SettingsAppearance.divider, for: appearance)
        headerSeparator.layer?.backgroundColor = divider
        shortcutSeparator.layer?.backgroundColor = divider
        updateCard.layer?.backgroundColor = SettingsAppearance.resolved(
            SettingsAppearance.updateCardBackground,
            for: appearance
        )
        updateCard.layer?.borderColor = SettingsAppearance.resolved(
            SettingsAppearance.updateCardBorder,
            for: appearance
        )
        dataSourcesCard.layer?.backgroundColor = SettingsAppearance.resolved(
            SettingsAppearance.updateCardBackground,
            for: appearance
        )
        dataSourcesCard.layer?.borderColor = SettingsAppearance.resolved(
            SettingsAppearance.updateCardBorder,
            for: appearance
        )
        updateTabAppearance(generalTab, selected: selectedPage == .general)
        updateTabAppearance(aboutTab, selected: selectedPage == .about)
        updateTabAppearance(dataSourcesTab, selected: selectedPage == .dataSources)
        launchAtLoginToggle.needsDisplay = true
    }

    @objc private func showGeneral() { show(page: .general) }
    @objc private func showAbout() { show(page: .about) }
    @objc private func showDataSources() { show(page: .dataSources) }

    @objc private func performSetupAction() {
        switch setupAction {
        case .accessibility: onGrantPermission()
        case .translationLanguages: onPrepareTranslationLanguages()
        }
    }
    @objc private func toggleLaunchAtLogin() {
        guard translationFeaturesEnabled else { return }
        onToggleLaunchAtLogin(launchAtLoginToggle.state == .on)
    }

    @objc private func reportBug() {
        guard translationFeaturesEnabled else { return }
        guard let url = BugReportDiagnosticsCollector.issueURL(
            shortcut: currentShortcutDisplay,
            launchAtLoginEnabled: launchAtLoginEnabled
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func checkForUpdates() {
        guard translationFeaturesEnabled else { return }
        if updateState.availableVersion == nil {
            onCheckForUpdates()
        } else {
            onInstallUpdate()
        }
    }
}
