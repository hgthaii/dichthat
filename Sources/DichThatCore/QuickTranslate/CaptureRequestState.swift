public struct CaptureRequestState: Equatable, Sendable {
    public enum BeginResult: Equatable, Sendable {
        case accepted(requestID: UInt64)
        case ignoredActive
        case ignoredTerminationPending
    }

    public enum CompletionResult: Equatable, Sendable {
        case accepted(replyToTermination: Bool)
        case stale
    }

    public enum TerminationDecision: Equatable, Sendable {
        case terminateNow
        case terminateLater
    }

    private var nextRequestID: UInt64 = 1
    public private(set) var activeRequestID: UInt64?
    public private(set) var terminationPending = false
    public private(set) var terminationReplyIssued = false

    public init() {}

    public mutating func begin() -> BeginResult {
        guard !terminationPending, !terminationReplyIssued else {
            return .ignoredTerminationPending
        }
        guard activeRequestID == nil else { return .ignoredActive }
        let requestID = nextRequestID
        nextRequestID &+= 1
        activeRequestID = requestID
        return .accepted(requestID: requestID)
    }

    public mutating func complete(requestID: UInt64) -> CompletionResult {
        guard activeRequestID == requestID else { return .stale }
        activeRequestID = nil
        guard terminationPending, !terminationReplyIssued else {
            return .accepted(replyToTermination: false)
        }
        terminationPending = false
        terminationReplyIssued = true
        return .accepted(replyToTermination: true)
    }

    public mutating func requestTermination() -> TerminationDecision {
        if activeRequestID != nil {
            terminationPending = true
            return .terminateLater
        }
        if terminationReplyIssued { return .terminateLater }
        return .terminateNow
    }
}
