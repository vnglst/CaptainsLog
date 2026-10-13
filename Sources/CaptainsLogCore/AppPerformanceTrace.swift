import Foundation
import Synchronization

/// Opt-in debug instrumentation for isolated native startup and shutdown checks.
public enum AppPerformanceTrace {
    private static let lock = NSLock()
    private static let decoded = Mutex(false)

    public static func firstDecode(_ event: String = "whisper-decode") {
        #if DEBUG
        let first = decoded.withLock { value in
            guard !value else { return false }; value = true; return true
        }
        guard first else { return }
        mark(event)
        if ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_QUIT_ON_DECODE"] == "1" {
            NotificationCenter.default.post(name: Notification.Name("CaptainsLogPerformanceDecode"), object: nil)
        }
        #endif
    }
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
