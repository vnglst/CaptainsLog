import SwiftUI

struct FieldNotesReprocessingControls: View {
    let appState: AppState
    @CLState private var confirming = false
    @CLState private var resumeSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apply your current settings to all saved recordings. This can take hours. Keep this Mac connected to power with its lid open; CaptainsLog prevents idle sleep while the run is active.")
                .font(FieldNotes.Typography.body(13))
                .foregroundStyle(FieldNotes.ColorToken.secondaryText)
            HStack {
                FieldNotesButton(title: "Reprocess all audio…", kind: .secondary, isDisabled: !appState.canReprocessAll || appState.reprocessingAudioCount == 0) {
                    resumeSaved = false
                    confirming = true
                }
                if appState.hasUnfinishedReprocessing {
                    FieldNotesButton(title: "Resume reprocessing…", kind: .secondary, isDisabled: !appState.canReprocessAll) {
                        resumeSaved = true
                        confirming = true
                    }
                }
                if appState.processing.isReprocessing {
                    FieldNotesButton(title: "Pause", kind: .secondary) { appState.pauseProcessing() }
                }
            }
            if let summary = appState.processing.reprocessingSummary {
                Text(summary).font(FieldNotes.Typography.metadata(12))
            }
            if let error = appState.processing.errorMessage {
                Text(error).font(FieldNotes.Typography.body(13)).foregroundStyle(.red)
            }
        }
        .alert(resumeSaved ? "Resume reprocessing?" : "Reprocess all recordings?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) { }
            Button(resumeSaved ? "Resume" : "Reprocess all", role: .destructive) { appState.reprocessAll(resumeSaved: resumeSaved) }
        } message: {
            Text("\(appState.reprocessingAudioCount) saved \(appState.reprocessingAudioCount == 1 ? "recording" : "recordings") will be processed sequentially using current settings. Generated notes will be replaced; previous notes will be backed up. Original audio is kept. You can pause and resume this run later.")
        }
    }
}
