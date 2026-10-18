import CaptainsLogCore
import SwiftUI

/// Shared by Context and the initial setup, without touching stored entries.
struct FieldNotesCategoriesEditor: View {
    @Environment(AppState.self) private var appState
    @CLState private var newCategory = ""
    @GestureState private var drag: (category: String, location: CGPoint)?
    @CLState private var categoryFrames: [String: CGRect] = [:]
    @Namespace private var categorySpace

    private var dropTarget: String? { drag.flatMap { category(at: $0.location) } }

    private var candidate: Categorize.Category? { Categorize.Category(name: newCategory) }
    private var canAdd: Bool {
        guard let candidate else { return false }
        return !appState.config.categories.contains(candidate.rawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 6) {
                ForEach(appState.config.categories, id: \.self) { raw in
                    HStack {
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                                .accessibilityHidden(true)
                            Text(Categorize.Category(rawValue: raw)?.displayName ?? raw)
                                .font(FieldNotes.Typography.body(13))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 3, coordinateSpace: .named(categorySpace))
                                .updating($drag) { value, drag, _ in
                                    drag = (raw, value.location)
                                }
                                .onEnded { value in
                                    moveCategory(raw, to: category(at: value.location))
                                }
                        )
                        .help("Drag to reorder categories")
                        Button {
                            appState.config.categories.removeAll { $0 == raw }
                        } label: {
                            Image(systemName: "minus.circle")
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(Categorize.Category(rawValue: raw)?.displayName ?? raw) category")
                    }
                    .padding(8)
                    .background(FieldNotes.ColorToken.canvas, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                    .opacity(drag?.category == raw ? 0.65 : 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(dropTarget == raw ? FieldNotes.ColorToken.secondaryText : .clear, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: CategoryFramesKey.self,
                                value: [raw: geometry.frame(in: .named(categorySpace))]
                            )
                        }
                    }
                }
            }
            .coordinateSpace(name: categorySpace)
            .onPreferenceChange(CategoryFramesKey.self) { categoryFrames = $0 }
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

    private func category(at location: CGPoint) -> String? {
        let frames = categoryFrames.filter { appState.config.categories.contains($0.key) }
        guard let left = frames.values.map(\.minX).min(),
              let right = frames.values.map(\.maxX).max(),
              let top = frames.values.map(\.minY).min(),
              let bottom = frames.values.map(\.maxY).max(),
              location.x >= left, location.x <= right,
              location.y >= top, location.y <= bottom else { return nil }
        return frames.min { abs($0.value.midY - location.y) < abs($1.value.midY - location.y) }?.key
    }

    private func moveCategory(_ category: String, to target: String?) {
        guard let target,
              let source = appState.config.categories.firstIndex(of: category),
              let destination = appState.config.categories.firstIndex(of: target),
              source != destination else { return }
        appState.config.categories.move(
            fromOffsets: IndexSet(integer: source),
            toOffset: destination > source ? destination + 1 : destination
        )
    }

    private func addCategory() {
        guard canAdd, let candidate else { return }
        appState.config.categories.append(candidate.rawValue)
        newCategory = ""
    }
}

private struct CategoryFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}
