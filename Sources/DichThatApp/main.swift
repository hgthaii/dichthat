import AppKit
import Darwin
import DichThatCore

private let singleInstanceLock = SingleInstanceLock(
    identifier: AppIdentity.bundleIdentifier
)

guard singleInstanceLock != nil else {
    NSRunningApplication.runningApplications(
        withBundleIdentifier: AppIdentity.bundleIdentifier
    )
    .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
    .activate(options: [.activateIgnoringOtherApps])
    exit(EXIT_SUCCESS)
}

let application = NSApplication.shared

guard InstallLocationGuard.allowLaunch(bundleURL: Bundle.main.bundleURL) else {
    exit(EXIT_SUCCESS)
}

private let appDelegate = AppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = appDelegate
application.run()
