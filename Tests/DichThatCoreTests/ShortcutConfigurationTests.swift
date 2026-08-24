import Testing
@testable import DichThatCore

@MainActor
@Test("Configuration registers before persisting")
func configurationRegistersBeforePersisting() {
    let events = EventLog()
    let registrar = FakeRegistrar(events: events)
    let preferences = FakePreferences(events: events)
    let configuration = ShortcutConfiguration(
        registrar: registrar,
        preferences: preferences
    )
    _ = configuration.start {}
    events.values.removeAll()

    let candidate = KeyboardShortcut(keyCode: 0, modifiers: [.command])
    let result = configuration.accept(candidate) {}

    #expect(result == .success(candidate))
    #expect(events.values == ["register", "persist"])
    #expect(registrar.registeredShortcut == candidate)
    #expect(preferences.savedShortcut == candidate)
}

@MainActor
@Test("Invalid or colliding candidate preserves prior state")
func failedCandidatePreservesPriorState() {
    let events = EventLog()
    let registrar = FakeRegistrar(events: events)
    let preferences = FakePreferences(events: events)
    let configuration = ShortcutConfiguration(
        registrar: registrar,
        preferences: preferences
    )
    let original = KeyboardShortcut.defaultShortcut
    #expect(configuration.start {} == .success(original))

    let invalid = KeyboardShortcut(keyCode: 17, modifiers: [.shift])
    #expect(configuration.accept(invalid) {} == .failure(
        .invalidShortcut(.requiresCommandControlOrOption)
    ))
    #expect(registrar.registeredShortcut == original)
    #expect(preferences.savedShortcut == nil)

    let collision = KeyboardShortcut(keyCode: 0, modifiers: [.command])
    registrar.failure = .hotKeyRegistrationFailed(status: -9876)
    #expect(configuration.accept(collision) {} == .failure(
        .registration(.hotKeyRegistrationFailed(status: -9876))
    ))
    #expect(registrar.registeredShortcut == original)
    #expect(preferences.savedShortcut == nil)
}

@MainActor
@Test("Persistence failure rolls registration back")
func persistenceFailureRollsBack() {
    let events = EventLog()
    let registrar = FakeRegistrar(events: events)
    let preferences = FakePreferences(events: events)
    let configuration = ShortcutConfiguration(
        registrar: registrar,
        preferences: preferences
    )
    let original = KeyboardShortcut.defaultShortcut
    _ = configuration.start {}
    preferences.shouldFailSave = true

    let candidate = KeyboardShortcut(keyCode: 0, modifiers: [.command])
    #expect(configuration.accept(candidate) {} == .failure(.persistenceFailed))
    #expect(registrar.registeredShortcut == original)
    #expect(preferences.savedShortcut == nil)
    #expect(events.values.suffix(3) == ["register", "persist", "register"])
}

private final class EventLog {
    var values: [String] = []
}

@MainActor
private final class FakeRegistrar: GlobalShortcutRegistering {
    let events: EventLog
    var registeredShortcut: KeyboardShortcut?
    var failure: ShortcutRegistrationError?

    init(events: EventLog) {
        self.events = events
    }

    func replaceRegistration(
        with shortcut: KeyboardShortcut,
        handler: @escaping @MainActor () -> Void
    ) throws(ShortcutRegistrationError) {
        events.values.append("register")
        if let failure { throw failure }
        registeredShortcut = shortcut
    }

    func unregister() {
        registeredShortcut = nil
    }
}

private final class FakePreferences: ShortcutPersisting {
    struct SaveFailure: Error {}

    let events: EventLog
    var savedShortcut: KeyboardShortcut?
    var shouldFailSave = false

    init(events: EventLog) {
        self.events = events
    }

    func loadShortcut() -> KeyboardShortcut {
        savedShortcut ?? .defaultShortcut
    }

    func saveShortcut(_ shortcut: KeyboardShortcut) throws {
        events.values.append("persist")
        if shouldFailSave { throw SaveFailure() }
        savedShortcut = shortcut
    }
}
