import AppKit
import ApplicationServices
import DichThatCore

final class AXSelectionCapture {
    private enum Strategy {
        case systemWideFocused
        case frontmostFocused
        case descendantSearch
    }

    private enum Method {
        case standard
        case textMarker
    }

    private struct Candidate {
        let owner: AXUIElement
        let text: String
        let method: Method
        let preservedRange: CFTypeRef?
    }

    private struct Budget {
        let deadline = CFAbsoluteTimeGetCurrent() + AppConfiguration.Accessibility.searchDuration
        var nodes = 0
        var calls = 0
        var visited = Set<CFHashCode>()

        mutating func beginNode(_ element: AXUIElement, depth: Int) -> Bool {
            guard CFAbsoluteTimeGetCurrent() <= deadline,
                  depth <= AppConfiguration.Accessibility.maximumDepth,
                  nodes < AppConfiguration.Accessibility.maximumNodes else {
                return false
            }
            guard visited.insert(CFHash(element)).inserted else { return false }
            nodes += 1
            return true
        }

        mutating func beginCall() -> Bool {
            guard CFAbsoluteTimeGetCurrent() <= deadline,
                  calls < AppConfiguration.Accessibility.maximumCalls else { return false }
            calls += 1
            return true
        }
    }

    private let selectedMarkerRange = "AXSelectedTextMarkerRange" as CFString
    private let stringForMarkerRange = "AXStringForTextMarkerRange" as CFString
    private let boundsForMarkerRange = "AXBoundsForTextMarkerRange" as CFString
    private let rectangleObjCType = String(cString: NSValue(rect: .zero).objCType)

    func capture(
        frontmostPID: pid_t?,
        mouseAnchor: CapturePoint
    ) -> SelectionCaptureOutput? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(
            systemWide,
            AppConfiguration.Accessibility.messagingTimeout
        )
        if let focused = elementAttribute(kAXFocusedUIElementAttribute as CFString, on: systemWide),
           let candidate = candidate(on: focused, strategy: .systemWideFocused) {
            return output(candidate, mouseAnchor: mouseAnchor)
        }

        guard let frontmostPID else { return nil }
        let application = AXUIElementCreateApplication(frontmostPID)
        AXUIElementSetMessagingTimeout(
            application,
            AppConfiguration.Accessibility.messagingTimeout
        )
        if let focused = elementAttribute(kAXFocusedUIElementAttribute as CFString, on: application),
           let candidate = candidate(on: focused, strategy: .frontmostFocused) {
            return output(candidate, mouseAnchor: mouseAnchor)
        }

        var roots: [AXUIElement] = []
        if let window = elementAttribute(kAXFocusedWindowAttribute as CFString, on: application) {
            roots.append(window)
        }
        roots.append(application)
        if let candidate = descendantCandidate(roots: roots) {
            return output(candidate, mouseAnchor: mouseAnchor)
        }
        return nil
    }

    private func candidate(
        on element: AXUIElement,
        strategy: Strategy,
        beforeCall: () -> Bool = { true }
    ) -> Candidate? {
        AXUIElementSetMessagingTimeout(
            element,
            AppConfiguration.Accessibility.messagingTimeout
        )
        guard beforeCall() else { return nil }
        if let value = attribute(kAXSelectedTextAttribute as CFString, on: element) as? String,
           !value.isEmpty {
            return Candidate(owner: element, text: value, method: .standard, preservedRange: nil)
        }

        guard beforeCall(),
              let markerRange = attribute(selectedMarkerRange, on: element),
              CFGetTypeID(markerRange) == AXTextMarkerRangeGetTypeID(),
              beforeCall(),
              let value = parameterizedAttribute(
                  stringForMarkerRange,
                  parameter: markerRange,
                  on: element
              ) as? String,
              !value.isEmpty
        else {
            return nil
        }
        return Candidate(
            owner: element,
            text: value,
            method: .textMarker,
            preservedRange: markerRange
        )
    }

    private func descendantCandidate(roots: [AXUIElement]) -> Candidate? {
        var budget = Budget()
        var queue = roots.map { ($0, 0) }
        var index = 0
        while index < queue.count {
            let (element, depth) = queue[index]
            index += 1
            guard budget.beginNode(element, depth: depth) else { continue }
            if let found = candidate(
                on: element,
                strategy: .descendantSearch,
                beforeCall: { budget.beginCall() }
            ) {
                return found
            }
            guard depth < AppConfiguration.Accessibility.maximumDepth,
                  budget.beginCall() else { continue }
            guard let children = attribute(kAXChildrenAttribute as CFString, on: element) as? [AXUIElement]
            else { continue }
            let capacity = max(
                0,
                AppConfiguration.Accessibility.maximumNodes - queue.count
            )
            queue.append(contentsOf: children.prefix(capacity).map { ($0, depth + 1) })
        }
        return nil
    }

    private func output(
        _ candidate: Candidate,
        mouseAnchor: CapturePoint
    ) -> SelectionCaptureOutput {
        let method: SelectionCaptureMethod = candidate.method == .standard
            ? .axStandard
            : .axTextMarker
        let anchor = bounds(for: candidate).map(SelectionAnchor.bounds)
            ?? .mouse(mouseAnchor)
        return SelectionCaptureOutput(text: candidate.text, method: method, anchor: anchor)
    }

    private func bounds(for candidate: Candidate) -> CaptureBounds? {
        let range: CFTypeRef
        let boundsAttribute: CFString
        switch candidate.method {
        case .standard:
            guard let selectedRange = attribute(
                kAXSelectedTextRangeAttribute as CFString,
                on: candidate.owner
            ) else { return nil }
            range = selectedRange
            boundsAttribute = kAXBoundsForRangeParameterizedAttribute as CFString
        case .textMarker:
            guard let markerRange = candidate.preservedRange else { return nil }
            range = markerRange
            boundsAttribute = boundsForMarkerRange
        }
        guard let value = parameterizedAttribute(
            boundsAttribute,
            parameter: range,
            on: candidate.owner
        ), let rect = decodeRect(value) else { return nil }
        return CaptureBounds(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    private func elementAttribute(_ name: CFString, on element: AXUIElement) -> AXUIElement? {
        guard let value = attribute(name, on: element),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func attribute(_ name: CFString, on element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value
    }

    private func parameterizedAttribute(
        _ name: CFString,
        parameter: CFTypeRef,
        on element: AXUIElement
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            name,
            parameter,
            &value
        ) == .success else { return nil }
        return value
    }

    private func decodeRect(_ value: CFTypeRef) -> CGRect? {
        if CFGetTypeID(value) == AXValueGetTypeID(),
           AXValueGetType(value as! AXValue) == .cgRect {
            var rect = CGRect.zero
            return AXValueGetValue(value as! AXValue, .cgRect, &rect) ? rect : nil
        }
        guard let boxed = value as? NSValue,
              String(cString: boxed.objCType) == rectangleObjCType
        else { return nil }
        return boxed.rectValue
    }
}
