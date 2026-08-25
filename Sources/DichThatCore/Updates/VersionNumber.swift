import Foundation

public struct VersionNumber: Comparable, Equatable, Sendable {
    private let components: [Int]

    public init?(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let values = normalized.split(separator: ".").map(String.init)
        guard !values.isEmpty, values.allSatisfy({ Int($0) != nil }) else { return nil }
        components = values.compactMap(Int.init)
    }

    public static func < (lhs: VersionNumber, rhs: VersionNumber) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0 ..< count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: VersionNumber, rhs: VersionNumber) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
