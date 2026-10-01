import AppKit
import CaptainsLogCore
import SwiftUI

@MainActor
@Observable
public final class UpdateManager {
    public private(set) var isChecking = false
    public private(set) var isInstalling = false
    public private(set) var isRestarting = false
    public private(set) var needsRestart = false
    public private(set) var availableVersion: String?
    public private(set) var message = "Updates are installed through Homebrew."
    public private(set) var automaticUpdates: Bool
    private var lastCheck: Date?
    private var lastInstallAttempt: Date?
    public private(set) var automaticChecks: Bool
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    private let dependencies: Dependencies

    /// System operations can be replaced by isolated fixtures in integration tests.
    @MainActor
    struct Dependencies {
        let supported: () -> Bool
        let appPath: String
        let appVersion: String?
        let now: () -> Date
        let check: () async throws -> AppUpdater.Status
        let install: () async throws -> Void
        let relaunch: (@escaping @MainActor (Error?) -> Void) -> Void
        let terminate: () -> Void

        static var live: Self {
            let updater = AppUpdater()
            return Self(
                supported: {
                    Bundle.main.bundleIdentifier == "nl.koenvangilst.CaptainsLog"
                        && Bundle.main.bundleURL.pathExtension == "app"
                        && ProcessInfo.processInfo.environment["CAPTAINSLOG_DEMO_MODE"] != "1"
                        && ProcessInfo.processInfo.environment["CAPTAINSLOG_UI_FIXTURE"] == nil
                },
                appPath: Bundle.main.bundleURL.path,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                now: { Date() },
                check: { try await updater.check() },
                install: { try await updater.install(allowRunningProcess: ProcessInfo.processInfo.processIdentifier) },
                relaunch: { completion in
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.createsNewApplicationInstance = true
                    configuration.promptsUserIfNeeded = false
                    configuration.activates = NSApplication.shared.isActive
                    NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
                        Task { @MainActor in completion(error) }
                    }
                },
                terminate: { NSApplication.shared.terminate(nil) }
            )
        }
    }

    public convenience init() {
        self.init(dependencies: .live)
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let config = CaptainsLogConfig.load()
        automaticUpdates = config.automaticUpdates ?? true
        automaticChecks = config.automaticUpdateChecks ?? true
    }

    public var supported: Bool { dependencies.supported() }

    public func setAutomaticChecks(_ enabled: Bool) {
        do {
            try CaptainsLogConfig.update { $0.automaticUpdateChecks = enabled }
            automaticChecks = enabled
        } catch {
            message = "Could not save update preference: \(error.localizedDescription)"
        }
    }

    public func setAutomaticUpdates(_ enabled: Bool) {
        do {
            try CaptainsLogConfig.update { $0.automaticUpdates = enabled }
            automaticUpdates = enabled
        } catch {
            message = "Could not save update preference: \(error.localizedDescription)"
        }
    }

    /// One application-wide monitor, independent of how many windows are open.
    public func startMonitoring(canInstall: @escaping @MainActor () -> Bool) {
        guard supported, monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            await self?.monitor(canInstall: canInstall)
        }
    }

    private func monitor(canInstall: () -> Bool) async {
        while !Task.isCancelled {
            await runScheduledUpdate(canInstall: canInstall)
            do { try await Task.sleep(for: .seconds(30)) }
            catch { return }
        }
    }

    /// One iteration of the real monitor, also exercised without wall-clock waits.
    func runScheduledUpdate(canInstall: () -> Bool) async {
        guard supported else { return }
        if automaticChecks && UpdatePolicy.isDue(lastCheck, interval: 24 * 60 * 60, now: dependencies.now()) {
            await check()
        }
        if !Task.isCancelled && UpdatePolicy.shouldInstall(
            automaticChecks: automaticChecks, automaticUpdates: automaticUpdates,
            updateAvailable: availableVersion != nil, isIdle: canInstall(),
            lastAttempt: lastInstallAttempt, now: dependencies.now()
        ) {
            lastInstallAttempt = dependencies.now()
            await install()
            if needsRestart { restart() }
        }
    }

    public func check() async {
        guard supported, !isChecking, !isInstalling, !needsRestart else { return }
        lastCheck = dependencies.now()
        isChecking = true
        defer { isChecking = false }
        message = "Checking for updates…"
        do {
            let status = try await dependencies.check()
            guard status.appPath == dependencies.appPath else {
                message = "Updates are available for the app installed through Homebrew. Open that copy to update."
                availableVersion = nil
                return
            }
            availableVersion = status.updateAvailable ? status.availableVersion : nil
            let runningVersion = dependencies.appVersion
            needsRestart = !status.updateAvailable && runningVersion != status.installedVersion
            message = needsRestart ? "Update installed. Quit and reopen CaptainsLog."
                : status.updateAvailable ? "Version \(status.availableVersion) is available."
                : "CaptainsLog is up to date."
        } catch {
            availableVersion = nil
            message = error.localizedDescription
        }
    }

    public func restart() {
        guard needsRestart, !isRestarting else { return }
        isRestarting = true
        message = "Restarting CaptainsLog…"
        dependencies.relaunch { [weak self] error in
            guard let self else { return }
            self.isRestarting = false
            if let error {
                self.message = "Could not restart: \(error.localizedDescription). Quit and reopen CaptainsLog."
            } else {
                self.dependencies.terminate()
            }
        }
    }

    public func install() async {
        guard supported, availableVersion != nil, !isChecking, !isInstalling, !needsRestart else { return }
        isInstalling = true
        defer { isInstalling = false }
        message = "Installing update…"
        do {
            try await dependencies.install()
            needsRestart = true
            availableVersion = nil
            message = "Update installed. Quit and reopen CaptainsLog."
        } catch {
            message = error.localizedDescription
        }
    }
}
