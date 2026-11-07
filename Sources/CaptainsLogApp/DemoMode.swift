#if DEBUG
import CaptainsLogCore
import EvalFixtureLibrary
import Foundation

/// Seeds a writable, ignored copy of the repository's canonical evaluation fixtures.
/// Explicit CAPTAINS_LOG_CONFIG_PATH remains available for isolated integration runs.
enum DemoMode {
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let runtime = repository.appendingPathComponent("tmp/demo-runtime-eval", isDirectory: true)

    static func prepare() throws {
        let fm = FileManager.default
        let configURL = runtime.appendingPathComponent("config.json")
        let dataURL = runtime.appendingPathComponent("data", isDirectory: true)
        try fm.createDirectory(at: dataURL, withIntermediateDirectories: true)
        setenv("CAPTAINS_LOG_CONFIG_PATH", configURL.path, 1)
        setenv("CAPTAINSLOG_DEMO_MODE", "1", 1)

        var config = CaptainsLogConfig.load()
        // Enforce the demo directory on every launch, even if its local config
        // was edited or a previous run was interrupted during a settings save.
        config.dataDir = dataURL.path
        try config.save()
        try EvalFixtureLibrary.prepare(
            evalRoot: repository.appendingPathComponent("eval", isDirectory: true),
            dataRoot: dataURL
        )
    }
}
#endif
