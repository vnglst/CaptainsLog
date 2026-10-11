import SwiftUI

struct FieldNotesProcessingOutputControls: View {
    let appState: AppState
    @CLState private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete intermediate processing results and finished logs to start again with your current settings. Original audio is kept. Then return to Logs and choose Process pending.")
                .font(FieldNotes.Typography.body(13))
                .foregroundStyle(FieldNotes.ColorToken.secondaryText)
            FieldNotesButton(title: "Delete all processing outputs…", kind: .secondary, isDisabled: !appState.canDeleteProcessingOutputs) {
                confirming = true
            }
            if let error = appState.processing.errorMessage {
                Text(error).font(FieldNotes.Typography.body(13)).foregroundStyle(.red)
            }
        }
        .alert("Delete all processing outputs?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) { }
            Button("Delete outputs", role: .destructive) { appState.deleteProcessingOutputs() }
        } message: {
            Text("All intermediate results, finished logs and previous reprocessing backups will be permanently deleted. Original source audio and your settings are kept. Return to Logs and choose Process pending to process the recordings again.")
        }
    }
}
