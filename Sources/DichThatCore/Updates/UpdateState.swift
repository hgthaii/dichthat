import Foundation

public enum UpdatePhase: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case available(version: String)
    case failed(message: String)
}

public struct UpdateState: Equatable, Sendable {
    public private(set) var phase: UpdatePhase
    public private(set) var lastCheckedAt: Date?

    public init(
        phase: UpdatePhase = .idle,
        lastCheckedAt: Date? = nil
    ) {
        self.phase = phase
        self.lastCheckedAt = lastCheckedAt
    }

    public var isChecking: Bool {
        phase == .checking
    }

    public var availableVersion: String? {
        guard case let .available(version) = phase else { return nil }
        return version
    }

    @discardableResult
    public mutating func beginCheck() -> Bool {
        guard !isChecking else { return false }
        phase = .checking
        return true
    }

    public mutating func foundUpdate(version: String, checkedAt: Date) {
        phase = .available(version: version)
        lastCheckedAt = checkedAt
    }

    public mutating func foundNoUpdate(checkedAt: Date) {
        phase = .upToDate
        lastCheckedAt = checkedAt
    }

    public mutating func fail(message: String, checkedAt: Date) {
        phase = .failed(message: message)
        lastCheckedAt = checkedAt
    }
}
