//
//  AppDelegate.swift
//  ReToken
//
//  Created by Ryan Cummins on 3/25/26.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appCoordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let coordinator = AppCoordinator()
        coordinator.start()
        appCoordinator = coordinator
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
