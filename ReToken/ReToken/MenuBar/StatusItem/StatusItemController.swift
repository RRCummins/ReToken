import Cocoa

final class StatusItemController: NSObject {
    private let appStateController: AppStateController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let dashboardWindowController: DashboardWindowController
    private let openAICredentialsWindowController: OpenAICredentialsWindowController
    private lazy var statusPopoverViewController = StatusPopoverViewController(
        appStateController: appStateController,
        onOpenDashboard: { [weak self] in
            self?.showDashboard(nil)
        },
        onOpenCredentials: { [weak self] in
            self?.openOpenAICredentials(nil)
        }
    )

    init(
        appStateController: AppStateController,
        credentialsStore: OpenAICredentialsStore = OpenAICredentialsStore()
    ) {
        self.appStateController = appStateController
        self.dashboardWindowController = DashboardWindowController(appStateController: appStateController)
        self.openAICredentialsWindowController = OpenAICredentialsWindowController(
            credentialsStore: credentialsStore,
            onSave: { [weak appStateController] in
                appStateController?.refreshData()
            }
        )
        super.init()
    }

    func install() {
        configureButton()
        configurePopover()
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

    @objc
    private func refresh(_ sender: Any?) {
        appStateController.refreshData()
    }

    @objc
    private func useMockProviders(_ sender: Any?) {
        appStateController.setProviderMode(.mock)
    }

    @objc
    private func useLiveProviders(_ sender: Any?) {
        appStateController.setProviderMode(.live)
    }

    @objc
    private func openOpenAICredentials(_ sender: Any?) {
        openAICredentialsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func useFiveMinuteRefresh(_ sender: Any?) {
        appStateController.setRefreshIntervalMinutes(5)
    }

    @objc
    private func useFifteenMinuteRefresh(_ sender: Any?) {
        appStateController.setRefreshIntervalMinutes(15)
    }

    @objc
    private func useThirtyMinuteRefresh(_ sender: Any?) {
        appStateController.setRefreshIntervalMinutes(30)
    }

    @objc
    private func showDashboard(_ sender: Any?) {
        dashboardWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    @objc
    private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        switch event.type {
        case .rightMouseUp:
            closePopover()
            showContextMenu()
        default:
            togglePopover()
        }
    }

    @objc
    private func handleAppStateChange() {
        apply(snapshot: appStateController.snapshot)
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(
            systemSymbolName: "flame.fill",
            accessibilityDescription: "ReToken"
        )?.withSymbolConfiguration(symbolConfiguration)

        button.image = image
        button.imagePosition = .imageLeading
        button.title = "RT"
        button.toolTip = "ReToken"
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func apply(snapshot: AppSnapshot) {
        guard let button = statusItem.button else {
            return
        }

        button.title = AppSnapshotFormatter.statusTitle(for: snapshot)
        button.toolTip = AppSnapshotFormatter.tooltip(for: snapshot)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = statusPopoverViewController
    }

    private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            closePopover()
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func showContextMenu() {
        statusItem.popUpMenu(makeMenu(for: appStateController.snapshot))
    }

    private func makeMenu(for snapshot: AppSnapshot) -> NSMenu {
        let menu = NSMenu()

        let modeHeader = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)
        menu.addItem(disabledItem(title: AppSnapshotFormatter.modeMenuLine(for: snapshot)))
        menu.addItem(modeItem(title: "Use Mock Providers", mode: .mock, selectedMode: snapshot.mode, action: #selector(useMockProviders(_:))))
        menu.addItem(modeItem(title: "Use Live Providers", mode: .live, selectedMode: snapshot.mode, action: #selector(useLiveProviders(_:))))
        menu.addItem(.separator())

        let refreshHeader = NSMenuItem(title: "Refresh", action: nil, keyEquivalent: "")
        refreshHeader.isEnabled = false
        menu.addItem(refreshHeader)
        menu.addItem(disabledItem(title: AppSnapshotFormatter.refreshMenuLine(intervalMinutes: appStateController.refreshIntervalMinutes)))
        menu.addItem(refreshIntervalItem(title: "Every 5 minutes", minutes: 5, action: #selector(useFiveMinuteRefresh(_:))))
        menu.addItem(refreshIntervalItem(title: "Every 15 minutes", minutes: 15, action: #selector(useFifteenMinuteRefresh(_:))))
        menu.addItem(refreshIntervalItem(title: "Every 30 minutes", minutes: 30, action: #selector(useThirtyMinuteRefresh(_:))))
        menu.addItem(.separator())

        let trackingHeader = NSMenuItem(title: "Tracking", action: nil, keyEquivalent: "")
        trackingHeader.isEnabled = false
        menu.addItem(trackingHeader)
        menu.addItem(disabledItem(title: AppSnapshotFormatter.trackingMenuLine(for: snapshot.usageTrackingSummary)))
        menu.addItem(.separator())

        let leaderboardHeader = NSMenuItem(title: "Leaderboards", action: nil, keyEquivalent: "")
        leaderboardHeader.isEnabled = false
        menu.addItem(leaderboardHeader)
        AppSnapshotFormatter.leaderboardMenuLines(for: snapshot.leaderboardSummary).forEach {
            menu.addItem(disabledItem(title: $0))
        }
        menu.addItem(.separator())

        let usageHeader = NSMenuItem(title: "Usage", action: nil, keyEquivalent: "")
        usageHeader.isEnabled = false
        menu.addItem(usageHeader)
        snapshot.usage.forEach { usageSnapshot in
            menu.addItem(disabledItem(title: AppSnapshotFormatter.usageMenuLine(for: usageSnapshot)))
        }
        menu.addItem(.separator())

        let accountHeader = NSMenuItem(title: "Account", action: nil, keyEquivalent: "")
        accountHeader.isEnabled = false
        menu.addItem(accountHeader)
        snapshot.accounts.forEach { accountSnapshot in
            menu.addItem(disabledItem(title: AppSnapshotFormatter.accountMenuLine(for: accountSnapshot)))
        }
        menu.addItem(.separator())

        let activityHeader = NSMenuItem(title: "Recent Activity", action: nil, keyEquivalent: "")
        activityHeader.isEnabled = false
        menu.addItem(activityHeader)
        snapshot.recentActivity.forEach { activityItem in
            menu.addItem(disabledItem(title: AppSnapshotFormatter.activityMenuLine(for: activityItem)))
        }
        menu.addItem(.separator())

        if snapshot.issues.isEmpty == false {
            let issuesHeader = NSMenuItem(title: "Issues", action: nil, keyEquivalent: "")
            issuesHeader.isEnabled = false
            menu.addItem(issuesHeader)
            snapshot.issues.forEach { issue in
                menu.addItem(disabledItem(title: AppSnapshotFormatter.issuesMenuLine(for: issue)))
            }
            menu.addItem(.separator())
        }

        let updatedLine = NSMenuItem(title: AppSnapshotFormatter.lastUpdatedLine(for: snapshot), action: nil, keyEquivalent: "")
        updatedLine.isEnabled = false
        menu.addItem(updatedLine)
        menu.addItem(actionItem(title: snapshot.mode.refreshActionTitle, action: #selector(refresh(_:))))
        menu.addItem(actionItem(title: "Open OpenAI Credentials", action: #selector(openOpenAICredentials(_:))))
        menu.addItem(actionItem(title: "Open Dashboard", action: #selector(showDashboard(_:))))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Quit ReToken", action: #selector(quitApplication(_:)), keyEquivalent: "q"))

        return menu
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func modeItem(title: String, mode: ProviderMode, selectedMode: ProviderMode, action: Selector) -> NSMenuItem {
        let item = actionItem(title: title, action: action)
        item.state = selectedMode == mode ? .on : .off
        return item
    }

    private func refreshIntervalItem(title: String, minutes: Int, action: Selector) -> NSMenuItem {
        let item = actionItem(title: title, action: action)
        item.state = appStateController.refreshIntervalMinutes == minutes ? .on : .off
        return item
    }
}
