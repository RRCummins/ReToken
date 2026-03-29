import Cocoa

let application = NSApplication.shared
let delegate = AppDelegate()
MainActor.assumeIsolated {
    application.delegate = delegate
}
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
