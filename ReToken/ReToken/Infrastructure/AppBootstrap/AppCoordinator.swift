import Cocoa

final class AppCoordinator {
    private let appStateController: AppStateController
    private let statusItemController: StatusItemController
    private let credentialsStore: OpenAICredentialsStore

    init(
        credentialsStore: OpenAICredentialsStore = OpenAICredentialsStore(),
        appStateController: AppStateController? = nil,
        statusItemController: StatusItemController? = nil
    ) {
        self.credentialsStore = credentialsStore
        let resolvedAppStateController = appStateController ?? AppStateController(
            liveProviderAdapters: [
                LiveClaudeProviderAdapter(),
                LiveCodexProviderAdapter(credentialsStore: credentialsStore),
                LiveGeminiProviderAdapter()
            ]
        )
        self.appStateController = resolvedAppStateController
        self.statusItemController = statusItemController ?? StatusItemController(
            appStateController: resolvedAppStateController,
            credentialsStore: credentialsStore
        )
    }

    func start() {
        NSApp.setActivationPolicy(.accessory)
        statusItemController.install()
        appStateController.startAutomaticRefresh()
        appStateController.refreshData()
    }

    func refreshData() {
        appStateController.refreshData()
    }
}
