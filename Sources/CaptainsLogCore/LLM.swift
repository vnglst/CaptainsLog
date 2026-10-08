import Foundation
import HuggingFace
import llama

private actor LLMInferenceGate {
    static let shared = LLMInferenceGate()

    func run<T>(_ work: () throws -> T) rethrows -> T {
        try work()
    }
}

public enum LLM {

    enum LLMError: LocalizedError, Equatable {
        case invalidModelContextSize(Int)
        case promptTooLarge(promptTokens: Int, modelContextTokens: Int)
        case requestedOutputTooLarge(promptTokens: Int, requestedTokens: Int, modelContextTokens: Int)
        case contextExhausted(promptTokens: Int, generatedTokens: Int, allocatedContextTokens: Int)
        case outputLimitReached(Int)

        var errorDescription: String? {
            switch self {
            case .invalidModelContextSize(let tokens):
                return "The model reported an invalid context size of \(tokens) tokens."
            case .promptTooLarge(let promptTokens, let modelContextTokens):
                return "The prompt contains \(promptTokens) tokens, exceeding the model's \(modelContextTokens)-token context window."
            case .requestedOutputTooLarge(let promptTokens, let requestedTokens, let modelContextTokens):
                return "The \(promptTokens)-token prompt plus \(requestedTokens) requested output tokens exceeds the model's \(modelContextTokens)-token context window."
            case .outputLimitReached(let tokens):
                return "Generation reached its \(tokens)-token output limit before finishing. The partial output was discarded."
            case .contextExhausted(let promptTokens, let generatedTokens, let allocatedContextTokens):
                return "Generation exhausted its allocated \(allocatedContextTokens)-token context after a \(promptTokens)-token prompt and \(generatedTokens) output tokens. The partial output was discarded."
            }
        }
    }

    public static let defaultModelId = "bartowski/Qwen_Qwen3.5-9B-GGUF"
    public static let ggufFilename = "Qwen_Qwen3.5-9B-Q4_K_M.gguf"

    /// Resolves the model ID to use: explicit arg > config > hardcoded default.
    public static func resolveModelId(_ explicit: String? = nil) -> String {
        explicit ?? CaptainsLogConfig.load().qwenModelId ?? defaultModelId
    }

    /// Returns the configured model file path.
    private static func resolveModelPath(modelId: String? = nil) -> String? {
        let cfg = CaptainsLogConfig.load()
        return configuredModelFile(in: cfg.qwenModelFolder)
    }

    /// Chooses the configured GGUF without loading llama.cpp or reading model contents.
    static func configuredModelFile(in folder: String?) -> String? {
        guard let folder, !folder.isEmpty, FileManager.default.fileExists(atPath: folder) else {
            return nil
        }

        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        let preferred = directory.appendingPathComponent(ggufFilename).path
        if FileManager.default.fileExists(atPath: preferred) {
            return preferred
        }

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folder) else {
            return nil
        }
        return files
            .filter { $0.hasSuffix(".gguf") }
            .sorted()
            .first
            .map { directory.appendingPathComponent($0).path }
    }

    private static func defaultModelsDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("CaptainsLog/models", isDirectory: true)
    }

    /// Downloads the GGUF model file from HuggingFace.
    public static func download(
        modelId: String? = nil,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws {
        let repo = resolveModelId(modelId)
        let filename = ggufFilename

        let modelsDir = defaultModelsDirectory()
        try FileManager.default.createDirectory(atPath: modelsDir.path, withIntermediateDirectories: true)

        let destination = modelsDir.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destination.path) {
            Logger.llm.info("Model already downloaded at \(destination.path)")
            try CaptainsLogConfig.update { $0.qwenModelFolder = modelsDir.path }
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            progressHandler(progress)
            return
        }

        Logger.llm.info("Downloading \(filename) from \(repo)...")

        let client = HubClient()
        let progress = Progress(totalUnitCount: 1)

        let observationTask = Task.detached {
            while !Task.isCancelled {
                progressHandler(progress)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        defer { observationTask.cancel() }

        guard let repoId = Repo.ID(rawValue: repo) else {
            throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid model ID: \(repo)"])
        }

        let downloadedURL = try await client.downloadFile(
            at: filename,
            from: repoId,
            to: destination,
            kind: .model,
            progress: progress
        )

        try CaptainsLogConfig.update { $0.qwenModelFolder = modelsDir.path }
        Logger.llm.info("Model downloaded to \(downloadedURL.path)")
    }

    /// Loads the model and returns a container for inference.
    public static func loadModel(modelId: String? = nil) async throws -> ModelContainer {
        if resolveModelPath(modelId: modelId) == nil {
            try await download(modelId: modelId)
        }
        guard let modelPath = resolveModelPath(modelId: modelId) else {
            throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model download did not produce a GGUF file."])
        }

        Logger.llm.info("Loading \(URL(fileURLWithPath: modelPath).lastPathComponent)...")
        
        // Verify the model file is readable
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model file not found: \(modelPath)"])
        }

        LlamaRuntime.initialize()

        var params = llama_model_default_params()
        params.n_gpu_layers = -1
        params.load_mode = LLAMA_LOAD_MODE_MMAP

        guard let model = llama_model_load_from_file(modelPath, params) else {
            throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load model: \(modelPath)"])
        }

        return ModelContainer(modelPath: modelPath, model: model)
    }

    /// Generates text using the model via llama.cpp's C API.
    public static func generate(
        container: ModelContainer,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 0,
        temperature: Float = 0.6,
        preventRepetition: Bool = false,
        seed: UInt32? = nil,
        diagnostic: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        Logger.llm.info("Running inference...")
        let start = Date()
        diagnostic?("LLM inference entered; preparing llama context.")
        
        let result = try await LLMInferenceGate.shared.run {
            try runInference(
                container: container,
                systemPrompt: systemPrompt,
                userPrompt: userMessage,
                maxTokens: maxTokens,
                temperature: temperature,
                preventRepetition: preventRepetition,
                seed: seed,
                diagnostic: diagnostic
            )
        }
        
        let elapsed = Date().timeIntervalSince(start)
        Logger.llm.info("Inference done in \(String(format: "%.1f", elapsed))s")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Warms up the model with a test inference.
    public static func warm(modelId: String? = nil) async throws {
        let container = try await loadModel(modelId: modelId)
        
        let systemPrompt = "You are a helpful assistant. Respond with exactly one short sentence."
        let userMessage = "Say hello."
        print("Output: ", terminator: "")
        let output = try await LLMInferenceGate.shared.run {
            try runInference(
                container: container,
                systemPrompt: systemPrompt,
                userPrompt: userMessage,
                maxTokens: 20,
                temperature: 0.6
            )
        }
        print(output)
    }

    /// Runs inference in-process through libllama.
    private static func runInference(
        container: ModelContainer,
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int,
        temperature: Float,
        preventRepetition: Bool = false,
        seed: UInt32? = nil,
        diagnostic: (@Sendable (String) -> Void)? = nil
    ) throws -> String {
        let prompt = makePrompt(systemPrompt: systemPrompt, userPrompt: userPrompt)
        let vocab = llama_model_get_vocab(container.model)
        let promptTokens = try tokenize(prompt, vocab: vocab, addSpecial: true, parseSpecial: true)
        let modelContextSize = Int(llama_model_n_ctx_train(container.model))
        let contextSize = try plannedContextSize(
            promptTokenCount: promptTokens.count,
            maxTokens: maxTokens,
            modelContextSize: modelContextSize
        )

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(contextSize)
        contextParams.n_batch = 512
        contextParams.n_ubatch = 512
        contextParams.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
        contextParams.n_threads_batch = contextParams.n_threads
        contextParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_AUTO

        guard let context = llama_init_from_model(container.model, contextParams) else {
            throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create llama context"])
        }
        defer { llama_free(context) }
        diagnostic?("Llama context created (allocated=\(contextParams.n_ctx), model maximum=\(modelContextSize), batch=\(contextParams.n_batch), threads=\(contextParams.n_threads)).")

        let allocatedContextSize = Int(llama_n_ctx(context))
        let availableGenerationTokens = allocatedContextSize - promptTokens.count
        let generationLimit = maxTokens > 0
            ? min(maxTokens, availableGenerationTokens)
            : availableGenerationTokens
        diagnostic?("Prompt tokenized: \(promptTokens.count) token(s); generation capacity=\(generationLimit).")

        try decode(tokens: promptTokens, context: context, batchSize: Int(contextParams.n_batch))
        diagnostic?("Prompt decoded; token generation started.")

        let sampler = makeSampler(temperature: temperature, vocab: vocab,
                                  preventRepetition: preventRepetition, seed: seed)
        defer { llama_sampler_free(sampler) }

        return try generateTokens(
            generationLimit: generationLimit,
            maxTokens: maxTokens,
            promptTokenCount: promptTokens.count,
            allocatedContextSize: allocatedContextSize,
            sampleToken: {
                // llama_sampler_sample already accepts the token into the chain.
                // Stateful repetition samplers must see each token exactly once.
                llama_sampler_sample(sampler, context, -1)
            },
            isEndToken: { llama_vocab_is_eog(vocab, $0) },
            tokenString: { tokenToString($0, vocab: vocab) },
            decodeToken: { try decode(tokens: [$0], context: context, batchSize: 1) },
            diagnostic: diagnostic
        )
    }

    /// Native sampling and decoding are injected so termination and partial-output
    /// rejection can be reproduced deterministically without loading a model.
    static func generateTokens(
        generationLimit: Int,
        maxTokens: Int,
        promptTokenCount: Int,
        allocatedContextSize: Int,
        sampleToken: () -> Int32,
        isEndToken: (Int32) -> Bool,
        tokenString: (Int32) -> String,
        decodeToken: (Int32) throws -> Void,
        diagnostic: (@Sendable (String) -> Void)? = nil
    ) throws -> String {
        var output = ""
        var reachedEndOfGeneration = false
        for tokenIndex in 0..<generationLimit {
            let token = sampleToken()

            if isEndToken(token) {
                reachedEndOfGeneration = true
                diagnostic?("Generation reached end-of-output after \(tokenIndex) token(s).")
                break
            }

            output += tokenString(token)
            try decodeToken(token)
            if (tokenIndex + 1).isMultiple(of: 256) {
                diagnostic?("Generation still running: \(tokenIndex + 1) token(s) decoded, \(output.utf8.count) output bytes.")
            }
        }

        // The final decoded token still has logits, even at the context boundary.
        // Accept an end token immediately after the budget, but never decode an
        // additional content token or return an unfinished response as success.
        if !reachedEndOfGeneration {
            reachedEndOfGeneration = isEndToken(sampleToken())
        }
        if !reachedEndOfGeneration {
            if maxTokens > 0 && generationLimit == maxTokens {
                throw LLMError.outputLimitReached(maxTokens)
            }
            throw LLMError.contextExhausted(
                promptTokens: promptTokenCount,
                generatedTokens: generationLimit,
                allocatedContextTokens: allocatedContextSize
            )
        }

        return output
    }

    /// Allocates only the context this request needs, bounded by the context length
    /// stored in the model. Unbounded generation reserves enough room to rewrite a
    /// prompt of the same token length; hitting the allocated boundary is reported as
    /// an error instead of returning a truncated result.
    static func plannedContextSize(
        promptTokenCount: Int,
        maxTokens: Int,
        modelContextSize: Int
    ) throws -> Int {
        guard modelContextSize > 0 else {
            throw LLMError.invalidModelContextSize(modelContextSize)
        }
        guard promptTokenCount < modelContextSize else {
            throw LLMError.promptTooLarge(
                promptTokens: promptTokenCount,
                modelContextTokens: modelContextSize
            )
        }

        let requestedGenerationTokens = maxTokens > 0 ? maxTokens : promptTokenCount
        if maxTokens > 0 && requestedGenerationTokens > modelContextSize - promptTokenCount {
            throw LLMError.requestedOutputTooLarge(
                promptTokens: promptTokenCount,
                requestedTokens: requestedGenerationTokens,
                modelContextTokens: modelContextSize
            )
        }

        let requiredTokens = promptTokenCount.addingReportingOverflow(requestedGenerationTokens)
        let unpaddedSize = requiredTokens.overflow
            ? modelContextSize
            : min(requiredTokens.partialValue, modelContextSize)
        let padding = 256
        let paddedSize = ((unpaddedSize + padding - 1) / padding) * padding
        return min(paddedSize, modelContextSize)
    }

    private static func makePrompt(systemPrompt: String, userPrompt: String) -> String {
        """
        <|im_start|>system
        \(systemPrompt)<|im_end|>
        <|im_start|>user
        \(userPrompt)<|im_end|>
        <|im_start|>assistant
        <think>

        </think>

        """
    }

    private static func tokenize(_ text: String, vocab: OpaquePointer?, addSpecial: Bool, parseSpecial: Bool) throws -> [llama_token] {
        try text.withCString { cString in
            let length = Int32(strlen(cString))
            let required = llama_tokenize(vocab, cString, length, nil, 0, addSpecial, parseSpecial)
            let capacity = required < 0 ? Int(-required) : Int(required)
            var tokens = [llama_token](repeating: 0, count: capacity)
            let count = llama_tokenize(vocab, cString, length, &tokens, Int32(tokens.count), addSpecial, parseSpecial)
            guard count >= 0 else {
                throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to tokenize prompt"])
            }
            tokens.removeSubrange(Int(count)..<tokens.count)
            return tokens
        }
    }

    private static func decode(tokens: [llama_token], context: OpaquePointer, batchSize: Int) throws {
        var offset = 0
        while offset < tokens.count {
            let count = min(batchSize, tokens.count - offset)
            var chunk = Array(tokens[offset..<(offset + count)])
            let result = chunk.withUnsafeMutableBufferPointer { buffer in
                let batch = llama_batch_get_one(buffer.baseAddress, Int32(buffer.count))
                return llama_decode(context, batch)
            }
            guard result == 0 else {
                throw NSError(domain: "LLM", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "llama_decode failed with code \(result)"])
            }
            offset += count
        }
    }

    private static func makeSampler(
        temperature: Float,
        vocab: OpaquePointer?,
        preventRepetition: Bool,
        seed: UInt32?
    ) -> UnsafeMutablePointer<llama_sampler> {
        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())!
        if preventRepetition {
            // DRY penalizes repeated sequences rather than every reused token.
            // Allow short YAML syntax to recur; keep newlines in the history so
            // a repeated list item is still detected across line boundaries.
            llama_sampler_chain_add(chain,
                llama_sampler_init_dry(vocab, 0.8, 1.75, 4, 512, nil, 0))
        }
        if temperature <= 0 {
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        } else {
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.9, 1))
            llama_sampler_chain_add(chain, llama_sampler_init_temp(temperature))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(seed ?? LLAMA_DEFAULT_SEED))
        }
        return chain
    }

    private static func tokenToString(_ token: llama_token, vocab: OpaquePointer?) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if count < 0 {
            buffer = [CChar](repeating: 0, count: Int(-count))
            let retryCount = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
            guard retryCount > 0 else { return "" }
            return String(decoding: buffer.prefix(Int(retryCount)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        guard count > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

/// Container to hold the model path for reuse across pipeline stages.
public final class ModelContainer: @unchecked Sendable {
    let modelPath: String
    let model: OpaquePointer

    init(modelPath: String, model: OpaquePointer) {
        self.modelPath = modelPath
        self.model = model
    }

    deinit {
        llama_model_free(model)
    }
}
