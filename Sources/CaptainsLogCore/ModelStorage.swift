import Foundation

/// Storage operations shared by Settings and the CLI. Never remove a containing
/// directory: custom model folders can also contain unrelated files.
public enum ModelStorage {
    public enum Model: String, CaseIterable, Sendable, Identifiable {
        case whisper, qwen, embeddings
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .whisper: "Whisper · Speech to text"
            case .qwen: "Qwen · Text processing"
            case .embeddings: "E5 · Smart search"
            }
        }
    }

    public struct Usage: Sendable, Identifiable {
        public let model: Model
        public let bytes: Int64
        public let installed: Bool
        public var id: Model { model }
    }

    private static func targets(
        for model: Model, config: CaptainsLogConfig, embeddingURL: URL
    ) -> [URL] {
        switch model {
        case .whisper:
            guard let folder = config.whisperModelFolder, !folder.isEmpty else { return [] }
            let root = URL(fileURLWithPath: folder, isDirectory: true)
            let bundles = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc"]
                .map { root.appendingPathComponent($0) }
            guard bundles.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) else { return [] }
            return bundles + ["config.json", "generation_config.json"].map { root.appendingPathComponent($0) }
        case .qwen:
            return LLM.configuredModelFile(in: config.qwenModelFolder).map { [URL(fileURLWithPath: $0)] } ?? []
        case .embeddings:
            return [embeddingURL]
        }
    }

    public static func usage(
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        embeddingURL: URL = E5EmbeddingModel.modelURL()
    ) throws -> [Usage] {
        try Model.allCases.map { model in
            let files = targets(for: model, config: config, embeddingURL: embeddingURL)
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            return Usage(model: model, bytes: try files.reduce(0) { try $0 + diskSize($1) },
                         installed: !files.isEmpty)
        }
    }

    /// Counts allocated file bytes, including compiled Core ML bundle contents.
    private static func diskSize(_ url: URL) throws -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey,
                                      .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        func size(_ file: URL) throws -> Int64 {
            let values = try file.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, values.isSymbolicLink != true else { return 0 }
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        let rootValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isSymbolicLink != true else { return 0 }
        var total = try size(url)
        guard rootValues.isDirectory == true else { return total }
        var failure: Error?
        if let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: [],
            errorHandler: { _, error in failure = error; return false }
        ) {
            for case let file as URL in enumerator { total += try size(file) }
        }
        if let failure { throw failure }
        return total
    }

    public static func delete(
        _ model: Model,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        embeddingURL: URL = E5EmbeddingModel.modelURL()
    ) throws {
        // Retain model identifiers so the next download uses the user's selection.
        try CaptainsLogConfig.update { saved in
            switch model {
            case .whisper: saved.whisperModelFolder = nil
            case .qwen: saved.qwenModelFolder = nil
            case .embeddings: break
            }
        }
        for url in targets(for: model, config: config, embeddingURL: embeddingURL)
            where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
