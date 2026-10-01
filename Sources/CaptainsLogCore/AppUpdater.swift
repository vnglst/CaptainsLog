import AppKit
import Foundation

/// Uses the same checksum-verified Homebrew cask as the documented install path.
public struct AppUpdater: Sendable {
    public static let cask = "vnglst/captainslog/captainslog"
    public let brewURL: URL

    public init(brewURL: URL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")) {
        self.brewURL = brewURL
    }

    public struct Status: Equatable, Sendable {
        public let installedVersion: String
        public let availableVersion: String
        public let appPath: String
        public let updateAvailable: Bool
    }

    public enum UpdateError: LocalizedError {
        case homebrewMissing, notInstalled, invalidMetadata, appRunning, commandFailed(String)

        public var errorDescription: String? {
            switch self {
            case .homebrewMissing: "Auto-updates require Homebrew at /opt/homebrew/bin/brew."
            case .notInstalled: "Auto-updates require an installation through the CaptainsLog Homebrew cask."
            case .appRunning: "Quit CaptainsLog before updating from the CLI."
            case .invalidMetadata: "Homebrew returned invalid CaptainsLog update information."
            case .commandFailed(let message): "Homebrew update failed: \(message)"
            }
        }
    }

    public static func parseStatus(_ data: Data) throws -> Status {
        struct Metadata: Decodable {
            struct Cask: Decodable {
                struct Artifact: Decodable {
                    let app: [String]?
                    let target: String?
                }
                let artifacts: [Artifact]
                let full_token: String
                let installed: String?
                let version: String
                let outdated: Bool
            }
            let casks: [Cask]
        }
        guard let metadata = try? JSONDecoder().decode(Metadata.self, from: data),
            let cask = metadata.casks.first(where: { $0.full_token == Self.cask }),
            !cask.version.isEmpty,
            let appPath = cask.artifacts.first(where: { $0.app == ["CaptainsLog.app"] })?.target
        else { throw UpdateError.invalidMetadata }
        guard let installed = cask.installed, !installed.isEmpty else {
            throw UpdateError.notInstalled
        }
        return Status(installedVersion: installed, availableVersion: cask.version, appPath: appPath,
                      updateAvailable: cask.outdated)
    }

    public func check(refresh: Bool = true) async throws -> Status {
        // Confirm ownership before refreshing taps or offering to replace an app.
        _ = try Self.parseStatus(await run(["info", "--json=v2", "--cask", Self.cask]))
        if refresh { _ = try await run(["update"]) }
        return try Self.parseStatus(await run(["info", "--json=v2", "--cask", Self.cask]))
    }

    public func install(allowRunningProcess: Int32? = nil) async throws {
        let status = try await check()
        guard status.updateAvailable else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "nl.koenvangilst.CaptainsLog")
        guard running.allSatisfy({ $0.processIdentifier == allowRunningProcess }) else {
            throw UpdateError.appRunning
        }
        // Keep the current process alive until the GUI can report success. The
        // app blocks new recordings and processing until it is restarted.
        _ = try await run(["upgrade", "--cask", "--no-quit", "--require-sha", Self.cask])
        let installed = try await check(refresh: false)
        guard !installed.updateAvailable else {
            throw UpdateError.commandFailed("The new version was not installed. Try again from Terminal.")
        }
    }

    private func run(_ arguments: [String]) async throws -> Data {
        let executable = brewURL
        return try await Task.detached(priority: .utility) {
            guard FileManager.default.isExecutableFile(atPath: executable.path) else {
                throw UpdateError.homebrewMissing
            }
            // Files avoid pipe buffer deadlocks for verbose downloads. Keep all
            // output private and remove it after each command.
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("CaptainsLogUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: root) }
            let outputURL = root.appendingPathComponent("stdout")
            let errorURL = root.appendingPathComponent("stderr")
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            FileManager.default.createFile(atPath: errorURL.path, contents: nil)
            let output = try FileHandle(forWritingTo: outputURL)
            let errors = try FileHandle(forWritingTo: errorURL)
            defer { try? output.close(); try? errors.close() }
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
            environment["HOMEBREW_NO_ANALYTICS"] = "1"
            environment["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
            environment["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = environment
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = errors
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let message = String(decoding: try Data(contentsOf: errorURL), as: UTF8.self)
                throw UpdateError.commandFailed(message.isEmpty ? "Exit code \(process.terminationStatus)" : message)
            }
            return try Data(contentsOf: outputURL)
        }.value
    }
}

/// Scheduling rules shared by the app and model-free CLI tests.
public enum UpdatePolicy {
    public static func isDue(_ lastRun: Date?, interval: TimeInterval, now: Date = Date()) -> Bool {
        lastRun.map { now.timeIntervalSince($0) >= interval } ?? true
    }

    public static func shouldInstall(
        automaticChecks: Bool, automaticUpdates: Bool, updateAvailable: Bool,
        isIdle: Bool, lastAttempt: Date?, now: Date = Date()
    ) -> Bool {
        automaticChecks && automaticUpdates && updateAvailable && isIdle
            && isDue(lastAttempt, interval: 60 * 60, now: now)
    }
}
