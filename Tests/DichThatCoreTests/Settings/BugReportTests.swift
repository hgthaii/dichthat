import Foundation
import Testing
@testable import DichThatCore

@Suite("Bug report")
struct BugReportTests {
    private let context = BugReportContext(
        appVersion: "1.2.3",
        operatingSystem: "macOS 26.6",
        architecture: "Apple Silicon (arm64)",
        accessibilityGranted: true,
        shortcut: "⌃⌥T",
        launchAtLoginEnabled: false,
        recentCrashSummary: "Exception: EXC_BAD_ACCESS / SIGSEGV"
    )

    @Test("Issue URL targets GitHub and carries a prefilled diagnostic template")
    func issueURL() throws {
        let url = try #require(BugReportBuilder.issueURL(
            repositoryURL: "https://github.com/example/app",
            context: context
        ))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/example/app/issues/new")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
        #expect(items["title"] == "[Bug] ")
        #expect(items["labels"] == "bug")
        #expect(items["body"]?.contains("DichThat 1.2.3") == true)
        #expect(items["body"]?.contains("EXC_BAD_ACCESS") == true)
    }

    @Test("Template declares its privacy boundary and never invents a crash")
    func privacyAndMissingCrash() {
        let body = BugReportBuilder.issueBody(context: BugReportContext(
            appVersion: "1.0",
            operatingSystem: "macOS",
            architecture: "arm64",
            accessibilityGranted: false,
            shortcut: "⌃⌥T",
            launchAtLoginEnabled: true,
            recentCrashSummary: nil
        ))
        #expect(body.contains("No recent DichThat crash report found."))
        #expect(body.contains("never include selected text or clipboard contents"))
    }
}
