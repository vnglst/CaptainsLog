import AppKit
import CaptainsLog
import CaptainsLogCore
import Darwin
import SwiftUI

@main
struct CaptainsLogApp: App {
    @CLState private var appState: AppState
    @NSApplicationDelegateAdaptor(CaptainsLogAppDelegate.self) private var appDelegate

    #if DEBUG
    private let designFixture = ProcessInfo.processInfo.environment["CAPTAINSLOG_UI_FIXTURE"]
    #endif

    init() {
        // Test bundles may be relaunched by automation or LaunchServices without
        // their inherited environment. Reject that launch before reading app state.
        if Bundle.main.bundleIdentifier?.hasPrefix("local.captainslog.") == true {
            guard let configPath = ProcessInfo.processInfo.environment["CAPTAINS_LOG_CONFIG_PATH"],
                  let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
                  let config = try? JSONDecoder().decode(CaptainsLogConfig.self, from: data),
                  config.schemaVersion == CaptainsLogConfig.currentSchemaVersion,
                  let dataDir = config.dataDir, !dataDir.isEmpty else {
                fputs("Isolated test bundles require a valid explicit CaptainsLog config and data directory.\n", stderr)
                exit(EX_CONFIG)
            }
        }
        let unmetRequirements = SystemRequirements.currentUnmetRequirements()
        if !unmetRequirements.isEmpty {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "This Mac cannot run CaptainsLog"
            alert.informativeText = unmetRequirements.joined(separator: "\n\n")
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            exit(EX_UNAVAILABLE)
        }
        AppPerformanceTrace.mark("app-init")
        #if DEBUG
        if ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_TRACE"] != nil {
            guard let configPath = ProcessInfo.processInfo.environment["CAPTAINS_LOG_CONFIG_PATH"],
                  let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
                  let config = try? JSONDecoder().decode(CaptainsLogConfig.self, from: data),
                  let dataDir = config.dataDir, !dataDir.isEmpty,
                  config.whisperModelFolder != nil, config.qwenModelFolder != nil else {
                fatalError("Performance checks require a valid isolated config and prepared model paths")
            }
        }
        // Configure the isolated demo before AppState reads any saved configuration.
        if ProcessInfo.processInfo.environment["CAPTAINS_LOG_CONFIG_PATH"] == nil {
            do {
                try DemoMode.prepare()
            } catch {
                fatalError("Could not prepare the safe demo data: \(error)")
            }
        }
        #endif
        let state = AppState()
        _appState = CLState(wrappedValue: state)
        appDelegate.prepareForTermination = {
            AppPerformanceTrace.mark("termination-preparing")
            async let processing: Void = state.processing.stopForTermination()
            async let recording: Void = state.recording.stopForTermination()
            async let search: Void = state.search.stopForTermination()
            async let native: Void = NativeInferenceLifecycle.shared.stopAndWait()
            _ = await (processing, recording, search, native)
            AppPerformanceTrace.mark("termination-drained")
        }
        // Required: SwiftPM executables have no .app bundle, so without this macOS won't let windows become key and keystrokes leak to the Finder.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

    }

    var body: some Scene {
        Window("CaptainsLog", id: "main") {
            FieldNotesContentView(
                bootstrap: {
                    #if DEBUG
                    return designFixture == nil
                    #else
                    return true
                    #endif
                }()
            )
                .environment(appState)
                #if DEBUG
                .background(MenuBarFixtureLauncher(enabled: designFixture?.hasPrefix("eval-menu") == true))
                .task {
                    AppPerformanceTrace.mark("view-ready")
                    if ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_PROCESS"] == "1" || ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_STARTUP_ONLY"] == "1" {
                        await appState.bootstrap()
                        while !AppPerformanceTrace.hasMarked("bootstrap-ready") || !appState.models.modelsReady { try? await Task.sleep(for: .milliseconds(20)) }
                        AppPerformanceTrace.mark("models-ready")
                        if ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_STARTUP_ONLY"] == "1" {
                            NotificationCenter.default.post(name: Notification.Name("CaptainsLogPerformanceDecode"), object: nil)
                        } else { appState.batchResumePending() }
                    }
                    if ProcessInfo.processInfo.environment["CAPTAINSLOG_SEARCH_QUIT_CHECK"] == "1" {
                        await appState.bootstrap()
                        while !AppPerformanceTrace.hasMarked("bootstrap-ready") || !appState.models.modelsReady {
                            try? await Task.sleep(for: .milliseconds(20))
                        }
                        appState.search.updateQuery("side project", dataDir: appState.config.dataDir)
                        while appState.search.state != .ready {
                            if case .error = appState.search.state { AppPerformanceTrace.mark("search-error"); return }
                            try? await Task.sleep(for: .milliseconds(20))
                        }
                        AppPerformanceTrace.mark("cached-search-ready")
                        try? await Task.sleep(for: .milliseconds(200))
                        NotificationCenter.default.post(name: Notification.Name("CaptainsLogPerformanceDecode"), object: nil)
                    }
                    if let designFixture {
                        appState.applyDesignFixture(named: designFixture)
                    }
                }
                .onChange(of: appState.stage) { _, stage in
                    if stage == .done && ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_FINISH_PIPELINE"] == "1" {
                        AppPerformanceTrace.mark("pipeline-complete")
                        NotificationCenter.default.post(name: Notification.Name("CaptainsLogPerformanceDecode"), object: nil)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CaptainsLogPerformanceDecode")).receive(on: RunLoop.main)) { _ in
                    if ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_QUIT_ON_LOAD"] == "1" || ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_QUIT_ON_DECODE"] == "1" || ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_STARTUP_ONLY"] == "1" || ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_FINISH_PIPELINE"] == "1" || ProcessInfo.processInfo.environment["CAPTAINSLOG_SEARCH_QUIT_CHECK"] == "1" {
                        AppPerformanceTrace.mark("quit-request")
                        NSApplication.shared.terminate(nil)
                    }
                }
                #endif
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 840, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Minimize to Menu Bar") {
                    NSApplication.shared.hide(nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }

        #if DEBUG
        Window("Synthetic Menu Bar Preview", id: "menu-preview") {
            VStack(alignment: .leading, spacing: 0) {
                Text("Synthetic menu preview · no microphone capture")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .top], 16)
                CaptainsLogMenuBarView()
                    .environment(appState)
            }
        }
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentSize)
        #endif

        MenuBarExtra {
            CaptainsLogMenuBarView()
                .environment(appState)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appState.isRecording ? "record.circle.fill" :
                    (appState.isProcessing ? "waveform" : "mic"))
                if appState.isRecording {
                    Text(String(format: "%02d:%02d", Int(appState.recordingDuration) / 60,
                                Int(appState.recordingDuration) % 60))
                        .monospacedDigit()
                }
            }
            .accessibilityLabel(appState.isRecording ? "CaptainsLog recording" : "CaptainsLog")
        }
        .menuBarExtraStyle(.window)

    }
}

@MainActor
private final class CaptainsLogAppDelegate: NSObject, NSApplicationDelegate {
    var prepareForTermination: (@MainActor @Sendable () async -> Void)?
    private let termination = AppTerminationCoordinator()
    private var isTerminating = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppPerformanceTrace.mark("delegate-terminate")
        guard !isTerminating else { return .terminateLater }
        isTerminating = true
        let prepare = prepareForTermination
        termination.begin(
            prepare: { await prepare?() },
            waitForAudio: {
                await Recorder.stopCaptureAndWait()
                AppPerformanceTrace.mark("termination-capture-closed")
            },
            onGraceful: {
                Task { @MainActor in
                    AppPerformanceTrace.mark("delegate-reply")
                    NSApplication.shared.reply(toApplicationShouldTerminate: true)
                }
            },
            onDeadline: {
                AppPerformanceTrace.mark("termination-bounded-exit")
                // Audio is finalized. Skip C++/Metal destructors while native
                // work is still unwinding; the OS releases process resources.
                _exit(EXIT_SUCCESS)
            }
        )
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

#if DEBUG
private struct MenuBarFixtureLauncher: View {
    @Environment(\.openWindow) private var openWindow
    let enabled: Bool

    var body: some View {
        Color.clear
            .task {
                if enabled { openWindow(id: "menu-preview") }
            }
    }
}
#endif
