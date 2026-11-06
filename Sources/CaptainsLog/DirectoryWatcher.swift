import CaptainsLogCore
import CoreServices
import Foundation

/// Watches pipeline directories and their descendants for file system changes.
@MainActor
@Observable
public final class DirectoryWatcher {
    static let reloadDebounceNanoseconds: UInt64 = 300_000_000

    @MainActor
    private final class Callback {
        weak var watcher: DirectoryWatcher?
        init(_ watcher: DirectoryWatcher) { self.watcher = watcher }
    }

    private var stream: FSEventStreamRef?
    private var watchSetupTask: Task<Void, Never>?
    private var watchReloadTask: Task<Void, Never>?
    public var onReload: () -> Void

    public init(onReload: @escaping () -> Void = { }) {
        self.onReload = onReload
    }

    isolated deinit { stopWatching() }

    public func startWatching(dataDir: String) {
        stopWatching()
        watchSetupTask = Task.detached(priority: .utility) { [weak self] in
            let logs = "\(dataDir)/\(Pipeline.Directory.enriched.path)"
            let paths = Pipeline.Directory.allCases.map { "\(dataDir)/\($0.path)" }
            for path in paths + Categorize.Category.allCases.map({ "\(logs)/\($0.folderName)" }) {
                guard !Task.isCancelled else { return }
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            }
            await self?.startStream(paths)
        }
    }

    private func startStream(_ paths: [String]) {
        guard !Task.isCancelled else { return }
        let callback = Callback(self)
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(callback).toOpaque()
        context.retain = { _ = Unmanaged<Callback>.fromOpaque($0!).retain(); return $0 }
        context.release = { Unmanaged<Callback>.fromOpaque($0!).release() }
        guard let stream = FSEventStreamCreate(nil, { _, info, _, _, _, _ in
            let callback = Unmanaged<Callback>.fromOpaque(info!).takeUnretainedValue()
            MainActor.assumeIsolated { callback.watcher?.scheduleReload() }
        }, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.05,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer))
        else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        if FSEventStreamStart(stream) {
            self.stream = stream
        } else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    public func stopWatching() {
        watchSetupTask?.cancel()
        watchSetupTask = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        watchReloadTask?.cancel()
        watchReloadTask = nil
    }

    /// Debounced reload to batch rapid file system events.
    public func scheduleReload() {
        watchReloadTask?.cancel()
        watchReloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.reloadDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.onReload()
        }
    }
}
