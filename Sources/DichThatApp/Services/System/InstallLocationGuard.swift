import AppKit
import DichThatCore

enum InstallLocationGuard {
    @MainActor
    static func allowLaunch(bundleURL: URL) -> Bool {
        let resourceValues = try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey])
        guard resourceValues?.volumeIsReadOnly == true else { return true }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = AppText.Installation.title
        alert.informativeText = AppText.Installation.message
        alert.addButton(withTitle: AppText.Installation.openApplications)
        alert.addButton(withTitle: AppText.Installation.quit)

        if alert.runModal() == .alertFirstButtonReturn,
           let applicationsURL = FileManager.default.urls(
               for: .applicationDirectory,
               in: .localDomainMask
           ).first {
            NSWorkspace.shared.open(applicationsURL)
        }
        return false
    }
}
