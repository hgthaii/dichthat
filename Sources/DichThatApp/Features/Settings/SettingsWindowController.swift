import AppKit
import DichThatCore

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private enum Page: Int { case general, about }

    private let generalTab = NSButton()
    private let aboutTab = NSButton()
    private let contentHost = NSView()
    private let generalView = NSView()
    private let aboutView = NSView()
    private let permissionCard = NSVisualEffectView()
    private let shortcutEditor = ShortcutEditorView()
    private let shortcutErrorLabel = NSTextField(labelWithString: "")
    private let startupErrorLabel = NSTextField(labelWithString: "")
    private let launchAtLoginToggle = AppToggleButton()
    private let updateButton = NSButton()
    private let reportBugButton = NSButton()
    private let updateStatusLabel = NSTextField(wrappingLabelWithString: "")
    private var isPresented = false
    private var releaseURL: URL?
    private var currentShortcutDisplay = ""
    private var launchAtLoginEnabled = false

    private let onGrantPermission: @MainActor () -> Void
    private let onOpenPermissionSettings: @MainActor () -> Void
    private let onCommitShortcut: @MainActor (KeyboardShortcut) -> String?
    private let onToggleLaunchAtLogin: @MainActor (Bool) -> Void
    private let onCheckForUpdates: @Sendable () async -> UpdateCheckResult
    private let onDismiss: @MainActor () -> Void

    init(
        onGrantPermission: @escaping @MainActor () -> Void,
        onOpenPermissionSettings: @escaping @MainActor () -> Void,
        onCommitShortcut: @escaping @MainActor (KeyboardShortcut) -> String?,
        onToggleSelectionIcon: @escaping @MainActor (Bool) -> Void,
        onToggleLaunchAtLogin: @escaping @MainActor (Bool) -> Void,
        onCheckForUpdates: @escaping @Sendable () async -> UpdateCheckResult,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.onGrantPermission = onGrantPermission
        self.onOpenPermissionSettings = onOpenPermissionSettings
        self.onCommitShortcut = onCommitShortcut
        _ = onToggleSelectionIcon
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onCheckForUpdates = onCheckForUpdates
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(
                    width: AppConfiguration.Settings.windowWidth,
                    height: AppConfiguration.Settings.windowHeight
                )
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppText.Settings.windowTitle
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(state: SettingsState) {
        isPresented = true
        refresh(state: state)
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func refresh(state: SettingsState) {
        permissionCard.isHidden = state.accessibilityGranted
        currentShortcutDisplay = state.shortcutDisplay
        launchAtLoginEnabled = state.launchAtLoginEnabled
        shortcutEditor.updateCurrentShortcut(state.shortcutDisplay)
        shortcutErrorLabel.stringValue = state.shortcutError ?? ""
        shortcutErrorLabel.isHidden = state.shortcutError == nil
        launchAtLoginToggle.state = state.launchAtLoginEnabled ? .on : .off
        launchAtLoginToggle.needsDisplay = true
        startupErrorLabel.stringValue = state.launchAtLoginError ?? ""
        startupErrorLabel.isHidden = state.launchAtLoginError == nil
    }

    func windowDidResignKey(_ notification: Notification) {
        window?.orderOut(nil)
        finishPresentation()
    }

    func windowWillClose(_ notification: Notification) { finishPresentation() }

    private func finishPresentation() {
        guard isPresented else { return }
        isPresented = false
        onDismiss()
    }

    private func configureContent() {
        guard let root = window?.contentView else { return }
        configureTab(generalTab, title: AppText.Settings.general, action: #selector(showGeneral))
        configureTab(aboutTab, title: AppText.Settings.about, action: #selector(showAbout))
        let tabs = NSStackView(views: [generalTab, aboutTab])
        tabs.orientation = .horizontal
        tabs.spacing = 4
        tabs.translatesAutoresizingMaskIntoConstraints = false
        contentHost.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(tabs)
        root.addSubview(contentHost)
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            tabs.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            generalTab.widthAnchor.constraint(equalToConstant: 92),
            generalTab.heightAnchor.constraint(equalToConstant: 28),
            aboutTab.widthAnchor.constraint(equalToConstant: 92),
            aboutTab.heightAnchor.constraint(equalToConstant: 28),
            contentHost.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            contentHost.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            contentHost.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 18),
            contentHost.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -22),
        ])

        configureGeneralView()
        configureAboutView()
        for view in [generalView, aboutView] {
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
    }

    private func configureGeneralView() {
        shortcutEditor.onCommit = { [weak self] shortcut in self?.onCommitShortcut(shortcut) }
        launchAtLoginToggle.target = self
        launchAtLoginToggle.action = #selector(toggleLaunchAtLogin)
        configureErrorLabel(shortcutErrorLabel)
        configureErrorLabel(startupErrorLabel)
        configurePermissionCard()

        let shortcutCard = makeShortcutCard()
        let loginCard = makeLoginCard()
        let arranged = [permissionCard, shortcutCard, shortcutErrorLabel, loginCard, startupErrorLabel]
        let stack = NSStackView(views: arranged)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        generalView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: generalView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: generalView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: generalView.topAnchor),
        ] + arranged.map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
    }

    private func configurePermissionCard() {
        styleCard(permissionCard)
        let icon = NSImageView(image: symbol("lock.fill"))
        icon.contentTintColor = .systemOrange
        let title = NSTextField(labelWithString: AppText.Settings.accessibilityTitle)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        let grant = NSButton(
            title: AppText.Settings.grantAccess,
            target: self,
            action: #selector(grantPermission)
        )
        let open = NSButton(
            title: AppText.Settings.openSettings,
            target: self,
            action: #selector(openPermissionSettings)
        )
        let buttons = NSStackView(views: [grant, open])
        buttons.orientation = .horizontal
        buttons.spacing = 6
        let row = NSStackView(views: [icon, title, NSView(), buttons])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false
        permissionCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: permissionCard.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: permissionCard.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: permissionCard.centerYAnchor),
            permissionCard.heightAnchor.constraint(equalToConstant: 56),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private func makeShortcutCard() -> NSVisualEffectView {
        let card = makeCard()
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
        card.addSubview(heading)
        card.addSubview(shortcutEditor)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            heading.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            heading.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            shortcutEditor.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            shortcutEditor.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            shortcutEditor.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            shortcutEditor.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            card.heightAnchor.constraint(equalToConstant: 104),
        ])
        return card
    }

    private func makeLoginCard() -> NSVisualEffectView {
        let card = makeCard()
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
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            card.heightAnchor.constraint(equalToConstant: 58),
        ])
        return card
    }

    private func configureAboutView() {
        let icon = NSImageView(image: NSImage(named: NSImage.applicationIconName) ?? NSImage())
        icon.imageScaling = .scaleProportionallyUpOrDown
        let name = NSTextField(labelWithString: AppIdentity.productName)
        name.font = .systemFont(ofSize: 21, weight: .semibold)
        let version = NSTextField(labelWithString: "\(AppText.Settings.versionPrefix) \(AppIdentity.currentVersion)")
        version.textColor = .secondaryLabelColor
        let description = NSTextField(wrappingLabelWithString: AppText.Settings.aboutDescription)
        description.alignment = .center
        description.textColor = .secondaryLabelColor
        updateButton.title = AppText.Settings.checkForUpdates
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        reportBugButton.title = AppText.Settings.reportABug
        reportBugButton.target = self
        reportBugButton.action = #selector(reportBug)
        let actions = NSStackView(views: [updateButton, reportBugButton])
        actions.orientation = .horizontal
        actions.spacing = 8
        updateStatusLabel.alignment = .center
        updateStatusLabel.font = .systemFont(ofSize: 11)
        updateStatusLabel.textColor = .secondaryLabelColor
        let copyright = NSTextField(labelWithString: AppIdentity.copyright)
        copyright.textColor = .tertiaryLabelColor
        let stack = NSStackView(views: [
            icon, name, version, description, actions, updateStatusLabel, copyright,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        aboutView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: aboutView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: aboutView.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            icon.widthAnchor.constraint(equalToConstant: 68),
            icon.heightAnchor.constraint(equalToConstant: 68),
        ])
    }

    private func makeCard() -> NSVisualEffectView {
        let card = NSVisualEffectView()
        styleCard(card)
        return card
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
        button.layer?.cornerRadius = 7
    }

    private func show(page: Page) {
        generalView.isHidden = page != .general
        aboutView.isHidden = page != .about
        updateTabAppearance(generalTab, selected: page == .general)
        updateTabAppearance(aboutTab, selected: page == .about)
    }

    private func updateTabAppearance(_ button: NSButton, selected: Bool) {
        button.layer?.backgroundColor = (
            selected ? NSColor.selectedContentBackgroundColor : NSColor.clear
        ).cgColor
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: selected ? NSColor.white : NSColor.labelColor,
            ]
        )
    }

    @objc private func showGeneral() { show(page: .general) }
    @objc private func showAbout() { show(page: .about) }

    @objc private func grantPermission() { onGrantPermission() }
    @objc private func openPermissionSettings() { onOpenPermissionSettings() }
    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin(launchAtLoginToggle.state == .on)
    }

    @objc private func reportBug() {
        guard let url = BugReportDiagnosticsCollector.issueURL(
            shortcut: currentShortcutDisplay,
            launchAtLoginEnabled: launchAtLoginEnabled
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func checkForUpdates() {
        if let releaseURL {
            NSWorkspace.shared.open(releaseURL)
            return
        }
        updateButton.isEnabled = false
        updateButton.title = AppText.Settings.checkingForUpdates
        updateStatusLabel.stringValue = ""
        Task { [weak self] in
            guard let self else { return }
            let result = await onCheckForUpdates()
            updateButton.isEnabled = true
            switch result {
            case .upToDate:
                updateButton.title = AppText.Settings.checkForUpdates
                updateStatusLabel.stringValue = AppText.Settings.upToDate
            case let .available(version, url):
                releaseURL = url
                updateButton.title = AppText.Settings.openRelease
                updateStatusLabel.stringValue = "\(version) \(AppText.Settings.updateAvailableSuffix)"
            case .unavailable:
                updateButton.title = AppText.Settings.checkForUpdates
                updateStatusLabel.stringValue = AppText.Settings.updateUnavailable
            }
        }
    }
}
