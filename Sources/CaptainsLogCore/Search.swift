import CryptoKit
import CSQLiteVec
import Foundation
import SQLite3

public struct SearchResult: Sendable, Equatable {
    public enum MatchKind: String, Sendable, Equatable {
        case keyword
        case semantic
    }

    public let stem: String
    public let slug: String?
    public let displayName: String
    public let path: String
    public let excerpt: String
    public let distance: Double
    public let matchKind: MatchKind
    public let matchedTerms: [String]

    public init(
        stem: String,
        slug: String?,
        displayName: String,
        path: String,
        excerpt: String,
        distance: Double,
        matchKind: MatchKind = .semantic,
        matchedTerms: [String] = []
    ) {
        self.stem = stem
        self.slug = slug
        self.displayName = displayName
        self.path = path
        self.excerpt = excerpt
        self.distance = distance
        self.matchKind = matchKind
        self.matchedTerms = matchedTerms
    }
}

public struct SearchIndexSummary: Sendable, Equatable {
    public var added = 0
    public var updated = 0
    public var unchanged = 0
    public var removed = 0
    public var chunks = 0

    public init() {}
}

public struct SearchProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case preparingModel
        case scanning
        case indexing
        case searching
    }

    public let phase: Phase
    public let completed: Int
    public let total: Int
    public let message: String

    public init(phase: Phase, completed: Int, total: Int, message: String) {
        self.phase = phase
        self.completed = completed
        self.total = total
        self.message = message
    }
}

public actor SemanticSearch {
    public static let schemaVersion = "2"
    public static let chunkerVersion = "2:384:48:32:64"

    private let dataDir: String
    private let model: any TextEmbeddingModel
    private let store: SearchStore

    public init(dataDir: String, model: any TextEmbeddingModel) throws {
        self.dataDir = dataDir
        self.model = model
        self.store = try SearchStore(
            path: URL(fileURLWithPath: dataDir)
                .appendingPathComponent(".search/search.sqlite").path)
    }

    public static func live(
        dataDir: String,
        downloadProgress: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> SemanticSearch {
        let model = try await E5EmbeddingModel.load(progressHandler: downloadProgress)
        return try SemanticSearch(dataDir: dataDir, model: model)
    }

    @discardableResult
    public func synchronize(
        rebuild: Bool = false,
        progress: @Sendable (SearchProgress) -> Void = { _ in }
    ) async throws -> SearchIndexSummary {
        progress(SearchProgress(
            phase: .scanning, completed: 0, total: 0, message: "Scanning completed entries"))

        let identity = await model.identity
        let metadata = [
            "schema_version": Self.schemaVersion,
            "model_identity": identity,
            "embedding_dimension": String(E5EmbeddingModel.dimension),
            "chunker_version": Self.chunkerVersion,
        ]
        let metadataChanged = try store.metadataDiffers(from: metadata)
        if rebuild || metadataChanged {
            try store.rebuild(metadata: metadata)
        }

        let listings = Pipeline.listEntries(dataDir: dataDir)
            .filter { $0.nextStage == .done }
        let existing = try store.documentFingerprints()
        let canonicalPaths = Set(listings.map(\.latestPath))
        var summary = SearchIndexSummary()

        for path in existing.keys where !canonicalPaths.contains(path) {
            try store.deleteDocument(path: path)
            summary.removed += 1
        }

        for (offset, listing) in listings.enumerated() {
            try Task.checkCancellation()
            progress(SearchProgress(
                phase: .indexing,
                completed: offset,
                total: listings.count,
                message: "Indexing \(listing.displayName.replacingOccurrences(of: "-", with: " "))"
            ))

            let content = try String(contentsOfFile: listing.latestPath, encoding: .utf8)
            let hash = Self.sha256(content)
            if existing[listing.latestPath] == hash {
                summary.unchanged += 1
                continue
            }

            let prepared = Self.prepare(content: content, displayName: listing.displayName)
            var cleanChunks = try await model.chunks(
                for: prepared.body, maxTokens: 384, overlap: 48)
            let bodyWasEmpty = cleanChunks.isEmpty
            if cleanChunks.isEmpty, !prepared.metadata.isEmpty {
                cleanChunks = try await model.chunks(
                    for: prepared.metadata, maxTokens: 384, overlap: 48)
            }

            // Bound each part independently so the title and YAML context cannot push
            // a body chunk beyond the E5 model's 511-token context window.
            let semanticTitle = try await model.chunks(
                for: prepared.title, maxTokens: 32, overlap: 0).first ?? ""
            let semanticMetadata = bodyWasEmpty ? "" : try await model.chunks(
                for: prepared.metadata, maxTokens: 64, overlap: 0).first ?? ""

            var indexedChunks: [(text: String, embedding: [Float])] = []
            indexedChunks.reserveCapacity(cleanChunks.count)
            for chunk in cleanChunks {
                try Task.checkCancellation()
                let semanticText = [semanticTitle, semanticMetadata, chunk]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                let embedding = try await model.embed(semanticText, as: .passage)
                indexedChunks.append((chunk, embedding))
            }

            try store.replaceDocument(
                path: listing.latestPath,
                stem: listing.stem,
                slug: listing.slug,
                displayName: listing.displayName,
                contentHash: hash,
                chunks: indexedChunks
            )
            summary.chunks += indexedChunks.count
            if existing[listing.latestPath] == nil {
                summary.added += 1
            } else {
                summary.updated += 1
            }
        }

        progress(SearchProgress(
            phase: .indexing,
            completed: listings.count,
            total: listings.count,
            message: "Search index ready"
        ))
        return summary
    }

    public func search(
        _ query: String,
        limit: Int = 10,
        synchronizeFirst: Bool = true,
        progress: @Sendable (SearchProgress) -> Void = { _ in }
    ) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        if synchronizeFirst {
            _ = try await synchronize(progress: progress)
        }
        progress(SearchProgress(
            phase: .searching, completed: 0, total: 2, message: "Searching exact words"))
        let terms = Self.keywordTerms(in: trimmed)
        var results = try store.keywordSearch(terms: terms, limit: limit)

        if results.count < limit {
            progress(SearchProgress(
                phase: .searching, completed: 1, total: 2,
                message: "Finding related passages"))
            let embedding = try await model.embed(trimmed, as: .query)
            let excludedPaths = Set(results.map(\.path))
            let semantic = try store.semanticSearch(
                embedding: embedding,
                terms: terms,
                excluding: excludedPaths,
                limit: limit - results.count
            )
            results.append(contentsOf: semantic)
        }
        progress(SearchProgress(
            phase: .searching, completed: 2, total: 2, message: "Search complete"))
        return results
    }

    private static func keywordTerms(in query: String) -> [String] {
        let stopWords: Set<String> = [
            "a", "an", "and", "are", "about", "did", "do", "for", "from", "how", "i",
            "in", "is", "it", "my", "of", "on", "or", "the", "to", "was", "what", "when",
            "where", "who", "why", "with",
            "de", "een", "en", "het", "ik", "in", "is", "met", "op", "te", "van", "wat",
            "der", "die", "das", "ein", "eine", "ist", "mit", "und", "von", "was", "wo",
        ]
        var seen = Set<String>()
        return query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
            .filter { term in
                guard term.count > 1, !stopWords.contains(term), seen.insert(term).inserted else {
                    return false
                }
                return true
            }
    }

    private static func prepare(
        content: String, displayName: String
    ) -> (title: String, metadata: String, body: String) {
        let title = displayName.replacingOccurrences(of: "-", with: " ")
        guard content.hasPrefix("---") else {
            return (title, "", content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let afterOpening = content.dropFirst(3)
        guard let closing = afterOpening.range(of: "\n---") else {
            return (title, "", content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let metadata = String(afterOpening[..<closing.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let body = String(afterOpening[closing.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, metadata, body)
    }

    private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private final class SearchStore {
    private var database: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String) throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true)
        guard sqlite3_open_v2(
            path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil) == SQLITE_OK
        else {
            throw SearchError.database("Could not open \(path)")
        }
        sqlite3_busy_timeout(database, 5_000)
        guard sqlite3_vec_init(database, nil, nil) == SQLITE_OK else {
            throw databaseError("Could not register sqlite-vec")
        }
        try execute("PRAGMA foreign_keys = ON")
        try createSchema()
    }

    deinit {
        sqlite3_close(database)
    }

    func metadataDiffers(from expected: [String: String]) throws -> Bool {
        let actual = try metadata()
        return actual != expected
    }

    func rebuild(metadata: [String: String]) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("DROP TABLE IF EXISTS chunk_fts")
            try execute("DROP TABLE IF EXISTS vec_chunks")
            try execute("DROP TABLE IF EXISTS chunks")
            try execute("DROP TABLE IF EXISTS documents")
            try execute("DROP TABLE IF EXISTS index_metadata")
            try createSchema()
            for (key, value) in metadata {
                try run(
                    "INSERT INTO index_metadata(key, value) VALUES (?, ?)",
                    bindings: [.text(key), .text(value)])
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func documentFingerprints() throws -> [String: String] {
        var result: [String: String] = [:]
        try query("SELECT path, content_hash FROM documents") { statement in
            result[columnText(statement, 0)] = columnText(statement, 1)
        }
        return result
    }

    func deleteDocument(path: String) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try run(
                "DELETE FROM chunk_fts WHERE chunk_id IN (SELECT chunks.id FROM chunks JOIN documents ON documents.id = chunks.document_id WHERE documents.path = ?)",
                bindings: [.text(path)])
            try run(
                "DELETE FROM vec_chunks WHERE chunk_id IN (SELECT chunks.id FROM chunks JOIN documents ON documents.id = chunks.document_id WHERE documents.path = ?)",
                bindings: [.text(path)])
            try run("DELETE FROM documents WHERE path = ?", bindings: [.text(path)])
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func replaceDocument(
        path: String,
        stem: String,
        slug: String?,
        displayName: String,
        contentHash: String,
        chunks: [(text: String, embedding: [Float])]
    ) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try run(
                "DELETE FROM chunk_fts WHERE chunk_id IN (SELECT chunks.id FROM chunks JOIN documents ON documents.id = chunks.document_id WHERE documents.path = ?)",
                bindings: [.text(path)])
            try run(
                "DELETE FROM vec_chunks WHERE chunk_id IN (SELECT chunks.id FROM chunks JOIN documents ON documents.id = chunks.document_id WHERE documents.path = ?)",
                bindings: [.text(path)])
            try run("DELETE FROM documents WHERE path = ?", bindings: [.text(path)])
            try run(
                "INSERT INTO documents(path, stem, slug, display_name, content_hash, indexed_at) VALUES (?, ?, ?, ?, ?, ?)",
                bindings: [
                    .text(path), .text(stem), slug.map(Binding.text) ?? .null,
                    .text(displayName), .text(contentHash), .text(ISO8601DateFormatter().string(from: Date())),
                ])
            let documentID = sqlite3_last_insert_rowid(database)
            for (ordinal, chunk) in chunks.enumerated() {
                try run(
                    "INSERT INTO chunks(document_id, ordinal, text) VALUES (?, ?, ?)",
                    bindings: [.integer(documentID), .integer(Int64(ordinal)), .text(chunk.text)])
                let chunkID = sqlite3_last_insert_rowid(database)
                try run(
                    "INSERT INTO chunk_fts(chunk_id, title, passage) VALUES (?, ?, ?)",
                    bindings: [
                        .integer(chunkID), .text(displayName), .text(chunk.text),
                    ])
                try run(
                    "INSERT INTO vec_chunks(chunk_id, embedding) VALUES (?, ?)",
                    bindings: [.integer(chunkID), .blob(Self.vectorData(chunk.embedding))])
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func keywordSearch(terms: [String], limit: Int) throws -> [SearchResult] {
        guard !terms.isEmpty, limit > 0 else { return [] }
        let expression = terms
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: " OR ")
        var results: [SearchResult] = []
        var seenPaths = Set<String>()
        try query(
            """
            SELECT d.stem, d.slug, d.display_name, d.path, c.text,
                   bm25(chunk_fts, 0.0, 5.0, 1.0) AS relevance
            FROM chunk_fts
            JOIN chunks AS c ON c.id = chunk_fts.chunk_id
            JOIN documents AS d ON d.id = c.document_id
            WHERE chunk_fts MATCH ?
            ORDER BY relevance, d.id DESC
            LIMIT ?
            """,
            bindings: [.text(expression), .integer(Int64(max(limit * 8, 40)))]
        ) { statement in
            let path = columnText(statement, 3)
            guard seenPaths.insert(path).inserted else { return }
            let title = columnText(statement, 2)
            let passage = columnText(statement, 4)
            let matchedTerms = Self.matchedTerms(terms, in: title + "\n" + passage)
            results.append(SearchResult(
                stem: columnText(statement, 0),
                slug: sqlite3_column_type(statement, 1) == SQLITE_NULL
                    ? nil : columnText(statement, 1),
                displayName: title,
                path: path,
                excerpt: Self.passageSnippet(passage, around: matchedTerms),
                distance: 0,
                matchKind: .keyword,
                matchedTerms: matchedTerms
            ))
        }
        return Array(results.prefix(limit))
    }

    func semanticSearch(
        embedding: [Float],
        terms: [String],
        excluding excludedPaths: Set<String>,
        limit: Int
    ) throws -> [SearchResult] {
        guard limit > 0 else { return [] }
        let candidateCount = max(limit * 8, 40)
        var results: [SearchResult] = []
        var seenPaths = excludedPaths
        try query(
            """
            SELECT d.stem, d.slug, d.display_name, d.path, c.text, v.distance
            FROM vec_chunks AS v
            JOIN chunks AS c ON c.id = v.chunk_id
            JOIN documents AS d ON d.id = c.document_id
            WHERE v.embedding MATCH ? AND k = ?
            ORDER BY v.distance
            """,
            bindings: [.blob(Self.vectorData(embedding)), .integer(Int64(candidateCount))]
        ) { statement in
            let path = columnText(statement, 3)
            guard seenPaths.insert(path).inserted else { return }
            let title = columnText(statement, 2)
            let passage = columnText(statement, 4)
            let matchedTerms = Self.matchedTerms(terms, in: title + "\n" + passage)
            let result = SearchResult(
                stem: columnText(statement, 0),
                slug: sqlite3_column_type(statement, 1) == SQLITE_NULL
                    ? nil : columnText(statement, 1),
                displayName: title,
                path: path,
                excerpt: Self.passageSnippet(passage, around: matchedTerms),
                distance: sqlite3_column_double(statement, 5),
                matchKind: .semantic,
                matchedTerms: matchedTerms
            )
            results.append(result)
        }
        return Array(results.prefix(limit))
    }

    private func createSchema() throws {
        try execute(
            "CREATE TABLE IF NOT EXISTS index_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY,
                path TEXT NOT NULL UNIQUE,
                stem TEXT NOT NULL,
                slug TEXT,
                display_name TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                indexed_at TEXT NOT NULL
            )
            """)
        try execute(
            """
            CREATE TABLE IF NOT EXISTS chunks (
                id INTEGER PRIMARY KEY,
                document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
                ordinal INTEGER NOT NULL,
                text TEXT NOT NULL,
                UNIQUE(document_id, ordinal)
            )
            """)
        try execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(
                chunk_id INTEGER PRIMARY KEY,
                embedding float[384] distance_metric=cosine
            )
            """)
        try execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts USING fts5(
                chunk_id UNINDEXED,
                title,
                passage,
                tokenize = 'unicode61 remove_diacritics 2'
            )
            """)
    }

    private static func matchedTerms(_ terms: [String], in text: String) -> [String] {
        terms.filter { keywordRange(of: $0, in: text) != nil }
    }

    private static func passageSnippet(_ passage: String, around terms: [String]) -> String {
        let flattened = passage
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = flattened as NSString
        guard source.length > 280 else { return flattened }

        let match = terms.compactMap { keywordRange(of: $0, in: flattened) }
            .min { $0.location < $1.location }
        let center = match?.location ?? 0
        let rawStart = max(0, center - 80)
        let rawLength = min(280, source.length - rawStart)
        let safeRange = source.rangeOfComposedCharacterSequences(
            for: NSRange(location: rawStart, length: rawLength))
        var snippet = source.substring(with: safeRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if safeRange.location > 0 { snippet = "…" + snippet }
        if NSMaxRange(safeRange) < source.length { snippet += "…" }
        return snippet
    }

    private static func keywordRange(of term: String, in text: String) -> NSRange? {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        guard let expression = try? NSRegularExpression(
            pattern: "(?i)(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])")
        else { return nil }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return expression.firstMatch(in: text, range: range)?.range
    }

    private func metadata() throws -> [String: String] {
        var result: [String: String] = [:]
        try query("SELECT key, value FROM index_metadata") { statement in
            result[columnText(statement, 0)] = columnText(statement, 1)
        }
        return result
    }

    private enum Binding {
        case text(String)
        case integer(Int64)
        case blob(Data)
        case null
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? lastError()
            sqlite3_free(errorPointer)
            throw SearchError.database(message)
        }
    }

    private func run(_ sql: String, bindings: [Binding] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("Could not prepare statement")
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError("Statement failed")
        }
    }

    private func query(
        _ sql: String,
        bindings: [Binding] = [],
        row: (OpaquePointer) throws -> Void
    ) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else { throw databaseError("Could not prepare query") }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                try row(statement)
            } else if status == SQLITE_DONE {
                break
            } else {
                throw databaseError("Query failed")
            }
        }
    }

    private func bind(_ bindings: [Binding], to statement: OpaquePointer?) throws {
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch binding {
            case .text(let value):
                status = sqlite3_bind_text(statement, index, value, -1, Self.transient)
            case .integer(let value):
                status = sqlite3_bind_int64(statement, index, value)
            case .blob(let data):
                status = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), Self.transient)
                }
            case .null:
                status = sqlite3_bind_null(statement, index)
            }
            guard status == SQLITE_OK else { throw databaseError("Could not bind value") }
        }
    }

    private func databaseError(_ context: String) -> SearchError {
        SearchError.database("\(context): \(lastError())")
    }

    private func lastError() -> String {
        database.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? "Unknown SQLite error"
    }

    private func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
        sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
    }

    private static func vectorData(_ values: [Float]) -> Data {
        values.withUnsafeBufferPointer { buffer in
            Data(bytes: buffer.baseAddress!, count: buffer.count * MemoryLayout<Float>.size)
        }
    }
}
