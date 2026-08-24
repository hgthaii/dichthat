import DichThatCore
import Foundation

struct GoogleWebTranslationProvider: Sendable {
    func translate(
        route: LanguageRoute,
        mode: TranslationMode
    ) async -> Result<TranslationOutput, TranslationFailure> {
        let request = GoogleTranslationRequestBuilder.request(for: route, mode: mode)
        switch await fetch(request) {
        case let .success(data):
            return mode == .dictionary
                ? GoogleTranslationResponseParser.parseEnriched(data: data, expectedRoute: route)
                : GoogleTranslationResponseParser.parse(data: data, expectedRoute: route)
        case let .failure(error):
            return .failure(error)
        }
    }

    func localize(
        batch: TranslationContextBatch
    ) async -> Result<[String: String], TranslationFailure> {
        let route = LanguageRoute(source: .english, target: .vietnamese, text: batch.text)
        switch await fetch(GoogleTranslationRequestBuilder.contextRequest(batchText: batch.text)) {
        case let .success(data):
            switch GoogleTranslationResponseParser.parse(data: data, expectedRoute: route) {
            case let .success(output):
                guard let localized = TranslationContextBatchParser.parse(
                    translatedText: output.text,
                    batch: batch
                ) else { return .failure(.malformedResponse) }
                return .success(localized)
            case let .failure(error):
                return .failure(error)
            }
        case let .failure(error):
            return .failure(error)
        }
    }

    private func fetch(_ request: URLRequest) async -> Result<Data, TranslationFailure> {
        if Task.isCancelled { return .failure(.cancelled) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = GoogleTranslationRequestBuilder.timeout
        configuration.timeoutIntervalForResource = GoogleTranslationRequestBuilder.timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: configuration)

        do {
            let (data, response) = try await session.data(
                for: request
            )
            if Task.isCancelled { return .failure(.cancelled) }
            guard let response = response as? HTTPURLResponse else {
                return .failure(.malformedResponse)
            }
            if let failure = GoogleTranslationTransportPolicy.failure(
                forHTTPStatus: response.statusCode
            ) {
                return .failure(failure)
            }
            return .success(data)
        } catch is CancellationError {
            return .failure(.cancelled)
        } catch let error as URLError {
            return .failure(GoogleTranslationTransportPolicy.failure(for: error.code))
        } catch {
            return .failure(.networkUnavailable)
        }
    }
}
