import Foundation

public enum CaptainsLogFileSystemError: LocalizedError {
    case insufficientDiskSpace(path: String, availableBytes: Int64, requiredBytes: Int64)
    case writeFailed(path: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .insufficientDiskSpace(let path, let availableBytes, let requiredBytes):
            return """
            Not enough free disk space to continue.

            CaptainsLog needs at least \(Self.formatBytes(requiredBytes)) free before transcription because Whisper/CoreML may write temporary files. The volume containing \(path) has \(Self.formatBytes(availableBytes)) available.

            Free disk space and retry this recording from the transcribing stage.
            """
        case .writeFailed(let path, let underlying):
            if Self.isNoSpaceError(underlying) {
                return """
                Could not write \(path): the disk is full.

                Free disk space and retry this recording from the current stage.
                """
            }
            return "Could not write \(path): \(underlying.localizedDescription)"
        }
    }

    private static func isNoSpaceError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == ENOSPC {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.domain == NSPOSIXErrorDomain && underlying.code == ENOSPC
        }
        let description = nsError.localizedDescription.lowercased()
        return description.contains("no space left") || description.contains("disk is full")
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

public enum FileSystemGuard {
    public static let minimumFreeBytesBeforeTranscription: Int64 = 5_000_000_000

    public static func requireFreeSpaceForTranscription(paths: [String]) throws {
        for path in paths {
            try requireFreeSpace(
                containing: URL(fileURLWithPath: path),
                minimumBytes: minimumFreeBytesBeforeTranscription
            )
        }
    }

    public static func writeText(_ text: String, to path: String) throws {
        do {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw CaptainsLogFileSystemError.writeFailed(path: path, underlying: error)
        }
    }

    static func availableBytes(containing url: URL) -> Int64? {
        guard let existingURL = existingAncestor(for: url) else { return nil }
        let values = try? existingURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ])
        if let important = values?.volumeAvailableCapacityForImportantUsage {
            return important
        }
        if let capacity = values?.volumeAvailableCapacity {
            return Int64(capacity)
        }
        return nil
    }

    private static func requireFreeSpace(containing url: URL, minimumBytes: Int64) throws {
        guard let availableBytes = availableBytes(containing: url) else { return }
        guard availableBytes >= minimumBytes else {
            throw CaptainsLogFileSystemError.insufficientDiskSpace(
                path: url.path,
                availableBytes: availableBytes,
                requiredBytes: minimumBytes
            )
        }
    }

    private static func existingAncestor(for url: URL) -> URL? {
        var current = url
        let fm = FileManager.default

        while !fm.fileExists(atPath: current.path) {
            let parent = current.deletingLastPathComponent()
            guard parent.path != current.path else { return nil }
            current = parent
        }

        return current
    }
}
