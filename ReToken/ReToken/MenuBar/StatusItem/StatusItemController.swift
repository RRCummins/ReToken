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
    private func menuBarShowToday(_ sender: Any?) {
        appStateController.setMenuBarShowsLifetime(false)
    }

    @objc
    private func menuBarShowLifetime(_ sender: Any?) {
        appStateController.setMenuBarShowsLifetime(true)
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

        button.title = AppSnapshotFormatter.statusTitle(
            for: snapshot,
            showLifetime: appStateController.menuBarShowsLifetime
        )
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
        guard let button = statusItem.button else {
            return
        }

        let menu = makeMenu(for: appStateController.snapshot)
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu(for snapshot: AppSnapshot) -> NSMenu {
        let menu = NSMenu()

        // Icon display setting
        let iconHeader = NSMenuItem(title: "Menu Bar Shows", action: nil, keyEquivalent: "")
        iconHeader.isEnabled = false
        menu.addItem(iconHeader)
        let showsLifetime = appStateController.menuBarShowsLifetime
        menu.addItem(checkItem(title: "Today's Tokens", checked: !showsLifetime, action: #selector(menuBarShowToday(_:))))
        menu.addItem(checkItem(title: "Lifetime Tokens", checked: showsLifetime, action: #selector(menuBarShowLifetime(_:))))
        menu.addItem(.separator())

        // Refresh schedule
        let refreshHeader = NSMenuItem(title: "Refresh", action: nil, keyEquivalent: "")
        refreshHeader.isEnabled = false
        menu.addItem(refreshHeader)
        menu.addItem(disabledItem(title: AppSnapshotFormatter.refreshMenuLine(intervalMinutes: appStateController.refreshIntervalMinutes)))
        menu.addItem(refreshIntervalItem(title: "Every 5 minutes", minutes: 5, action: #selector(useFiveMinuteRefresh(_:))))
        menu.addItem(refreshIntervalItem(title: "Every 15 minutes", minutes: 15, action: #selector(useFifteenMinuteRefresh(_:))))
        menu.addItem(refreshIntervalItem(title: "Every 30 minutes", minutes: 30, action: #selector(useThirtyMinuteRefresh(_:))))
        menu.addItem(.separator())

        // Leaderboards
        let leaderboardHeader = NSMenuItem(title: "Leaderboards", action: nil, keyEquivalent: "")
        leaderboardHeader.isEnabled = false
        menu.addItem(leaderboardHeader)
        AppSnapshotFormatter.leaderboardMenuLines(for: snapshot.leaderboardSummary).forEach {
            menu.addItem(disabledItem(title: $0))
        }
        menu.addItem(.separator())

        // Usage
        let usageHeader = NSMenuItem(title: "Usage", action: nil, keyEquivalent: "")
        usageHeader.isEnabled = false
        menu.addItem(usageHeader)
        snapshot.usage.forEach { menu.addItem(disabledItem(title: AppSnapshotFormatter.usageMenuLine(for: $0))) }
        menu.addItem(.separator())

        // Recent Activity
        let activityHeader = NSMenuItem(title: "Recent Activity", action: nil, keyEquivalent: "")
        activityHeader.isEnabled = false
        menu.addItem(activityHeader)
        snapshot.recentActivity.prefix(5).forEach { menu.addItem(disabledItem(title: AppSnapshotFormatter.activityMenuLine(for: $0))) }
        menu.addItem(.separator())

        // Issues (only when present)
        if !snapshot.issues.isEmpty {
            let issuesHeader = NSMenuItem(title: "Issues", action: nil, keyEquivalent: "")
            issuesHeader.isEnabled = false
            menu.addItem(issuesHeader)
            snapshot.issues.forEach { menu.addItem(disabledItem(title: AppSnapshotFormatter.issuesMenuLine(for: $0))) }
            menu.addItem(.separator())
        }

        // Actions
        menu.addItem(disabledItem(title: AppSnapshotFormatter.lastUpdatedLine(for: snapshot)))
        menu.addItem(actionItem(title: "Refresh Now", action: #selector(refresh(_:))))
        menu.addItem(actionItem(title: "Open Credentials", action: #selector(openOpenAICredentials(_:))))
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

    private func checkItem(title: String, checked: Bool, action: Selector) -> NSMenuItem {
        let item = actionItem(title: title, action: action)
        item.state = checked ? .on : .off
        return item
    }

    private func refreshIntervalItem(title: String, minutes: Int, action: Selector) -> NSMenuItem {
        let item = actionItem(title: title, action: action)
        item.state = appStateController.refreshIntervalMinutes == minutes ? .on : .off
        return item
    }
}
