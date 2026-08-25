import ApplicationServices
import Foundation
import DichThatCore

enum BugReportDiagnosticsCollector {
    static func issueURL(
        shortcut: String,
        launchAtLoginEnabled: Bool
    ) -> URL? {
        BugReportBuilder.issueURL(context: BugReportContext(
            appVersion: AppIdentity.currentVersion,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: architecture,
            accessibilityGranted: AXIsProcessTrusted(),
            shortcut: shortcut,
            launchAtLoginEnabled: launchAtLoginEnabled,
            recentCrashSummary: latestCrashSummary()
        ))
    }

    private static var architecture: String {
        #if arch(arm64)
        "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        "Intel (x86_64)"
        #else
        "Unknown"
        #endif
    }

    private static func latestCrashSummary() -> String? {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        let latest = files
            .filter { $0.lastPathComponent.hasPrefix("DichThat-") && $0.pathExtension == "ips" }
            .max { lhs, rhs in
                let left = try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate
                let right = try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate
                return (left ?? .distantPast) < (right ?? .distantPast)
            }
        guard let latest,
              let contents = try? String(contentsOf: latest, encoding: .utf8),
              let newline = contents.firstIndex(of: "\n")
        else { return nil }

        let headerData = Data(contents[..<newline].utf8)
        let reportData = Data(contents[contents.index(after: newline)...].utf8)
        guard let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
              let report = try? JSONSerialization.jsonObject(with: reportData) as? [String: Any]
        else { return nil }

        var lines: [String] = []
        if let timestamp = header["timestamp"] as? String { lines.append("Time: \(timestamp)") }
        if let exception = report["exception"] as? [String: Any] {
            let type = exception["type"] as? String ?? "unknown"
            let signal = exception["signal"] as? String ?? "unknown"
            lines.append("Exception: \(type) / \(signal)")
        }
        if let termination = report["termination"] as? [String: Any],
           let indicator = termination["indicator"] as? String {
            lines.append("Termination: \(indicator)")
        }
        if let threads = report["threads"] as? [[String: Any]],
           let triggered = threads.first(where: { ($0["triggered"] as? Bool) == true }),
           let frames = triggered["frames"] as? [[String: Any]] {
            let stack = frames.prefix(8).compactMap { frame -> String? in
                if let symbol = frame["symbol"] as? String { return symbol }
                if let source = frame["sourceFile"] as? String,
                   let line = frame["sourceLine"] as? Int {
                    return "\((source as NSString).lastPathComponent):\(line)"
                }
                return nil
            }
            if !stack.isEmpty {
                lines.append("Stack:")
                lines.append(contentsOf: stack.map { "- \($0)" })
            }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
