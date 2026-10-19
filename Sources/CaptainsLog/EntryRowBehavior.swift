import Foundation
import CaptainsLogCore

enum EntryRowStatus: Equatable {
    case processed
    case failed
    case paused
    case queued
    case active(String)
}

/// User-visible row actions derived from entry state, kept independent of SwiftUI rendering.
struct EntryRowBehavior: Equatable {
    let status: EntryRowStatus
    let canOpen: Bool
    let canRevealInFinder: Bool
    let canResume: Bool
    let canReprocess: Bool
    let resumeTitle: String?
    let compactStatusLabel: String
    let isFailure: Bool

    init(entry: LogEntry) {
        let failed = entry.processingError != nil
        let paused = entry.stage != .done && !entry.isActive && !entry.isQueued && !failed
        isFailure = failed
        compactStatusLabel = entry.isActive ? "LIVE" : entry.isQueued ? "QUEUED" : paused ? "PAUSED" : failed ? "ERROR" : ""
        canOpen = entry.stage == .done
        canRevealInFinder = !entry.path.isEmpty
        canResume = !entry.isQueued && (paused || failed)
        canReprocess = entry.stage == .done && !entry.isActive
        resumeTitle = canResume ? (failed ? "Retry processing" : "Resume processing") : nil

        if entry.stage == .done {
            status = .processed
        } else if entry.isQueued {
            status = .queued
        } else if failed {
            status = .failed
        } else if paused {
            status = .paused
        } else {
            status = .active(entry.stage.rawValue.capitalized)
        }
    }
}

struct EntryNavigationState {
    var categoryFilter = CategoryFilter()
    private(set) var selectedEntry: LogEntry?

    var selectedStem: String? { selectedEntry?.stem }

    mutating func show(_ entry: LogEntry) {
        selectedEntry = entry
    }

    mutating func returnToList() {
        selectedEntry = nil
    }
}

enum RecordDockPrimaryAction: Equatable {
    case start
    case stop
}

enum RecordDockPauseAction: Equatable {
    case pause
    case resume
}

struct RecordDockBehavior: Equatable {
    let primaryAction: RecordDockPrimaryAction
    let pauseAction: RecordDockPauseAction?
    let canSelectInputDevice: Bool
    let showsAudioLevel: Bool

    init(isRecording: Bool, isPaused: Bool, inputDeviceCount: Int) {
        primaryAction = isRecording ? .stop : .start
        pauseAction = isRecording ? (isPaused ? .resume : .pause) : nil
        canSelectInputDevice = inputDeviceCount > 0
        showsAudioLevel = isRecording && !isPaused
    }
}

enum QueueStripAction: Equatable {
    case pause
    case processPending
}

struct QueueStripBehavior: Equatable {
    let action: QueueStripAction
    let statusLabel: String

    init(isProcessing: Bool, statusMessage: String, pendingCount: Int) {
        if isProcessing {
            action = .pause
            statusLabel = statusMessage
        } else {
            action = .processPending
            statusLabel = "\(pendingCount) logs waiting"
        }
    }
}
