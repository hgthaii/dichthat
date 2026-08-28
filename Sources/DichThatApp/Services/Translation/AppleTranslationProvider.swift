import AppKit
import DichThatCore
import SwiftUI
@preconcurrency import Translation

@MainActor
final class AppleTranslationProvider: ObservableObject {
    @Published fileprivate var configuration: TranslationSession.Configuration?

    private struct SessionKey: Hashable {
        let source: String
        let target: String
    }

    private struct PendingRequest {
        let id: UUID
        let source: SupportedLanguage
        let target: SupportedLanguage
        let texts: [String]
        let continuation: CheckedContinuation<Result<[String], TranslationFailure>, Never>
        var isRunning: Bool
    }

    private struct PendingPreparation {
        let id: UUID
        let source: SupportedLanguage
        let target: SupportedLanguage
        let continuation: CheckedContinuation<Result<Void, TranslationFailure>, Never>
        var isRunning: Bool
    }

    private var pendingRequest: PendingRequest?
    private var pendingPreparation: PendingPreparation?
    private var bridgeView: NSView?
    private var installedSessions: [SessionKey: TranslationSession] = [:]
    private var activeDirectRequest: (id: UUID, key: SessionKey, session: TranslationSession)?
    private var activePreparation: (id: UUID, session: TranslationSession)?

    func attachBridge(to parent: NSView) {
        if let bridgeView {
            guard bridgeView.superview !== parent else { return }
            bridgeView.removeFromSuperview()
            self.bridgeView = nil
        }
        let view = NSHostingView(rootView: AppleTranslationBridge(provider: self))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alphaValue = 0.001
        parent.addSubview(view)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 1),
            view.heightAnchor.constraint(equalToConstant: 1),
            view.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: parent.centerYAnchor),
        ])
        bridgeView = view
    }

    func languagesAreReady() async -> Bool {
        let englishToVietnamese = await installedSession(source: .english, target: .vietnamese)
        guard englishToVietnamese != nil else { return false }
        return await installedSession(source: .vietnamese, target: .english) != nil
    }

    func cancelLanguagePreparation() {
        activePreparation?.session.cancel()
        activePreparation = nil
        cancelPendingPreparation()
        configuration = nil
    }

    func prepareLanguages() async -> Result<Void, TranslationFailure> {
        let pairs: [(SupportedLanguage, SupportedLanguage)] = [
            (.english, .vietnamese),
            (.vietnamese, .english),
        ]
        for (source, target) in pairs {
            if await installedSession(source: source, target: target) != nil { continue }
            let result = await preparePair(source: source, target: target)
            guard case .success = result else { return result }
        }
        return .success(())
    }

    func translate(route: LanguageRoute) async -> Result<TranslationOutput, TranslationFailure> {
        switch await translate(texts: [route.text], source: route.source, target: route.target) {
        case let .success(values):
            guard let translated = values.first else { return .failure(.emptyTranslation) }
            return .success(TranslationOutput(
                sourceText: route.text,
                text: translated,
                source: route.source,
                target: route.target
            ))
        case let .failure(error):
            return .failure(error)
        }
    }

    func translate(
        texts: [String],
        source: SupportedLanguage,
        target: SupportedLanguage
    ) async -> Result<[String], TranslationFailure> {
        guard !texts.isEmpty else { return .success([]) }
        let requestID = UUID()
        cancelActiveDirectRequest()
        cancelPendingRequest()
        cancelPendingPreparation()

        if let cachedSession = await installedSession(source: source, target: target) {
            guard !Task.isCancelled else { return .failure(.cancelled) }
            let key = sessionKey(source: source, target: target)
            activeDirectRequest = (requestID, key, cachedSession)
            return await withTaskCancellationHandler {
                let result = await performTranslation(texts: texts, session: cachedSession)
                if activeDirectRequest?.id == requestID {
                    activeDirectRequest = nil
                }
                return result
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.cancelDirectRequest(requestID: requestID)
                }
            }
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: .failure(.cancelled))
                    return
                }
                pendingRequest = PendingRequest(
                    id: requestID,
                    source: source,
                    target: target,
                    texts: texts,
                    continuation: continuation,
                    isRunning: false
                )
                refreshConfiguration(source: source, target: target)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(requestID: requestID)
            }
        }
    }

    fileprivate func use(session: TranslationSession) async {
        if var pendingPreparation,
           !pendingPreparation.isRunning,
           sessionMatchesPreparation(session, preparation: pendingPreparation) {
            pendingPreparation.isRunning = true
            self.pendingPreparation = pendingPreparation
            activePreparation = (pendingPreparation.id, session)
            do {
                try await session.prepareTranslation()
                try Task.checkCancellation()
                let key = sessionKey(
                    source: pendingPreparation.source,
                    target: pendingPreparation.target
                )
                installedSessions[key] = makeInstalledSession(
                    source: pendingPreparation.source,
                    target: pendingPreparation.target
                )
                completePreparation(requestID: pendingPreparation.id, result: .success(()))
            } catch is CancellationError {
                completePreparation(requestID: pendingPreparation.id, result: .failure(.cancelled))
            } catch {
                completePreparation(
                    requestID: pendingPreparation.id,
                    result: .failure(.translationUnavailable)
                )
            }
            if activePreparation?.id == pendingPreparation.id {
                activePreparation = nil
            }
            return
        }

        guard var pendingRequest,
              !pendingRequest.isRunning,
              sessionMatchesRequest(session, request: pendingRequest)
        else { return }
        pendingRequest.isRunning = true
        self.pendingRequest = pendingRequest

        do {
            try await session.prepareTranslation()
            try Task.checkCancellation()
            let result = await performTranslation(texts: pendingRequest.texts, session: session)
            if case .success = result {
                let key = sessionKey(source: pendingRequest.source, target: pendingRequest.target)
                installedSessions[key] = makeInstalledSession(
                    source: pendingRequest.source,
                    target: pendingRequest.target
                )
            }
            complete(requestID: pendingRequest.id, result: result)
        } catch is CancellationError {
            complete(requestID: pendingRequest.id, result: .failure(.cancelled))
        } catch TranslationError.unsupportedSourceLanguage,
                TranslationError.unsupportedTargetLanguage,
                TranslationError.unsupportedLanguagePairing {
            complete(requestID: pendingRequest.id, result: .failure(.unsupportedLanguage))
        } catch TranslationError.unableToIdentifyLanguage {
            complete(requestID: pendingRequest.id, result: .failure(.ambiguousLanguage))
        } catch TranslationError.nothingToTranslate {
            complete(requestID: pendingRequest.id, result: .failure(.emptyInput))
        } catch {
            complete(requestID: pendingRequest.id, result: .failure(.translationUnavailable))
        }
    }

    private func installedSession(
        source: SupportedLanguage,
        target: SupportedLanguage
    ) async -> TranslationSession? {
        let key = sessionKey(source: source, target: target)
        if let session = installedSessions[key] { return session }
        let session = makeInstalledSession(source: source, target: target)
        guard await session.isReady else { return nil }
        installedSessions[key] = session
        return session
    }

    private func preparePair(
        source: SupportedLanguage,
        target: SupportedLanguage
    ) async -> Result<Void, TranslationFailure> {
        let requestID = UUID()
        cancelActiveDirectRequest()
        cancelPendingRequest()
        cancelPendingPreparation()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: .failure(.cancelled))
                    return
                }
                pendingPreparation = PendingPreparation(
                    id: requestID,
                    source: source,
                    target: target,
                    continuation: continuation,
                    isRunning: false
                )
                refreshConfiguration(source: source, target: target)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelPreparation(requestID: requestID)
            }
        }
    }

    private func performTranslation(
        texts: [String],
        session: TranslationSession
    ) async -> Result<[String], TranslationFailure> {
        do {
            nonisolated(unsafe) let requests = texts.enumerated().map { index, text in
                TranslationSession.Request(sourceText: text, clientIdentifier: String(index))
            }
            let responses = try await session.translations(from: requests)
            var indexed: [Int: String] = [:]
            for response in responses {
                guard let identifier = response.clientIdentifier,
                      let index = Int(identifier),
                      indexed[index] == nil
                else { continue }
                indexed[index] = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let translated = texts.indices.compactMap { indexed[$0] }
            guard translated.count == texts.count,
                  translated.allSatisfy({ !$0.isEmpty })
            else { return .failure(.emptyTranslation) }
            return .success(translated)
        } catch is CancellationError {
            return .failure(.cancelled)
        } catch TranslationError.unsupportedSourceLanguage,
                TranslationError.unsupportedTargetLanguage,
                TranslationError.unsupportedLanguagePairing {
            return .failure(.unsupportedLanguage)
        } catch TranslationError.unableToIdentifyLanguage {
            return .failure(.ambiguousLanguage)
        } catch TranslationError.nothingToTranslate {
            return .failure(.emptyInput)
        } catch {
            return .failure(.translationUnavailable)
        }
    }

    private func sessionKey(
        source: SupportedLanguage,
        target: SupportedLanguage
    ) -> SessionKey {
        SessionKey(source: source.rawValue, target: target.rawValue)
    }

    private func makeInstalledSession(
        source: SupportedLanguage,
        target: SupportedLanguage
    ) -> TranslationSession {
        let sourceLanguage = Locale.Language(identifier: source.rawValue)
        let targetLanguage = Locale.Language(identifier: target.rawValue)
        if #available(macOS 26.4, *) {
            return TranslationSession(
                installedSource: sourceLanguage,
                target: targetLanguage,
                preferredStrategy: .lowLatency
            )
        }
        return TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
    }

    private func refreshConfiguration(source: SupportedLanguage, target: SupportedLanguage) {
        let source = Locale.Language(identifier: source.rawValue)
        let target = Locale.Language(identifier: target.rawValue)
        if configuration?.source == source, configuration?.target == target {
            configuration?.invalidate()
        } else if #available(macOS 26.4, *) {
            configuration = TranslationSession.Configuration(
                source: source,
                target: target,
                preferredStrategy: .lowLatency
            )
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    private func sessionMatchesRequest(
        _ session: TranslationSession,
        request: PendingRequest
    ) -> Bool {
        session.sourceLanguage == Locale.Language(identifier: request.source.rawValue)
            && session.targetLanguage == Locale.Language(identifier: request.target.rawValue)
    }

    private func sessionMatchesPreparation(
        _ session: TranslationSession,
        preparation: PendingPreparation
    ) -> Bool {
        session.sourceLanguage == Locale.Language(identifier: preparation.source.rawValue)
            && session.targetLanguage == Locale.Language(identifier: preparation.target.rawValue)
    }

    private func complete(
        requestID: UUID,
        result: Result<[String], TranslationFailure>
    ) {
        guard let pendingRequest, pendingRequest.id == requestID else { return }
        self.pendingRequest = nil
        pendingRequest.continuation.resume(returning: result)
    }

    private func completePreparation(
        requestID: UUID,
        result: Result<Void, TranslationFailure>
    ) {
        guard let pendingPreparation, pendingPreparation.id == requestID else { return }
        self.pendingPreparation = nil
        pendingPreparation.continuation.resume(returning: result)
    }

    private func cancel(requestID: UUID) {
        cancelDirectRequest(requestID: requestID)
        guard pendingRequest?.id == requestID else { return }
        cancelPendingRequest()
        configuration = nil
    }

    private func cancelPreparation(requestID: UUID) {
        guard pendingPreparation?.id == requestID else { return }
        cancelPendingPreparation()
        configuration = nil
    }

    private func cancelDirectRequest(requestID: UUID) {
        guard let activeDirectRequest, activeDirectRequest.id == requestID else { return }
        activeDirectRequest.session.cancel()
        installedSessions[activeDirectRequest.key] = nil
        self.activeDirectRequest = nil
    }

    private func cancelActiveDirectRequest() {
        guard let activeDirectRequest else { return }
        cancelDirectRequest(requestID: activeDirectRequest.id)
    }

    private func cancelPendingRequest() {
        guard let pendingRequest else { return }
        self.pendingRequest = nil
        pendingRequest.continuation.resume(returning: .failure(.cancelled))
    }

    private func cancelPendingPreparation() {
        guard let pendingPreparation else { return }
        self.pendingPreparation = nil
        if activePreparation?.id == pendingPreparation.id {
            activePreparation?.session.cancel()
            activePreparation = nil
        }
        pendingPreparation.continuation.resume(returning: .failure(.cancelled))
    }
}

private struct AppleTranslationBridge: View {
    @ObservedObject var provider: AppleTranslationProvider

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(provider.configuration) { session in
                await provider.use(session: session)
            }
    }
}
