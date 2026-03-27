import Cocoa

final class OpenAICredentialsWindowController: NSWindowController {
    init(
        credentialsStore: OpenAICredentialsStore,
        onSave: @escaping () -> Void
    ) {
        let viewController = OpenAICredentialsViewController(
            credentialsStore: credentialsStore,
            onSave: onSave
        )
        let window = NSWindow(contentViewController: viewController)
        window.title = "OpenAI Credentials"
        window.setContentSize(NSSize(width: 520, height: 280))
        window.styleMask = [.titled, .closable]
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
