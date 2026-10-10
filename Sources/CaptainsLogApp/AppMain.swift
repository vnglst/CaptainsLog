import AppKit
import CaptainsLog
import SwiftUI

@main
struct CaptainsLogApp: App {
    @CLState private var appState: AppState
    @NSApplicationDelegateAdaptor(CaptainsLogAppDelegate.self) private var appDelegate

    #if DEBUG
    private let designFixture = ProcessInfo.processInfo.environment["CAPTAINSLOG_UI_FIXTURE"]
    #endif

    init() {
        #if DEBUG
        // Configure the isolated demo before AppState reads any saved configuration.
        if ProcessInfo.processInfo.environment["CAPTAINS_LOG_CONFIG_PATH"] == nil {
            do {
                try DemoMode.prepare()
            } catch {
                fatalError("Could not prepare the safe demo data: \(error)")
            }
        }
        #endif
        _appState = CLState(wrappedValue: AppState())
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
                .task {
                    if let designFixture {
                        appState.applyDesignFixture(named: designFixture)
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
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
