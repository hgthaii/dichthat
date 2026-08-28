import DichThatCore
import Foundation
import SQLite3

nonisolated(unsafe) private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private struct Arguments {
    let wordNetDirectory: URL
    let cmuDictionary: URL
    let output: URL

    init() throws {
        var values = CommandLine.arguments.dropFirst()
        func value(after flag: String) throws -> String {
            guard let index = values.firstIndex(of: flag) else { throw BuilderError.missingArgument(flag) }
            let valueIndex = values.index(after: index)
            guard valueIndex < values.endIndex else { throw BuilderError.missingArgument(flag) }
            let value = values[valueIndex]
            values.remove(at: valueIndex)
            values.remove(at: index)
            return value
        }
        wordNetDirectory = URL(fileURLWithPath: try value(after: "--wordnet"), isDirectory: true)
        cmuDictionary = URL(fileURLWithPath: try value(after: "--cmudict"))
        output = URL(fileURLWithPath: try value(after: "--output"))
        guard values.isEmpty else { throw BuilderError.unexpectedArgument(String(values.first!)) }
    }
}

private enum BuilderError: Error, CustomStringConvertible {
    case missingArgument(String)
    case unexpectedArgument(String)
    case invalidWordNet(URL)
    case sqlite(String)

    var description: String {
        switch self {
        case let .missingArgument(value): "Missing required argument: \(value)"
        case let .unexpectedArgument(value): "Unexpected argument: \(value)"
        case let .invalidWordNet(url): "Invalid Open English WordNet file: \(url.path)"
        case let .sqlite(message): "SQLite error: \(message)"
        }
    }
}

private final class Database {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard sqlite3_open(url.path, &handle) == SQLITE_OK else {
            throw BuilderError.sqlite("Could not create database")
        }
        try execute("PRAGMA journal_mode = OFF")
        try execute("PRAGMA synchronous = OFF")
        try execute("""
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        );
        CREATE TABLE senses (
            lemma TEXT NOT NULL,
            part_of_speech TEXT NOT NULL,
            definition TEXT NOT NULL,
            example TEXT,
            synonyms_json TEXT NOT NULL,
            sense_rank INTEGER NOT NULL
        );
        CREATE INDEX senses_lemma_rank ON senses(lemma, sense_rank);
        CREATE TABLE pronunciations (
            lemma TEXT NOT NULL,
            ipa TEXT NOT NULL,
            pronunciation_rank INTEGER NOT NULL,
            PRIMARY KEY(lemma, ipa)
        );
        CREATE INDEX pronunciations_lemma_rank ON pronunciations(lemma, pronunciation_rank);
        """)
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "Unknown database error"
            sqlite3_free(error)
            throw BuilderError.sqlite(message)
        }
    }

    func statement(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else { throw BuilderError.sqlite(message) }
        return statement
    }

    func bind(_ value: String?, at index: Int32, to statement: OpaquePointer) throws {
        let result: Int32
        if let value {
            result = value.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
        } else {
            result = sqlite3_bind_null(statement, index)
        }
        guard result == SQLITE_OK else { throw BuilderError.sqlite(message) }
    }

    func step(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else { throw BuilderError.sqlite(message) }
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }

    private var message: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Database is closed"
    }
}

private struct Builder {
    private struct WordNetSynset {
        let partOfSpeech: String
        let definition: String
        let example: String?
        let members: [String]
    }

    let arguments: Arguments
    let database: Database

    func run() throws {
        try database.execute("BEGIN IMMEDIATE")
        try insertMetadata()
        try insertWordNet()
        try insertPronunciations()
        try database.execute("COMMIT; ANALYZE; VACUUM")
    }

    private func insertMetadata() throws {
        let statement = try database.statement("INSERT INTO metadata(key, value) VALUES(?, ?)")
        defer { sqlite3_finalize(statement) }
        for (key, value) in [
            ("schema_version", "1"),
            ("wordnet_version", "2025"),
            ("cmudict_commit", "74790861f652b15e4ac49015a90074ad62a27690"),
        ] {
            try database.bind(key, at: 1, to: statement)
            try database.bind(value, at: 2, to: statement)
            try database.step(statement)
        }
    }

    private func insertWordNet() throws {
        let allFiles = try FileManager.default.contentsOfDirectory(
            at: arguments.wordNetDirectory,
            includingPropertiesForKeys: nil
        )
        let synsetFiles = allFiles.filter {
            $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix("entries-")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let entryFiles = allFiles.filter {
            $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("entries-")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !synsetFiles.isEmpty, !entryFiles.isEmpty else {
            throw BuilderError.invalidWordNet(arguments.wordNetDirectory)
        }

        var synsets: [String: WordNetSynset] = [:]
        for file in synsetFiles {
            let data = try Data(contentsOf: file, options: .mappedIfSafe)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { throw BuilderError.invalidWordNet(file) }
            for (identifier, value) in root {
                guard let synset = value as? [String: Any],
                      let definition = (synset["definition"] as? [String])?.first?.cleaned,
                      let members = synset["members"] as? [String],
                      let code = synset["partOfSpeech"] as? String,
                      let partOfSpeech = partOfSpeechName(code)
                else { continue }
                synsets[identifier] = WordNetSynset(
                    partOfSpeech: partOfSpeech,
                    definition: definition,
                    example: (synset["example"] as? [String])?.first?.cleaned,
                    members: members.compactMap(normalizeLemma)
                )
            }
        }

        let statement = try database.statement("""
        INSERT INTO senses(lemma, part_of_speech, definition, example, synonyms_json, sense_rank)
        VALUES(?, ?, ?, ?, ?, ?)
        """)
        defer { sqlite3_finalize(statement) }
        let encoder = JSONEncoder()

        for file in entryFiles {
            let data = try Data(contentsOf: file, options: .mappedIfSafe)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { throw BuilderError.invalidWordNet(file) }
            for rawLemma in root.keys.sorted() {
                guard let lemma = normalizeLemma(rawLemma),
                      let variants = root[rawLemma] as? [String: Any]
                else { continue }
                let senseGroups: [[String]] = variants.keys.sorted().compactMap { variant in
                    guard let entry = variants[variant] as? [String: Any],
                          let senses = entry["sense"] as? [[String: Any]]
                    else { return nil }
                    return senses.compactMap { $0["synset"] as? String }
                }
                guard !senseGroups.isEmpty else { continue }
                var orderedIdentifiers: [String] = []
                let maximumSenseCount = senseGroups.map(\.count).max() ?? 0
                for offset in 0 ..< maximumSenseCount {
                    for group in senseGroups where group.indices.contains(offset) {
                        let identifier = group[offset]
                        if !orderedIdentifiers.contains(identifier) { orderedIdentifiers.append(identifier) }
                    }
                }

                for (rank, identifier) in orderedIdentifiers.prefix(3).enumerated() {
                    guard let synset = synsets[identifier] else { continue }
                    let synonyms = synset.members.filter { $0 != lemma }.prefix(5)
                    let synonymsJSON = String(
                        data: try encoder.encode(Array(synonyms)),
                        encoding: .utf8
                    ) ?? "[]"
                    try database.bind(lemma, at: 1, to: statement)
                    try database.bind(synset.partOfSpeech, at: 2, to: statement)
                    try database.bind(synset.definition, at: 3, to: statement)
                    try database.bind(synset.example, at: 4, to: statement)
                    try database.bind(synonymsJSON, at: 5, to: statement)
                    sqlite3_bind_int(statement, 6, Int32(rank))
                    try database.step(statement)
                }
            }
        }
    }

    private func insertPronunciations() throws {
        let statement = try database.statement(
            "INSERT OR IGNORE INTO pronunciations(lemma, ipa, pronunciation_rank) VALUES(?, ?, ?)"
        )
        defer { sqlite3_finalize(statement) }
        let content = try String(contentsOf: arguments.cmuDictionary, encoding: .utf8)
        var ranks: [String: Int] = [:]
        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";;;"),
                  let separator = line.firstIndex(where: \.isWhitespace)
            else { continue }
            var lemma = String(line[..<separator]).lowercased()
            if let variant = lemma.firstIndex(of: "(") { lemma = String(lemma[..<variant]) }
            guard isSupportedLemma(lemma),
                  let ipa = ARPABETConverter.ipa(from: String(line[separator...]))
            else { continue }
            let rank = ranks[lemma, default: 0]
            guard rank < 3 else { continue }
            ranks[lemma] = rank + 1
            try database.bind(lemma, at: 1, to: statement)
            try database.bind(ipa, at: 2, to: statement)
            sqlite3_bind_int(statement, 3, Int32(rank))
            try database.step(statement)
        }
    }

    private func partOfSpeechName(_ code: String) -> String? {
        switch code {
        case "n": "noun"
        case "v": "verb"
        case "a", "s": "adjective"
        case "r": "adverb"
        default: nil
        }
    }

    private func normalizeLemma(_ value: String) -> String? {
        let lemma = value.replacingOccurrences(of: "_", with: " ").lowercased()
        return isSupportedLemma(lemma) ? lemma : nil
    }

    private func isSupportedLemma(_ value: String) -> Bool {
        let scalars = Array(value.unicodeScalars)
        guard !scalars.isEmpty, scalars.count <= 64 else { return false }
        return scalars.enumerated().allSatisfy { index, scalar in
            let isLetter = (97 ... 122).contains(scalar.value)
            let isSeparator = scalar.value == 39 || scalar.value == 45
            return isLetter || (isSeparator && index > 0 && index < scalars.count - 1)
        }
    }
}

private extension String {
    var cleaned: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

do {
    let arguments = try Arguments()
    try Builder(arguments: arguments, database: Database(url: arguments.output)).run()
    print(arguments.output.path)
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
