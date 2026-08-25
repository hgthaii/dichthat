import DichThatCore
import Foundation

struct EnglishDictionaryProvider: Sendable {
    func lookup(word: String) async -> EnglishDictionaryEnrichment? {
        guard let request = EnglishDictionaryRequestBuilder.request(word: word) else { return nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = EnglishDictionaryRequestBuilder.timeout
        configuration.timeoutIntervalForResource = EnglishDictionaryRequestBuilder.timeout
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        do {
            let (data, response) = try await URLSession(configuration: configuration).data(for: request)
            guard !Task.isCancelled,
                  let response = response as? HTTPURLResponse,
                  (200 ... 299).contains(response.statusCode)
            else { return nil }
            return EnglishDictionaryResponseParser.parse(data: data)
        } catch {
            return nil
        }
    }
}
