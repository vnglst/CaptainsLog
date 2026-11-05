import Foundation

/// Build listening passages from both complete word alignments, not an old checklist.
extension Tools {
    func differencePassages(reference: String, transcript: String, comparison: String,
                            timing: EvalItem, identifier: String, duration: Double) throws -> [EvalItem] {
        let ref = ReviewText(reference)
        let scores = try [transcript, comparison].map { try TranscriptionScore(reference: reference, hypothesis: $0) }
        let segments = timing["transcription"] as? [EvalItem] ?? []
        try require(!segments.isEmpty, "Comparison requires timestamped transcription segments")
        let segmentTexts = segments.map { $0["text"] as? String ?? "" }
        try require(TranscriptionScore.words(segmentTexts.joined(separator: " ")) == TranscriptionScore.words(comparison), "Comparison timing text does not match its transcript")
        var bounds: [(start: Double, end: Double, a: Int, b: Int)] = [], offset = 0
        for (segment, text) in zip(segments, segmentTexts) {
            guard let offsets = segment["offsets"] as? EvalItem,
                  let from = offsets["from"] as? NSNumber, let to = offsets["to"] as? NSNumber else { throw ToolFailure("Missing comparison timestamps") }
            let start = from.doubleValue / 1000, end = to.doubleValue / 1000
            try require(start >= 0 && end >= start && start <= duration + 0.5 && (bounds.last?.start ?? 0) <= start, "Invalid comparison timestamps")
            let count = TranscriptionScore.words(text).count
            if count > 0 { bounds.append((start, min(end, duration), offset, offset + count)) }
            offset += count
        }
        try require(!bounds.isEmpty, "Comparison timing has no spoken words")
        let alignment = scores[1].referenceBoundaries
        // Assign every edit from either model to the comparison model's timed segment.
        // A deletion uses the nearest surviving word; final insertions use the last clip.
        var selected = Set<Int>()
        for (model, score) in scores.enumerated() {
            for edit in score.edits {
                let word = model == 1 && edit.operation != "deletion" ? edit.hypothesisIndex : alignment[min(edit.referenceIndex, ref.ranges.count)]
                selected.insert(bounds.firstIndex(where: { word < $0.b }) ?? bounds.count - 1)
            }
        }
        // Keep each timestamped segment separate; adjacent errors must not grow
        // into minute-long review clips simply because each segment has an edit.
        let groups = selected.sorted().map { (first: $0, last: $0) }
        var passages: [EvalItem] = []
        for group in groups {
            let first = bounds[group.first], last = bounds[group.last]
            var a = alignment.firstIndex(where: { $0 >= first.a }) ?? ref.ranges.count
            var b = alignment.lastIndex(where: { $0 <= last.b }) ?? ref.ranges.count
            // Include boundary edits assigned to the selected segments, including omissions.
            for (model, score) in scores.enumerated() {
                for edit in score.edits {
                    let word = model == 1 && edit.operation != "deletion" ? edit.hypothesisIndex : alignment[min(edit.referenceIndex, ref.ranges.count)]
                    let index = bounds.firstIndex(where: { word < $0.b }) ?? bounds.count - 1
                    if index >= group.first && index <= group.last {
                        a = min(a, edit.referenceIndex)
                        b = max(b, min(ref.ranges.count, edit.referenceIndex + 1))
                    }
                }
            }
            a = min(a, ref.ranges.count - 1); b = max(a + 1, min(b, ref.ranges.count))
            let excerpt = ref.excerpt(a, b)
            let errors = try zip([transcript, comparison], scores).map { text, score in
                try TranscriptionScore(reference: excerpt, hypothesis: ReviewText(text).excerpt(score.referenceBoundaries[a], score.referenceBoundaries[b])).errors
            }
            try require(errors.contains(where: { $0 > 0 }), "Generated discrepancy passage contains no text differences")
            let short = String(format: "E%02d", passages.count + 1)
            let models = zip(["Whisper Large-v2", "Whisper Large-v3"], errors).filter { $0.1 > 0 }.map { $0.0 }.joined(separator: " and ")
            passages.append(["id": identifier + "-" + short, "short_id": short,
                "title": models + " differs", "start_seconds": max(0, first.start - 0.75), "end_seconds": min(duration, last.end + 0.75),
                "reference_start_word": a, "reference_end_word": b,
                "model_errors": errors,
                "check": "Selected from word differences against the reference: Large-v2 \(errors[0]) edit(s), Large-v3 \(errors[1]) edit(s). Listen to establish the spoken wording; model agreement is not audio verification. Clip times come from Large-v3 segments and include context padding."])
        }
        for score in scores {
            for edit in score.edits {
                try require(passages.contains { passage in
                    let a = passage["reference_start_word"] as! Int, b = passage["reference_end_word"] as! Int
                    return edit.referenceIndex >= a && (edit.referenceIndex < b || edit.referenceIndex == ref.ranges.count && b == ref.ranges.count)
                }, "An aligned model difference was omitted from the review")
            }
        }
        return passages
    }
}
