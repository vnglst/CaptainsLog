import CaptainsLogCore
import SwiftUI

/// Shared by Settings and the initial setup, without touching stored entries.
struct FieldNotesCategoriesEditor: View {
    @Environment(AppState.self) private var appState
    @CLState private var newCategory = ""

    private var candidate: Categorize.Category? { Categorize.Category(name: newCategory) }
    private var canAdd: Bool {
        guard let candidate else { return false }
        return !appState.config.categories.contains(candidate.rawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(appState.config.categories, id: \.self) { raw in
                        HStack {
                            Text(Categorize.Category(rawValue: raw)?.displayName ?? raw)
                                .font(FieldNotes.Typography.body(13))
                            Spacer()
                            Button {
                                appState.config.categories.removeAll { $0 == raw }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(Categorize.Category(rawValue: raw)?.displayName ?? raw) category")
                        }
                        .padding(8)
                        .background(FieldNotes.ColorToken.canvas, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(height: min(CGFloat(appState.config.categories.count) * 39, 156))
            HStack {
                TextField("New category", text: $newCategory)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCategory)
                    .accessibilityLabel("New category")
                FieldNotesButton(title: "Add", kind: .secondary, isDisabled: !canAdd, action: addCategory)
            }
            if appState.config.categories.isEmpty {
                Text("Add a category before processing recordings.")
                    .font(FieldNotes.Typography.body(12))
                    .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(FieldNotes.ColorToken.primaryText)
    }

    private func addCategory() {
        guard canAdd, let candidate else { return }
        appState.config.categories.append(candidate.rawValue)
        newCategory = ""
    }
}
