import CaptainsLogCore
import Foundation
import SwiftUI

enum FirstRunPresentationPolicy {
    static func shouldPresent(hasLaunched: Bool, demoMode: Bool) -> Bool {
        !demoMode && !hasLaunched
    }
}

/// Manages app configuration, settings persistence, and user data directory selection.
@MainActor
@Observable
public final class ConfigManager {
    public var dataDir: String {
        didSet {
            scheduleConfigSave()
            reloadContextFiles()
        }
    }
    public var personalContext: String { didSet { scheduleContextSave() } }
    public var corrections: String { didSet { scheduleContextSave() } }
    public var whisperModel: String { didSet { scheduleConfigSave() } }
    public var whisperModelFolder: String { didSet { scheduleConfigSave() } }
    public var qwenModelId: String { didSet { scheduleConfigSave() } }
    public var qwenModelFolder: String { didSet { scheduleConfigSave() } }

    public var needsFirstRun: Bool {
        FirstRunPresentationPolicy.shouldPresent(
            hasLaunched: UserDefaults.standard.bool(forKey: "CaptainsLogHasLaunched"),
            demoMode: ProcessInfo.processInfo.environment["CAPTAINSLOG_DEMO_MODE"] == "1"
        )
    }

    private var configSaveTask: Task<Void, Never>?
    private var contextSaveTask: Task<Void, Never>?
    private var contextFilesLoaded: Bool
    private let dataDirectoryPicker: (URL?) -> URL?

    public convenience init(loadContextFiles: Bool = true) {
        self.init(
            loadContextFiles: loadContextFiles,
            dataDirectoryPicker: Self.presentDataDirectoryPicker
        )
    }

    init(
        loadContextFiles: Bool = true,
        dataDirectoryPicker: @escaping (URL?) -> URL?
    ) {
        self.dataDirectoryPicker = dataDirectoryPicker
        let cfg = CaptainsLogConfig.load()
        if let saved = cfg.dataDir {
            dataDir = saved
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            dataDir = "\(home)/Documents/CaptainsLog"
        }
        personalContext = loadContextFiles ? (cfg.readPersonalInfo() ?? "") : ""
        corrections = loadContextFiles ? (cfg.readCorrections() ?? "") : ""
        contextFilesLoaded = loadContextFiles
        whisperModel = cfg.whisperModel ?? ""
        whisperModelFolder = cfg.whisperModelFolder ?? ""
        qwenModelId = cfg.qwenModelId ?? ""
        qwenModelFolder = cfg.qwenModelFolder ?? ""
    }

    public func completeFirstRun() {
        guard ProcessInfo.processInfo.environment["CAPTAINSLOG_DEMO_MODE"] != "1" else { return }
        UserDefaults.standard.set(true, forKey: "CaptainsLogHasLaunched")
    }

    private func logWarning(_ message: String) {
        fputs("Warning: \(message)\n", stderr)
    }

    /// Trailing-edge debounce for config.json fields.
    private func scheduleConfigSave() {
        configSaveTask?.cancel()
        configSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            do {
                try CaptainsLogConfig.update { cfg in
                    cfg.dataDir = self.dataDir
                    cfg.whisperModel = self.whisperModel.isEmpty ? nil : self.whisperModel
                    cfg.whisperModelFolder = self.whisperModelFolder.isEmpty ? nil : self.whisperModelFolder
                    cfg.qwenModelId = self.qwenModelId.isEmpty ? nil : self.qwenModelId
                    cfg.qwenModelFolder = self.qwenModelFolder.isEmpty ? nil : self.qwenModelFolder
                }
            } catch {
                self.logWarning("Failed to save config: \(error.localizedDescription)")
            }
        }
    }

    /// Trailing-edge debounce for context markdown files.
    private func scheduleContextSave() {
        contextSaveTask?.cancel()
        contextSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            let cfg = CaptainsLogConfig().withDataDir(self.dataDir)
            do {
                try cfg.writePersonalInfo(self.personalContext)
                try cfg.writeCorrections(self.corrections)
            } catch {
                self.logWarning("Failed to save context files in \(cfg.contextDir().path): \(error.localizedDescription)")
            }
        }
    }

    /// Reload context fields from the markdown files at the current dataDir.
    public func reloadContextFiles() {
        let cfg = CaptainsLogConfig().withDataDir(dataDir)
        personalContext = cfg.readPersonalInfo() ?? ""
        corrections = cfg.readCorrections() ?? ""
        contextFilesLoaded = true
    }

    public func loadContextFilesIfNeeded() {
        guard !contextFilesLoaded else { return }
        reloadContextFiles()
    }

    public func pickWhisperModelFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose local Whisper model folder"
        panel.message = "Select a folder containing a WhisperKit-compatible model. Leave unset to fetch from Hugging Face."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            whisperModelFolder = url.path
        }
    }

    public func pickQwenModelFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose local text model folder"
        panel.message = "Select a folder containing Qwen 3.5 9B 4-bit GGUF (llama.cpp)."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            qwenModelFolder = url.path
        }
    }

    public func pickDataDirectory() {
        guard ProcessInfo.processInfo.environment["CAPTAINSLOG_DEMO_MODE"] != "1" else { return }
        let configuredPath = (dataDir as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let currentDirectory = URL(fileURLWithPath: configuredPath, isDirectory: true)
        let initialDirectory: URL? =
            FileManager.default.fileExists(atPath: currentDirectory.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
                ? currentDirectory
                : nil
        if let url = dataDirectoryPicker(initialDirectory) {
            dataDir = url.path
        }
    }

    private static func presentDataDirectoryPicker(initialDirectory: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose data folder"
        panel.message = "Select the folder where CaptainsLog stores audio, transcripts, and enriched logs."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = initialDirectory
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
