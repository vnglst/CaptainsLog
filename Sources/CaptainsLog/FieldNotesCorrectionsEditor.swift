import SwiftUI

struct FieldNotesCorrectionsEditor: View {
    @Binding var text: String
    @CLState private var document = CorrectionDocument("")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($document.entries) { $entry in
                HStack(alignment: .bottom, spacing: 10) {
                    spellingField("Misspelling", text: $entry.misspelling)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                        .padding(.bottom, 10)
                    spellingField("Correct spelling", text: $entry.spelling)
                    Button {
                        document.remove(entry.id)
                        text = document.text
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 32, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove correction for \(entry.misspelling)")
                }
            }
            FieldNotesButton(title: "Add correction", kind: .secondary) {
                document.add()
                text = document.text
            }
            if !document.preservedText.isEmpty {
                Text("Existing correction notes (preserved)")
                    .font(FieldNotes.Typography.metadata(11))
                    .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                Text(document.preservedText)
                    .font(FieldNotes.Typography.body(13))
                    .textSelection(.enabled)
            }
        }
        .onAppear { document = CorrectionDocument(text) }
        .onChange(of: text) { _, value in
            if value != document.text { document = CorrectionDocument(value) }
        }
        .onChange(of: document.text) { _, value in text = value }
    }

    private func spellingField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(FieldNotes.Typography.metadata(11))
                .foregroundStyle(FieldNotes.ColorToken.secondaryText)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(FieldNotes.Typography.body(13))
                .padding(10)
                .background(FieldNotes.ColorToken.canvas, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(FieldNotes.ColorToken.stroke))
                .accessibilityLabel(label)
        }
    }
}
