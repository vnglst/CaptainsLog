import Foundation
@_exported import OSLog

extension Logger {
    private static let subsystem = "nl.koenvangilst.captainslog"

    static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    static let recorder = Logger(subsystem: subsystem, category: "recorder")
    static let transcriber = Logger(subsystem: subsystem, category: "transcriber")
    static let llm = Logger(subsystem: subsystem, category: "llm")
    static let config = Logger(subsystem: subsystem, category: "config")
}

/// Writes durable, human-readable diagnostics while also mirroring them to stdout.
///
/// OSLog is useful during development, but a per-recording trace survives an app
/// restart and can be inspected after an inference appears to stall.
public actor DiagnosticLog {
    public let path: String
    private let label: String

    public init(path: String, label: String = "diagnostic") {
        self.path = path
        self.label = label

        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
    }

    public func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(label) \(timestamp)] \(message)"
        guard let data = (line + "\n").data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)

        guard let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path))
        else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }
}
