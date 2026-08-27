import Foundation

public enum AppLanguage: String, CaseIterable, Equatable, Sendable {
    case english = "en"
    case vietnamese = "vi"

    public static var current: AppLanguage {
        detect(preferredLanguages: Locale.preferredLanguages)
    }

    public static func detect(preferredLanguages: [String]) -> AppLanguage {
        guard let preferred = preferredLanguages.first else { return .english }
        let normalized = preferred
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        return normalized == "vi" || normalized.hasPrefix("vi-")
            ? .vietnamese
            : .english
    }

    public var localeIdentifier: String {
        switch self {
        case .english: return "en_US"
        case .vietnamese: return "vi_VN"
        }
    }

    public func localized(english: String, vietnamese: String) -> String {
        switch self {
        case .english: return english
        case .vietnamese: return vietnamese
        }
    }
}
