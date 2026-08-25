import Testing
@testable import DichThatCore

private let context = SelectionTriggerContext(
    targetPID: 42,
    mouseAnchor: CapturePoint(x: 100, y: 200)
)

@Test("Lifecycle installs monitor after trust is granted without relaunch")
func permissionGrantInstallsMonitor() {
    var lifecycle = SelectionMonitorLifecycleState()
    let untrustedActions = lifecycle.refresh(isTrusted: false)
    #expect(untrustedActions == [.reportPermissionRequired])
    #expect(!lifecycle.monitorInstalled)
    let trustedActions = lifecycle.refresh(isTrusted: true)
    #expect(trustedActions == [.installMonitor])
    let installationAction = lifecycle.monitorInstallationCompleted(success: true)
    #expect(installationAction == .reportMonitoring)
    #expect(lifecycle.monitorInstalled)
    let repeatedActions = lifecycle.refresh(isTrusted: true)
    #expect(repeatedActions == [.reportMonitoring])
}

@Test("Lifecycle removes monitor when trust is revoked")
func permissionRevocationRemovesMonitor() {
    var lifecycle = SelectionMonitorLifecycleState()
    _ = lifecycle.refresh(isTrusted: true)
    _ = lifecycle.monitorInstallationCompleted(success: true)

    let revokedActions = lifecycle.refresh(isTrusted: false)
    #expect(revokedActions == [
        .removeMonitor,
        .reportPermissionRequired,
    ])
    #expect(!lifecycle.isTrusted)
    #expect(!lifecycle.monitorInstalled)
}

@Test("Click and sub-threshold drag never request observation")
func clickDoesNotShowIcon() {
    var state = SelectionObservationState()
    state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
    #expect(state.mouseUp(context: context) == nil)
    state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
    state.mouseDragged(to: CapturePoint(x: 3, y: 0))
    #expect(state.mouseUp(context: context) == nil)
}

@Test("Threshold creates request and stale completion cannot present")
func thresholdAndGenerationGuard() {
    var state = SelectionObservationState()
    state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
    state.mouseDragged(to: CapturePoint(x: 4, y: 0))
    let request = state.mouseUp(context: context)
    #expect(request != nil)
    state.invalidate()
    #expect(state.complete(request: request!, result: .validMouse) == nil)
}

@Test("Only confirmed nonempty bounds or mouse results present current generation")
func confirmedSelectionPresentation() {
    var state = SelectionObservationState()
    state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
    state.mouseDragged(to: CapturePoint(x: 5, y: 0))
    let first = state.mouseUp(context: context)!
    let bounds = CaptureBounds(x: 10, y: 20, width: 30, height: 10)
    #expect(state.complete(request: first, result: .validBounds(bounds))?.anchor == .bounds(bounds))

    state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
    state.mouseDragged(to: CapturePoint(x: 5, y: 0))
    let second = state.mouseUp(context: context)!
    #expect(state.complete(request: second, result: .validMouse)?.anchor == .mouse(context.mouseAnchor))

    state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
    state.mouseDragged(to: CapturePoint(x: 5, y: 0))
    let third = state.mouseUp(context: context)!
    #expect(state.complete(request: third, result: .heuristicMouse) == nil)
}

@Test("Invalidation timeout and click consume presentation exactly once")
func lifecycleAndClickConsumption() {
    var state = SelectionObservationState()
    state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
    state.mouseDragged(to: CapturePoint(x: 5, y: 0))
    let request = state.mouseUp(context: context)!
    _ = state.complete(request: request, result: .validMouse)
    let staleTimeout = state.timeout(generation: request.generation + 1)
    #expect(!staleTimeout)
    #expect(state.consumeClick() == context)
    #expect(state.consumeClick() == nil)

    state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
    state.mouseDragged(to: CapturePoint(x: 5, y: 0))
    let timeoutRequest = state.mouseUp(context: context)!
    _ = state.complete(request: timeoutRequest, result: .validMouse)
    let currentTimeout = state.timeout(generation: timeoutRequest.generation)
    #expect(currentTimeout)
    #expect(state.presentation == nil)
}

@Test("Double and multi-click suppress their full gesture generation")
func multiClickGestureIsSuppressed() {
    for clickCount in [2, 3] {
        var state = SelectionObservationState()
        state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: clickCount)
        state.mouseDragged(to: CapturePoint(x: 20, y: 0))
        #expect(state.mouseUp(context: context) == nil)
        #expect(state.presentation == nil)

        state.mouseDown(at: CapturePoint(x: 0, y: 0), clickCount: 1)
        state.mouseDragged(to: CapturePoint(x: 5, y: 0))
        #expect(state.mouseUp(context: context) != nil)
    }
}

@Test("Geometry converts Quartz coordinates and clamps to visible frame")
func geometryConversionAndClamping() {
    let converted = SelectionIconGeometry.appKitBounds(
        fromQuartz: CaptureBounds(x: 10, y: 100, width: 50, height: 20),
        mainDisplayHeight: 900
    )
    #expect(converted == CaptureBounds(x: 10, y: 780, width: 50, height: 20))
    let origin = SelectionIconGeometry.iconOrigin(
        anchor: .bounds(CaptureBounds(x: 790, y: 0, width: 20, height: 10)),
        mainDisplayHeight: 900,
        iconSize: 32,
        offset: 8,
        visibleFrame: CaptureBounds(x: 0, y: 0, width: 800, height: 860)
    )
    #expect(origin.x == 768)
    #expect(origin.y >= 0 && origin.y <= 828)
}
