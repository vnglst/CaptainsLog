import AppKit
import CaptainsLog
import CaptainsLogCore
import SwiftUI

@main
struct CaptainsLogApp: App {
    @CLState private var appState: AppState
    @NSApplicationDelegateAdaptor(CaptainsLogAppDelegate.self) private var appDelegate

    #if DEBUG
    private let designFixture = ProcessInfo.processInfo.environment["CAPTAINSLOG_UI_FIXTURE"]
    #endif

    init() {
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
            async let native: Void = NativeInferenceLifecycle.shared.stopAndWait()
            _ = await (processing, recording, native)
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
                            NSApplication.shared.terminate(nil)
                        } else { appState.batchResumePending() }
                    }
                    if let designFixture {
                        appState.applyDesignFixture(named: designFixture)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CaptainsLogPerformanceDecode")).receive(on: RunLoop.main)) { _ in
                    if ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_QUIT_ON_DECODE"] == "1" {
                        AppPerformanceTrace.mark("quit-request")
                        NSApplication.shared.terminate(nil)
                    }
                }
                #endif
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 840, height: 780)
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
    var prepareForTermination: (@MainActor () async -> Void)?
    private var isTerminating = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppPerformanceTrace.mark("delegate-terminate")
        guard !isTerminating else { return .terminateLater }
        isTerminating = true
        Task { @MainActor in
            await prepareForTermination?()
            // Native contexts have unwound before AppKit frees global Metal state.
            AppPerformanceTrace.mark("delegate-reply")
            sender.reply(toApplicationShouldTerminate: true)
        }
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
