import AppKit
import SwiftUI

/// Compact controls sharing the same recorder and processing queue as the main window.
public struct CaptainsLogMenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: appState.isRecording ? "record.circle.fill" : "mic")
                    .foregroundStyle(appState.isRecording ? Color.red : Color.primary)
                Text(recordingLabel)
                    .monospacedDigit()
                Spacer()
            }
            .font(.headline)

            Button(appState.isRecording ? "Stop Recording" : "Start Recording",
                   systemImage: appState.isRecording ? "stop.fill" : "record.circle") {
                if appState.isRecording {
                    appState.stopRecording()
                } else {
                    appState.startRecording()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.isRecording &&
                (appState.needsFirstRun || appState.updates.isInstalling || appState.updates.needsRestart))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if showsProcessing { ProgressView().controlSize(.small) }
                    Text(processingLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let error = appState.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .help(error)
                }
            }
            .frame(height: 60, alignment: .topLeading)

            Divider()
            Button("Open CaptainsLog", systemImage: "macwindow") {
                openWindow(id: "main")
                NSApplication.shared.unhide(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
                for window in NSApplication.shared.windows where window.canBecomeMain {
                    window.deminiaturize(nil)
                    window.makeKeyAndOrderFront(nil)
                }
            }
            Button("Quit CaptainsLog", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private var recordingLabel: String {
        guard appState.isRecording else { return "CaptainsLog" }
        let seconds = Int(appState.recordingDuration)
        let duration = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        return "\(appState.isRecordingPaused ? "Paused" : "Recording") · \(duration)"
    }

    private var showsProcessing: Bool {
        appState.isProcessing || appState.processingStem != nil
    }

    private var processingLabel: String {
        if showsProcessing {
            return appState.isRecording ? "Processing memos" : "Processing memos · \(appState.stage.rawValue)"
        }
        if appState.processing.hasScheduledWork { return "Memos waiting to process" }
        if appState.needsFirstRun { return "Open CaptainsLog to finish setup" }
        return "Ready to record"
    }
}
