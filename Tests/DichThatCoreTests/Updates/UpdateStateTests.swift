import Foundation
import Testing
@testable import DichThatCore

@Test("Update checks are single-flight")
func updateCheckIsSingleFlight() {
    var state = UpdateState()

    let started = state.beginCheck()
    let duplicateStarted = state.beginCheck()
    #expect(started)
    #expect(!duplicateStarted)
    #expect(state.phase == .checking)
}

@Test("Available update stores version and check time")
func availableUpdateIsRecorded() {
    let checkedAt = Date(timeIntervalSince1970: 123)
    var state = UpdateState()

    state.foundUpdate(version: "0.3.0", checkedAt: checkedAt)

    #expect(state.availableVersion == "0.3.0")
    #expect(state.lastCheckedAt == checkedAt)
}

@Test("No update and failure replace checking state")
func updateCheckCanComplete() {
    let checkedAt = Date(timeIntervalSince1970: 456)
    var current = UpdateState()
    _ = current.beginCheck()
    current.foundNoUpdate(checkedAt: checkedAt)
    #expect(current.phase == .upToDate)

    var failed = UpdateState()
    _ = failed.beginCheck()
    failed.fail(message: "Offline", checkedAt: checkedAt)
    #expect(failed.phase == .failed(message: "Offline"))
    #expect(!failed.isChecking)
}
