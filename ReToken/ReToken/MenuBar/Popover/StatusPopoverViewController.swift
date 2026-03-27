import Cocoa

final class StatusPopoverViewController: NSViewController {
    private let appStateController: AppStateController
    private let onOpenDashboard: () -> Void
    private let onOpenCredentials: () -> Void

    private let titleLabel = NSTextField(labelWithString: "ReToken")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let totalTokensLabel = NSTextField(labelWithString: "0")
    private let rankBadgeLabel = NSTextField(labelWithString: "WARMING UP")
    private let leaderboardLabel = NSTextField(labelWithString: "")
    private let modeControl = NSSegmentedControl(labels: ["Mock", "Live"], trackingMode: .selectOne, target: nil, action: nil)
    private let refreshIntervalButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let credentialsButton = NSButton(title: "Credentials", target: nil, action: nil)
    private let dashboardButton = NSButton(title: "Full Board", target: nil, action: nil)
    private let issuesContainer = StatusSectionView(title: "Issues", accentColor: NSColor.systemOrange)
    private let providersContainer = StatusSectionView(title: "Providers", accentColor: NSColor.systemPink)
    private let activityContainer = StatusSectionView(title: "Recent Activity", accentColor: NSColor.systemTeal)
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
        configureControls()
        layoutView()
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

    private func configureView() {
        preferredContentSize = NSSize(width: 430, height: 560)
        rootEffectView.material = .hudWindow
        rootEffectView.state = .active
        rootEffectView.blendingMode = .behindWindow
        rootEffectView.wantsLayer = true
        rootEffectView.layer?.cornerRadius = 18
        rootEffectView.layer?.masksToBounds = true
    }

    private func configureControls() {
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.78, alpha: 1.0)
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping

        totalTokensLabel.font = .systemFont(ofSize: 42, weight: .black)
        totalTokensLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.33, alpha: 1.0)

        rankBadgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        rankBadgeLabel.textColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        rankBadgeLabel.wantsLayer = true
        rankBadgeLabel.layer?.cornerRadius = 10
        rankBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.36, alpha: 1.0).cgColor
        rankBadgeLabel.alignment = .center
        rankBadgeLabel.cell?.usesSingleLineMode = true
        rankBadgeLabel.lineBreakMode = .byClipping

        leaderboardLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        leaderboardLabel.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        leaderboardLabel.maximumNumberOfLines = 0
        leaderboardLabel.lineBreakMode = .byWordWrapping

        modeControl.target = self
        modeControl.action = #selector(changeProviderMode(_:))
        modeControl.segmentStyle = .capsule

        refreshIntervalButton.target = self
        refreshIntervalButton.action = #selector(changeRefreshInterval(_:))
        refreshIntervalButton.removeAllItems()
        refreshIntervalButton.addItems(withTitles: ["5m refresh", "15m refresh", "30m refresh"])

        [refreshButton, credentialsButton, dashboardButton].forEach {
            $0.bezelStyle = .rounded
            $0.controlSize = .large
        }
        refreshButton.target = self
        refreshButton.action = #selector(refresh(_:))
        credentialsButton.target = self
        credentialsButton.action = #selector(openCredentials(_:))
        dashboardButton.target = self
        dashboardButton.action = #selector(openDashboard(_:))
    }

    private func layoutView() {
        let heroStack = NSStackView(views: [totalTokensLabel, rankBadgeLabel])
        heroStack.orientation = .horizontal
        heroStack.alignment = .centerY
        heroStack.spacing = 10

        let controlsStack = NSStackView(views: [modeControl, refreshIntervalButton])
        controlsStack.orientation = .horizontal
        controlsStack.alignment = .centerY
        controlsStack.spacing = 10
        controlsStack.distribution = .fillEqually

        let actionsStack = NSStackView(views: [refreshButton, credentialsButton, dashboardButton])
        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.spacing = 10
        actionsStack.distribution = .fillEqually

        let contentStack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            heroStack,
            leaderboardLabel,
            controlsStack,
            actionsStack,
            providersContainer,
            activityContainer,
            issuesContainer
        ])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)
        scrollView.documentView = documentView

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -18),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 18),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -18),

            rankBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 92)
        ])
    }

    @objc
    private func handleAppStateChange() {
        apply(snapshot: appStateController.snapshot)
    }

    @objc
    private func refresh(_ sender: Any?) {
        appStateController.refreshData()
    }

    @objc
    private func openCredentials(_ sender: Any?) {
        onOpenCredentials()
    }

    @objc
    private func openDashboard(_ sender: Any?) {
        onOpenDashboard()
    }

    @objc
    private func changeProviderMode(_ sender: NSSegmentedControl) {
        let mode: ProviderMode = sender.selectedSegment == 1 ? .live : .mock
        appStateController.setProviderMode(mode)
    }

    @objc
    private func changeRefreshInterval(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0:
            appStateController.setRefreshIntervalMinutes(5)
        case 1:
            appStateController.setRefreshIntervalMinutes(15)
        default:
            appStateController.setRefreshIntervalMinutes(30)
        }
    }

    private func apply(snapshot: AppSnapshot) {
        titleLabel.stringValue = "ReToken"
        subtitleLabel.stringValue = AppSnapshotFormatter.lastUpdatedLine(for: snapshot)
        totalTokensLabel.stringValue = AppSnapshotFormatter.compactTokenCount(snapshot.totalTodayTokens)
        rankBadgeLabel.stringValue = snapshot.leaderboardSummary.currentRunRank.map { "ALL-TIME #\($0)" } ?? "NEW RUN"
        leaderboardLabel.stringValue = leaderboardText(for: snapshot)

        modeControl.selectedSegment = snapshot.mode == .live ? 1 : 0

        switch appStateController.refreshIntervalMinutes {
        case 15:
            refreshIntervalButton.selectItem(at: 1)
        case 30:
            refreshIntervalButton.selectItem(at: 2)
        default:
            refreshIntervalButton.selectItem(at: 0)
        }

        providersContainer.setRows(makeProviderRows(from: snapshot))
        activityContainer.setRows(makeActivityRows(from: snapshot))
        issuesContainer.setRows(makeIssueRows(from: snapshot))
    }

    private func leaderboardText(for snapshot: AppSnapshot) -> String {
        let summary = snapshot.leaderboardSummary
        let peak = AppSnapshotFormatter.compactTokenCount(summary.bestRecordedTotal)
        if let champion = summary.championEntry {
            return "Peak board: \(peak) total. Champion \(champion.provider.displayName) at \(AppSnapshotFormatter.compactTokenCount(champion.bestTokens))."
        }

        return "Start stacking runs and this board will crown a champion."
    }

    private func makeProviderRows(from snapshot: AppSnapshot) -> [NSView] {
        let maxTokens = max(snapshot.usage.map(\.todayTokens).max() ?? 1, 1)
        let accountsByProvider = Dictionary(uniqueKeysWithValues: snapshot.accounts.map { ($0.provider, $0) })

        return snapshot.usage.map { usage in
            let subtitle = accountsByProvider[usage.provider].map {
                "\($0.planLabel) • \(usage.windowDescription)"
            } ?? usage.windowDescription
            return ProviderStatRowView(
                provider: usage.provider,
                title: AppSnapshotFormatter.compactTokenCount(usage.todayTokens),
                subtitle: subtitle,
                ratio: CGFloat(usage.todayTokens) / CGFloat(maxTokens)
            )
        }
    }

    private func makeActivityRows(from snapshot: AppSnapshot) -> [NSView] {
        if snapshot.recentActivity.isEmpty {
            return [StatusTextRowView(text: "No recent activity yet.", textColor: NSColor(calibratedWhite: 0.72, alpha: 1.0))]
        }

        return snapshot.recentActivity.prefix(3).map { item in
            let relative = RelativeDateTimeFormatter().localizedString(for: item.occurredAt, relativeTo: .now)
            return StatusTextRowView(
                text: "\(item.provider.displayName) • \(item.title)\n\(item.detail) • \(relative)",
                textColor: .white
            )
        }
    }

    private func makeIssueRows(from snapshot: AppSnapshot) -> [NSView] {
        if snapshot.issues.isEmpty {
            return [StatusTextRowView(text: "No active issues.", textColor: NSColor(calibratedWhite: 0.76, alpha: 1.0))]
        }

        return snapshot.issues.map { issue in
            StatusTextRowView(
                text: AppSnapshotFormatter.issuesMenuLine(for: issue),
                textColor: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.45, alpha: 1.0)
            )
        }
    }
}

private final class StatusSectionView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let stackView = NSStackView()

    init(title: String, accentColor: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.72).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = accentColor.withAlphaComponent(0.32).cgColor

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = accentColor

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView(views: [titleLabel, stackView])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            container.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    func setRows(_ rows: [NSView]) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rows.forEach { stackView.addArrangedSubview($0) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ProviderStatRowView: NSView {
    private let fillView = NSView()
    private let fillWidthConstraint: NSLayoutConstraint

    init(provider: ProviderKind, title: String, subtitle: String, ratio: CGFloat) {
        let nameLabel = NSTextField(labelWithString: provider.displayName)
        let valueLabel = NSTextField(labelWithString: title)
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        let barTrack = NSView()

        fillWidthConstraint = fillView.widthAnchor.constraint(equalTo: barTrack.widthAnchor, multiplier: max(0.06, min(ratio, 1.0)))

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = .white

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = provider.accentColor

        subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.72, alpha: 1.0)
        subtitleLabel.maximumNumberOfLines = 0
        subtitleLabel.lineBreakMode = .byWordWrapping

        barTrack.wantsLayer = true
        barTrack.layer?.cornerRadius = 4
        barTrack.layer?.backgroundColor = NSColor(calibratedWhite: 0.22, alpha: 1.0).cgColor
        barTrack.translatesAutoresizingMaskIntoConstraints = false

        fillView.wantsLayer = true
        fillView.layer?.cornerRadius = 4
        fillView.layer?.backgroundColor = provider.accentColor.cgColor
        fillView.translatesAutoresizingMaskIntoConstraints = false
        barTrack.addSubview(fillView)

        let titleRow = NSStackView(views: [nameLabel, NSView(), valueLabel])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY

        let stackView = NSStackView(views: [titleRow, barTrack, subtitleLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            barTrack.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            barTrack.heightAnchor.constraint(equalToConstant: 8),

            fillView.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            fillView.topAnchor.constraint(equalTo: barTrack.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            fillWidthConstraint
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class StatusTextRowView: NSView {
    init(text: String, textColor: NSColor) {
        let label = NSTextField(labelWithString: text)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = textColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
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
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ProviderKind {
    var accentColor: NSColor {
        switch self {
        case .claude:
            return NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.31, alpha: 1.0)
        case .codex:
            return NSColor(calibratedRed: 0.98, green: 0.39, blue: 0.46, alpha: 1.0)
        case .gemini:
            return NSColor(calibratedRed: 0.35, green: 0.73, blue: 1.0, alpha: 1.0)
        }
    }
}
