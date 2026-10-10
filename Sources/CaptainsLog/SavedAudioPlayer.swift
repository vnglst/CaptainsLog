import AVFoundation
import CaptainsLogCore
import SwiftUI

/// Entry-scoped playback: releasing the detail view also releases its recording.
@MainActor
@Observable
final class SavedAudioPlayback {
    private var player: AVPlayer?
    private var resumeAfterSeeking = false
    private var isSeeking = false
    private(set) var duration: Double = 0
    private(set) var position: Double = 0
    private(set) var isPlaying = false
    private(set) var isLoading = true
    private(set) var error: String?

    func load(url: URL?) async {
        stop()
        duration = 0
        position = 0
        error = nil
        isLoading = true
        defer { isLoading = false }
        guard let url else {
            error = "The original recording is unavailable."
            return
        }
        do {
            let asset = AVURLAsset(url: url)
            let (length, playable) = try await asset.load(.duration, .isPlayable)
            try Task.checkCancellation()
            guard playable, length.seconds.isFinite, length.seconds > 0 else {
                error = "This recording cannot be played."
                return
            }
            duration = length.seconds
            player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        } catch {
            if !Task.isCancelled { self.error = "This recording could not be opened." }
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if position >= duration - 0.05 { seek(to: 0) }
            player.play()
            isPlaying = true
        }
    }

    func seek(to seconds: Double) {
        guard let player, seconds.isFinite else { return }
        position = min(max(0, seconds), duration)
        player.seek(to: CMTime(seconds: position, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setSeeking(_ seeking: Bool) {
        isSeeking = seeking
        if seeking {
            resumeAfterSeeking = isPlaying
            player?.pause()
        } else {
            if resumeAfterSeeking { player?.play() }
            resumeAfterSeeking = false
        }
    }

    func refresh() {
        guard let player else { return }
        if player.currentItem?.status == .failed {
            error = "Playback failed. Reopen the entry to try again."
            stop()
            return
        }
        guard !isSeeking else { return }
        let current = player.currentTime().seconds
        if current.isFinite { position = min(max(0, current), duration) }
        if position >= duration - 0.05, player.rate == 0 { isPlaying = false }
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        isSeeking = false
        resumeAfterSeeking = false
    }

    static func timeLabel(_ seconds: Double) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct SavedAudioPlayerView: View {
    let stem: String
    let dataDir: String
    @CLState private var playback = SavedAudioPlayback()

    private var sourceURL: URL? {
        Pipeline.sourceAudioURLs(stem: stem, dataDirURL: URL(fileURLWithPath: dataDir)).first
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(FieldNotes.ColorToken.stroke).frame(height: 1)
            HStack(spacing: FieldNotes.Spacing.m) {
                Button { playback.togglePlayback() } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FieldNotes.ColorToken.amber)
                        .frame(width: 36, height: 36)
                        .background(FieldNotes.ColorToken.raisedSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(playback.isLoading || playback.error != nil)
                .accessibilityLabel(playback.isPlaying ? "Pause recording" : "Play recording")

                if let error = playback.error {
                    Text(error)
                        .font(FieldNotes.Typography.body(12))
                        .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if playback.isLoading {
                    ProgressView().controlSize(.small)
                    Text("Loading recording…")
                        .font(FieldNotes.Typography.body(12))
                        .foregroundStyle(FieldNotes.ColorToken.secondaryText)
                    Spacer()
                } else {
                    Text(SavedAudioPlayback.timeLabel(playback.position))
                        .frame(minWidth: 40, alignment: .trailing)
                    Slider(
                        value: Binding(get: { playback.position }, set: { playback.seek(to: $0) }),
                        in: 0...max(playback.duration, 0.01),
                        onEditingChanged: { playback.setSeeking($0) }
                    )
                    .tint(FieldNotes.ColorToken.amber)
                    .accessibilityLabel("Recording position")
                    .accessibilityValue("\(SavedAudioPlayback.timeLabel(playback.position)) of \(SavedAudioPlayback.timeLabel(playback.duration))")
                    Text(SavedAudioPlayback.timeLabel(playback.duration))
                        .frame(minWidth: 40, alignment: .leading)
                }
            }
            .font(FieldNotes.Typography.metadata(11))
            .monospacedDigit()
            .foregroundStyle(FieldNotes.ColorToken.secondaryText)
            .padding(.horizontal, FieldNotes.Spacing.xl)
            .padding(.vertical, FieldNotes.Spacing.m)
            .frame(maxWidth: .infinity)
            .background(FieldNotes.ColorToken.surface)
        }
        .task(id: "\(dataDir)/\(stem)") {
            await playback.load(url: sourceURL)
            while !Task.isCancelled {
                playback.refresh()
                do { try await Task.sleep(for: .milliseconds(200)) }
                catch { break }
            }
        }
        .onDisappear { playback.stop() }
    }
}
