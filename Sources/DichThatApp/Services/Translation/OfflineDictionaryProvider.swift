import DichThatCore
import Foundation
import SQLite3

struct OfflineDictionaryProvider: Sendable {
    private let databaseURL: URL?

    init(databaseURL: URL? = Bundle.main.url(forResource: "OfflineDictionary", withExtension: "sqlite")) {
        self.databaseURL = databaseURL
    }

    func lookup(word: String) -> EnglishDictionaryEnrichment? {
        let lemma = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lemma.isEmpty, let databaseURL else { return nil }
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database
        else {
            sqlite3_close(database)
            return nil
        }
        defer { sqlite3_close(database) }

        let phonetics = pronunciations(for: lemma, database: database)
        let meanings = meanings(for: lemma, database: database)
        guard !phonetics.isEmpty || !meanings.isEmpty else { return nil }
        return EnglishDictionaryEnrichment(
            phonetics: phonetics,
            pronunciations: phonetics.map {
                EnglishPronunciation(phonetic: $0)
            },
            meanings: meanings
        )
    }

    private func pronunciations(for lemma: String, database: OpaquePointer) -> [String] {
        query(
            "SELECT ipa FROM pronunciations WHERE lemma = ? ORDER BY pronunciation_rank LIMIT 3",
            lemma: lemma,
            database: database
        ) { statement in string(statement, column: 0).map { [$0] } ?? [] }
    }

    private func meanings(for lemma: String, database: OpaquePointer) -> [EnglishDictionaryMeaning] {
        query(
            """
            SELECT part_of_speech, definition, example, synonyms_json
            FROM senses WHERE lemma = ? ORDER BY sense_rank LIMIT 3
            """,
            lemma: lemma,
            database: database
        ) { statement in
            guard let partOfSpeech = string(statement, column: 0),
                  let definition = string(statement, column: 1),
                  let synonymsJSON = string(statement, column: 3),
                  let data = synonymsJSON.data(using: .utf8),
                  let synonyms = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return [EnglishDictionaryMeaning(
                partOfSpeech: partOfSpeech,
                definition: definition,
                example: string(statement, column: 2),
                synonyms: synonyms
            )]
        }
    }

    private func query<Value>(
        _ sql: String,
        lemma: String,
        database: OpaquePointer,
        map: (OpaquePointer) -> [Value]
    ) -> [Value] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else { return [] }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard lemma.withCString({ sqlite3_bind_text(statement, 1, $0, -1, transient) }) == SQLITE_OK
        else { return [] }
        var values: [Value] = []
        while sqlite3_step(statement) == SQLITE_ROW { values.append(contentsOf: map(statement)) }
        return values
    }

    private func string(_ statement: OpaquePointer, column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, column)
        else { return nil }
        return String(cString: value)
    }
}
