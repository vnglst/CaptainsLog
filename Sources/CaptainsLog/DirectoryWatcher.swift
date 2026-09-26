import Dispatch
import Foundation

/// Watches pipeline directories for file system changes and triggers reloads.
@MainActor
@Observable
public final class DirectoryWatcher {
    static let reloadDebounceNanoseconds: UInt64 = 300_000_000

    private var dirWatchers: [DispatchSourceFileSystemObject] = []
    private var watchSetupTask: Task<Void, Never>?
    private var watchReloadTask: Task<Void, Never>?
    public var onReload: () -> Void

    public init(onReload: @escaping () -> Void = { }) {
        self.onReload = onReload
    }

    deinit {
        // DispatchSource cancellation must happen on the dispatch queue it was created on.
        // We rely on the source's cancelHandler (which calls close(fd)) for cleanup.
        // The dirWatchers array will be deallocated naturally.
    }

    public func startWatching(dataDir: String) {
        stopWatching()
        let subdirs = [
            "audio",
            ".pipeline/01-transcribed",
            ".pipeline/02-logs",
            ".pipeline/03-category",
            ".pipeline/04-rename",
            "logs",
            "logs/personal",
            "logs/professional",
            "logs/side-project",
        ]
        watchSetupTask = Task { [weak self] in
            let descriptors = await Task.detached(priority: .utility) {
                let fm = FileManager.default
                return subdirs.compactMap { subdir -> Int32? in
                    guard !Task.isCancelled else { return nil }
                    let path = "\(dataDir)/\(subdir)"
                    try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
                    let fd = open(path, O_EVTONLY)
                    return fd >= 0 ? fd : nil
                }
            }.value

            guard let self, !Task.isCancelled else {
                descriptors.forEach { close($0) }
                return
            }

            for fd in descriptors {
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd, eventMask: .write, queue: .main)
                source.setEventHandler { [weak self] in
                    Task { @MainActor [weak self] in self?.scheduleReload() }
                }
                source.setCancelHandler { close(fd) }
                source.resume()
                dirWatchers.append(source)
            }
            watchSetupTask = nil
        }
    }

    public func stopWatching() {
        watchSetupTask?.cancel()
        watchSetupTask = nil
        dirWatchers.forEach { $0.cancel() }
        dirWatchers = []
        watchReloadTask?.cancel()
        watchReloadTask = nil
    }

    /// Debounced reload to batch rapid file system events.
    public func scheduleReload() {
        watchReloadTask?.cancel()
        watchReloadTask = Task {
            try? await Task.sleep(nanoseconds: Self.reloadDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            onReload()
        }
    }
}
