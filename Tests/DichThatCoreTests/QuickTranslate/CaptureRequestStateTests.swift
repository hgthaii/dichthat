import Testing
@testable import DichThatCore

@Test("Capture requests are single-flight and stale completions are rejected")
func requestSingleFlightAndStaleGuard() {
    var state = CaptureRequestState()
    #expect(state.begin() == .accepted(requestID: 1))
    #expect(state.begin() == .ignoredActive)
    #expect(state.complete(requestID: 99) == .stale)
    #expect(state.activeRequestID == 1)
    #expect(state.complete(requestID: 1) == .accepted(replyToTermination: false))
    #expect(state.begin() == .accepted(requestID: 2))
    #expect(state.complete(requestID: 1) == .stale)
    #expect(state.activeRequestID == 2)
}

@Test("Termination is deferred and replied exactly once")
func terminationReplyIsExactlyOnce() {
    var state = CaptureRequestState()
    #expect(state.requestTermination() == .terminateNow)
    #expect(state.begin() == .accepted(requestID: 1))
    #expect(state.requestTermination() == .terminateLater)
    #expect(state.requestTermination() == .terminateLater)
    #expect(state.complete(requestID: 1) == .accepted(replyToTermination: true))
    #expect(state.terminationReplyIssued)
    #expect(state.complete(requestID: 1) == .stale)
    #expect(state.requestTermination() == .terminateNow)
    #expect(state.begin() == .ignoredTerminationPending)
}
