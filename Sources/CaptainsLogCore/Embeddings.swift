import CLlama
import CryptoKit
import Foundation
import HuggingFace

private let llamaLogCallback: @convention(c) (
    ggml_log_level, UnsafePointer<CChar>?, UnsafeMutableRawPointer?
) -> Void = { level, message, _ in
    guard level == GGML_LOG_LEVEL_ERROR, let message else { return }
    Logger.llm.error("llama.cpp: \(String(cString: message), privacy: .public)")
}

enum LlamaRuntime {
    private static let initialized: Void = {
        llama_log_set(llamaLogCallback, nil)
        llama_backend_init()
    }()

    static func initialize() {
        _ = initialized
    }
}

public enum EmbeddingInputKind: Sendable {
    case query
    case passage

    fileprivate var prefix: String {
        switch self {
        case .query: "query: "
        case .passage: "passage: "
        }
    }
}

public protocol TextEmbeddingModel: Sendable {
    var identity: String { get async }
    func embed(_ text: String, as kind: EmbeddingInputKind) async throws -> [Float]
    func chunks(for text: String, maxTokens: Int, overlap: Int) async throws -> [String]
}

public actor E5EmbeddingModel: TextEmbeddingModel {
    public static let repository = "TwinSunsLLC/multilingual-e5-small-gguf"
    public static let revision = "b6cac9615d4ecce28d7f22539b7322d695fc2886"
    public static let filename = "multilingual-e5-small-q8_0.gguf"
    public static let expectedSHA256 = "e011debc1208e31bf7b6aebee2d9fc8bd2ca11694a77ed66ac9d0c9d0a877c93"
    public static let dimension = 384
    public static let maximumTokens = 511

    public nonisolated var identity: String {
        "\(Self.repository)@\(Self.revision):\(Self.expectedSHA256)"
    }

    private let container: ModelContainer

    private init(container: ModelContainer) {
        self.container = container
    }

    public static func modelURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("CaptainsLog/models/embeddings", isDirectory: true)
            .appendingPathComponent(filename)
    }

    public static func isDownloaded() -> Bool {
        FileManager.default.fileExists(atPath: modelURL().path)
    }

    public static func download(
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws {
        let destination = modelURL()
        if FileManager.default.fileExists(atPath: destination.path),
           try sha256(of: destination) == expectedSHA256
        {
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            progressHandler(progress)
            return
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        guard let repo = Repo.ID(rawValue: repository) else {
            throw SearchError.invalidModelRepository(repository)
        }

        let progress = Progress(totalUnitCount: 1)
        let observationTask = Task.detached {
            while !Task.isCancelled {
                progressHandler(progress)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        defer { observationTask.cancel() }

        let downloaded = try await HubClient().downloadFile(
            at: filename,
            from: repo,
            to: destination,
            kind: .model,
            revision: revision,
            progress: progress
        )

        let digest = try sha256(of: downloaded)
        guard digest == expectedSHA256 else {
            try? FileManager.default.removeItem(at: downloaded)
            throw SearchError.modelChecksumMismatch(expected: expectedSHA256, actual: digest)
        }
        progress.completedUnitCount = progress.totalUnitCount
        progressHandler(progress)
    }

    public static func load(
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> E5EmbeddingModel {
        try await download(progressHandler: progressHandler)
        let url = modelURL()
        LlamaRuntime.initialize()

        var parameters = llama_model_default_params()
        parameters.n_gpu_layers = -1
        parameters.load_mode = LLAMA_LOAD_MODE_MMAP
        guard let model = llama_model_load_from_file(url.path, parameters) else {
            throw SearchError.modelLoadFailed(url.path)
        }
        let dimension = Int(llama_model_n_embd(model))
        guard dimension == Self.dimension else {
            llama_model_free(model)
            throw SearchError.invalidEmbeddingDimension(expected: Self.dimension, actual: dimension)
        }
        return E5EmbeddingModel(container: ModelContainer(modelPath: url.path, model: model))
    }

    public func embed(_ text: String, as kind: EmbeddingInputKind) throws -> [Float] {
        let input = kind.prefix + text
        let vocabulary = llama_model_get_vocab(container.model)
        let tokens = try tokenize(input, vocabulary: vocabulary, addSpecial: true)
        guard !tokens.isEmpty, tokens.count <= Self.maximumTokens else {
            throw SearchError.embeddingInputTooLarge(tokens: tokens.count, maximum: Self.maximumTokens)
        }

        var parameters = llama_context_default_params()
        parameters.n_ctx = UInt32(Self.maximumTokens)
        parameters.n_batch = UInt32(Self.maximumTokens)
        parameters.n_ubatch = UInt32(Self.maximumTokens)
        parameters.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
        parameters.n_threads_batch = parameters.n_threads
        parameters.pooling_type = LLAMA_POOLING_TYPE_MEAN
        parameters.attention_type = LLAMA_ATTENTION_TYPE_NON_CAUSAL
        parameters.embeddings = true
        parameters.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_AUTO

        guard let context = llama_init_from_model(container.model, parameters) else {
            throw SearchError.embeddingContextCreationFailed
        }
        defer { llama_free(context) }

        var mutableTokens = tokens
        let decodeResult = mutableTokens.withUnsafeMutableBufferPointer { buffer in
            let batch = llama_batch_get_one(buffer.baseAddress, Int32(buffer.count))
            return llama_decode(context, batch)
        }
        guard decodeResult == 0 else {
            throw SearchError.embeddingDecodeFailed(Int(decodeResult))
        }

        guard let pointer = llama_get_embeddings_seq(context, 0) else {
            throw SearchError.embeddingUnavailable
        }
        let raw = Array(UnsafeBufferPointer(start: pointer, count: Self.dimension))
        let magnitude = sqrt(raw.reduce(Float.zero) { $0 + $1 * $1 })
        guard magnitude.isFinite, magnitude > 0 else {
            throw SearchError.invalidEmbeddingMagnitude
        }
        return raw.map { $0 / magnitude }
    }

    public func chunks(for text: String, maxTokens: Int = 384, overlap: Int = 48) throws -> [String] {
        precondition(maxTokens > 0)
        precondition(overlap >= 0 && overlap < maxTokens)
        let vocabulary = llama_model_get_vocab(container.model)
        let tokens = try tokenize(text, vocabulary: vocabulary, addSpecial: false)
        guard !tokens.isEmpty else { return [] }

        var result: [String] = []
        var start = 0
        while start < tokens.count {
            let end = min(start + maxTokens, tokens.count)
            let chunk = tokens[start..<end]
                .map { tokenToString($0, vocabulary: vocabulary) }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty { result.append(chunk) }
            if end == tokens.count { break }
            start = end - overlap
        }
        return result
    }

    private func tokenize(
        _ text: String, vocabulary: OpaquePointer?, addSpecial: Bool
    ) throws -> [llama_token] {
        try text.withCString { cString in
            let length = Int32(strlen(cString))
            let required = llama_tokenize(
                vocabulary, cString, length, nil, 0, addSpecial, false)
            let capacity = required < 0 ? Int(-required) : Int(required)
            var tokens = [llama_token](repeating: 0, count: capacity)
            let count = llama_tokenize(
                vocabulary, cString, length, &tokens, Int32(tokens.count), addSpecial, false)
            guard count >= 0 else { throw SearchError.tokenizationFailed }
            tokens.removeSubrange(Int(count)..<tokens.count)
            return tokens
        }
    }

    private func tokenToString(_ token: llama_token, vocabulary: OpaquePointer?) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        var count = llama_token_to_piece(
            vocabulary, token, &buffer, Int32(buffer.count), 0, false)
        if count < 0 {
            buffer = [CChar](repeating: 0, count: Int(-count))
            count = llama_token_to_piece(
                vocabulary, token, &buffer, Int32(buffer.count), 0, false)
        }
        guard count > 0 else { return "" }
        return String(
            decoding: buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public enum SearchError: LocalizedError, Equatable {
    case invalidModelRepository(String)
    case modelChecksumMismatch(expected: String, actual: String)
    case modelLoadFailed(String)
    case invalidEmbeddingDimension(expected: Int, actual: Int)
    case embeddingInputTooLarge(tokens: Int, maximum: Int)
    case embeddingContextCreationFailed
    case embeddingDecodeFailed(Int)
    case embeddingUnavailable
    case invalidEmbeddingMagnitude
    case tokenizationFailed
    case database(String)
    case invalidIndexMetadata

    public var errorDescription: String? {
        switch self {
        case .invalidModelRepository(let repository):
            "Invalid embedding model repository: \(repository)"
        case .modelChecksumMismatch(let expected, let actual):
            "Embedding model checksum mismatch (expected \(expected), got \(actual))."
        case .modelLoadFailed(let path):
            "Could not load the embedding model at \(path)."
        case .invalidEmbeddingDimension(let expected, let actual):
            "Embedding dimension mismatch (expected \(expected), got \(actual))."
        case .embeddingInputTooLarge(let tokens, let maximum):
            "Embedding input has \(tokens) tokens; the model supports \(maximum)."
        case .embeddingContextCreationFailed:
            "Could not create the embedding inference context."
        case .embeddingDecodeFailed(let code):
            "Embedding inference failed with code \(code)."
        case .embeddingUnavailable:
            "The embedding model returned no vector."
        case .invalidEmbeddingMagnitude:
            "The embedding model returned an invalid vector."
        case .tokenizationFailed:
            "Could not tokenize text for semantic search."
        case .database(let message):
            "Search index error: \(message)"
        case .invalidIndexMetadata:
            "The search index metadata is invalid and must be rebuilt."
        }
    }
}
