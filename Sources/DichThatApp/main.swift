import AppKit

let application = NSApplication.shared
private let appDelegate = AppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = appDelegate
application.run()
