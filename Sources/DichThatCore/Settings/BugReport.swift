import Foundation

public struct BugReportContext: Equatable, Sendable {
    public let appVersion: String
    public let operatingSystem: String
    public let architecture: String
    public let accessibilityGranted: Bool
    public let shortcut: String
    public let launchAtLoginEnabled: Bool
    public let recentCrashSummary: String?

    public init(
        appVersion: String,
        operatingSystem: String,
        architecture: String,
        accessibilityGranted: Bool,
        shortcut: String,
        launchAtLoginEnabled: Bool,
        recentCrashSummary: String?
    ) {
        self.appVersion = appVersion
        self.operatingSystem = operatingSystem
        self.architecture = architecture
        self.accessibilityGranted = accessibilityGranted
        self.shortcut = shortcut
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.recentCrashSummary = recentCrashSummary
    }
}

public enum BugReportBuilder {
    public static func issueURL(
        repositoryURL: String = AppIdentity.repositoryURL,
        context: BugReportContext
    ) -> URL? {
        guard var components = URLComponents(string: repositoryURL + "/issues/new") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "title", value: "[Bug] "),
            URLQueryItem(name: "labels", value: "bug"),
            URLQueryItem(name: "body", value: issueBody(context: context)),
        ]
        return components.url
    }

    public static func issueBody(context: BugReportContext) -> String {
        let crash = context.recentCrashSummary ?? "No recent DichThat crash report found."
        return """
        ## What happened?
        <!-- Please describe the problem. -->

        ## Steps to reproduce
        1.
        2.
        3.

        ## Expected behavior
        <!-- What did you expect to happen? -->

        <details>
        <summary>Diagnostics</summary>

        ```text
        App: DichThat \(context.appVersion)
        macOS: \(context.operatingSystem)
        Architecture: \(context.architecture)
        Accessibility: \(context.accessibilityGranted ? "granted" : "not granted")
        Shortcut: \(context.shortcut)
        Launch at login: \(context.launchAtLoginEnabled ? "enabled" : "disabled")

        Latest crash:
        \(crash)
        ```
        </details>

        <!-- Diagnostics never include selected text or clipboard contents. -->
        """
    }
}
