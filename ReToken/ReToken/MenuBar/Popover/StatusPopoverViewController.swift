import Cocoa

final class StatusPopoverViewController: NSViewController {
    private let appStateController: AppStateController
    private let onOpenDashboard: () -> Void
    private let onOpenCredentials: () -> Void

    // MARK: - Header views
    private let headerTitleLabel = NSTextField(labelWithString: "ReToken")
    private let modeDotView = NSView()
    private let lastUpdatedLabel = NSTextField(labelWithString: "")

    // MARK: - Hero views
    private let heroTokensLabel = NSTextField(labelWithString: "0")
    private let heroSubtitleLabel = NSTextField(labelWithString: "TOKENS TODAY")
    private let heroLifetimeTokensLabel = NSTextField(labelWithString: "0")
    private let heroLifetimeSubtitleLabel = NSTextField(labelWithString: "LIFETIME")
    private let rankBadgeLabel = NSTextField(labelWithString: "WARMING UP")
    private let shareButton = NSButton(title: "", target: nil, action: nil)

    // MARK: - Scrollable content
    private let providersStack = NSStackView()
    private let activityStack = NSStackView()
    private let issuesStack = NSStackView()
    private let issuesSectionContainer = NSView()

    // MARK: - Bottom bar
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let dashboardButton = NSButton(title: "Dashboard", target: nil, action: nil)

    private let rootEffectView = NSVisualEffectView()

    init(
        appStateController: AppStateController,
        onOpenDashboard: @escaping () -> Void,
        onOpenCredentials: @escaping () -> Void
    ) {
        self.appStateController = appStateController
        self.onOpenDashboard = onOpenDashboard
        self.onOpenCredentials = onOpenCredentials
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = rootEffectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()
        buildLayout()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange),
            name: .appStateControllerDidChange,
            object: appStateController
        )
        apply(snapshot: appStateController.snapshot)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Configuration

    private func configureView() {
        preferredContentSize = NSSize(width: 400, height: 600)
        rootEffectView.material = .hudWindow
        rootEffectView.state = .active
        rootEffectView.blendingMode = .behindWindow
        rootEffectView.wantsLayer = true
        rootEffectView.layer?.cornerRadius = 18
        rootEffectView.layer?.masksToBounds = true
    }

    // MARK: - Layout

    private func buildLayout() {
        // Fixed header
        let headerView = makeHeaderView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // Fixed hero
        let heroView = makeHeroView()
        heroView.translatesAutoresizingMaskIntoConstraints = false

        // Divider
        let divider = makeDivider()

        // Scrollable body
        let scrollView = makeScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Fixed bottom bar
        let bottomBar = makeBottomBar()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        [headerView, heroView, divider, scrollView, bottomBar].forEach {
            rootEffectView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            // Header pinned to top
            headerView.leadingAnchor.constraint(equalTo: rootEffectView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: rootEffectView.trailingAnchor, constant: -16),
            headerView.topAnchor.constraint(equalTo: rootEffectView.topAnchor, constant: 14),
            headerView.heightAnchor.constraint(equalToConstant: 28),

            // Hero below header
            heroView.leadingAnchor.constraint(equalTo: rootEffectView.leadingAnchor, constant: 16),
            heroView.trailingAnchor.constraint(equalTo: rootEffectView.trailingAnchor, constant: -16),
            heroView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),

            // Divider below hero
            divider.leadingAnchor.constraint(equalTo: rootEffectView.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: rootEffectView.trailingAnchor, constant: -16),
            divider.topAnchor.constraint(equalTo: heroView.bottomAnchor, constant: 14),
            divider.heightAnchor.constraint(equalToConstant: 1),

            // Bottom bar pinned to bottom
            bottomBar.leadingAnchor.constraint(equalTo: rootEffectView.leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: rootEffectView.trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: rootEffectView.bottomAnchor, constant: -12),
            bottomBar.heightAnchor.constraint(equalToConstant: 36),

            // Scroll view fills remaining space
            scrollView.leadingAnchor.constraint(equalTo: rootEffectView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootEffectView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8)
        ])
    }

    private func makeHeaderView() -> NSView {
        let flameImageView = NSImageView()
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            flameImageView.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        }
        flameImageView.contentTintColor = NSColor(calibratedRed: 0.98, green: 0.60, blue: 0.28, alpha: 1.0)
        flameImageView.translatesAutoresizingMaskIntoConstraints = false
        flameImageView.widthAnchor.constraint(equalToConstant: 18).isActive = true
        flameImageView.heightAnchor.constraint(equalToConstant: 18).isActive = true

        headerTitleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headerTitleLabel.textColor = .white

        modeDotView.wantsLayer = true
        modeDotView.layer?.cornerRadius = 4
        modeDotView.layer?.backgroundColor = NSColor.systemGreen.cgColor
        modeDotView.translatesAutoresizingMaskIntoConstraints = false
        modeDotView.widthAnchor.constraint(equalToConstant: 8).isActive = true
        modeDotView.heightAnchor.constraint(equalToConstant: 8).isActive = true

        lastUpdatedLabel.font = .systemFont(ofSize: 10, weight: .regular)
        lastUpdatedLabel.textColor = NSColor(calibratedWhite: 0.55, alpha: 1.0)
        lastUpdatedLabel.alignment = .right

        // Left cluster: flame + title + dot
        let leftStack = NSStackView(views: [flameImageView, headerTitleLabel, modeDotView])
        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 6

        // Share button
        let shareConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        shareButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")?
            .withSymbolConfiguration(shareConfig)
        shareButton.bezelStyle = .accessoryBar
        shareButton.isBordered = false
        shareButton.contentTintColor = NSColor(calibratedWhite: 0.55, alpha: 1.0)
        shareButton.target = self
        shareButton.action = #selector(shareSnapshot(_:))
        shareButton.toolTip = "Copy snapshot to clipboard"

        // Full header row
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let headerStack = NSStackView(views: [leftStack, spacer, lastUpdatedLabel, shareButton])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        return headerStack
    }

    private func makeHeroView() -> NSView {
        let todayAccent = NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.28, alpha: 1.0)
        let lifetimeAccent = NSColor(calibratedRed: 0.55, green: 0.85, blue: 1.0, alpha: 1.0)
        let subtitleColor = NSColor(calibratedWhite: 0.48, alpha: 1.0)

        // Today column
        heroTokensLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 42, weight: .bold)
        heroTokensLabel.textColor = todayAccent
        heroTokensLabel.alignment = .left

        heroSubtitleLabel.font = .systemFont(ofSize: 10, weight: .heavy)
        heroSubtitleLabel.textColor = subtitleColor
        heroSubtitleLabel.stringValue = "TOKENS TODAY"

        let todayColumn = NSStackView(views: [heroTokensLabel, heroSubtitleLabel])
        todayColumn.orientation = .vertical
        todayColumn.alignment = .leading
        todayColumn.spacing = 2

        // Lifetime column
        heroLifetimeTokensLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 42, weight: .bold)
        heroLifetimeTokensLabel.textColor = lifetimeAccent
        heroLifetimeTokensLabel.alignment = .left

        heroLifetimeSubtitleLabel.font = .systemFont(ofSize: 10, weight: .heavy)
        heroLifetimeSubtitleLabel.textColor = subtitleColor
        heroLifetimeSubtitleLabel.stringValue = "LIFETIME"

        let lifetimeColumn = NSStackView(views: [heroLifetimeTokensLabel, heroLifetimeSubtitleLabel])
        lifetimeColumn.orientation = .vertical
        lifetimeColumn.alignment = .leading
        lifetimeColumn.spacing = 2

        // Divider between columns
        let colDivider = NSView()
        colDivider.wantsLayer = true
        colDivider.layer?.backgroundColor = NSColor(calibratedWhite: 0.30, alpha: 0.45).cgColor
        colDivider.translatesAutoresizingMaskIntoConstraints = false
        colDivider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        colDivider.heightAnchor.constraint(equalToConstant: 52).isActive = true

        // Rank badge pill
        rankBadgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        rankBadgeLabel.textColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
        rankBadgeLabel.wantsLayer = true
        rankBadgeLabel.layer?.cornerRadius = 9
        rankBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.36, alpha: 1.0).cgColor
        rankBadgeLabel.alignment = .center
        rankBadgeLabel.cell?.usesSingleLineMode = true
        rankBadgeLabel.lineBreakMode = .byClipping
        rankBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true

        // Columns row
        let columnsRow = NSStackView(views: [todayColumn, colDivider, lifetimeColumn])
        columnsRow.orientation = .horizontal
        columnsRow.alignment = .centerY
        columnsRow.spacing = 16

        let heroStack = NSStackView(views: [columnsRow, rankBadgeLabel])
        heroStack.orientation = .vertical
        heroStack.alignment = .leading
        heroStack.spacing = 8

        return heroStack
    }

    private func makeDivider() -> NSView {
        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(calibratedWhite: 0.30, alpha: 0.45).cgColor
        return divider
    }

    private func makeScrollView() -> NSScrollView {
        // Section header for Providers
        let providersSectionHeader = makeSectionHeader("● PROVIDERS", color: ProviderKind.claude.accentColor)
        providersStack.orientation = .vertical
        providersStack.alignment = .leading
        providersStack.spacing = 8

        // Section header for Activity
        let activitySectionHeader = makeSectionHeader("● RECENT ACTIVITY", color: ProviderKind.codex.accentColor)
        activityStack.orientation = .vertical
        activityStack.alignment = .leading
        activityStack.spacing = 6

        // Issues section (hidden when empty)
        let issuesSectionHeader = makeSectionHeader("● ISSUES", color: NSColor(calibratedRed: 1.0, green: 0.60, blue: 0.25, alpha: 1.0))
        issuesStack.orientation = .vertical
        issuesStack.alignment = .leading
        issuesStack.spacing = 6

        issuesSectionContainer.translatesAutoresizingMaskIntoConstraints = false

        let issuesSectionInner = NSStackView(views: [issuesSectionHeader, issuesStack])
        issuesSectionInner.orientation = .vertical
        issuesSectionInner.alignment = .leading
        issuesSectionInner.spacing = 8
        issuesSectionInner.translatesAutoresizingMaskIntoConstraints = false
        issuesSectionContainer.addSubview(issuesSectionInner)
        NSLayoutConstraint.activate([
            issuesSectionInner.leadingAnchor.constraint(equalTo: issuesSectionContainer.leadingAnchor),
            issuesSectionInner.trailingAnchor.constraint(equalTo: issuesSectionContainer.trailingAnchor),
            issuesSectionInner.topAnchor.constraint(equalTo: issuesSectionContainer.topAnchor),
            issuesSectionInner.bottomAnchor.constraint(equalTo: issuesSectionContainer.bottomAnchor)
        ])

        let contentStack = NSStackView(views: [
            providersSectionHeader,
            providersStack,
            activitySectionHeader,
            activityStack,
            issuesSectionContainer
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.setCustomSpacing(8, after: providersSectionHeader)
        contentStack.setCustomSpacing(10, after: activitySectionHeader)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 10),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -10),

            providersStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            activityStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            issuesSectionContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])

        return scrollView
    }

    private func makeBottomBar() -> NSView {
        refreshButton.bezelStyle = .accessoryBar
        refreshButton.controlSize = .regular
        refreshButton.target = self
        refreshButton.action = #selector(refresh(_:))
        refreshButton.font = .systemFont(ofSize: 12, weight: .medium)

        dashboardButton.bezelStyle = .accessoryBar
        dashboardButton.controlSize = .regular
        dashboardButton.target = self
        dashboardButton.action = #selector(openDashboard(_:))
        dashboardButton.font = .systemFont(ofSize: 12, weight: .medium)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let bar = NSStackView(views: [spacer, refreshButton, dashboardButton])
        bar.orientation = .horizontal
        bar.alignment = .centerY
        bar.spacing = 8
        return bar
    }

    private func makeSectionHeader(_ text: String, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = color
        return label
    }

    // MARK: - State handling

    @objc
    private func handleAppStateChange() {
        apply(snapshot: appStateController.snapshot)
    }

    @objc
    private func refresh(_ sender: Any?) {
        appStateController.refreshData()
    }

    @objc
    private func openDashboard(_ sender: Any?) {
        onOpenDashboard()
    }

    @objc
    private func shareSnapshot(_ sender: Any?) {
        let bounds = view.bounds
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        view.cacheDisplay(in: bounds, to: bitmap)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        // Camera-flash overlay animation
        let flashView = NSView(frame: bounds)
        flashView.wantsLayer = true
        flashView.layer?.backgroundColor = NSColor.white.cgColor
        flashView.layer?.opacity = 0.85
        view.addSubview(flashView)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            flashView.animator().alphaValue = 0
        }, completionHandler: {
            flashView.removeFromSuperview()
        })

        // Flash copy button green
        shareButton.contentTintColor = NSColor.systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.shareButton.contentTintColor = NSColor(calibratedWhite: 0.55, alpha: 1.0)
        }
    }

    // MARK: - Apply snapshot

    private func apply(snapshot: AppSnapshot) {
        // Header
        let isLive = snapshot.mode == .live
        modeDotView.layer?.backgroundColor = (isLive ? NSColor.systemGreen : NSColor.systemOrange).cgColor
        lastUpdatedLabel.stringValue = AppSnapshotFormatter.lastUpdatedLine(for: snapshot)

        // Hero — today + lifetime side by side
        heroTokensLabel.stringValue = AppSnapshotFormatter.compactTokenCount(snapshot.totalTodayTokens)
        heroLifetimeTokensLabel.stringValue = AppSnapshotFormatter.compactTokenCount(snapshot.totalLifetimeTokens)
        rankBadgeLabel.stringValue = snapshot.leaderboardSummary.currentRunRank.map { "ALL-TIME #\($0)" } ?? "NEW RUN"

        // Provider rows
        replaceArrangedSubviews(
            of: providersStack,
            with: makeProviderRows(from: snapshot)
        )

        // Activity rows
        replaceArrangedSubviews(
            of: activityStack,
            with: makeActivityRows(from: snapshot)
        )

        // Issues (hide section when empty)
        let issueRows = makeIssueRows(from: snapshot)
        issuesSectionContainer.isHidden = snapshot.issues.isEmpty
        replaceArrangedSubviews(of: issuesStack, with: issueRows)
    }

    private func replaceArrangedSubviews(of stack: NSStackView, with views: [NSView]) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        views.forEach { stack.addArrangedSubview($0) }
    }

    // MARK: - Row factories

    private func makeProviderRows(from snapshot: AppSnapshot) -> [NSView] {
        guard snapshot.usage.isEmpty == false else {
            return [PopoverActivityEmptyRow(text: "No provider data available yet.")]
        }

        let maxTokens = max(snapshot.usage.map(\.todayTokens).max() ?? 1, 1)
        let accountsByProvider = Dictionary(uniqueKeysWithValues: snapshot.accounts.map { ($0.provider, $0) })

        return snapshot.usage.map { usage in
            let planLabel = accountsByProvider[usage.provider]?.planLabel
            let subtitle = AppSnapshotFormatter.providerPrimarySummary(for: usage)
            let detail = AppSnapshotFormatter.providerSecondarySummary(
                for: usage,
                planLabel: planLabel,
                referenceDate: snapshot.lastUpdatedAt
            )
            return ProviderStatRowView(
                provider: usage.provider,
                todayTitle: AppSnapshotFormatter.compactTokenCount(usage.todayTokens),
                subtitle: subtitle,
                detail: detail,
                ratio: CGFloat(usage.todayTokens) / CGFloat(maxTokens)
            )
        }
    }

    private func makeActivityRows(from snapshot: AppSnapshot) -> [NSView] {
        if snapshot.recentActivity.isEmpty {
            return [PopoverActivityEmptyRow()]
        }

        return snapshot.recentActivity.prefix(5).map { item in
            PopoverActivityRow(item: item)
        }
    }

    private func makeIssueRows(from snapshot: AppSnapshot) -> [NSView] {
        return snapshot.issues.map { issue in
            let text = AppSnapshotFormatter.issuesMenuLine(for: issue)
            let label = NSTextField(labelWithString: text)
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(calibratedRed: 1.0, green: 0.65, blue: 0.30, alpha: 1.0)
            label.maximumNumberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }
    }
}

// MARK: - Provider stat row

private final class ProviderStatRowView: NSView {
    private let fillView = NSView()
    private let fillWidthConstraint: NSLayoutConstraint

    init(provider: ProviderKind, todayTitle: String, subtitle: String, detail: String?, ratio: CGFloat) {
        let nameLabel = NSTextField(labelWithString: provider.displayName)
        let iconView = NSImageView()
        let valueLabel = NSTextField(labelWithString: todayTitle)
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        let detailLabel = NSTextField(labelWithString: detail ?? "")
        let barTrack = NSView()

        fillWidthConstraint = fillView.widthAnchor.constraint(
            equalTo: barTrack.widthAnchor,
            multiplier: max(0.04, min(ratio, 1.0))
        )

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = .white

        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            iconView.image = NSImage(systemSymbolName: provider.symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        }
        iconView.contentTintColor = provider.accentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        valueLabel.textColor = provider.accentColor

        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.76, alpha: 1.0)
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail

        detailLabel.font = .systemFont(ofSize: 10, weight: .regular)
        detailLabel.textColor = NSColor(calibratedWhite: 0.54, alpha: 1.0)
        detailLabel.maximumNumberOfLines = 2
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.isHidden = (detail?.isEmpty ?? true)

        barTrack.wantsLayer = true
        barTrack.layer?.cornerRadius = 3
        barTrack.layer?.backgroundColor = NSColor(calibratedWhite: 0.20, alpha: 1.0).cgColor
        barTrack.translatesAutoresizingMaskIntoConstraints = false

        fillView.wantsLayer = true
        fillView.layer?.cornerRadius = 3
        fillView.layer?.backgroundColor = provider.accentColor.cgColor
        fillView.translatesAutoresizingMaskIntoConstraints = false
        barTrack.addSubview(fillView)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let titleRow = NSStackView(views: [iconView, nameLabel, spacer, valueLabel])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 6

        let stackView = NSStackView(views: [titleRow, barTrack, subtitleLabel, detailLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            barTrack.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            barTrack.heightAnchor.constraint(equalToConstant: 12),

            fillView.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            fillView.topAnchor.constraint(equalTo: barTrack.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            fillWidthConstraint
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Activity rows

private final class PopoverActivityRow: NSView {
    init(item: RecentActivityItem) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let dotView = NSView()
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4
        dotView.layer?.backgroundColor = item.provider.accentColor.cgColor
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dotView.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let titleLabel = NSTextField(labelWithString: "\(item.provider.displayName) • \(item.title)")
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .short
        let relative = relFormatter.localizedString(for: item.occurredAt, relativeTo: .now)
        let timeLabel = NSTextField(labelWithString: relative)
        timeLabel.font = .systemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = NSColor(calibratedWhite: 0.55, alpha: 1.0)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = NSStackView(views: [dotView, titleLabel, timeLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

private final class PopoverActivityEmptyRow: NSView {
    init(text: String = "No recent activity yet.") {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = NSColor(calibratedWhite: 0.50, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - ProviderKind style helpers

private extension ProviderKind {
    var accentColor: NSColor {
        switch self {
        case .claude: return NSColor(calibratedRed: 0.98, green: 0.60, blue: 0.28, alpha: 1.0)
        case .codex:  return NSColor(calibratedRed: 0.47, green: 0.83, blue: 0.55, alpha: 1.0)
        case .gemini: return NSColor(calibratedRed: 0.35, green: 0.68, blue: 1.0,  alpha: 1.0)
        }
    }

    var symbolName: String {
        switch self {
        case .claude: return "flame.fill"
        case .codex:  return "terminal.fill"
        case .gemini: return "sparkles"
        }
    }
}
