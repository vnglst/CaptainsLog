import AppKit
import CaptainsLogCore
import SwiftUI

/// The production Field Notes shell. It intentionally retains the existing AppState
/// actions so the visual migration does not change the local pipeline's behaviour.
public struct FieldNotesContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @CLState private var section: Section = .entries
    @CLState private var deleteTarget: LogEntry?
    @CLState private var selectedEntry: LogEntry?
    private let bootstrap: Bool

    enum Section { case entries, settings }

    public init(bootstrap: Bool = true) {
        self.bootstrap = bootstrap
    }

    public var body: some View {
        HStack(spacing: 0) {
            FieldNotesSidebar(section: $section) {
                returnToList()
            }
            Rectangle().fill(FieldNotes.ColorToken.stroke).frame(width: 1)

            ZStack(alignment: .bottom) {
                Group {
                    switch section {
                    case .entries:
                        if let selectedEntry {
                            FieldNotesEntryDetailView(entry: selectedEntry) {
                                returnToList()
                            }
                            .transition(detailTransition)
                        } else {
                            FieldNotesEntriesView(deleteTarget: $deleteTarget) { entry in
                                show(entry)
                            }
                            .transition(listTransition)
                        }
                    case .settings: FieldNotesSettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if section == .entries && selectedEntry == nil {
                    FieldNotesRecordDock()
                        .padding(.horizontal, FieldNotes.Spacing.xl)
                        .padding(.bottom, FieldNotes.Spacing.l)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.97, anchor: .bottom))
                        )
                }
            }
            .clipped()
        }
        .frame(minWidth: 720, minHeight: 780)
        .background(FieldNotes.ColorToken.canvas)
        .preferredColorScheme(.dark)
        .sheet(item: $deleteTarget) { target in
            FieldNotesDeleteDialog(entry: target) {
                appState.deleteEntry(stem: target.stem, slug: target.slug)
            }
        }
        .sheet(isPresented: .constant(appState.needsFirstRun)) {
            FieldNotesOnboardingView().environment(appState)
                .interactiveDismissDisabled()
        }
        .task {
            guard bootstrap else { return }
            await appState.bootstrap()
        }
        #if DEBUG
        .task {
            guard let marker = ProcessInfo.processInfo.environment[
                "CAPTAINSLOG_STARTUP_BENCHMARK_MARKER"
            ] else { return }
            await appState.benchmarkRecordingStartup(markerPath: marker)
        }
        #endif
    }

    private var listTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var detailTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    private func show(_ entry: LogEntry) {
        updateSelection(entry)
    }

    private func returnToList() {
        updateSelection(nil)
    }

    private func updateSelection(_ entry: LogEntry?) {
        if reduceMotion {
            selectedEntry = entry
        } else {
            withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                selectedEntry = entry
            }
        }
    }
}

private struct FieldNotesSidebar: View {
    @Binding var section: FieldNotesContentView.Section
    let onShowEntries: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FieldNotes.Spacing.s) {
            HStack(spacing: FieldNotes.Spacing.s) {
                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FieldNotes.ColorToken.amber)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(FieldNotes.ColorToken.amber, lineWidth: 1))
                Text("CaptainsLog")
                    .font(FieldNotes.Typography.title(20))
                    .foregroundStyle(FieldNotes.ColorToken.primaryText)
            }
            .padding(.bottom, FieldNotes.Spacing.xxl)

            FieldNotesSidebarItem(title: "Logs", icon: "doc.text", isSelected: section == .entries) {
                section = .entries
                onShowEntries()
            }
            FieldNotesSidebarItem(title: "Settings", icon: "gearshape", isSelected: section == .settings) {
                section = .settings
            }

            Spacer()
            Text("LOCAL-FIRST NOTES")
                .font(FieldNotes.Typography.metadata(10))
                .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
        }
        .padding(FieldNotes.Spacing.xl)
        .frame(width: 248, alignment: .leading)
        .background(FieldNotes.ColorToken.surface)
    }

}

private struct FieldNotesSidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @CLState private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(FieldNotes.Typography.body(15, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected || isHovered ? FieldNotes.ColorToken.primaryText : FieldNotes.ColorToken.secondaryText)
                .padding(.horizontal, FieldNotes.Spacing.s)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var background: Color {
        if isSelected { return FieldNotes.ColorToken.raisedSurface }
        return isHovered ? FieldNotes.ColorToken.raisedSurface.opacity(0.55) : .clear
    }
}

private struct FieldNotesEntriesView: View {
    @Environment(AppState.self) private var appState
    @Binding var deleteTarget: LogEntry?
    let onSelect: (LogEntry) -> Void

    private var groups: [(date: Date, entries: [LogEntry])] {
        let calendar = Calendar.current
        return Dictionary(grouping: appState.allEntries) { entry in
            guard let date = entry.recordingDate else { return Date.distantPast }
            return calendar.startOfDay(for: date)
        }
        .map { (date: $0.key, entries: $0.value) }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !appState.pendingEntries.isEmpty || appState.isProcessing { queueStrip }
            if appState.search.isActive {
                searchContent
            } else if appState.allEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups, id: \.date) { group in
                            dateHeader(label(for: group.date))
                            ForEach(group.entries) { entry in
                                FieldNotesEntryRow(entry: entry, deleteTarget: $deleteTarget) {
                                    onSelect(entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, FieldNotes.Spacing.xl)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: FieldNotes.Spacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Logs")
                        .font(FieldNotes.Typography.title(28))
                        .foregroundStyle(FieldNotes.ColorToken.primaryText)
                    Text("Your recorded thoughts, processed on this Mac")
                        .font(FieldNotes.Typography.body(13))
                        .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                }
                Spacer()
                Text("\(appState.allEntries.count) logs")
                    .font(FieldNotes.Typography.metadata())
                    .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
            }
            FieldNotesSearchField(
                text: Binding(
                    get: { appState.search.query },
                    set: { appState.search.updateQuery($0, dataDir: appState.dataDir) }
                ),
                isWorking: searchIsWorking
            )
        }
        .padding(.horizontal, FieldNotes.Spacing.xl)
        .padding(.vertical, FieldNotes.Spacing.xl)
    }

    private var searchIsWorking: Bool {
        switch appState.search.state {
        case .preparingModel, .indexing, .searching: true
        case .idle, .ready, .error: false
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        switch appState.search.state {
        case .idle, .preparingModel:
            searchStatus(icon: "arrow.down.circle", title: "Preparing smart search",
                         detail: "The multilingual search model stays on this Mac.")
        case .indexing(let message, let completed, let total):
            searchStatus(icon: "text.magnifyingglass", title: "Indexing logs",
                         detail: total > 0 ? "\(message) · \(completed) of \(total)" : message)
        case .searching:
            searchStatus(icon: "waveform.path.ecg", title: "Following the signal",
                         detail: "Comparing your words with the local note index.")
        case .ready:
            if appState.search.results.isEmpty {
                searchStatus(icon: "scope", title: "No matching logs",
                             detail: "Try describing the idea another way.", showProgress: false)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: FieldNotes.Spacing.s) {
                            Text("SEARCH RESULTS · MOST RELEVANT FIRST")
                                .font(FieldNotes.Typography.metadata(10, weight: .semibold))
                                .foregroundStyle(FieldNotes.ColorToken.mutedAmber)
                            Rectangle().fill(FieldNotes.ColorToken.stroke).frame(height: 1)
                        }
                        .padding(.top, FieldNotes.Spacing.l)
                        .padding(.bottom, FieldNotes.Spacing.xs)

                        ForEach(Array(appState.search.results.enumerated()), id: \.element.stem) { index, result in
                            FieldNotesSearchResultRow(result: result, rank: index + 1) {
                                if let entry = appState.allEntries.first(where: { $0.stem == result.stem }) {
                                    onSelect(entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, FieldNotes.Spacing.xl)
                    .padding(.bottom, 120)
                }
            }
        case .error(let message):
            VStack(spacing: FieldNotes.Spacing.m) {
                searchStatusContent(
                    icon: "exclamationmark.triangle",
                    title: "Smart search stopped",
                    detail: message,
                    showProgress: false
                )
                FieldNotesButton(title: "Try again", kind: .primary) {
                    appState.search.retry(dataDir: appState.dataDir)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 90)
        }
    }

    private func searchStatus(
        icon: String, title: String, detail: String, showProgress: Bool = true
    ) -> some View {
        searchStatusContent(
            icon: icon, title: title, detail: detail, showProgress: showProgress
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, FieldNotes.Spacing.xl)
        .padding(.bottom, 90)
    }

    private func searchStatusContent(
        icon: String, title: String, detail: String, showProgress: Bool
    ) -> some View {
        VStack(spacing: FieldNotes.Spacing.s) {
            ZStack {
                Circle()
                    .stroke(FieldNotes.ColorToken.stroke, lineWidth: 1)
                    .frame(width: 48, height: 48)
                if showProgress {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(FieldNotes.ColorToken.amber)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(FieldNotes.ColorToken.mutedAmber)
                }
            }
            Text(title)
                .font(FieldNotes.Typography.title(19))
                .foregroundStyle(FieldNotes.ColorToken.primaryText)
            Text(detail)
                .font(FieldNotes.Typography.body(13))
                .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 420)
        }
    }

    private var queueStrip: some View {
        HStack(spacing: FieldNotes.Spacing.s) {
            FieldNotesStatus(state: appState.isProcessing ? .active : .paused,
                             label: appState.isProcessing ? appState.statusMessage : "\(appState.pendingEntries.count) logs waiting")
            Spacer()
            if appState.isProcessing {
                FieldNotesButton(title: "Pause", kind: .secondary) { appState.pauseProcessing() }
            } else {
                FieldNotesButton(title: "Process pending", kind: .primary) { appState.batchResumePending() }
            }
        }
        .padding(.horizontal, FieldNotes.Spacing.xl)
        .padding(.vertical, FieldNotes.Spacing.s)
        .background(FieldNotes.ColorToken.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(FieldNotes.ColorToken.stroke).frame(height: 1) }
    }

    private var emptyState: some View {
        VStack(spacing: FieldNotes.Spacing.s) {
            Image(systemName: "waveform")
                .font(.system(size: 30))
                .foregroundStyle(FieldNotes.ColorToken.mutedAmber)
            Text("Capture your first thought")
                .font(FieldNotes.Typography.title(20))
                .foregroundStyle(FieldNotes.ColorToken.primaryText)
            Text("Use the record control below. Your audio and Markdown notes remain on this Mac.")
                .font(FieldNotes.Typography.body())
                .foregroundStyle(FieldNotes.ColorToken.secondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 90)
    }

    private func dateHeader(_ title: String) -> some View {
        HStack(spacing: FieldNotes.Spacing.s) {
            Text(title)
                .font(FieldNotes.Typography.body(13, weight: .medium))
                .foregroundStyle(FieldNotes.ColorToken.secondaryText)
            Rectangle().fill(FieldNotes.ColorToken.stroke).frame(height: 1)
        }
        .padding(.top, FieldNotes.Spacing.l)
        .padding(.bottom, FieldNotes.Spacing.xs)
    }

    private func label(for date: Date?) -> String {
        guard let date else { return "Unknown date" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(
            calendar.isDate(date, equalTo: .now, toGranularity: .year) ? "EEEEdMMMM" : "EEEEdMMMMy"
        )
        return formatter.string(from: date)
    }
}

private struct FieldNotesSearchField: View {
    @Binding var text: String
    let isWorking: Bool
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: FieldNotes.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(focused || !text.isEmpty
                    ? FieldNotes.ColorToken.amber : FieldNotes.ColorToken.tertiaryText)
                .frame(width: 18)
            TextField(
                "Search ideas, decisions, people, or projects",
                text: $text
            )
            .textFieldStyle(.plain)
            .font(FieldNotes.Typography.body(13))
            .foregroundStyle(FieldNotes.ColorToken.primaryText)
            .focused($focused)
        .accessibilityLabel("Search logs by meaning")

            ProgressView()
                .controlSize(.small)
                .tint(FieldNotes.ColorToken.amber)
                .opacity(isWorking ? 1 : 0)
                .frame(width: 20, height: 20)

            Button {
                text = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .opacity(text.isEmpty ? 0 : 1)
            .allowsHitTesting(!text.isEmpty)
            .accessibilityLabel("Clear search")
        }
        .padding(.horizontal, FieldNotes.Spacing.m)
        .frame(height: 40)
        .background(FieldNotes.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous)
                .stroke(focused ? FieldNotes.ColorToken.amber : FieldNotes.ColorToken.stroke,
                        lineWidth: focused ? 1.5 : 1)
        }
        .animation(.easeOut(duration: 0.12), value: focused)
    }
}

private struct FieldNotesSearchResultRow: View {
    let result: SearchResult
    let rank: Int
    let onSelect: () -> Void
    @CLState private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: FieldNotes.Spacing.m) {
                VStack(alignment: .leading, spacing: FieldNotes.Spacing.xs) {
                    HStack(spacing: FieldNotes.Spacing.s) {
                        Text(result.matchKind == .keyword ? "KEYWORD MATCH" : "RELATED PASSAGE")
                            .font(FieldNotes.Typography.metadata(9, weight: .semibold))
                            .foregroundStyle(result.matchKind == .keyword
                                ? FieldNotes.ColorToken.mutedAmber
                                : FieldNotes.ColorToken.tertiaryText)
                        Text(String(format: "%02d", rank))
                            .font(FieldNotes.Typography.metadata(9))
                            .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
                    }
                    Text(highlighted(
                        result.displayName.replacingOccurrences(of: "-", with: " "),
                        baseFont: FieldNotes.Typography.body(16, weight: .semibold),
                        highlightFont: FieldNotes.Typography.body(16, weight: .bold),
                        baseColor: FieldNotes.ColorToken.primaryText
                    ))
                    .lineLimit(1)
                    Text(highlighted(
                        result.excerpt.replacingOccurrences(of: "\n", with: " "),
                        baseFont: FieldNotes.Typography.body(13),
                        highlightFont: FieldNotes.Typography.body(13, weight: .bold),
                        baseColor: FieldNotes.ColorToken.secondaryText
                    ))
                    .lineLimit(3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
                    .padding(.top, 4)
            }
            .padding(.vertical, FieldNotes.Spacing.m)
            .padding(.horizontal, FieldNotes.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? FieldNotes.ColorToken.raisedSurface.opacity(0.65) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle().fill(FieldNotes.ColorToken.stroke.opacity(0.7)).frame(height: 1)
        }
        .onHover { isHovered = $0 }
        .accessibilityLabel("Search result \(rank), \(result.displayName)")
        .accessibilityHint("Opens this log")
    }

    private func highlighted(
        _ text: String,
        baseFont: Font,
        highlightFont: Font,
        baseColor: Color
    ) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.font = baseFont
        attributed.foregroundColor = baseColor
        for term in result.matchedTerms {
            let escaped = NSRegularExpression.escapedPattern(for: term)
            guard let expression = try? NSRegularExpression(
                pattern: "(?i)(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])")
            else { continue }
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            for match in expression.matches(in: text, range: fullRange) {
                guard let stringRange = Range(match.range, in: text),
                      let range = Range(stringRange, in: attributed)
                else { continue }
                attributed[range].font = highlightFont
                attributed[range].foregroundColor = FieldNotes.ColorToken.amber
            }
        }
        return attributed
    }
}

private struct FieldNotesEntryRow: View {
    let entry: LogEntry
    @Environment(AppState.self) private var appState
    @Binding var deleteTarget: LogEntry?
    let onSelect: () -> Void
    @CLState private var isHovered = false

    private var failed: Bool { entry.processingError != nil }
    private var paused: Bool { entry.stage != .done && !entry.isActive && !failed }
    private var canOpen: Bool { entry.stage == .done }

    var body: some View {
        HStack(alignment: .top, spacing: FieldNotes.Spacing.m) {
            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.recordingTime ?? "—")
                    .font(FieldNotes.Typography.metadata(11, weight: .medium))
                    .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                Text(entry.isActive ? "LIVE" : paused ? "PAUSED" : failed ? "ERROR" : "")
                    .font(FieldNotes.Typography.metadata(9))
                    .foregroundStyle(failed ? FieldNotes.ColorToken.danger : FieldNotes.ColorToken.tertiaryText)
            }
            .frame(width: 56, alignment: .trailing)

            VStack(alignment: .leading, spacing: FieldNotes.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: FieldNotes.Spacing.s) {
                    Text(entry.displayName)
                        .font(FieldNotes.Typography.body(16, weight: .semibold))
                        .foregroundStyle(FieldNotes.ColorToken.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    status
                }

                if let summary = entry.summary, !summary.isEmpty {
                    Text(summary)
                        .font(FieldNotes.Typography.body(13))
                        .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                        .lineLimit(2)
                }
                if let error = entry.processingError {
                    Text(error)
                        .font(FieldNotes.Typography.metadata(11))
                        .foregroundStyle(FieldNotes.ColorToken.danger)
                        .lineLimit(2)
                }

                HStack(spacing: FieldNotes.Spacing.s) {
                    if !entry.tags.isEmpty {
                        Text(entry.tags.prefix(3).map { "#\($0)" }.joined(separator: "   "))
                            .font(FieldNotes.Typography.metadata(10))
                            .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Menu {
                        if !entry.path.isEmpty {
                            Button("Reveal in Finder") { NSWorkspace.shared.selectFile(entry.path, inFileViewerRootedAtPath: "") }
                        }
                        if paused || failed {
                            Button(failed ? "Retry processing" : "Resume processing") {
                                appState.resumeProcessing(stem: entry.stem, fromStage: entry.stage)
                            }
                        }
                        if entry.stage == .done {
                            Button("Reprocess from audio") { appState.reprocessEntry(stem: entry.stem, slug: entry.slug) }
                        }
                        Divider()
                        Button("Move to Trash", role: .destructive) { deleteTarget = entry }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
                            .frame(width: 24, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                    .opacity(isHovered ? 1 : 0.7)
                    .accessibilityLabel("Actions for \(entry.displayName)")
                }
            }
        }
        .padding(.vertical, FieldNotes.Spacing.m)
        .padding(.horizontal, FieldNotes.Spacing.s)
        .contentShape(Rectangle())
        .background(isHovered && canOpen ? FieldNotes.ColorToken.raisedSurface.opacity(0.65) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous))
        .overlay(alignment: .bottom) { Rectangle().fill(FieldNotes.ColorToken.stroke.opacity(0.7)).frame(height: 1) }
        .onTapGesture {
            if canOpen { onSelect() }
        }
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(canOpen ? .isButton : [])
        .accessibilityAction(named: "Open enriched entry") {
            if canOpen { onSelect() }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    @ViewBuilder
    private var status: some View {
        if entry.stage == .done {
            FieldNotesStatus(state: .processed, label: "Processed")
        } else if failed {
            FieldNotesStatus(state: .failed, label: "Needs attention")
        } else if paused {
            FieldNotesStatus(state: .paused, label: "Paused")
        } else {
            FieldNotesStatus(state: .active, label: entry.stage.rawValue.capitalized)
        }
    }
}

private struct FieldNotesEntryDetailView: View {
    let entry: LogEntry
    let onBack: () -> Void
    @CLState private var markdown = AttributedString()
    @CLState private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(FieldNotes.ColorToken.stroke).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: FieldNotes.Spacing.l) {
                    if let summary = entry.summary, !summary.isEmpty {
                        Text(summary)
                            .font(FieldNotes.Typography.body(15))
                            .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                            .lineSpacing(4)
                            .padding(FieldNotes.Spacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fieldNotesSurface(.flat)
                    }

                    if let loadError {
                        ContentUnavailableView(
                            "Entry unavailable",
                            systemImage: "doc.badge.exclamationmark",
                            description: Text(loadError)
                        )
                        .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        Text(markdown)
                            .foregroundStyle(FieldNotes.ColorToken.primaryText)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(FieldNotes.Spacing.xl)
                .padding(.bottom, FieldNotes.Spacing.xxl)
                .frame(maxWidth: .infinity)
            }
        }
        .task(id: entry.path) { loadEntry() }
        .onExitCommand(perform: onBack)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FieldNotes.Spacing.m) {
            HStack(spacing: FieldNotes.Spacing.s) {
                Button(action: onBack) {
                    Label("All entries", systemImage: "chevron.left")
                        .font(FieldNotes.Typography.body(13, weight: .medium))
                        .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("[", modifiers: .command)
                .accessibilityHint("Returns to the list of entries")

                Spacer()

                if !entry.path.isEmpty {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(entry.path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.plain)
                    .font(FieldNotes.Typography.body(12, weight: .medium))
                    .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
                }
            }

            Text(entry.displayName)
                .font(FieldNotes.Typography.title(28))
                .foregroundStyle(FieldNotes.ColorToken.primaryText)
                .textSelection(.enabled)

            FieldNotesMetadataFlowLayout(spacing: FieldNotes.Spacing.xs) {
                if let date = entry.recordingDate {
                    FieldNotesMetadataPill(
                        title: date.formatted(date: .long, time: .omitted),
                        icon: "calendar",
                        kind: .temporal
                    )
                }
                if let time = entry.recordingTime {
                    FieldNotesMetadataPill(title: time, icon: "clock", kind: .temporal)
                }
                ForEach(Array(entry.projects.enumerated()), id: \.offset) { _, project in
                    FieldNotesMetadataPill(title: project, icon: "folder", kind: .project)
                }
                ForEach(Array(entry.tags.enumerated()), id: \.offset) { _, tag in
                    FieldNotesMetadataPill(title: "#\(tag)", icon: nil, kind: .tag)
                }
            }
        }
        .padding(.horizontal, FieldNotes.Spacing.xl)
        .padding(.vertical, FieldNotes.Spacing.l)
    }

    private func loadEntry() {
        do {
            let body = try entry.readableBody()
            guard !body.isEmpty else {
                markdown = AttributedString("This entry has no readable content.")
                loadError = nil
                return
            }
            markdown = try AttributedString(
                markdown: body,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
            loadError = nil
        } catch {
            markdown = AttributedString()
            loadError = error.localizedDescription
        }
    }
}

private struct FieldNotesMetadataPill: View {
    enum Kind { case temporal, project, tag }

    let title: String
    let icon: String?
    let kind: Kind

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(FieldNotes.Typography.metadata(10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .frame(height: 27)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch kind {
        case .temporal: return FieldNotes.ColorToken.secondaryText
        case .project: return FieldNotes.ColorToken.primaryText
        case .tag: return FieldNotes.ColorToken.amber
        }
    }

    private var iconColor: Color {
        kind == .project ? FieldNotes.ColorToken.mutedAmber : FieldNotes.ColorToken.tertiaryText
    }

    private var fill: Color {
        switch kind {
        case .temporal: return FieldNotes.ColorToken.raisedSurface
        case .project: return FieldNotes.ColorToken.mutedAmber.opacity(0.08)
        case .tag: return FieldNotes.ColorToken.amber.opacity(0.09)
        }
    }

    private var stroke: Color {
        switch kind {
        case .temporal: return FieldNotes.ColorToken.stroke
        case .project: return FieldNotes.ColorToken.mutedAmber.opacity(0.28)
        case .tag: return FieldNotes.ColorToken.amber.opacity(0.24)
        }
    }
}

private struct FieldNotesMetadataFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(in: bounds.width, subviews: subviews)
        for item in result.items {
            item.subview.place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> LayoutResult {
        var items: [LayoutItem] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x > 0, cursor.x + size.width > maxWidth {
                cursor.x = 0
                cursor.y += rowHeight + spacing
                rowHeight = 0
            }

            items.append(LayoutItem(subview: subview, origin: cursor))
            contentWidth = max(contentWidth, cursor.x + size.width)
            cursor.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        let width = maxWidth.isFinite ? min(maxWidth, contentWidth) : contentWidth
        return LayoutResult(size: CGSize(width: width, height: cursor.y + rowHeight), items: items)
    }

    private struct LayoutItem {
        let subview: LayoutSubview
        let origin: CGPoint
    }

    private struct LayoutResult {
        let size: CGSize
        let items: [LayoutItem]
    }
}

private struct FieldNotesRecordDock: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: FieldNotes.Spacing.m) {
            Button {
                appState.isRecording ? appState.stopRecording() : appState.startRecording()
            } label: {
                ZStack {
                    Circle().fill(appState.isRecording ? FieldNotes.ColorToken.danger : FieldNotes.ColorToken.amber)
                    if appState.isRecording {
                        RoundedRectangle(cornerRadius: 4).fill(FieldNotes.ColorToken.canvas).frame(width: 17, height: 17)
                    } else {
                        Circle().fill(FieldNotes.ColorToken.canvas).frame(width: 21, height: 21)
                    }
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityLabel(appState.isRecording ? "Stop recording" : "Start recording")
            .accessibilityHint(appState.isRecording ? "Saves this note and begins processing it." : "Starts a new voice note.")

            if appState.isRecording {
                Button {
                    appState.isRecordingPaused ? appState.resumeRecording() : appState.pauseRecording()
                } label: {
                    Image(systemName: appState.isRecordingPaused ? "play.fill" : "pause.fill")
                        .foregroundStyle(FieldNotes.ColorToken.primaryText)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(FieldNotes.ColorToken.raisedSurface))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .accessibilityLabel(appState.isRecordingPaused ? "Resume recording" : "Pause recording")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dockLabel)
                    .font(FieldNotes.Typography.body(14, weight: .medium))
                    .foregroundStyle(appState.isRecording ? FieldNotes.ColorToken.amber : FieldNotes.ColorToken.primaryText)
                if appState.isRecording && !appState.isRecordingPaused {
                    FieldNotesAudioRuler(level: normalizedLevel, height: 22, count: 44)
                } else {
                    Text(appState.isRecordingPaused ? "Recording is paused" : "Press ⌘R to start a new note")
                        .font(FieldNotes.Typography.body(12))
                        .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
                        .frame(height: 22, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach(appState.inputDevices) { device in
                    Button {
                        appState.selectedDeviceUID = device.uid
                    } label: {
                        Label(device.name, systemImage: device.uid == appState.selectedDeviceUID ? "checkmark" : "mic")
                    }
                }
            } label: {
                HStack(spacing: FieldNotes.Spacing.xs) {
                    Image(systemName: "mic")
                    Text(selectedDeviceName).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
                .font(FieldNotes.Typography.body(13, weight: .medium))
                .foregroundStyle(FieldNotes.ColorToken.primaryText)
                .padding(.horizontal, FieldNotes.Spacing.s)
                .frame(height: 38)
                .fieldNotesSurface(.flat, radius: FieldNotes.Radius.control)
            }
            .menuStyle(.borderlessButton)
            .disabled(appState.inputDevices.isEmpty)
        }
        .padding(FieldNotes.Spacing.m)
        .fieldNotesSurface(.floating, radius: FieldNotes.Radius.dock)
    }

    private var dockLabel: String {
        if appState.isRecordingPaused { return "Paused · \(duration)" }
        if appState.isRecording { return "Recording · \(duration)" }
        return "Ready to record"
    }

    private var selectedDeviceName: String {
        appState.inputDevices.first { $0.uid == appState.selectedDeviceUID }?.name ?? "No input device"
    }

    private var duration: String { String(format: "%02d:%02d", Int(appState.recordingDuration) / 60, Int(appState.recordingDuration) % 60) }
    private var normalizedLevel: Float { max(0, min(1, (20 * log10(max(appState.audioLevel, 0.0001)) + 60) / 60)) }
}

private struct FieldNotesSettingsView: View {
    @Environment(AppState.self) private var appState
    @CLState private var showThirdPartyNotices = false

    var body: some View {
        @Bindable var state = appState
        ScrollView {
            VStack(alignment: .leading, spacing: FieldNotes.Spacing.l) {
                Text("Settings")
                    .font(FieldNotes.Typography.title(28))
                    .foregroundStyle(FieldNotes.ColorToken.primaryText)

                section("Storage") {
                    Text(shortenedPath(appState.dataDir)).font(FieldNotes.Typography.metadata(12)).foregroundStyle(FieldNotes.ColorToken.primaryText)
                    HStack { FieldNotesButton(title: "Choose folder", isDisabled: isDemoMode) { appState.pickDataDirectory() }; FieldNotesButton(title: "Reveal in Finder", kind: .secondary) { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: appState.dataDir) } }
                    helper(isDemoMode ? "Demo data stays in this repository's temporary working copy." : "Audio, transcripts, and enriched Markdown notes are stored here.")
                }
                section("Personal context") {
                    FieldNotesTextEditor(text: $state.personalContext, placeholder: "Information that helps CaptainsLog understand your work and vocabulary.")
                    helper("\(appState.personalContext.count) characters · Used during cleanup.")
                }
                section("Name and term corrections") {
                    FieldNotesTextEditor(text: $state.corrections, placeholder: "One correction per line, for example:\nKoenh → Koen")
                    helper("These replacement rules are used during cleanup.")
                }
                section("Audio input") {
                    HStack {
                        Text(appState.inputDevices.first { $0.uid == appState.selectedDeviceUID }?.name ?? "No input device")
                            .font(FieldNotes.Typography.body()).foregroundStyle(FieldNotes.ColorToken.primaryText)
                        Spacer()
                        FieldNotesButton(title: "Refresh devices", kind: .secondary) { appState.refreshDevices() }
                    }
                }
                section("Models") {
                    modelStatus
                    helper("Model paths and identifiers are managed through the CLI.")
                }
                section("About") {
                    Text(appState.versionString)
                        .font(FieldNotes.Typography.metadata())
                        .foregroundStyle(FieldNotes.ColorToken.tertiaryText)
                    FieldNotesButton(title: "Third-party notices", kind: .secondary) {
                        showThirdPartyNotices = true
                    }
                }
            }
            .padding(FieldNotes.Spacing.xl)
            .padding(.bottom, FieldNotes.Spacing.xxl)
        }
        .onAppear { appState.config.loadContextFilesIfNeeded() }
        .sheet(isPresented: $showThirdPartyNotices) {
            ThirdPartyNoticesView()
        }
    }

    private var isDemoMode: Bool {
        ProcessInfo.processInfo.environment["CAPTAINSLOG_DEMO_MODE"] == "1"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FieldNotes.Spacing.s) {
            Text(title).font(FieldNotes.Typography.title(18)).foregroundStyle(FieldNotes.ColorToken.primaryText)
            content().padding(FieldNotes.Spacing.m).fieldNotesSurface()
        }
    }

    private func helper(_ text: String) -> some View {
        Text(text).font(FieldNotes.Typography.body(12)).foregroundStyle(FieldNotes.ColorToken.secondaryText)
    }

    @ViewBuilder
    private var modelStatus: some View {
        switch appState.modelState {
        case .ready:
            FieldNotesStatus(state: .processed, label: "Local models ready")
        case .downloading:
            FieldNotesStatus(state: .active, label: "Preparing local models")
        case .error:
            FieldNotesStatus(state: .failed, label: "Local models need attention")
        }
    }
    private func shortenedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

private struct ThirdPartyNoticesView: View {
    @Environment(\.dismiss) private var dismiss

    private let licenseFolderURL = Bundle.main.resourceURL?
        .appendingPathComponent("ThirdPartyLicenses", isDirectory: true)

    var body: some View {
        VStack(alignment: .leading, spacing: FieldNotes.Spacing.l) {
            HStack {
                Text("Third-party notices")
                    .font(FieldNotes.Typography.title(24))
                    .foregroundStyle(FieldNotes.ColorToken.primaryText)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: FieldNotes.Spacing.l) {
                    notice("Antonio font", "Copyright 2013 The Antonio Project Authors. SIL Open Font License 1.1.", url: "https://github.com/googlefonts/antonioFont")
                    notice("Open-source software", "CaptainsLog includes Swift packages, sqlite-vec, llama.cpp, and LLVM OpenMP. Their license texts are bundled with the app.", url: "https://github.com/ggml-org/llama.cpp")
                    notice("Whisper Large-v2 · Apache-2.0", "Downloaded separately; model weights are not included in the app archive.", url: "https://huggingface.co/openai/whisper-large-v2")
                    notice("Qwen 3.5 9B GGUF · Apache-2.0", "Downloaded separately; this GGUF is a community conversion of the Qwen model.", url: "https://huggingface.co/bartowski/Qwen_Qwen3.5-9B-GGUF")
                    notice("multilingual-e5-small GGUF · MIT", "Downloaded separately; this Q8_0 GGUF is a community conversion of the E5 model.", url: "https://huggingface.co/TwinSunsLLC/multilingual-e5-small-gguf")
                    notice("Evaluation examples", "The test corpus includes unofficial Star Trek fan-created examples and readings from published literary works. The respective rights remain with their owners. CaptainsLog is unaffiliated with Star Trek rights holders.", url: "https://github.com/vnglst/CaptainsLog/blob/main/THIRD-PARTY-NOTICES.md")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if let licenseFolderURL, FileManager.default.fileExists(atPath: licenseFolderURL.path) {
                    FieldNotesButton(title: "Open full license texts", kind: .secondary) {
                        NSWorkspace.shared.open(licenseFolderURL)
                    }
                }
                Spacer()
            }
        }
        .padding(FieldNotes.Spacing.xl)
        .frame(minWidth: 560, minHeight: 480)
        .background(FieldNotes.ColorToken.canvas)
        .preferredColorScheme(.dark)
    }

    private func notice(_ title: String, _ detail: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: FieldNotes.Spacing.xs) {
            Text(title)
                .font(FieldNotes.Typography.title(16))
                .foregroundStyle(FieldNotes.ColorToken.primaryText)
            Text(detail)
                .font(FieldNotes.Typography.body(13))
                .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let destination = URL(string: url) {
                Link("Source and license details", destination: destination)
                    .font(FieldNotes.Typography.body(12))
                    .tint(FieldNotes.ColorToken.amber)
            }
        }
        .padding(FieldNotes.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fieldNotesSurface()
    }
}

private struct FieldNotesTextEditor: View {
    @Binding var text: String
    let placeholder: String
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty { Text(placeholder).font(FieldNotes.Typography.body(13)).foregroundStyle(FieldNotes.ColorToken.tertiaryText).padding(FieldNotes.Spacing.s).allowsHitTesting(false) }
            TextEditor(text: $text).scrollContentBackground(.hidden).font(FieldNotes.Typography.body(13)).foregroundStyle(FieldNotes.ColorToken.primaryText).tint(FieldNotes.ColorToken.amber).frame(minHeight: 96).padding(4)
        }
        .fieldNotesSurface(.flat, radius: FieldNotes.Radius.control)
    }
}

private struct FieldNotesOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FieldNotes.Spacing.l) {
                Image(systemName: "waveform").font(.system(size: 30)).foregroundStyle(FieldNotes.ColorToken.amber)
                Text("CaptainsLog").font(FieldNotes.Typography.title(23)).foregroundStyle(FieldNotes.ColorToken.primaryText)
                Spacer()
                Text("1  Storage").font(FieldNotes.Typography.metadata()).foregroundStyle(FieldNotes.ColorToken.amber)
                Text("2  Local models").font(FieldNotes.Typography.metadata()).foregroundStyle(FieldNotes.ColorToken.secondaryText)
            }
            .padding(FieldNotes.Spacing.xxl).frame(width: 230, alignment: .leading).background(FieldNotes.ColorToken.surface)
            VStack(alignment: .leading, spacing: FieldNotes.Spacing.xl) {
                Text("Your voice, kept local.").font(FieldNotes.Typography.title(32)).foregroundStyle(FieldNotes.ColorToken.primaryText)
                Text("CaptainsLog transcribes, cleans, titles, and organizes recordings on this Mac. Choose where your audio and Markdown notes should live.").font(FieldNotes.Typography.body(15)).foregroundStyle(FieldNotes.ColorToken.secondaryText).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: FieldNotes.Spacing.s) {
                    Text("Storage location").font(FieldNotes.Typography.title(18)).foregroundStyle(FieldNotes.ColorToken.primaryText)
                    Text(shortenedPath(appState.dataDir)).font(FieldNotes.Typography.metadata(12)).foregroundStyle(FieldNotes.ColorToken.primaryText)
                    FieldNotesButton(title: "Choose folder") { appState.pickDataDirectory() }
                }.padding(FieldNotes.Spacing.m).fieldNotesSurface()
                Spacer()
                HStack { Text("Nothing leaves your Mac").font(FieldNotes.Typography.body(13)).foregroundStyle(FieldNotes.ColorToken.secondaryText); Spacer(); FieldNotesButton(title: "Set up CaptainsLog") { appState.completeFirstRun(); dismiss() } }
            }
            .padding(FieldNotes.Spacing.xxl)
        }
        .frame(width: 720, height: 680)
        .background(FieldNotes.ColorToken.canvas)
        .preferredColorScheme(.dark)
    }
    private func shortenedPath(_ path: String) -> String { let home = FileManager.default.homeDirectoryForCurrentUser.path; return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path }
}

private struct FieldNotesDeleteDialog: View {
    let entry: LogEntry
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: FieldNotes.Spacing.l) {
            Image(systemName: "trash").font(.system(size: 28)).foregroundStyle(FieldNotes.ColorToken.danger)
            Text("Move to Trash?").font(FieldNotes.Typography.title(22)).foregroundStyle(FieldNotes.ColorToken.primaryText)
            Text("All files for ‘\(entry.displayName)’ will be moved to the Trash. You can recover them from there.").font(FieldNotes.Typography.body(13)).foregroundStyle(FieldNotes.ColorToken.secondaryText).multilineTextAlignment(.center)
            HStack { FieldNotesButton(title: "Cancel", kind: .secondary) { dismiss() }; FieldNotesButton(title: "Move to Trash", kind: .destructive) { onConfirm(); dismiss() } }
        }
        .padding(FieldNotes.Spacing.xxl).frame(width: 420).background(FieldNotes.ColorToken.surface).preferredColorScheme(.dark)
    }
}
