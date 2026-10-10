import AppKit
import SwiftUI

/// Compact controls sharing the same recorder and processing queue as the main window.
public struct CaptainsLogMenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: FieldNotes.Spacing.m) {
            HStack(spacing: FieldNotes.Spacing.s) {
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FieldNotes.ColorToken.amber)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(FieldNotes.ColorToken.amber, lineWidth: 1))
                Text("CaptainsLog")
                    .font(FieldNotes.Typography.title(18))
            }

            Button {
                if appState.isRecording {
                    appState.stopRecording()
                } else {
                    appState.startRecording()
                }
            } label: {
                HStack(spacing: FieldNotes.Spacing.s) {
                    Image(systemName: appState.isRecording ? "stop.fill" : "record.circle")
                    Text(appState.isRecording ? "Stop recording" : "Start recording")
                        .font(FieldNotes.Typography.body(14, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(FieldNotes.ColorToken.canvas)
                .background(appState.isRecording ? FieldNotes.ColorToken.danger : FieldNotes.ColorToken.amber)
                .clipShape(RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!appState.isRecording &&
                (appState.needsFirstRun || appState.updates.isInstalling || appState.updates.needsRestart))

            VStack(alignment: .leading, spacing: FieldNotes.Spacing.xs) {
                if appState.isRecording {
                    HStack(spacing: FieldNotes.Spacing.xs) {
                        Circle().fill(FieldNotes.ColorToken.danger).frame(width: 7, height: 7)
                        Text(recordingLabel)
                            .font(FieldNotes.Typography.body(13, weight: .medium))
                            .monospacedDigit()
                    }
                    .foregroundStyle(FieldNotes.ColorToken.danger)
                }
                if !appState.isRecording || showsProcessing || appState.processing.hasScheduledWork {
                    HStack(spacing: FieldNotes.Spacing.xs) {
                        if showsProcessing {
                            ProgressView().controlSize(.small).tint(FieldNotes.ColorToken.amber)
                        }
                        Text(processingLabel)
                            .font(FieldNotes.Typography.body(12))
                            .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                            .lineLimit(2)
                    }
                }
                if let error = appState.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(FieldNotes.Typography.body(12))
                        .foregroundStyle(FieldNotes.ColorToken.danger)
                        .lineLimit(2)
                        .help(error)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(FieldNotes.ColorToken.stroke).frame(height: 1)
            VStack(alignment: .leading, spacing: FieldNotes.Spacing.xs) {
                menuAction("Open CaptainsLog", icon: "macwindow") {
                    openWindow(id: "main")
                    NSApplication.shared.unhide(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "CaptainsLog" }) {
                        window.deminiaturize(nil)
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                menuAction("Quit CaptainsLog", icon: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(FieldNotes.Spacing.m)
        .frame(width: 292)
        .foregroundStyle(FieldNotes.ColorToken.primaryText)
        .background(FieldNotes.ColorToken.surface)
        .preferredColorScheme(.dark)
    }

    private func menuAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(FieldNotes.Typography.body(13))
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
