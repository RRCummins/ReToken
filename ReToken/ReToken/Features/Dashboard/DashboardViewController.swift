import Cocoa

final class DashboardViewController: NSViewController {
    private let appStateController: AppStateController

    // MARK: - Header
    private let titleLabel = NSTextField(labelWithString: "ReToken")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let heroLabel = NSTextField(labelWithString: "")

    // MARK: - Cards
    private let usageCard = DashboardCardView(
        title: "Usage",
        accentColor: NSColor(calibratedRed: 0.98, green: 0.60, blue: 0.28, alpha: 1.0)
    )
    private let hourlyChartCard = DashboardCardView(
        title: "Hourly Burn",
        accentColor: NSColor(calibratedRed: 0.98, green: 0.75, blue: 0.36, alpha: 1.0)
    )
    private let weeklyChartCard = DashboardCardView(
        title: "Weekly Burn",
        accentColor: NSColor(calibratedRed: 0.44, green: 0.79, blue: 1.0, alpha: 1.0)
    )
    private let leaderboardCard = DashboardCardView(
        title: "Leaderboard",
        accentColor: NSColor(calibratedRed: 0.90, green: 0.45, blue: 0.88, alpha: 1.0)
    )
    private let trackingCard = DashboardCardView(
        title: "Tracking",
        accentColor: NSColor(calibratedRed: 0.98, green: 0.85, blue: 0.35, alpha: 1.0)
    )
    private let accountsCard = DashboardCardView(
        title: "Accounts",
        accentColor: NSColor(calibratedRed: 0.35, green: 0.68, blue: 1.0, alpha: 1.0)
    )
    private let activityCard = DashboardCardView(
        title: "Recent Activity",
        accentColor: NSColor(calibratedRed: 0.47, green: 0.83, blue: 0.55, alpha: 1.0)
    )
    private let issuesCard = DashboardCardView(
        title: "Issues",
        accentColor: NSColor(calibratedRed: 1.0, green: 0.60, blue: 0.25, alpha: 1.0)
    )

    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private let contentStackView = NSStackView()

    init(appStateController: AppStateController) {
        self.appStateController = appStateController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1.0).cgColor
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = NSSize(width: 940, height: 920)
        configureScrollView()
        configureHeader()
        layoutContent()
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

    // MARK: - Setup

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        documentView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.spacing = 20
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureHeader() {
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .white

        summaryLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        summaryLabel.textColor = NSColor(calibratedWhite: 0.65, alpha: 1.0)
        summaryLabel.maximumNumberOfLines = 2
        summaryLabel.lineBreakMode = .byWordWrapping

        heroLabel.font = .monospacedDigitSystemFont(ofSize: 26, weight: .heavy)
        heroLabel.textColor = NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.28, alpha: 1.0)
        heroLabel.maximumNumberOfLines = 1
    }

    // MARK: - Layout

    private func layoutContent() {
        let headerStack = NSStackView(views: [titleLabel, summaryLabel, heroLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6

        // Top two-column row: usage + leaderboard
        let chartsRow = makeTwoColumnRow(left: hourlyChartCard, right: weeklyChartCard)
        let topRow = makeTwoColumnRow(left: usageCard, right: leaderboardCard)

        // Second row: tracking + accounts
        let midRow = makeTwoColumnRow(left: trackingCard, right: accountsCard)

        contentStackView.addArrangedSubview(headerStack)
        contentStackView.addArrangedSubview(chartsRow)
        contentStackView.addArrangedSubview(topRow)
        contentStackView.addArrangedSubview(midRow)
        contentStackView.addArrangedSubview(activityCard)
        contentStackView.addArrangedSubview(issuesCard)

        documentView.addSubview(contentStackView)
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
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -24),
            contentStackView.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 24),
            contentStackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -24),

            // Full-width items
            headerStack.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            chartsRow.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            topRow.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            midRow.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            activityCard.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            issuesCard.widthAnchor.constraint(equalTo: contentStackView.widthAnchor)
        ])
    }

    private func makeTwoColumnRow(left: NSView, right: NSView) -> NSStackView {
        left.translatesAutoresizingMaskIntoConstraints = false
        right.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [left, right])
        row.orientation = .horizontal
        row.alignment = .top
        row.distribution = .fillEqually
        row.spacing = 16
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    // MARK: - State handling

    @objc
    private func handleAppStateChange() {
        apply(snapshot: appStateController.snapshot)
    }

    // MARK: - Apply snapshot

    private func apply(snapshot: AppSnapshot) {
        summaryLabel.stringValue = AppSnapshotFormatter.lastUpdatedLine(for: snapshot)
        heroLabel.stringValue = heroText(for: snapshot)
        let charts = appStateController.loadDashboardUsageCharts(now: snapshot.lastUpdatedAt)

        usageCard.setContent(makeUsageRows(from: snapshot))
        hourlyChartCard.setContent(makeHourlyChartRows(charts: charts))
        weeklyChartCard.setContent(makeWeeklyChartRows(charts: charts))
        leaderboardCard.setContent(makeLeaderboardRows(from: snapshot))
        trackingCard.setContent(makeTrackingRows(from: snapshot))
        accountsCard.setContent(makeAccountRows(from: snapshot))
        activityCard.setContent(makeActivityRows(from: snapshot))
        issuesCard.setContent(makeIssueRows(from: snapshot))
    }

    // MARK: - Row builders

    private func makeUsageRows(from snapshot: AppSnapshot) -> [NSView] {
        guard !snapshot.usage.isEmpty else {
            return [dashSimpleRow("No usage data available.")]
        }
        let maxTokens = max(snapshot.usage.map(\.todayTokens).max() ?? 1, 1)
        let accountsByProvider = Dictionary(uniqueKeysWithValues: snapshot.accounts.map { ($0.provider, $0) })

        return snapshot.usage.map { usage in
            let subtitle = AppSnapshotFormatter.providerPrimarySummary(for: usage)
            let detail = AppSnapshotFormatter.providerSecondarySummary(
                for: usage,
                planLabel: accountsByProvider[usage.provider]?.planLabel,
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

    private func makeLeaderboardRows(from snapshot: AppSnapshot) -> [NSView] {
        let summary = snapshot.leaderboardSummary
        guard !summary.isEmpty else {
            return [dashSimpleRow("No leaderboard history yet.")]
        }

        var rows: [NSView] = []

        let rankText = summary.currentRunRank.map { "Current run: #\($0) all-time" } ?? "Current run: warming up"
        rows.append(dashStatRow(label: "Rank", value: rankText))

        let bestText = "Best combined: \(AppSnapshotFormatter.compactTokenCount(summary.bestRecordedTotal))"
        rows.append(dashStatRow(label: "Best", value: bestText))

        if let champion = summary.championEntry {
            let champText = "\(champion.provider.displayName) • \(AppSnapshotFormatter.compactTokenCount(champion.bestTokens)) best • \(champion.sampleCount) samples"
            rows.append(dashStatRow(label: "Champion", value: champText))
        }

        if let mostTracked = summary.mostTrackedProvider {
            rows.append(dashStatRow(label: "Most tracked", value: "\(mostTracked.displayName) × \(summary.mostTrackedSampleCount)"))
        }

        return rows
    }

    private func makeHourlyChartRows(charts: DashboardUsageCharts) -> [NSView] {
        guard charts.hourly.isEmpty == false else {
            return [dashSimpleRow("Need a few refresh samples before the hourly burn chart wakes up.")]
        }

        let peakPoint = charts.hourly.max { $0.totalTokens < $1.totalTokens }
        let chartView = DashboardLineChartView(points: charts.hourly, accentColor: hourlyChartCard.accentColor)
        let summary = peakPoint.map {
            "Peak \(AppSnapshotFormatter.compactTokenCount($0.totalTokens)) at \(Self.hourFormatter.string(from: $0.timestamp))"
        } ?? "Peak hour pending"
        let range = "\(Self.hourFormatter.string(from: charts.hourly.first?.timestamp ?? .now)) → \(Self.hourFormatter.string(from: charts.hourly.last?.timestamp ?? .now))"

        return [
            chartView,
            dashStatRow(label: "Peak hour", value: summary),
            dashStatRow(label: "Range", value: range)
        ]
    }

    private func makeWeeklyChartRows(charts: DashboardUsageCharts) -> [NSView] {
        guard charts.daily.isEmpty == false else {
            return [dashSimpleRow("Weekly burn chart needs a few days of telemetry first.")]
        }

        let peakPoint = charts.daily.max { $0.totalTokens < $1.totalTokens }
        let chartView = DashboardBarChartView(points: charts.daily, accentColor: weeklyChartCard.accentColor)
        let summary = peakPoint.map {
            "Best day \(AppSnapshotFormatter.compactTokenCount($0.totalTokens)) on \(Self.dayFormatter.string(from: $0.timestamp))"
        } ?? "Best day pending"
        let total = charts.daily.reduce(0) { $0 + $1.totalTokens }

        return [
            chartView,
            dashStatRow(label: "Best day", value: summary),
            dashStatRow(label: "7d sum", value: AppSnapshotFormatter.compactTokenCount(total))
        ]
    }

    private func makeTrackingRows(from snapshot: AppSnapshot) -> [NSView] {
        let summary = snapshot.usageTrackingSummary
        guard !summary.isEmpty else {
            return [dashSimpleRow("No tracked usage yet.")]
        }

        var rows: [NSView] = []
        rows.append(dashStatRow(label: "Samples", value: "\(summary.sampleCount) across \(summary.trackedProviderCount) agents"))

        if let peak = summary.peakProvider {
            rows.append(dashStatRow(label: "Peak", value: "\(peak.displayName) • \(AppSnapshotFormatter.compactTokenCount(summary.peakTokens))"))
        }

        if let lastAt = summary.lastRecordedAt {
            let rel = RelativeDateTimeFormatter().localizedString(for: lastAt, relativeTo: .now)
            rows.append(dashStatRow(label: "Last record", value: rel))
        }

        return rows
    }

    private func makeAccountRows(from snapshot: AppSnapshot) -> [NSView] {
        guard !snapshot.accounts.isEmpty else {
            return [dashSimpleRow("No account info available.")]
        }

        return snapshot.accounts.map { account in
            let detail = "\(account.planLabel) • \(account.accountLabel)"
            let billing = account.billingStatus
            return dashProviderInfoRow(provider: account.provider, detail: detail, extra: billing)
        }
    }

    private func makeActivityRows(from snapshot: AppSnapshot) -> [NSView] {
        guard !snapshot.recentActivity.isEmpty else {
            return [dashSimpleRow("No recent activity recorded.")]
        }

        return snapshot.recentActivity.prefix(8).map { item in
            DashboardActivityRow(item: item)
        }
    }

    private func makeIssueRows(from snapshot: AppSnapshot) -> [NSView] {
        guard !snapshot.issues.isEmpty else {
            return [dashSimpleRow("No active issues.")]
        }

        return snapshot.issues.map { issue in
            let text = AppSnapshotFormatter.issuesMenuLine(for: issue)
            let label = NSTextField(labelWithString: text)
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = NSColor(calibratedRed: 1.0, green: 0.65, blue: 0.25, alpha: 1.0)
            label.maximumNumberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }
    }

    // MARK: - Generic row helpers

    private func dashSimpleRow(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = NSColor(calibratedWhite: 0.60, alpha: 1.0)
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func dashStatRow(label: String, value: String) -> NSView {
        let labelField = NSTextField(labelWithString: label.uppercased())
        labelField.font = .systemFont(ofSize: 10, weight: .semibold)
        labelField.textColor = NSColor(calibratedWhite: 0.52, alpha: 1.0)
        labelField.setContentHuggingPriority(.required, for: .horizontal)
        labelField.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueField = NSTextField(labelWithString: value)
        valueField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        valueField.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        valueField.maximumNumberOfLines = 1
        valueField.lineBreakMode = .byTruncatingTail
        valueField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [labelField, valueField])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        labelField.widthAnchor.constraint(equalToConstant: 100).isActive = true

        return row
    }

    private func dashProviderInfoRow(provider: ProviderKind, detail: String, extra: String) -> NSView {
        let nameLabel = NSTextField(labelWithString: provider.displayName)
        nameLabel.font = .systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = provider.accentColor

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = NSColor(calibratedWhite: 0.85, alpha: 1.0)
        detailLabel.maximumNumberOfLines = 1
        detailLabel.lineBreakMode = .byTruncatingTail

        let extraLabel = NSTextField(labelWithString: extra)
        extraLabel.font = .systemFont(ofSize: 11, weight: .regular)
        extraLabel.textColor = NSColor(calibratedWhite: 0.55, alpha: 1.0)
        extraLabel.maximumNumberOfLines = 1

        let col = NSStackView(views: [nameLabel, detailLabel, extraLabel])
        col.orientation = .vertical
        col.alignment = .leading
        col.spacing = 3
        col.translatesAutoresizingMaskIntoConstraints = false
        return col
    }

    // MARK: - Hero text

    private func heroText(for snapshot: AppSnapshot) -> String {
        let total = AppSnapshotFormatter.compactTokenCount(snapshot.totalTodayTokens)
        let lifetime = snapshot.totalLifetimeTokens
        let lifetimePart = lifetime > 0 ? "  ↑ \(AppSnapshotFormatter.compactTokenCount(lifetime)) lifetime" : ""
        if let rank = snapshot.leaderboardSummary.currentRunRank {
            return "\(total) burned today  •  #\(rank) all-time\(lifetimePart)"
        }
        return "\(total) burned today\(lifetimePart)"
    }

    fileprivate static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }()

    fileprivate static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

// MARK: - DashboardCardView

private final class DashboardCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyStack = NSStackView()
    let accentColor: NSColor

    // Backward-compat bodyText setter
    var bodyText: String = "" {
        didSet {
            let label = NSTextField(labelWithString: bodyText)
            label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            label.textColor = NSColor(calibratedWhite: 0.88, alpha: 1.0)
            label.maximumNumberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            setContent([label])
        }
    }

    init(title: String, accentColor: NSColor) {
        self.accentColor = accentColor
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.94).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = accentColor.withAlphaComponent(0.40).cgColor

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = accentColor

        bodyStack.orientation = .vertical
        bodyStack.alignment = .leading
        bodyStack.spacing = 10
        bodyStack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView(views: [titleLabel, bodyStack])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            bodyStack.widthAnchor.constraint(equalTo: container.widthAnchor)
        ])
    }

    func setContent(_ rows: [NSView]) {
        bodyStack.arrangedSubviews.forEach {
            bodyStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rows.forEach { row in
            bodyStack.addArrangedSubview(row)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - ProviderStatRowView (shared with Dashboard)

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
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.78, alpha: 1.0)
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail

        detailLabel.font = .systemFont(ofSize: 10, weight: .regular)
        detailLabel.textColor = NSColor(calibratedWhite: 0.56, alpha: 1.0)
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

// MARK: - Dashboard activity row

private final class DashboardActivityRow: NSView {
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
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .short
        let relative = relFormatter.localizedString(for: item.occurredAt, relativeTo: .now)
        let timeLabel = NSTextField(labelWithString: relative)
        timeLabel.font = .systemFont(ofSize: 12, weight: .regular)
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

// MARK: - Dashboard charts

private final class DashboardLineChartView: NSView {
    private let points: [UsageChartPoint]
    private let accentColor: NSColor

    init(points: [UsageChartPoint], accentColor: NSColor) {
        self.points = points
        self.accentColor = accentColor
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 150).isActive = true
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let insetRect = bounds.insetBy(dx: 10, dy: 18)
        guard points.isEmpty == false, insetRect.width > 0, insetRect.height > 0 else {
            return
        }

        let maxValue = max(points.map(\.totalTokens).max() ?? 0, 1)
        drawGrid(in: insetRect, lines: 4)

        let fillPath = NSBezierPath()
        let linePath = NSBezierPath()
        linePath.lineWidth = 2.5
        linePath.lineJoinStyle = .round
        linePath.lineCapStyle = .round

        for (index, point) in points.enumerated() {
            let fraction = points.count == 1 ? 0 : CGFloat(index) / CGFloat(points.count - 1)
            let x = insetRect.minX + (fraction * insetRect.width)
            let y = insetRect.minY + (CGFloat(point.totalTokens) / CGFloat(maxValue) * insetRect.height)
            let chartPoint = CGPoint(x: x, y: y)

            if index == 0 {
                linePath.move(to: chartPoint)
                fillPath.move(to: CGPoint(x: x, y: insetRect.minY))
                fillPath.line(to: chartPoint)
            } else {
                linePath.line(to: chartPoint)
                fillPath.line(to: chartPoint)
            }
        }

        let lastPoint = linePath.currentPoint
        fillPath.line(to: CGPoint(x: lastPoint.x, y: insetRect.minY))
        fillPath.close()

        accentColor.withAlphaComponent(0.14).setFill()
        fillPath.fill()

        accentColor.setStroke()
        linePath.stroke()

        let dotRect = CGRect(x: lastPoint.x - 4, y: lastPoint.y - 4, width: 8, height: 8)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        accentColor.setFill()
        dotPath.fill()

        drawLineLabels(in: bounds)
    }

    private func drawGrid(in rect: CGRect, lines: Int) {
        NSColor(calibratedWhite: 1.0, alpha: 0.08).setStroke()
        for index in 0..<lines {
            let fraction = CGFloat(index) / CGFloat(max(lines - 1, 1))
            let y = rect.minY + (fraction * rect.height)
            let path = NSBezierPath()
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawLineLabels(in rect: CGRect) {
        let formatter = DashboardViewController.hourFormatter
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.58, alpha: 1.0)
        ]

        let labelY = rect.minY + 2
        let firstText = formatter.string(from: points.first?.timestamp ?? .now)
        NSString(string: firstText).draw(at: CGPoint(x: rect.minX + 8, y: labelY), withAttributes: labelAttributes)

        let midText = formatter.string(from: points[points.count / 2].timestamp)
        let midSize = NSString(string: midText).size(withAttributes: labelAttributes)
        NSString(string: midText).draw(
            at: CGPoint(x: rect.midX - (midSize.width / 2), y: labelY),
            withAttributes: labelAttributes
        )

        let lastText = formatter.string(from: points.last?.timestamp ?? .now)
        let lastSize = NSString(string: lastText).size(withAttributes: labelAttributes)
        NSString(string: lastText).draw(
            at: CGPoint(x: rect.maxX - lastSize.width - 8, y: labelY),
            withAttributes: labelAttributes
        )
    }
}

private final class DashboardBarChartView: NSView {
    private let points: [UsageChartPoint]
    private let accentColor: NSColor

    init(points: [UsageChartPoint], accentColor: NSColor) {
        self.points = points
        self.accentColor = accentColor
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 150).isActive = true
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let insetRect = bounds.insetBy(dx: 12, dy: 20)
        guard points.isEmpty == false, insetRect.width > 0, insetRect.height > 0 else {
            return
        }

        let maxValue = max(points.map(\.totalTokens).max() ?? 0, 1)
        let slotWidth = insetRect.width / CGFloat(max(points.count, 1))
        let barWidth = max(12, slotWidth * 0.56)
        let formatter = DashboardViewController.dayFormatter
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.58, alpha: 1.0)
        ]

        for (index, point) in points.enumerated() {
            let x = insetRect.minX + (CGFloat(index) * slotWidth) + ((slotWidth - barWidth) / 2)
            let height = CGFloat(point.totalTokens) / CGFloat(maxValue) * insetRect.height
            let barRect = CGRect(x: x, y: insetRect.minY, width: barWidth, height: max(height, 2))
            let path = NSBezierPath(roundedRect: barRect, xRadius: 4, yRadius: 4)

            let alpha = 0.42 + (0.58 * (CGFloat(point.totalTokens) / CGFloat(maxValue)))
            accentColor.withAlphaComponent(alpha).setFill()
            path.fill()

            let dayLabel = formatter.string(from: point.timestamp)
            let size = NSString(string: dayLabel).size(withAttributes: labelAttributes)
            NSString(string: dayLabel).draw(
                at: CGPoint(x: x + (barWidth - size.width) / 2, y: bounds.minY + 2),
                withAttributes: labelAttributes
            )
        }
    }
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
