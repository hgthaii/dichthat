import Carbon
import DichThatCore

private let carbonGlobalShortcutSignature: OSType = 0x4449_4348 // DICH

private struct CarbonHotKeyEventSnapshot: Sendable {
    let signature: UInt32
    let id: UInt32
}

private final class CarbonHotKeyEventBridge: Sendable {
    private let handler: @MainActor @Sendable (CarbonHotKeyEventSnapshot) -> Void

    init(handler: @escaping @MainActor @Sendable (CarbonHotKeyEventSnapshot) -> Void) {
        self.handler = handler
    }

    func enqueue(_ snapshot: CarbonHotKeyEventSnapshot) {
        DispatchQueue.main.async { [handler, snapshot] in
            handler(snapshot)
        }
    }
}

private func carbonGlobalHotKeyEventCallback(
    _: EventHandlerCallRef?,
    event: EventRef?,
    context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let context else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier
    )
    guard status == noErr else { return status }
    let snapshot = CarbonHotKeyEventSnapshot(
        signature: identifier.signature,
        id: identifier.id
    )
    let bridge = Unmanaged<CarbonHotKeyEventBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
    bridge.enqueue(snapshot)
    return noErr
}

@MainActor
final class CarbonGlobalShortcutRegistrar: GlobalShortcutRegistering {
    private var eventHandler: EventHandlerRef?
    private var eventBridge: CarbonHotKeyEventBridge?
    private var hotKey: EventHotKeyRef?
    private var activeHotKeyID: UInt32?
    private var callback: (@MainActor () -> Void)?
    private var nextHotKeyID: UInt32 = 1

    func replaceRegistration(
        with shortcut: KeyboardShortcut,
        handler: @escaping @MainActor () -> Void
    ) throws(ShortcutRegistrationError) {
        do {
            try shortcut.validate()
        } catch let error {
            throw .invalidShortcut(error)
        }

        try installEventHandlerIfNeeded()

        let candidateID = nextHotKeyID
        nextHotKeyID &+= 1
        let identifier = EventHotKeyID(signature: carbonGlobalShortcutSignature, id: candidateID)
        var candidateHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers(for: shortcut.modifiers),
            identifier,
            GetApplicationEventTarget(),
            0,
            &candidateHotKey
        )
        guard status == noErr, let candidateHotKey else {
            throw .hotKeyRegistrationFailed(status: status)
        }

        let previousHotKey = hotKey
        hotKey = candidateHotKey
        activeHotKeyID = candidateID
        callback = handler
        if let previousHotKey {
            UnregisterEventHotKey(previousHotKey)
        }
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        hotKey = nil
        eventHandler = nil
        eventBridge = nil
        activeHotKeyID = nil
        callback = nil
    }

    private func installEventHandlerIfNeeded() throws(ShortcutRegistrationError) {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var installedHandler: EventHandlerRef?
        let bridge = CarbonHotKeyEventBridge { [weak self] snapshot in
            self?.handle(snapshot: snapshot)
        }
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonGlobalHotKeyEventCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(bridge).toOpaque(),
            &installedHandler
        )
        guard status == noErr, let installedHandler else {
            throw .eventHandlerInstallationFailed(status: status)
        }
        eventBridge = bridge
        eventHandler = installedHandler
    }

    private func handle(snapshot: CarbonHotKeyEventSnapshot) {
        guard
            snapshot.signature == carbonGlobalShortcutSignature,
            snapshot.id == activeHotKeyID
        else { return }
        callback?()
    }

    private func carbonModifiers(for modifiers: KeyboardShortcut.Modifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
