import Foundation

public struct CaptainsLogConfig: Codable {
    public static let defaultDataDirName = "Documents/CaptainsLog"
    public static let currentSchemaVersion = 1

    public static func resolveDataDir(
        explicit: String?, configured: String?, environment: String?
    ) -> String {
        explicit ?? configured ?? environment ?? "processed"
    }

    public var schemaVersion: Int
    public var dataDir: String?
    public var whisperModelFolder: String?
    public var whisperModel: String?
    public var qwenModelId: String?
    public var qwenModelFolder: String?
    public init(
        schemaVersion: Int = currentSchemaVersion,
        dataDir: String? = nil,
        whisperModelFolder: String? = nil,
        whisperModel: String? = nil,
        qwenModelId: String? = nil,
        qwenModelFolder: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.dataDir = dataDir
        self.whisperModelFolder = whisperModelFolder
        self.whisperModel = whisperModel
        self.qwenModelId = qwenModelId
        self.qwenModelFolder = qwenModelFolder
    }

    public func withDataDir(_ dataDir: String?) -> CaptainsLogConfig {
        var copy = self
        copy.dataDir = dataDir
        return copy
    }

    public func contextDir() -> URL {
        let base = dataDir ?? {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return "\(home)/\(Self.defaultDataDirName)"
        }()
        return URL(fileURLWithPath: base).appendingPathComponent("context")
    }

    public func personalInfoURL() -> URL {
        contextDir().appendingPathComponent("personal_info.md")
    }

    public func correctionsURL() -> URL {
        contextDir().appendingPathComponent("corrections.md")
    }

    public static func migrate(from oldVersion: Int, to config: inout CaptainsLogConfig) {
        switch oldVersion {
        case 0:
            // Schema v0 → v1: add schemaVersion field
            config.schemaVersion = currentSchemaVersion
            fallthrough
        default:
            break
        }
    }

    public func readPersonalInfo() -> String? {
        let url = personalInfoURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            Logger.config.warning("Failed to read personal context at \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    public func readCorrections() -> String? {
        let url = correctionsURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            Logger.config.warning("Failed to read corrections at \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    public func writePersonalInfo(_ text: String) throws {
        try FileManager.default.createDirectory(atPath: contextDir().path, withIntermediateDirectories: true)
        try text.write(to: personalInfoURL(), atomically: true, encoding: .utf8)
    }

    public func writeCorrections(_ text: String) throws {
        try FileManager.default.createDirectory(atPath: contextDir().path, withIntermediateDirectories: true)
        try text.write(to: correctionsURL(), atomically: true, encoding: .utf8)
    }

    public static var configURL: URL {
        if let override = ProcessInfo.processInfo.environment["CAPTAINS_LOG_CONFIG_PATH"],
            !override.isEmpty
        {
            return URL(fileURLWithPath: override)
        }
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "CaptainsLog/config.json")
    }

    public static func load() -> CaptainsLogConfig {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return CaptainsLogConfig()
        }
        do {
            let data = try Data(contentsOf: url)
            var config = try JSONDecoder().decode(CaptainsLogConfig.self, from: data)
            if config.schemaVersion < currentSchemaVersion {
                migrate(from: config.schemaVersion, to: &config)
                try? config.save()
            }
            validate(config: config)
            return config
        } catch {
            Logger.config.error("Failed to load config at \(url.path): \(error.localizedDescription)")
            return CaptainsLogConfig()
        }
    }

    private static func validate(config: CaptainsLogConfig) {
        if let dataDir = config.dataDir {
            if !FileManager.default.fileExists(atPath: dataDir) {
                Logger.config.warning("Configured dataDir does not exist: \(dataDir)")
            }
        }
    }

    public func save() throws {
        let url = Self.configURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }

    public static func update(_ mutator: (inout CaptainsLogConfig) -> Void) throws {
        var config = load()
        mutator(&config)
        try config.save()
    }
}
