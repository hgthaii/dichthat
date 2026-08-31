import AppKit
import DichThatCore

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private final class SettingsWindow: NSWindow {
        override func cancelOperation(_ sender: Any?) {
            performClose(sender)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers == .control,
               event.charactersIgnoringModifiers?.lowercased() == "w" {
                performClose(nil)
                return true
            }
            return super.performKeyEquivalent(with: event)
        }
    }

    private final class AppearanceView: NSView {
        var onAppearanceChange: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

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
    private let tabSelectionIndicator = NSView()
    private let headerSeparator = NSView()
    private let setupSeparator = NSView()
    private let inputShortcutSeparator = NSView()
    private let aboutSeparator = NSView()
    private let contentHost = NSView()
    private let generalView = NSView()
    private let aboutView = NSView()
    private let dataSourcesView = NSView()
    private let setupSection = NSView()
    private let setupCard = NSVisualEffectView()
    private let setupIcon = NSImageView()
    private let setupTitleLabel = NSTextField(labelWithString: "")
    private let setupDetailLabel = NSTextField(labelWithString: "")
    private let setupProgress = NSProgressIndicator()
    private let setupActionButton = AnimatedSettingsButton()
    private let shortcutEditor = ShortcutEditorView()
    private let inputShortcutEditor = ShortcutEditorView()
    private let shortcutErrorLabel = NSTextField(labelWithString: "")
    private let inputShortcutErrorLabel = NSTextField(labelWithString: "")
    private let shortcutErrorBanner = NSView()
    private let inputShortcutErrorBanner = NSView()
    private let startupErrorLabel = NSTextField(labelWithString: "")
    private let launchAtLoginToggle = AppToggleButton()
    private let contextTranslationSection = NSView()
    private let contextTranslationStampView = NSView()
    private let contextTranslationBadge = NSTextField(labelWithString: AppText.Settings.comingSoon)
    private let contextTranslationToggle = AppToggleButton()
    private let updateCard = NSVisualEffectView()
    private let updateDetailLabel = NSTextField(labelWithString: "")
    private let updateMetadataLabel = NSTextField(labelWithString: "")
    private let updateProgress = NSProgressIndicator()
    private let updateButton = AnimatedSettingsButton()
    private let reportBugButton = AnimatedSettingsButton()
    private let dataSourcesCard = NSVisualEffectView()
    private let dataSourcesTextView = NSTextView()
    private var rootHeightConstraint: NSLayoutConstraint?
    private var tabIndicatorLeadingConstraint: NSLayoutConstraint?
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
    private let onCommitInputShortcut: @MainActor (KeyboardShortcut) -> String?
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
        onCommitInputShortcut: @escaping @MainActor (KeyboardShortcut) -> String?,
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
        self.onCommitInputShortcut = onCommitInputShortcut
        _ = onToggleSelectionIcon
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onCheckForUpdates = onCheckForUpdates
        self.onInstallUpdate = onInstallUpdate
        self.onDismiss = onDismiss

        let settingsContentSize = NSSize(
            width: AppConfiguration.Settings.windowWidth,
            height: AppConfiguration.Settings.windowHeight
        )
        let window = SettingsWindow(
            contentRect: NSRect(origin: .zero, size: settingsContentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = AppText.Settings.windowTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.isRestorable = false
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
        window?.initialFirstResponder = rootView
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(rootView)
    }

    func refresh(state: SettingsState) {
        translationFeaturesEnabled = state.translationLanguagesReady
        isPreparingTranslationLanguages = state.isPreparingTranslationLanguages
        refreshSetupCard(state: state)
        currentShortcutDisplay = state.shortcutDisplay
        launchAtLoginEnabled = state.launchAtLoginEnabled
        shortcutEditor.updateCurrentShortcut(state.shortcutDisplay)
        inputShortcutEditor.updateCurrentShortcut(state.inputShortcutDisplay)
        updateShortcutErrorBanner(
            shortcutErrorBanner,
            label: shortcutErrorLabel,
            message: state.shortcutError
        )
        updateShortcutErrorBanner(
            inputShortcutErrorBanner,
            label: inputShortcutErrorLabel,
            message: state.inputShortcutError
        )
        launchAtLoginToggle.state = state.launchAtLoginEnabled ? .on : .off
        launchAtLoginToggle.needsDisplay = true
        startupErrorLabel.stringValue = state.launchAtLoginError ?? ""
        startupErrorLabel.isHidden = state.launchAtLoginError == nil
        contextTranslationSection.isHidden = !translationFeaturesEnabled
            || !state.accessibilityGranted
        shortcutEditor.setControlsEnabled(translationFeaturesEnabled)
        inputShortcutEditor.setControlsEnabled(translationFeaturesEnabled)
        launchAtLoginToggle.isEnabled = translationFeaturesEnabled
        launchAtLoginToggle.alphaValue = translationFeaturesEnabled ? 1 : 0.45
        aboutTab.isEnabled = translationFeaturesEnabled
        dataSourcesTab.isEnabled = translationFeaturesEnabled
        reportBugButton.isEnabled = translationFeaturesEnabled
        if !translationFeaturesEnabled, selectedPage != .general {
            show(page: .general)
        }
        updateWindowHeight()
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
        let rootHeightConstraint = rootView.heightAnchor.constraint(
            equalToConstant: AppConfiguration.Settings.windowHeight
        )
        self.rootHeightConstraint = rootHeightConstraint
        NSLayoutConstraint.activate([
            rootView.widthAnchor.constraint(
                equalToConstant: AppConfiguration.Settings.windowWidth
            ),
            rootHeightConstraint,
        ])
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
        tabBackground.layer?.masksToBounds = true
        tabBackground.translatesAutoresizingMaskIntoConstraints = false
        tabSelectionIndicator.wantsLayer = true
        tabSelectionIndicator.layer?.cornerRadius = 6
        tabSelectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        tabBackground.addSubview(tabSelectionIndicator)
        tabBackground.addSubview(tabs)

        let tabIndicatorLeadingConstraint = tabSelectionIndicator.leadingAnchor.constraint(
            equalTo: tabBackground.leadingAnchor,
            constant: 1
        )
        self.tabIndicatorLeadingConstraint = tabIndicatorLeadingConstraint

        headerSeparator.wantsLayer = true
        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        contentHost.wantsLayer = true
        contentHost.layer?.masksToBounds = true
        contentHost.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(tabBackground)
        rootView.addSubview(headerSeparator)
        rootView.addSubview(contentHost)
        NSLayoutConstraint.activate([
            tabBackground.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 32),
            tabBackground.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            tabs.leadingAnchor.constraint(equalTo: tabBackground.leadingAnchor, constant: 1),
            tabs.trailingAnchor.constraint(equalTo: tabBackground.trailingAnchor, constant: -1),
            tabs.topAnchor.constraint(equalTo: tabBackground.topAnchor, constant: 1),
            tabs.bottomAnchor.constraint(equalTo: tabBackground.bottomAnchor, constant: -1),
            tabIndicatorLeadingConstraint,
            tabSelectionIndicator.topAnchor.constraint(
                equalTo: tabBackground.topAnchor,
                constant: 1
            ),
            tabSelectionIndicator.bottomAnchor.constraint(
                equalTo: tabBackground.bottomAnchor,
                constant: -1
            ),
            tabSelectionIndicator.widthAnchor.constraint(
                equalToConstant: AppConfiguration.Settings.tabWidth
            ),
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
        inputShortcutEditor.onCommit = {
            [weak self] shortcut in self?.onCommitInputShortcut(shortcut)
        }
        launchAtLoginToggle.target = self
        launchAtLoginToggle.action = #selector(toggleLaunchAtLogin)
        configureShortcutErrorBanner(shortcutErrorBanner, label: shortcutErrorLabel)
        configureShortcutErrorBanner(inputShortcutErrorBanner, label: inputShortcutErrorLabel)
        configureErrorLabel(startupErrorLabel)
        configureSetupCard()

        let shortcutSection = makeShortcutSection(
            title: AppText.Settings.shortcutTitle,
            subtitle: AppText.Settings.shortcutSubtitle,
            editor: shortcutEditor,
            errorBanner: shortcutErrorBanner,
            separator: nil
        )
        let inputShortcutSection = makeShortcutSection(
            title: AppText.Settings.inputShortcutTitle,
            subtitle: AppText.Settings.inputShortcutSubtitle,
            editor: inputShortcutEditor,
            errorBanner: inputShortcutErrorBanner,
            separator: inputShortcutSeparator
        )
        let loginSection = makeLoginSection()
        configureContextTranslationSection()
        let arranged = [
            setupSection, shortcutSection, inputShortcutSection,
            loginSection, startupErrorLabel, contextTranslationSection,
        ]
        let stack = NSStackView(views: arranged)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = AppConfiguration.Settings.sectionSpacing
        stack.setCustomSpacing(24, after: setupSection)
        stack.setCustomSpacing(0, after: shortcutSection)
        stack.setCustomSpacing(28, after: inputShortcutSection)
        stack.translatesAutoresizingMaskIntoConstraints = false
        generalView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: generalView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: generalView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: generalView.topAnchor, constant: 31),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: generalView.bottomAnchor),
        ] + arranged.map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
    }

    private func configureSetupCard() {
        styleCard(setupCard)
        setupCard.layer?.borderWidth = 1
        setupIcon.imageScaling = .scaleProportionallyDown
        setupTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        setupDetailLabel.font = .systemFont(ofSize: 11)
        setupDetailLabel.textColor = .secondaryLabelColor
        setupDetailLabel.maximumNumberOfLines = 2
        setupDetailLabel.lineBreakMode = .byWordWrapping
        let labels = NSStackView(views: [setupTitleLabel, setupDetailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 8
        setupActionButton.target = self
        setupActionButton.action = #selector(performSetupAction)
        setupActionButton.isBordered = false
        setupActionButton.wantsLayer = true
        setupActionButton.layer?.cornerRadius = 7
        setupActionButton.hoverScale = 1.003
        setupActionButton.pressedScale = 0.99
        setupActionButton.font = .systemFont(ofSize: 12, weight: .semibold)
        setupCard.translatesAutoresizingMaskIntoConstraints = false
        setupActionButton.translatesAutoresizingMaskIntoConstraints = false
        setupSeparator.wantsLayer = true
        setupSeparator.translatesAutoresizingMaskIntoConstraints = false
        setupProgress.style = .spinning
        setupProgress.controlSize = .small
        setupProgress.isDisplayedWhenStopped = false
        let row = NSStackView(views: [
            setupIcon, labels, NSView(), setupProgress,
        ])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        setupSection.addSubview(setupCard)
        setupSection.addSubview(setupActionButton)
        setupSection.addSubview(setupSeparator)
        setupCard.addSubview(row)
        NSLayoutConstraint.activate([
            setupCard.leadingAnchor.constraint(equalTo: setupSection.leadingAnchor),
            setupCard.trailingAnchor.constraint(equalTo: setupSection.trailingAnchor),
            setupCard.topAnchor.constraint(equalTo: setupSection.topAnchor),
            setupCard.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.permissionHeight),
            row.leadingAnchor.constraint(equalTo: setupCard.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: setupCard.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: setupCard.topAnchor, constant: 16),
            setupActionButton.leadingAnchor.constraint(equalTo: setupSection.leadingAnchor),
            setupActionButton.trailingAnchor.constraint(equalTo: setupSection.trailingAnchor),
            setupActionButton.topAnchor.constraint(equalTo: setupCard.bottomAnchor, constant: 16),
            setupActionButton.heightAnchor.constraint(
                equalToConstant: AppConfiguration.Settings.permissionActionHeight
            ),
            setupSeparator.leadingAnchor.constraint(equalTo: setupSection.leadingAnchor),
            setupSeparator.trailingAnchor.constraint(equalTo: setupSection.trailingAnchor),
            setupSeparator.topAnchor.constraint(equalTo: setupActionButton.bottomAnchor, constant: 23),
            setupSeparator.bottomAnchor.constraint(equalTo: setupSection.bottomAnchor),
            setupSeparator.heightAnchor.constraint(equalToConstant: 1),
            setupIcon.widthAnchor.constraint(equalToConstant: 16),
            setupIcon.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private func refreshSetupCard(state: SettingsState) {
        if !state.translationLanguagesReady {
            setupSection.isHidden = false
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
            setupSection.isHidden = false
            setupAction = .accessibility
            setupIcon.image = symbol("exclamationmark.triangle.fill")
            setupIcon.contentTintColor = .systemOrange
            setupTitleLabel.stringValue = AppText.Settings.accessibilityTitle
            setupDetailLabel.stringValue = AppText.Settings.accessibilityDescription
            setupActionButton.title = AppText.Settings.grantAccess
            setupActionButton.isHidden = false
            setupActionButton.isEnabled = true
        } else {
            setupProgress.stopAnimation(nil)
            setupSection.isHidden = true
        }
        refreshSetupActionAppearance()
    }

    private func refreshSetupActionAppearance() {
        setupActionButton.attributedTitle = NSAttributedString(
            string: setupActionButton.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.black.withAlphaComponent(
                    setupActionButton.isEnabled ? 0.88 : 0.42
                ),
            ]
        )
    }

    private func makeShortcutSection(
        title titleText: String,
        subtitle subtitleText: String,
        editor: ShortcutEditorView,
        errorBanner: NSView,
        separator: NSView?
    ) -> NSView {
        let section = NSView()
        let title = NSTextField(labelWithString: titleText)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        let subtitle = NSTextField(labelWithString: subtitleText)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2
        subtitle.lineBreakMode = .byWordWrapping
        let heading = NSStackView(views: [title, subtitle])
        heading.orientation = .vertical
        heading.alignment = .leading
        heading.spacing = 1
        heading.translatesAutoresizingMaskIntoConstraints = false
        editor.translatesAutoresizingMaskIntoConstraints = false
        separator?.wantsLayer = true
        separator?.translatesAutoresizingMaskIntoConstraints = false
        let row = NSStackView(views: [heading, NSView(), editor])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(row)
        section.addSubview(errorBanner)
        if let separator { section.addSubview(separator) }
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            row.topAnchor.constraint(equalTo: section.topAnchor),
            row.heightAnchor.constraint(equalToConstant: 42),
            editor.widthAnchor.constraint(
                equalToConstant: AppConfiguration.Settings.shortcutEditorWidth
            ),
            editor.heightAnchor.constraint(equalToConstant: 30),
            errorBanner.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            errorBanner.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            errorBanner.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 1),
            errorBanner.heightAnchor.constraint(equalToConstant: 24),
            section.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.shortcutHeight),
        ])
        if let separator {
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: section.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: section.trailingAnchor),
                separator.bottomAnchor.constraint(equalTo: section.bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1),
            ])
        }
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

    private func configureContextTranslationSection() {
        let title = NSTextField(labelWithString: AppText.Settings.contextTranslationTitle)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.textColor = .secondaryLabelColor
        let subtitle = NSTextField(labelWithString: AppText.Settings.contextTranslationSubtitle)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .tertiaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail

        contextTranslationBadge.font = .monospacedSystemFont(ofSize: 8, weight: .semibold)
        contextTranslationBadge.textColor = SettingsAppearance.comingSoonStamp
        contextTranslationBadge.alignment = .center
        contextTranslationBadge.translatesAutoresizingMaskIntoConstraints = false
        contextTranslationStampView.wantsLayer = true
        contextTranslationStampView.layer?.cornerRadius = 4
        contextTranslationStampView.layer?.borderWidth = 1
        contextTranslationStampView.layer?.setAffineTransform(
            CGAffineTransform(rotationAngle: -3 * .pi / 180)
        )
        contextTranslationStampView.setContentCompressionResistancePriority(.required, for: .horizontal)
        contextTranslationStampView.addSubview(contextTranslationBadge)
        NSLayoutConstraint.activate([
            contextTranslationBadge.centerXAnchor.constraint(equalTo: contextTranslationStampView.centerXAnchor),
            contextTranslationBadge.centerYAnchor.constraint(equalTo: contextTranslationStampView.centerYAnchor),
        ])

        let titleRow = NSStackView(views: [title, contextTranslationStampView])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8
        let labels = NSStackView(views: [titleRow, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        labels.alphaValue = 0.72

        contextTranslationToggle.state = .off
        contextTranslationToggle.isEnabled = false
        contextTranslationToggle.setAccessibilityLabel(AppText.Settings.contextTranslationTitle)

        let row = NSStackView(views: [labels, NSView(), contextTranslationToggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        contextTranslationSection.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contextTranslationSection.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contextTranslationSection.trailingAnchor),
            row.topAnchor.constraint(equalTo: contextTranslationSection.topAnchor, constant: 3),
            contextTranslationStampView.widthAnchor.constraint(equalToConstant: 86),
            contextTranslationStampView.heightAnchor.constraint(equalToConstant: 18),
            contextTranslationSection.heightAnchor.constraint(
                equalToConstant: AppConfiguration.Settings.rowHeight
            ),
        ])
    }

    private func configureAboutView() {
        let icon = AdaptiveAppIconView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        let name = NSTextField(labelWithString: AppIdentity.productName)
        name.font = .systemFont(ofSize: 22, weight: .bold)
        let version = NSTextField(labelWithString: "\(AppText.Settings.versionPrefix) \(appVersion)")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor
        let slogan = NSTextField(labelWithString: AppText.Settings.aboutDescription)
        slogan.font = .systemFont(ofSize: 13)
        slogan.textColor = .secondaryLabelColor
        configureUpdateCard()
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        updateButton.controlSize = .small
        updateButton.font = .systemFont(ofSize: 11, weight: .medium)
        reportBugButton.title = AppText.Settings.reportABug
        reportBugButton.target = self
        reportBugButton.action = #selector(reportBug)
        reportBugButton.isBordered = false
        reportBugButton.wantsLayer = true
        reportBugButton.layer?.cornerRadius = 7
        reportBugButton.layer?.borderWidth = 1
        reportBugButton.font = .systemFont(ofSize: 11, weight: .medium)
        let copyright = NSTextField(labelWithString: AppIdentity.copyright)
        copyright.font = .systemFont(ofSize: 10)
        copyright.textColor = .tertiaryLabelColor
        let identity = NSStackView(views: [icon, name, version, slogan])
        identity.orientation = .vertical
        identity.alignment = .centerX
        identity.spacing = 2
        identity.setCustomSpacing(10, after: icon)
        identity.setCustomSpacing(8, after: version)
        identity.translatesAutoresizingMaskIntoConstraints = false
        let footer = NSStackView(views: [reportBugButton, NSView(), copyright])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.translatesAutoresizingMaskIntoConstraints = false
        aboutSeparator.wantsLayer = true
        aboutSeparator.translatesAutoresizingMaskIntoConstraints = false
        updateCard.translatesAutoresizingMaskIntoConstraints = false
        aboutView.addSubview(identity)
        aboutView.addSubview(aboutSeparator)
        aboutView.addSubview(updateCard)
        aboutView.addSubview(footer)
        NSLayoutConstraint.activate([
            identity.centerXAnchor.constraint(equalTo: aboutView.centerXAnchor),
            identity.topAnchor.constraint(equalTo: aboutView.topAnchor, constant: 28),
            icon.widthAnchor.constraint(equalToConstant: AppConfiguration.Settings.aboutIconSize),
            icon.heightAnchor.constraint(equalToConstant: AppConfiguration.Settings.aboutIconSize),
            updateCard.leadingAnchor.constraint(equalTo: aboutView.leadingAnchor),
            updateCard.trailingAnchor.constraint(equalTo: aboutView.trailingAnchor),
            aboutSeparator.leadingAnchor.constraint(equalTo: aboutView.leadingAnchor),
            aboutSeparator.trailingAnchor.constraint(equalTo: aboutView.trailingAnchor),
            aboutSeparator.topAnchor.constraint(equalTo: identity.bottomAnchor, constant: 20),
            aboutSeparator.heightAnchor.constraint(equalToConstant: 1),
            updateCard.topAnchor.constraint(equalTo: aboutSeparator.bottomAnchor, constant: 16),
            footer.leadingAnchor.constraint(equalTo: aboutView.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: aboutView.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: aboutView.bottomAnchor, constant: -24),
            reportBugButton.widthAnchor.constraint(equalToConstant: 104),
            reportBugButton.heightAnchor.constraint(equalToConstant: 32),
        ])
        refresh(updateState: updateState)
    }

    private func configureDataSourcesView() {
        let title = NSTextField(labelWithString: AppText.Settings.dataSources)
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        let subtitle = NSTextField(labelWithString: AppText.Settings.dataSourcesDescription)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        styleCard(dataSourcesCard)
        dataSourcesCard.layer?.borderWidth = AppConfiguration.Settings.cardBorderWidth
        dataSourcesCard.translatesAutoresizingMaskIntoConstraints = false

        dataSourcesTextView.isEditable = false
        dataSourcesTextView.isSelectable = true
        dataSourcesTextView.isAutomaticLinkDetectionEnabled = false
        dataSourcesTextView.drawsBackground = false
        dataSourcesTextView.font = .systemFont(ofSize: 11)
        dataSourcesTextView.textColor = .secondaryLabelColor
        dataSourcesTextView.textContainerInset = NSSize(width: 0, height: 6)
        dataSourcesTextView.isVerticallyResizable = true
        dataSourcesTextView.isHorizontallyResizable = false
        dataSourcesTextView.autoresizingMask = [.width]
        dataSourcesTextView.textContainer?.widthTracksTextView = true
        dataSourcesTextView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        dataSourcesTextView.textStorage?.setAttributedString(dataSourcesAttributedText())

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = dataSourcesTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        dataSourcesCard.addSubview(scrollView)

        dataSourcesView.addSubview(title)
        dataSourcesView.addSubview(subtitle)
        dataSourcesView.addSubview(dataSourcesCard)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: dataSourcesView.leadingAnchor),
            title.topAnchor.constraint(equalTo: dataSourcesView.topAnchor, constant: 32),
            subtitle.leadingAnchor.constraint(equalTo: dataSourcesView.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: dataSourcesView.trailingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            dataSourcesCard.leadingAnchor.constraint(equalTo: dataSourcesView.leadingAnchor),
            dataSourcesCard.trailingAnchor.constraint(equalTo: dataSourcesView.trailingAnchor),
            dataSourcesCard.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 25),
            dataSourcesCard.heightAnchor.constraint(equalToConstant: 260),
            scrollView.leadingAnchor.constraint(equalTo: dataSourcesCard.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: dataSourcesCard.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: dataSourcesCard.topAnchor, constant: 14),
            scrollView.bottomAnchor.constraint(equalTo: dataSourcesCard.bottomAnchor, constant: -14),
        ])
    }

    private func dataSourcesAttributedText() -> NSAttributedString {
        let rawText = dataSourcesText()
        guard rawText != AppText.Settings.dataSourcesUnavailable else {
            return NSAttributedString(
                string: rawText,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
        }

        let paragraphs = rawText.components(separatedBy: "\n\n")
        let result = NSMutableAttributedString()
        for (index, paragraph) in paragraphs.enumerated() {
            let lines = paragraph.components(separatedBy: .newlines)
            guard let firstLine = lines.first, !firstLine.isEmpty else { continue }
            let isSystemFrameworkNotice = firstLine.hasPrefix(
                "Apple Translation and AVSpeechSynthesizer"
            )
            let title = isSystemFrameworkNotice ? "macOS Frameworks" : firstLine
            if index > 0 { result.append(NSAttributedString(string: "\n\n")) }

            var titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.linkColor,
            ]
            if let sourceLine = lines.first(where: { $0.hasPrefix("Source: ") }),
               let url = URL(string: String(sourceLine.dropFirst("Source: ".count))) {
                titleAttributes[.link] = url
            }
            result.append(NSAttributedString(string: title, attributes: titleAttributes))

            let body = isSystemFrameworkNotice
                ? lines.joined(separator: " ")
                : lines.dropFirst().joined(separator: "\n")
            guard !body.isEmpty else { continue }
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 2
            result.append(NSAttributedString(
                string: "\n\(body)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10.5),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: paragraphStyle,
                ]
            ))
        }
        return result
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

    private func configureShortcutErrorBanner(_ banner: NSView, label: NSTextField) {
        banner.wantsLayer = true
        banner.layer?.cornerRadius = 7
        banner.layer?.borderWidth = 1
        banner.alphaValue = 0
        banner.layer?.masksToBounds = true

        let icon = NSImageView(image: symbol("exclamationmark.triangle.fill"))
        icon.contentTintColor = .systemRed
        icon.imageScaling = .scaleProportionallyDown
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .systemRed
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        let row = NSStackView(views: [icon, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(lessThanOrEqualTo: banner.trailingAnchor, constant: -10),
            row.topAnchor.constraint(equalTo: banner.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -4),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    private func updateShortcutErrorBanner(
        _ banner: NSView,
        label: NSTextField,
        message: String?
    ) {
        label.stringValue = message ?? ""
        let targetAlpha: CGFloat = message == nil ? 0 : 1
        guard banner.alphaValue != targetAlpha else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = isPresented ? 0.16 : 0
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            banner.animator().alphaValue = targetAlpha
        }
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
        let pageChanged = selectedPage != page
        selectedPage = page
        updateWindowHeight()
        generalView.isHidden = page != .general
        aboutView.isHidden = page != .about
        dataSourcesView.isHidden = page != .dataSources
        updateTabSelectionIndicator(for: page, animated: pageChanged)
        updateTabAppearance(generalTab, selected: page == .general)
        updateTabAppearance(aboutTab, selected: page == .about)
        updateTabAppearance(dataSourcesTab, selected: page == .dataSources)
    }

    private func updateTabSelectionIndicator(for page: Page, animated: Bool) {
        guard let tabIndicatorLeadingConstraint, let indicatorLayer = tabSelectionIndicator.layer
        else { return }
        let previousPosition = indicatorLayer.presentation()?.position ?? indicatorLayer.position
        tabIndicatorLeadingConstraint.constant = 1
            + CGFloat(page.rawValue) * AppConfiguration.Settings.tabWidth

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tabBackground.layoutSubtreeIfNeeded()
        CATransaction.commit()

        guard animated,
              isPresented,
              window?.isVisible == true,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else {
            indicatorLayer.removeAnimation(forKey: "settings-tab-slide")
            return
        }
        let slide = CABasicAnimation(keyPath: "position")
        slide.fromValue = previousPosition
        slide.toValue = indicatorLayer.position
        slide.duration = AppConfiguration.Settings.tabAnimationDuration
        slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        indicatorLayer.add(slide, forKey: "settings-tab-slide")
    }

    private func updateWindowHeight() {
        guard let window, let rootHeightConstraint else { return }
        let targetHeight: CGFloat = switch selectedPage {
        case .general:
            setupSection.isHidden
                ? AppConfiguration.Settings.compactGeneralWindowHeight
                : AppConfiguration.Settings.windowHeight
        case .about:
            AppConfiguration.Settings.aboutWindowHeight
        case .dataSources:
            AppConfiguration.Settings.dataSourcesWindowHeight
        }
        let currentContentHeight = window.contentRect(forFrameRect: window.frame).height
        guard abs(rootHeightConstraint.constant - targetHeight) > 0.5
                || abs(currentContentHeight - targetHeight) > 0.5
        else { return }

        let currentFrame = window.frame
        let targetContentRect = NSRect(
            origin: .zero,
            size: NSSize(
                width: AppConfiguration.Settings.windowWidth,
                height: targetHeight
            )
        )
        var targetFrame = window.frameRect(forContentRect: targetContentRect)
        targetFrame.origin.x = currentFrame.minX
        targetFrame.origin.y = currentFrame.maxY - targetFrame.height

        rootHeightConstraint.constant = targetHeight
        window.setFrame(targetFrame, display: window.isVisible, animate: false)
        rootView.layoutSubtreeIfNeeded()
    }

    private func updateTabAppearance(_ button: NSButton, selected: Bool) {
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
        // Let the window draw the background so the rounded window frame stays crisp.
        rootView.layer?.backgroundColor = nil
        window?.backgroundColor = SettingsAppearance.windowBackground
        tabBackground.layer?.backgroundColor = SettingsAppearance.resolved(
            SettingsAppearance.controlBackground,
            for: appearance
        )
        tabBackground.layer?.borderColor = SettingsAppearance.resolved(
            SettingsAppearance.border,
            for: appearance
        )
        tabSelectionIndicator.layer?.backgroundColor = SettingsAppearance.resolved(
            SettingsAppearance.selectedControlBackground,
            for: appearance
        )
        let divider = SettingsAppearance.resolved(SettingsAppearance.divider, for: appearance)
        headerSeparator.layer?.backgroundColor = nil
        setupSeparator.layer?.backgroundColor = divider
        inputShortcutSeparator.layer?.backgroundColor = divider
        aboutSeparator.layer?.backgroundColor = divider
        let errorBackground = SettingsAppearance.resolved(
            NSColor.systemRed.withAlphaComponent(0.08),
            for: appearance
        )
        let errorBorder = SettingsAppearance.resolved(
            NSColor.systemRed.withAlphaComponent(0.28),
            for: appearance
        )
        for banner in [shortcutErrorBanner, inputShortcutErrorBanner] {
            banner.layer?.backgroundColor = errorBackground
            banner.layer?.borderColor = errorBorder
        }
        setupCard.layer?.backgroundColor = SettingsAppearance.resolved(
            SettingsAppearance.permissionBackground,
            for: appearance
        )
        setupCard.layer?.borderColor = SettingsAppearance.resolved(
            SettingsAppearance.permissionBorder,
            for: appearance
        )
        setupActionButton.layer?.backgroundColor = SettingsAppearance.resolved(
            NSColor.systemOrange,
            for: appearance
        )
        refreshSetupActionAppearance()
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
        reportBugButton.layer?.backgroundColor = SettingsAppearance.resolved(
            SettingsAppearance.cardBackground,
            for: appearance
        )
        reportBugButton.layer?.borderColor = SettingsAppearance.resolved(
            SettingsAppearance.cardBorder,
            for: appearance
        )
        contextTranslationStampView.layer?.backgroundColor = SettingsAppearance.resolved(
            NSColor.clear,
            for: appearance
        )
        contextTranslationStampView.layer?.borderColor = SettingsAppearance.resolved(
            SettingsAppearance.comingSoonStamp,
            for: appearance
        )
        updateTabAppearance(generalTab, selected: selectedPage == .general)
        updateTabAppearance(aboutTab, selected: selectedPage == .about)
        updateTabAppearance(dataSourcesTab, selected: selectedPage == .dataSources)
        launchAtLoginToggle.needsDisplay = true
        contextTranslationToggle.needsDisplay = true
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
