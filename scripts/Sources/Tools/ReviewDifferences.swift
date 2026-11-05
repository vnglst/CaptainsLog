import Foundation

/// Build listening passages from both complete word alignments, not an old checklist.
extension Tools {
    func reviewDifferenceTitle(reference: String, transcripts: [String]) throws -> String {
        let text = ReviewText(reference)
        let edits = try transcripts.flatMap { try TranscriptionScore(reference: reference, hypothesis: $0).edits }
        try require(!edits.isEmpty, "Only text differences can receive a review title")
        let index = min(edits.map(\.referenceIndex).min() ?? 0, text.ranges.count - 1)
        let topic = text.excerpt(max(0, index - 1), min(text.ranges.count, index + 3))
            .replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .punctuationCharacters)
        let kinds = Set(edits.map(\.operation))
        let issue: String
        if kinds.contains("insertion") && kinds.contains("deletion") { issue = "possible stumble or omitted words" }
        else if kinds.contains("insertion") { issue = "possible added or repeated words" }
        else if kinds.contains("deletion") { issue = "possibly omitted words" }
        else { issue = "wording or spelling to verify" }
        return topic.prefix(1).uppercased() + topic.dropFirst() + ": " + issue
    }

    /// Navigation timing is independent of the hypotheses being evaluated.
    /// An omitted phrase cannot be timed from a model that never emitted it.
    func retimeReviewPassages(_ passages: [EvalItem], reference: String, timing: EvalItem,
                              duration: Double) throws -> [EvalItem] {
        let segments = timing["transcription"] as? [EvalItem] ?? []
        let texts = segments.map { $0["text"] as? String ?? "" }
        let score = try TranscriptionScore(reference: reference, hypothesis: texts.joined(separator: " "))
        var bounds: [(a: Int, b: Int, start: Double, end: Double)] = [], offset = 0
        for (segment, text) in zip(segments, texts) {
            guard let times = segment["offsets"] as? EvalItem,
                  let start = times["from"] as? NSNumber, let end = times["to"] as? NSNumber else {
                throw ToolFailure("Missing navigation timing offsets")
            }
            let count = TranscriptionScore.words(text).count
            let from = start.doubleValue / 1000, to = min(duration, end.doubleValue / 1000)
            try require(from >= 0 && to >= from && to <= duration && (bounds.last?.start ?? 0) <= from,
                        "Invalid navigation timing offsets")
            let tokens = (segment["tokens"] as? [EvalItem] ?? []).filter {
                !($0["text"] as? String ?? "").hasPrefix("[_")
            }
            let tokenText = tokens.map { $0["text"] as? String ?? "" }.joined()
            let validTokenTimes = tokens.allSatisfy { token in
                guard let times = token["offsets"] as? EvalItem,
                      let start = times["from"] as? NSNumber, let end = times["to"] as? NSNumber else { return false }
                return start.doubleValue / 1000 >= from && end.doubleValue >= start.doubleValue
                    && end.doubleValue / 1000 <= to
            }
            // whisper.cpp can emit backwards token ranges at segment starts.
            // Fall back to that segment instead of manufacturing word precision.
            if !tokens.isEmpty && validTokenTimes && TranscriptionScore.words(tokenText) == TranscriptionScore.words(text) {
                var character = 0
                let tokenRanges: [(NSRange, Double, Double)] = try tokens.map { token in
                    let length = ((token["text"] as? String ?? "") as NSString).length
                    defer { character += length }
                    guard let times = token["offsets"] as? EvalItem,
                          let start = times["from"] as? NSNumber, let end = times["to"] as? NSNumber else {
                        throw ToolFailure("Missing navigation token timing")
                    }
                    let a = start.doubleValue / 1000, b = min(duration, end.doubleValue / 1000)
                    try require(a >= from && b >= a && b <= to, "Invalid navigation token timing")
                    return (NSRange(location: character, length: length), a, b)
                }
                for (index, word) in ReviewText(tokenText).ranges.enumerated() {
                    let overlapping = tokenRanges.filter { NSIntersectionRange($0.0, word).length > 0 }
                    bounds.append((offset + index, offset + index + 1,
                        overlapping.map { $0.1 }.min() ?? from, overlapping.map { $0.2 }.max() ?? to))
                }
            } else if count > 0 { bounds.append((offset, offset + count, from, to)) }
            offset += count
        }
        try require(!bounds.isEmpty, "Navigation timing has no words")
        return try passages.map { passage in
            guard var a = passage["reference_start_word"] as? Int,
                  var b = passage["reference_end_word"] as? Int,
                  a >= 0, a < b, b < score.referenceBoundaries.count else {
                throw ToolFailure("Invalid navigation reference range")
            }
            // Insertion-only alignments can collapse a whole disputed phrase
            // onto one anchor word. Include enough reference to hear it in context.
            if b - a == 1 {
                a = max(0, a - 4); b = min(score.referenceWords, b + 4)
            }
            let firstWord = score.referenceBoundaries[a], lastWord = score.referenceBoundaries[b]
            let first = bounds.firstIndex { firstWord < $0.b } ?? bounds.count - 1
            let last = bounds.lastIndex { $0.a < max(firstWord + 1, lastWord) } ?? first
            var updated = passage
            updated["reference_start_word"] = a; updated["reference_end_word"] = b
            updated["start_seconds"] = max(0, bounds[first].start - 0.75)
            updated["end_seconds"] = min(duration, bounds[max(first, last)].end + 0.75)
            return updated
        }
    }

    func differencePassages(reference: String, transcript: String, comparison: String,
                            timing: EvalItem, identifier: String, duration: Double) throws -> [EvalItem] {
        let ref = ReviewText(reference)
        let scores = try [transcript, comparison].map { try TranscriptionScore(reference: reference, hypothesis: $0) }
        let segments = timing["transcription"] as? [EvalItem] ?? []
        try require(!segments.isEmpty, "Comparison requires timestamped transcription segments")
        let segmentTexts = segments.map { $0["text"] as? String ?? "" }
        try require(TranscriptionScore.words(segmentTexts.joined(separator: " ")) == TranscriptionScore.words(comparison), "Comparison timing text does not match its transcript")
        var bounds: [(start: Double, end: Double, a: Int, b: Int, words: [String])] = [], offset = 0
        for (segment, text) in zip(segments, segmentTexts) {
            guard let offsets = segment["offsets"] as? EvalItem,
                  let from = offsets["from"] as? NSNumber, let to = offsets["to"] as? NSNumber else { throw ToolFailure("Missing comparison timestamps") }
            let start = from.doubleValue / 1000, end = to.doubleValue / 1000
            try require(start >= 0 && end >= start && start <= duration + 0.5 && (bounds.last?.start ?? 0) <= start, "Invalid comparison timestamps")
            let count = TranscriptionScore.words(text).count
            if count > 0 { bounds.append((start, min(end, duration), offset, offset + count, TranscriptionScore.words(text))) }
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
        var groups: [(first: Int, last: Int)] = []
        for index in selected.sorted() {
            var first = index, last = index
            // Repeated output can align its first copy to an insertion and its
            // second copy to the reference. Review both copies together so the
            // reference sentence is not split from the audio that contains it.
            while first > 0 && bounds[first - 1].words == bounds[index].words { first -= 1 }
            while last + 1 < bounds.count && bounds[last + 1].words == bounds[index].words { last += 1 }
            if let previous = groups.last, first <= previous.last {
                groups[groups.count - 1] = (previous.first, max(previous.last, last))
            } else { groups.append((first, last)) }
        }
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
            var clipStart = max(0, first.start - 0.75), clipEnd = min(duration, last.end + 0.75)
            // Timestamped hallucination segments can collapse onto the same
            // reference word. Review that audio once rather than repeating it.
            if let previous = passages.last,
               let oldA = previous["reference_start_word"] as? Int, let oldB = previous["reference_end_word"] as? Int,
               let oldStart = previous["start_seconds"] as? Double, let oldEnd = previous["end_seconds"] as? Double,
               ((oldA <= a && oldB >= b) || (a <= oldA && b >= oldB)),
               clipStart <= oldEnd && clipEnd >= oldStart {
                a = min(a, oldA); b = max(b, oldB)
                clipStart = min(clipStart, oldStart); clipEnd = max(clipEnd, oldEnd)
                passages.removeLast()
            }
            let excerpt = ref.excerpt(a, b)
            let errors = try zip([transcript, comparison], scores).map { text, score in
                try TranscriptionScore(reference: excerpt, hypothesis: ReviewText(text).excerpt(score.referenceBoundaries[a], score.referenceBoundaries[b])).errors
            }
            try require(errors.contains(where: { $0 > 0 }), "Generated discrepancy passage contains no text differences")
            let short = String(format: "E%02d", passages.count + 1)
            let title = try reviewDifferenceTitle(reference: excerpt,
                transcripts: zip([transcript, comparison], scores).map { text, score in
                    ReviewText(text).excerpt(score.referenceBoundaries[a], score.referenceBoundaries[b])
                })
            passages.append(["id": identifier + "-" + short, "short_id": short,
                "title": title, "start_seconds": clipStart, "end_seconds": clipEnd,
                "reference_start_word": a, "reference_end_word": b,
                "model_errors": errors,
                "check": "Listen to the highlighted wording and confirm the exact words spoken. The clip includes a little surrounding audio for context."])
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
