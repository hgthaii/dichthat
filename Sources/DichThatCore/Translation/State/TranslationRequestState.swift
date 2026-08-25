public struct TranslationRequestState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case loading(requestID: UInt64)
        case success(requestID: UInt64)
        case failure(requestID: UInt64)
    }

    public enum Outcome: Equatable, Sendable {
        case success
        case failure
    }

    public enum Completion: Equatable, Sendable {
        case accepted
        case stale
    }

    private var nextRequestID: UInt64 = 1
    public private(set) var activeRequestID: UInt64?
    public private(set) var phase: Phase = .idle

    public init() {}

    public mutating func begin() -> UInt64 {
        let requestID = nextRequestID
        nextRequestID &+= 1
        activeRequestID = requestID
        phase = .loading(requestID: requestID)
        return requestID
    }

    public mutating func complete(requestID: UInt64, outcome: Outcome) -> Completion {
        guard activeRequestID == requestID else { return .stale }
        activeRequestID = nil
        switch outcome {
        case .success:
            phase = .success(requestID: requestID)
        case .failure:
            phase = .failure(requestID: requestID)
        }
        return .accepted
    }

    @discardableResult
    public mutating func cancel() -> UInt64? {
        defer {
            activeRequestID = nil
            phase = .idle
        }
        return activeRequestID
    }

    public mutating func dismiss() {
        activeRequestID = nil
        phase = .idle
    }

    public mutating func invalidateSelection() {
        activeRequestID = nil
        phase = .idle
    }
}
