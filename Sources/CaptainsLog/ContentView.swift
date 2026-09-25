import CaptainsLogCore
import SwiftUI

// MARK: - Tab

enum MainTab { case log, settings }

// MARK: - ContentView

public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @CLState private var tab: MainTab = .log
    @CLState private var settingsScrollTarget: String? = nil
    private let bootstrap: Bool

    /// `bootstrap` is disabled only for the debug visual-fixture harness. Production
    /// launches continue to configure the watcher, audio devices, entries, and models.
    public init(bootstrap: Bool = true) {
        self.bootstrap = bootstrap
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                TopFrame(tab: tab)
                HStack(alignment: .top, spacing: 6) {
                    LeftRail(tab: $tab, settingsScrollTarget: $settingsScrollTarget)
                    if tab == .log {
                        EntriesColumn()
                    } else {
                        SettingsPanel(scrollTarget: $settingsScrollTarget)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 14)
                .padding(.top, 6)
                .frame(maxHeight: .infinity)
                // Reserve dock space on log tab only
                if tab == .log {
                    Color.clear.frame(height: 84)
                }
            }
            // Hero dock only on log tab
            if tab == .log {
                HeroRecordDock()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .frame(minWidth: 720, minHeight: 780)
        .background(Color.lcarsVoid)
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.dark)
        .sheet(isPresented: .constant(appState.needsFirstRun)) {
            FirstRunView()
                .environment(appState)
                .interactiveDismissDisabled()
        }
        .task {
            guard bootstrap else { return }
            await appState.bootstrap()
        }
    }
}

// MARK: - TopFrame

private struct TopFrame: View {
    @Environment(AppState.self) private var appState
    let tab: MainTab

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            LCARSElbow(color: .lcarsOrange, width: 110, height: 74,
                       radius: 36, direction: .topLeft, thickness: 26)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(tab == .log ? "CAPTAINSLOG · 041" : "SETTINGS")
                        .font(LCARSFonts.antonio(14, weight: .semibold))
                        .foregroundStyle(.black)
                        .tracking(1.6)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: 26)
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0, bottomLeadingRadius: 0,
                                bottomTrailingRadius: 13, topTrailingRadius: 13
                            )
                            .fill(tab == .log ? Color.lcarsOrange : Color.lcarsRusset)
                        )
                    LCARSPill(label: "LOCAL",   color: .lcarsWheat,  height: 26, pad: 12)
                    LCARSPill(label: isoDate,   color: .lcarsPlum,   height: 26, pad: 12)
                }

                HStack(spacing: 6) {
                    LCARSCell(label: "041",       color: .lcarsRusset, height: 16, width: 64)
                    LCARSCell(label: "ON-DEVICE", color: .lcarsDusty,  height: 16, width: 110)
                    LCARSCell(label: "M3 · 16GB", color: .lcarsSteel,  height: 16, width: 90)
                    Color(hex: "#1a1613").frame(height: 16).clipShape(Capsule())
                    LCARSCell(label: diskLabel,   color: .lcarsOrange, height: 16, width: 80)
                }
            }
        }
        .padding(.top, 34)
        .padding(.leading, 10)
        .padding(.trailing, 14)
    }

    private var diskLabel: String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let free = attrs[.systemFreeSize] as? Int64 else { return "DISK" }
        return "\(Int(free / 1_073_741_824)) GB"
    }

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"; return f
    }()

    private var isoDate: String { Self.isoDateFormatter.string(from: Date()) }
}

// MARK: - LeftRail

private struct LeftRail: View {
    @Environment(AppState.self) private var appState
    @Binding var tab: MainTab
    @Binding var settingsScrollTarget: String?

    var body: some View {
        VStack(spacing: 4) {
            railCell(label: "LOG",      color: .lcarsOrange, height: 48, active: tab == .log) {
                tab = .log
            }
            railCell(label: "ENTRIES",  color: .lcarsWheat,  height: 28, active: tab == .log) {
                tab = .log
            }
            railCell(label: "SETTINGS", color: tab == .settings ? .lcarsRusset : .lcarsDim,
                     height: 28, active: tab == .settings) {
                tab = .settings
            }

            Spacer().frame(height: 24)

            if tab == .log {
                LCARSCell(label: "QUEUE",   color: .lcarsDusty, height: 18, width: 110,
                          align: .trailing, fontSize: 8)
                queueCells
            } else {
                LCARSCell(label: "SETTINGS",    color: .lcarsOrange, height: 48, width: 110, align: .trailing, fontSize: 12)
                Button { settingsScrollTarget = "folder" } label: {
                    LCARSCell(label: "FOLDER",  color: .lcarsWheat,  height: 32, width: 110, align: .trailing, fontSize: 12)
                }.buttonStyle(.plain)
                Button { settingsScrollTarget = "context" } label: {
                    LCARSCell(label: "CONTEXT", color: .lcarsPlum,   height: 32, width: 110, align: .trailing, fontSize: 12)
                }.buttonStyle(.plain)
                Button { settingsScrollTarget = "corrections" } label: {
                    LCARSCell(label: "CORRECTIONS", color: .lcarsSteel, height: 32, width: 110, align: .trailing, fontSize: 12)
                }.buttonStyle(.plain)
                Spacer().frame(height: 8)
                LCARSCell(label: "CLI · cl", color: .lcarsDim,   height: 22, width: 110, align: .trailing,
                          fontSize: 9)
                LCARSCell(label: appState.versionString, color: .lcarsDusty, height: 22, width: 110, align: .trailing,
                          fontSize: 9)
            }

            Spacer(minLength: 8)
            LCARSElbow(color: .lcarsOrange, width: 110, height: 48,
                       radius: 36, direction: .bottomLeft, thickness: 26)
        }
        .frame(width: 110)
    }

    private func railCell(label: String, color: Color, height: CGFloat,
                          active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LCARSCell(label: label, color: color, height: height, width: 110, align: .trailing)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var queueCells: some View {
        let active = appState.pendingEntries.filter { $0.isActive }.count
        let paused = appState.pendingEntries.filter { !$0.isActive }.count
        if active > 0 {
            LCARSCell(label: "\(active) CLEANING", color: .lcarsWheat, height: 36, width: 110, align: .trailing)
        }
        if paused > 0 {
            LCARSCell(label: "\(paused) PAUSED", color: .lcarsRusset, height: 22, width: 110, align: .trailing)
        }
        if active == 0 && paused == 0 {
            LCARSCell(label: "IDLE", color: Color(hex: "#2a2520"), textColor: .lcarsDim,
                      height: 22, width: 110, align: .trailing)
        }
    }
}

// MARK: - EntriesColumn

private struct EntriesColumn: View {
    @Environment(AppState.self) private var appState

    private var groupedEntries: [(label: String, entries: [LogEntry], headerColor: Color)] {
        var groups: [(label: String, entries: [LogEntry], headerColor: Color)] = []
        var seen: [String: Int] = [:]
        for entry in appState.allEntries {
            let key = dateLabel(for: entry.recordingDate)
            if let idx = seen[key] {
                groups[idx].entries.append(entry)
            } else {
                seen[key] = groups.count
                groups.append((label: key, entries: [entry], headerColor: dateHeaderColor(for: entry.recordingDate)))
            }
        }
        return groups
    }

    private func dateHeaderColor(for date: Date?) -> Color {
        guard let date else { return .lcarsDim }
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return .lcarsWheat }
        if cal.isDateInYesterday(date) { return .lcarsRusset }
        return .lcarsDim
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.allEntries.isEmpty {
                emptyState
            } else {
                pendingBar
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedEntries, id: \.label) { group in
                            DateSectionHeader(label: group.label, color: group.headerColor)
                            ForEach(group.entries) { entry in
                                EntryRow(entry: entry)
                            }
                        }
                    }
                    .frame(maxWidth: 800)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.visible)
            }
        }
    }

    @ViewBuilder
    private var pendingBar: some View {
        let pending = appState.pendingEntries
        let show = !pending.isEmpty || appState.isProcessing
        HStack {
            Text("\(pending.count) PENDING")
                .font(LCARSFonts.antonio(10))
                .foregroundStyle(Color.lcarsDim)
                .tracking(1.4)
            Spacer()
            if appState.isProcessing {
                actionButton(label: "▌▌ PAUSE") { appState.pauseProcessing() }
            } else if !pending.isEmpty {
                actionButton(label: "▶ PROCESS ALL") { appState.batchResumePending() }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .opacity(show ? 1 : 0)
        .allowsHitTesting(show)
    }

    private func actionButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(LCARSFonts.antonio(11, weight: .medium))
                .foregroundStyle(Color.lcarsOrange)
                .tracking(1.2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().strokeBorder(Color.lcarsOrange.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("NO LOG ENTRIES")
                .font(LCARSFonts.antonio(15))
                .foregroundStyle(Color.lcarsDim)
                .tracking(2)
            Text("Press ⌘R or tap the record button.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.lcarsDim.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE · d MMM yyyy"; return f
    }()

    private func dateLabel(for date: Date?) -> String {
        guard let date else { return "UNKNOWN DATE" }
        return Self.dayFormatter.string(from: date).uppercased()
    }
}

// MARK: - DateSectionHeader

private struct DateSectionHeader: View {
    let label: String
    var color: Color = .lcarsWheat
    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(LCARSFonts.antonio(13))
                .foregroundStyle(color)
                .tracking(2.5)
            Rectangle().fill(Color(hex: "#2a2520")).frame(height: 2)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - EntryRow

struct EntryRow: View {
    let entry: LogEntry
    @Environment(AppState.self) private var appState
    @CLState private var isHovered = false
    @CLState private var showDeleteConfirmation = false

    private var isFailed: Bool { entry.processingError != nil }
    private var isPaused: Bool { entry.stage != .done && !entry.isActive && !isFailed }
    private var isFree:   Bool { appState.processingStem == nil }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            timeGutter
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(entry.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.lcarsInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    ZStack(alignment: .trailing) {
                        LCARSPill(label: stageLabel, color: stagePillColor, height: 16, pad: 8)
                            .opacity(isHovered ? 0 : 1)
                        actionButtons
                            .opacity(isHovered ? 1 : 0)
                            .offset(x: isHovered ? 0 : 10)
                            .allowsHitTesting(isHovered)
                    }
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                }
                if let summary = entry.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(hex: "#a9a090"))
                        .lineLimit(2)
                }
                if let processingError = entry.processingError {
                    Text(processingError)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.lcarsRusset)
                        .lineLimit(2)
                }
                HStack(spacing: 10) {
                    StageDots(stages: stageDotStates, compact: true)
                    if !entry.tags.isEmpty {
                        Rectangle().fill(Color(hex: "#2a2520")).frame(width: 1, height: 12)
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.lcarsDim)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: "#15110e")).frame(height: 1).padding(.horizontal, 4)
        }
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationView(displayName: entry.displayName) {
                appState.deleteEntry(stem: entry.stem, slug: entry.slug)
            }
        }
    }

    // MARK: Time gutter

    private var timeGutter: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let time = entry.recordingTime {
                Text(time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.lcarsWheat)
                    .tracking(0.5)
            }
            Text(isFailed ? "ERROR" : isPaused ? "PAUSED" : entry.isActive ? "LIVE" : "")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(isFailed ? Color.lcarsRusset : Color.lcarsDim)
        }
        .frame(width: 60, alignment: .leading)
        .padding(.top, 2)
    }

    // MARK: Stage dots

    private var stageDotStates: [StageDots.SegState] {
        let order: [Pipeline.Stage] = [.transcribing, .cleaning, .categorizing, .naming, .enriching]
        return order.map { target in
            if entry.stage == .done { return .done }
            guard let currentIdx = order.firstIndex(of: entry.stage) else { return .queued }
            let targetIdx = order.firstIndex(of: target)!
            if targetIdx < currentIdx { return .done }
            if targetIdx == currentIdx { return entry.isActive ? .active : .paused }
            return .queued
        }
    }

    // MARK: Status pill

    private var stageLabel: String {
        if entry.stage == .done { return "READY" }
        if isFailed { return "ERROR" }
        if isPaused { return "PAUSED" }
        switch entry.stage {
        case .recording:    return "RECORDING"
        case .transcribing: return "TRANSCRIBING"
        case .cleaning:     return "CLEANING"
        case .categorizing: return "CATEGORIZING"
        case .naming:       return "NAMING"
        case .enriching:    return "ENRICHING"
        case .done:         return "READY"
        }
    }

    private var stagePillColor: Color {
        if entry.stage == .done { return .lcarsOrange }
        if isFailed             { return .lcarsRusset }
        if isPaused             { return .lcarsRusset }
        return .lcarsWheat
    }

    // MARK: Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
            // Reveal in Finder — all entries with a path
            if !entry.path.isEmpty {
                actionCell("OPEN", color: .lcarsSteel, tip: "Reveal in Finder") {
                    NSWorkspace.shared.selectFile(entry.path, inFileViewerRootedAtPath: "")
                }
            }

            // Resume processing — only when held / queued
            if isPaused || isFailed {
                actionCell(isFailed ? "RETRY" : "PROCESS", color: .lcarsOrange, tip: isFailed ? "Retry processing" : "Resume processing") {
                    appState.resumeProcessing(stem: entry.stem, fromStage: entry.stage)
                }
                .disabled(!isFree)
            }

            // Full reprocess — preserve audio, regenerate every derived stage.
            if entry.stage == .done {
                actionCell("REDO", color: .lcarsPlum, tip: "Redo all processing from transcription") {
                    appState.reprocessEntry(stem: entry.stem, slug: entry.slug)
                }
                .disabled(!isFree)
            }

            // Delete — destructive, red outline
            actionCell("DEL", color: .lcarsRusset, tip: "Move to Trash") {
                showDeleteConfirmation = true
            }
            .disabled(entry.isActive)
        }
    }

    private func actionCell(_ label: String, color: Color, tip: String, action: @escaping () -> Void) -> some View {
        ActionCell(label: label, color: color, tip: tip, action: action)
    }
}

// MARK: - ActionCell

private struct ActionCell: View {
    let label: String
    let color: Color
    let tip: String
    let action: () -> Void
    @CLState private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(LCARSFonts.antonio(8))
                .foregroundStyle(isHovered ? Color.black : color.opacity(0.85))
                .tracking(1.2)
                .padding(.horizontal, 6)
                .frame(height: 16)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isHovered ? color : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - SettingsPanel

private struct SettingsPanel: View {
    @Environment(AppState.self) private var appState
    @Binding var scrollTarget: String?

    var body: some View {
        @Bindable var appState = appState
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    lcarsSection("DATA FOLDER", color: .lcarsWheat) {
                        dataFolderContent
                    }
                    .id("folder")
                    lcarsSection("PERSONAL CONTEXT", color: .lcarsPlum) {
                        VStack(alignment: .leading, spacing: 6) {
                            PromptField(
                                text: $appState.personalContext,
                                placeholder: "e.g. Speaker is a Dutch software engineer working on voice tooling."
                            )
                            Text("\(appState.personalContext.count) / 2000 CHARS · INJECTED INTO ALL PROMPTS")
                                .font(LCARSFont.caption)
                                .foregroundStyle(Color.lcarsDim)
                                .tracking(0.5)
                        }
                    }
                    .id("context")
                    lcarsSection("NAME & TERM CORRECTIONS", color: .lcarsSteel) {
                        VStack(alignment: .leading, spacing: 6) {
                            PromptField(
                                text: $appState.corrections,
                                placeholder: "One per line, e.g.\nKoenh → Koen\nRhabo → Pioneer Trust",
                                isMonospaced: true
                            )
                            HStack(spacing: 0) {
                                Text("REPLACEMENT RULES · ")
                                Text("FROM").foregroundStyle(Color.lcarsRusset)
                                Text(" → ").foregroundStyle(Color.lcarsDim)
                                Text("TO").foregroundStyle(Color.lcarsOrange)
                                Text(" · INJECTED INTO CLEANUP PROMPT")
                            }
                            .font(LCARSFont.caption)
                            .foregroundStyle(Color.lcarsDim)
                            .tracking(0.5)
                        }
                    }
                    .id("corrections")
                    cliNote
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .padding(.bottom, 20)
            }
            .onChange(of: scrollTarget) { _, newTarget in
                guard let newTarget else { return }
                withAnimation { proxy.scrollTo(newTarget, anchor: .top) }
                Task { @MainActor in scrollTarget = nil }
            }
            .onAppear { appState.config.loadContextFilesIfNeeded() }
        }
    }

    // MARK: Section wrapper

    @ViewBuilder
    private func lcarsSection<Content: View>(_ title: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LCARSCell(label: title, color: color, height: 20, width: nil, align: .trailing, fontSize: 9)
                    .fixedSize()
                Rectangle().fill(Color(hex: "#2a2520")).frame(height: 2)
            }
            content()
                .padding(.leading, 4)
        }
    }

    // MARK: Data Folder

    @ViewBuilder
    private var dataFolderContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("▣")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundStyle(Color.lcarsOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortenedPath(appState.dataDir))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.lcarsInk)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(diskSubtitle)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Color.lcarsDim)
                        .tracking(0.5)
                }
                Spacer()
                pillButton("CHOOSE…", color: .lcarsOrange) { appState.pickDataDirectory() }
                pillButton("REVEAL",  color: .lcarsDim) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: appState.dataDir)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.lcarsPanel)
            Text("Audio, transcripts, and enriched logs are stored in subfolders here. Point this at your Obsidian vault to sync automatically.")
                .font(.system(size: 11))
                .foregroundStyle(Color.lcarsDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var diskSubtitle: String {
        let count = appState.allEntries.count
        let countLabel = String(format: "%03d", count)
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let free = attrs[.systemFreeSize] as? Int64 else {
            return "\(countLabel) ENTRIES"
        }
        return "\(countLabel) ENTRIES · \(Int(free / 1_073_741_824)) GB FREE · APFS"
    }

    // MARK: CLI Note

    private var cliNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LCARSCell(label: "CLI · cl", color: .lcarsDim, height: 20, width: nil, align: .trailing, fontSize: 9)
                    .fixedSize()
                Rectangle().fill(Color(hex: "#2a2520")).frame(height: 2)
            }
            Text("Advanced config (model paths, model IDs) is managed via the CLI:\ncl config set <key> <value>")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.lcarsDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
        }
        .padding(.top, 4)
    }

    // MARK: Helpers

    private func pillButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(LCARSFonts.antonio(11, weight: .medium))
                .foregroundStyle(color == .lcarsDim ? Color.black : Color.black)
                .tracking(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(color))
        }
        .buttonStyle(.plain)
    }

    private func shortenedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

// MARK: - HeroRecordDock

private struct HeroRecordDock: View {
    @Environment(AppState.self) private var appState
    private var isRecording: Bool { appState.isRecording }
    private var isPaused:    Bool { appState.isRecordingPaused }

    var body: some View {
        HStack(spacing: 14) {
            recordButton
            if isRecording {
                pauseResumeButton.transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(dockLabel)
                    .font(LCARSFonts.antonio(11))
                    .foregroundStyle(isPaused ? Color.lcarsRusset : Color.lcarsWheat)
                    .tracking(2)
                    .lineLimit(1)
                WaveformBars(
                    level: (isRecording && !isPaused) ? normalizedLevel : 0,
                    color: isRecording ? .lcarsOrange : Color(hex: "#3a3128"),
                    height: 28, count: 56
                )
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .trailing, spacing: 6) {
                MicSelectorView()
                Text(isRecording ? "⌘R STOP · ⌘⇧P \(isPaused ? "RESUME" : "PAUSE")" : "⌘R · TOGGLE")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.lcarsDim)
                    .tracking(1.0)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.lcarsPanel))
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }

    // dB-normalized level: maps -60dB→0dB to 0→1 for useful waveform display.
    // Raw RMS (0.001–0.05) would keep bars near zero without this transform.
    private var normalizedLevel: Float {
        let db = 20 * log10(max(appState.audioLevel, 0.0001))
        return max(0, min(1, (db + 60) / 60))
    }

    private var dockLabel: String {
        if isRecording && isPaused { return "PAUSED · \(formatDuration(appState.recordingDuration))" }
        if isRecording { return "RECORDING · \(formatDuration(appState.recordingDuration))" }
        return "READY TO RECORD"
    }

    private var recordButton: some View {
        Button {
            if isRecording { appState.stopRecording() }
            else { appState.startRecording() }
        } label: {
            ZStack {
                Circle().fill(buttonFill).frame(width: 56, height: 56)
                    .shadow(color: isRecording ? Color.lcarsRusset.opacity(0.5) : .clear, radius: 12)
                if isRecording {
                    RoundedRectangle(cornerRadius: 4).fill(Color.black).frame(width: 18, height: 18)
                } else {
                    Circle().fill(Color.black).frame(width: 22, height: 22)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isRecording)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: .command)
        .help(isRecording ? "Stop recording (⌘R)" : "Start recording (⌘R)")
    }

    private var buttonFill: Color {
        if isRecording { return .lcarsRusset }
        return .lcarsOrange
    }

    private var pauseResumeButton: some View {
        Button {
            if isPaused { appState.resumeRecording() }
            else { appState.pauseRecording() }
        } label: {
            ZStack {
                Circle().fill(Color.lcarsWheat).frame(width: 44, height: 44)
                if isPaused {
                    // Resume: single right-pointing triangle
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                } else {
                    // Pause: two vertical bars
                    HStack(spacing: 3) {
                        Rectangle().fill(Color.black).frame(width: 4, height: 16)
                        Rectangle().fill(Color.black).frame(width: 4, height: 16)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .help(isPaused ? "Resume recording (⌘⇧P)" : "Pause recording (⌘⇧P)")
        .animation(.easeInOut(duration: 0.15), value: isPaused)
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

// MARK: - MicSelectorView

struct MicSelectorView: View {
    @Environment(AppState.self) private var appState
    @CLState private var isExpanded = false

    private var selectedName: String {
        appState.inputDevices.first { $0.uid == appState.selectedDeviceUID }?.name ?? "No Device"
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(Color.black).frame(width: 8, height: 8)
                    Text("INPUT")
                        .font(LCARSFonts.antonio(12, weight: .medium))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14,
                                          bottomTrailingRadius: 0, topTrailingRadius: 0)
                    .fill(Color.lcarsOrange)
                )
                HStack(spacing: 8) {
                    Text(selectedName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.lcarsInk)
                        .lineLimit(1)
                    Text(isExpanded ? "▴" : "▾").font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.lcarsOrange)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color(hex: "#1a1208"))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 14, topTrailingRadius: 14)
                    .strokeBorder(Color.lcarsOrange, lineWidth: 1)
                )
                .clipShape(
                    UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 14, topTrailingRadius: 14)
                )
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if isExpanded {
                deviceList.offset(y: 32).transition(.opacity.combined(with: .move(edge: .top))).zIndex(20)
            }
        }
        .zIndex(10)
    }

    private var deviceList: some View {
        VStack(spacing: 1) {
            ForEach(appState.inputDevices) { device in
                let isSelected = device.uid == appState.selectedDeviceUID
                Button {
                    appState.selectedDeviceUID = device.uid
                    withAnimation(.easeOut(duration: 0.15)) { isExpanded = false }
                } label: {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(isSelected ? Color.lcarsOrange : Color.clear)
                            .frame(width: 3)
                        HStack(spacing: 8) {
                            Text(device.name)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .lineLimit(1)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.lcarsOrange)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .foregroundStyle(isSelected ? Color.lcarsOrange : Color.lcarsWheat)
                    .background(isSelected ? Color.lcarsOrange.opacity(0.12) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if device.id != appState.inputDevices.last?.id {
                    Rectangle().fill(Color(hex: "#2a2520")).frame(height: 1)
                }
            }
        }
        .frame(minWidth: 220)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.lcarsPanel)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.lcarsOrange.opacity(0.3), lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - DeleteConfirmationView

struct DeleteConfirmationView: View {
    let displayName: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "trash").font(.system(size: 28)).foregroundStyle(Color.lcarsRusset)
            VStack(spacing: 8) {
                Text("MOVE TO TRASH")
                    .font(LCARSFonts.antonio(16, weight: .medium))
                    .foregroundStyle(Color.lcarsOrange)
                    .tracking(2)
                Text("\"\(displayName)\"")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.lcarsWheat)
                    .lineLimit(2).multilineTextAlignment(.center)
                Text("All files for this entry will be moved to the Trash.\nYou can recover them from there.")
                    .font(.system(size: 12)).foregroundStyle(Color.lcarsDim)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Cancel").font(.system(size: 13, design: .monospaced)).foregroundStyle(Color.lcarsWheat)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Capsule().strokeBorder(Color.lcarsWheat.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button { onConfirm(); dismiss() } label: {
                    Text("Move to Trash").font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.lcarsVoid).padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Capsule().fill(Color.lcarsRusset))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(32).frame(width: 380, height: 280)
        .background(Color.lcarsVoid).preferredColorScheme(.dark)
    }
}

// MARK: - ModelStatusView

struct ModelStatusView: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        switch appState.modelState {
        case .downloading(let model, let progress):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("DOWNLOADING")
                        .font(LCARSFonts.antonio(9))
                        .foregroundStyle(Color.black)
                        .tracking(1)
                        .padding(.horizontal, 10)
                        .frame(height: 18)
                        .background(Color.lcarsPlum)
                    HStack(spacing: 4) {
                        stageBadge("WHISPER", isActive: model.contains("Whisper"))
                        stageBadge("QWEN",    isActive: model.contains("Qwen"))
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(LCARSFont.mono(11, weight: .medium))
                        .foregroundStyle(Color.lcarsWheat)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: "#1a1208")).frame(height: 4)
                        Capsule().fill(Color.lcarsPlum)
                            .frame(width: max(4, geo.size.width * progress), height: 4)
                            .animation(.easeOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 4)
            }
        case .error(let message):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("ERROR")
                        .font(LCARSFonts.antonio(9))
                        .foregroundStyle(Color.black)
                        .tracking(1)
                        .padding(.horizontal, 10)
                        .frame(height: 18)
                        .background(Color.lcarsRusset)
                    Spacer()
                    Button { appState.ensureModelsDownloaded() } label: {
                        Text("RETRY")
                            .font(LCARSFont.mono(9, weight: .medium))
                            .foregroundStyle(Color.lcarsOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(Capsule().strokeBorder(Color.lcarsOrange.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Text(message)
                    .font(LCARSFont.mono(10))
                    .foregroundStyle(Color.lcarsDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .ready: EmptyView()
        }
    }

    private func stageBadge(_ label: String, isActive: Bool) -> some View {
        Text(label)
            .font(LCARSFont.mono(8, weight: isActive ? .bold : .regular))
            .foregroundStyle(isActive ? Color.black : Color.lcarsDim)
            .tracking(0.8)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isActive ? Color.lcarsPlum : Color(hex: "#2a2520"))
            .clipShape(Capsule())
    }
}
