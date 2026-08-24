public enum ShortcutRegistrationError: Error, Equatable, Sendable {
    case invalidShortcut(KeyboardShortcut.ValidationError)
    case eventHandlerInstallationFailed(status: Int32)
    case hotKeyRegistrationFailed(status: Int32)
}

@MainActor
public protocol GlobalShortcutRegistering: AnyObject {
    func replaceRegistration(
        with shortcut: KeyboardShortcut,
        handler: @escaping @MainActor () -> Void
    ) throws(ShortcutRegistrationError)

    func unregister()
}

public enum ShortcutConfigurationError: Error, Equatable, Sendable {
    case invalidShortcut(KeyboardShortcut.ValidationError)
    case registration(ShortcutRegistrationError)
    case persistenceFailed
    case rollbackFailed(ShortcutRegistrationError)
}

@MainActor
public final class ShortcutConfiguration {
    private let registrar: any GlobalShortcutRegistering
    private let preferences: any ShortcutPersisting
    private var activeShortcut: KeyboardShortcut?
    private var activeHandler: (@MainActor () -> Void)?

    public init(
        registrar: any GlobalShortcutRegistering,
        preferences: any ShortcutPersisting
    ) {
        self.registrar = registrar
        self.preferences = preferences
    }

    public func start(
        handler: @escaping @MainActor () -> Void
    ) -> Result<KeyboardShortcut, ShortcutConfigurationError> {
        let shortcut = preferences.loadShortcut()
        do {
            try registrar.replaceRegistration(with: shortcut, handler: handler)
            activeShortcut = shortcut
            activeHandler = handler
            return .success(shortcut)
        } catch {
            return .failure(.registration(error))
        }
    }

    public func accept(
        _ candidate: KeyboardShortcut,
        handler: @escaping @MainActor () -> Void
    ) -> Result<KeyboardShortcut, ShortcutConfigurationError> {
        do {
            try candidate.validate()
        } catch let error {
            return .failure(.invalidShortcut(error))
        }

        let previousShortcut = activeShortcut
        let previousHandler = activeHandler

        do {
            try registrar.replaceRegistration(with: candidate, handler: handler)
        } catch {
            return .failure(.registration(error))
        }

        do {
            try preferences.saveShortcut(candidate)
        } catch {
            guard let previousShortcut, let previousHandler else {
                registrar.unregister()
                return .failure(.persistenceFailed)
            }
            do {
                try registrar.replaceRegistration(
                    with: previousShortcut,
                    handler: previousHandler
                )
            } catch {
                return .failure(.rollbackFailed(error))
            }
            return .failure(.persistenceFailed)
        }

        activeShortcut = candidate
        activeHandler = handler
        return .success(candidate)
    }
}
