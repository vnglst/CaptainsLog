import Foundation

/// Opt-in debug instrumentation for isolated native startup and shutdown checks.
public enum AppPerformanceTrace {
    private static let lock = NSLock()
    public static func mark(_ event: String) {
        #if DEBUG
        guard let path = ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_TRACE"] else { return }
        lock.withLock {
            let line = "\(ProcessInfo.processInfo.systemUptime) \(event)\n"
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil)
            }
            if let file = FileHandle(forWritingAtPath: path) {
                file.seekToEndOfFile()
                file.write(Data(line.utf8))
                try? file.close()
            }
        }
        #endif
    }
}
