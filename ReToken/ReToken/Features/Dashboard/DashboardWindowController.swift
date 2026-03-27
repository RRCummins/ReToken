import Cocoa

final class DashboardWindowController: NSWindowController {
    init(appStateController: AppStateController) {
        let viewController = DashboardViewController(appStateController: appStateController)
        let window = NSWindow(contentViewController: viewController)
        window.title = "ReToken"
        window.setContentSize(NSSize(width: 760, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
