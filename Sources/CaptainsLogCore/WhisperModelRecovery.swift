import Foundation

/// Cache recovery shared by CLI transcription and the native app. Healthy model
/// loads do not scan caches; compiled cache removal targets only the path reported
/// by the failed Whisper initialization, never unrelated temporary directories.
public enum WhisperModelRecovery {
    public static func prepareDownload(fileManager: FileManager = .default) {
        guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let root = caches.appendingPathComponent("CaptainsLog/models/whisper", isDirectory: true)
        removeDownloadMetadata(in: root, fileManager: fileManager)
    }

    public static func recover(from error: Error, fileManager: FileManager = .default) throws {
        prepareDownload(fileManager: fileManager)
        try removeReportedCompiledCache(from: error, temporaryRoot: fileManager.temporaryDirectory, fileManager: fileManager)
    }

    public static func removeDownloadMetadata(in root: URL, fileManager: FileManager = .default) {
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil, options: []) else { return }
        for case let url as URL in enumerator where url.lastPathComponent == "config.json.metadata" {
            try? fileManager.removeItem(at: url)
        }
    }

    static func removeReportedCompiledCache(
        from error: Error, temporaryRoot: URL, fileManager: FileManager = .default
    ) throws {
        let nsError = error as NSError
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            try removeReportedCompiledCache(from: underlying, temporaryRoot: temporaryRoot, fileManager: fileManager)
        }
        let reported = (nsError.userInfo[NSFilePathErrorKey] as? String).map { URL(fileURLWithPath: $0) }
            ?? nsError.userInfo[NSURLErrorKey] as? URL
        guard let reported, reported.lastPathComponent == "model.mlmodel.metadata" else { return }
        let compiled = reported.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let root = temporaryRoot.resolvingSymlinksInPath().standardizedFileURL
        guard compiled.pathExtension == "mlmodelc", compiled.path.hasPrefix(root.path + "/") else { return }
        if fileManager.fileExists(atPath: compiled.path) { try fileManager.removeItem(at: compiled) }
    }
}
