import Testing
@testable import DichThatCore

@Test("New translation makes prior completion stale")
func translationGenerationReplacement() {
    var state = TranslationRequestState()
    let first = state.begin()
    let second = state.begin()
    #expect(state.complete(requestID: first, outcome: .success) == .stale)
    #expect(state.complete(requestID: second, outcome: .success) == .accepted)
    #expect(state.phase == .success(requestID: second))
}

@Test("Cancellation and dismissal invalidate completion")
func translationCancellationAndDismissal() {
    var state = TranslationRequestState()
    let cancelled = state.begin()
    #expect(state.cancel() == cancelled)
    #expect(state.complete(requestID: cancelled, outcome: .success) == .stale)
    #expect(state.phase == .idle)

    let dismissed = state.begin()
    state.dismiss()
    #expect(state.complete(requestID: dismissed, outcome: .failure) == .stale)
    #expect(state.phase == .idle)
}

@Test("Selection invalidation clears loading and rejects late completion")
func selectionInvalidationRejectsLateLoadingCompletion() {
    var state = TranslationRequestState()
    let requestID = state.begin()
    #expect(state.phase == .loading(requestID: requestID))
    state.invalidateSelection()
    #expect(state.phase == .idle)
    #expect(state.complete(requestID: requestID, outcome: .success) == .stale)
    #expect(state.phase == .idle)
}

@Test("Selection invalidation clears success and failure presentation")
func selectionInvalidationClearsPresentedResults() {
    var state = TranslationRequestState()
    let successID = state.begin()
    #expect(state.complete(requestID: successID, outcome: .success) == .accepted)
    #expect(state.phase == .success(requestID: successID))
    state.invalidateSelection()
    #expect(state.phase == .idle)

    let failureID = state.begin()
    #expect(state.complete(requestID: failureID, outcome: .failure) == .accepted)
    #expect(state.phase == .failure(requestID: failureID))
    state.invalidateSelection()
    #expect(state.phase == .idle)
}
