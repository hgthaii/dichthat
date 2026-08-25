import DichThatCore
import Foundation

enum UpdateCheckResult: Sendable {
    case upToDate
    case available(version: String, releaseURL: URL)
    case unavailable
}

struct UpdateChecker: Sendable {
    func check() async -> UpdateCheckResult {
        var request = URLRequest(url: CoreConfiguration.Updates.latestReleaseAPI)
        request.timeoutInterval = CoreConfiguration.Updates.timeout
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { return .unavailable }
            if response.statusCode == 404 { return .upToDate }
            guard
                  (200 ... 299).contains(response.statusCode),
                  let release = try? JSONDecoder().decode(Release.self, from: data),
                  let latest = VersionNumber(release.tagName),
                  let current = VersionNumber(AppIdentity.currentVersion),
                  let releaseURL = URL(string: release.htmlURL)
            else { return .unavailable }
            return latest > current
                ? .available(version: release.tagName, releaseURL: releaseURL)
                : .upToDate
        } catch {
            return .unavailable
        }
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
}
