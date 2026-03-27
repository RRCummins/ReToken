import Cocoa

final class DashboardViewController: NSViewController {
    private let appStateController: AppStateController
    private let titleLabel = NSTextField(labelWithString: "ReToken")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let heroLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private let contentStackView = NSStackView()
    private let issuesCard = DashboardCardView(title: "Issues", accentColor: .systemOrange)
    private let leaderboardCard = DashboardCardView(title: "Leaderboards", accentColor: .systemPink)
    private let trackingCard = DashboardCardView(title: "Tracking", accentColor: .systemYellow)
    private let usageCard = DashboardCardView(title: "Usage", accentColor: .systemRed)
    private let accountsCard = DashboardCardView(title: "Accounts", accentColor: .systemBlue)
    private let activityCard = DashboardCardView(title: "Recent Activity", accentColor: .systemGreen)

    init(appStateController: AppStateController) {
        self.appStateController = appStateController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()
        configureLabels()
        layoutLabels()
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
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        documentView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.spacing = 18
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureLabels() {
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .white
        summaryLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        summaryLabel.textColor = NSColor(calibratedWhite: 0.78, alpha: 1.0)
        summaryLabel.maximumNumberOfLines = 0
        summaryLabel.lineBreakMode = .byWordWrapping

        heroLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        heroLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.69, blue: 0.29, alpha: 1.0)
        heroLabel.maximumNumberOfLines = 0
        heroLabel.lineBreakMode = .byWordWrapping
    }

    @objc
    private func handleAppStateChange() {
        apply(snapshot: appStateController.snapshot)
    }

    private func apply(snapshot: AppSnapshot) {
        summaryLabel.stringValue = AppSnapshotFormatter.lastUpdatedLine(for: snapshot)
        heroLabel.stringValue = heroText(for: snapshot)
        issuesCard.bodyText = AppSnapshotFormatter.issuesDashboardText(for: snapshot)
        leaderboardCard.bodyText = AppSnapshotFormatter.leaderboardDashboardText(for: snapshot)
        trackingCard.bodyText = AppSnapshotFormatter.trackingDashboardText(for: snapshot)
        usageCard.bodyText = AppSnapshotFormatter.usageDashboardText(for: snapshot)
        accountsCard.bodyText = AppSnapshotFormatter.accountsDashboardText(for: snapshot)
        activityCard.bodyText = AppSnapshotFormatter.activityDashboardText(for: snapshot)
    }

    private func layoutLabels() {
        let headerStack = NSStackView(views: [titleLabel, summaryLabel, heroLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 8
        [
            headerStack,
            leaderboardCard,
            trackingCard,
            usageCard,
            accountsCard,
            activityCard,
            issuesCard
        ].forEach { contentStackView.addArrangedSubview($0) }

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
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -24),
            contentStackView.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 24),
            contentStackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -24)
        ])
    }

    private func heroText(for snapshot: AppSnapshot) -> String {
        let total = AppSnapshotFormatter.compactTokenCount(snapshot.totalTodayTokens)
        if let rank = snapshot.leaderboardSummary.currentRunRank {
            return "\(total) burned today • running #\(rank) on your all-time board"
        }

        return "\(total) burned today • build your leaderboard"
    }
}

private final class DashboardCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(labelWithString: "")

    var bodyText: String = "" {
        didSet {
            bodyLabel.stringValue = bodyText
        }
    }

    init(title: String, accentColor: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor(calibratedWhite: 0.14, alpha: 0.92).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = accentColor.withAlphaComponent(0.45).cgColor

        titleLabel.stringValue = title.uppercased()
        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = accentColor

        bodyLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        bodyLabel.textColor = NSColor(calibratedWhite: 0.90, alpha: 1.0)
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping

        let stackView = NSStackView(views: [titleLabel, bodyLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
