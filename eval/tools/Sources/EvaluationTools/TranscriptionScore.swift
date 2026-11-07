import ToolSupport
import Foundation

/// Unit-cost word Levenshtein alignment. Ties prefer match/substitution,
/// then deletion, then insertion, so reports are deterministic.
struct TranscriptionScore {
    static let normalization = "unicode-words-v1"
    struct Edit {
        let operation: String
        let referenceIndex: Int
        let hypothesisIndex: Int
        let reference: String
        let hypothesis: String
        var json: [String: Any] {
            ["operation": operation, "reference_index": referenceIndex,
             "hypothesis_index": hypothesisIndex, "reference": reference, "hypothesis": hypothesis]
        }
    }
    let referenceWords: Int
    let hypothesisWords: Int
    let substitutions: Int
    let deletions: Int
    let insertions: Int
    let edits: [Edit]
    /// Hypothesis word boundary for each reference boundary, using the same alignment.
    let referenceBoundaries: [Int]
    var errors: Int { substitutions + deletions + insertions }
    var wer: Double { Double(errors) / Double(referenceWords) }
    var json: [String: Any] {
        ["normalization": Self.normalization, "alignment": "unit-cost-levenshtein-diagonal-delete-insert-v1",
         "reference_words": referenceWords, "hypothesis_words": hypothesisWords,
         "substitutions": substitutions, "deletions": deletions, "insertions": insertions,
         "errors": errors, "wer": wer, "wer_percent": wer * 100, "edits": edits.map(\.json)]
    }
    // Preserve accents and internal apostrophes, standardize curly apostrophes,
    // split on punctuation (including hyphens), ignore case and whitespace.
    // Do not fold names, numbers, diacritics, fillers or reading mistakes.
    static func words(_ text: String) -> [String] {
        let normalized = text.precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
        let regex = try! NSRegularExpression(pattern: "[\\p{L}\\p{M}\\p{N}]+(?:'[\\p{L}\\p{M}\\p{N}]+)*")
        let ns = normalized as NSString
        return regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }
    init(reference: String, hypothesis: String) throws {
        let r = Self.words(reference), h = Self.words(hypothesis)
        guard !r.isEmpty else { throw ToolFailure("WER requires a nonempty reference transcript") }
        referenceWords = r.count; hypothesisWords = h.count
        // Two cost rows and one byte per traceback cell, rather than full Int costs.
        let width = h.count + 1
        var trace = [UInt8](repeating: 0, count: (r.count + 1) * width)
        var previous = Array(0...h.count)
        for j in 1..<width { trace[j] = 3 }
        for i in 1...r.count {
            var current = [Int](repeating: 0, count: width); current[0] = i
            trace[i * width] = 2
            for j in 1..<width {
                let diagonal = previous[j - 1] + (r[i - 1] == h[j - 1] ? 0 : 1)
                let deletion = previous[j] + 1, insertion = current[j - 1] + 1
                let cost = min(diagonal, deletion, insertion)
                current[j] = cost
                trace[i * width + j] = cost == diagonal ? 1 : (cost == deletion ? 2 : 3)
            }
            previous = current
        }
        var i = r.count, j = h.count, s = 0, d = 0, a = 0, result: [Edit] = []
        var boundaries = [Int](repeating: 0, count: r.count + 1)
        boundaries[r.count] = h.count
        while i > 0 || j > 0 {
            switch trace[i * width + j] {
            case 1:
                i -= 1; j -= 1
                if r[i] != h[j] { s += 1; result.append(Edit(operation: "substitution", referenceIndex: i, hypothesisIndex: j, reference: r[i], hypothesis: h[j])) }
            case 2:
                i -= 1; d += 1; result.append(Edit(operation: "deletion", referenceIndex: i, hypothesisIndex: j, reference: r[i], hypothesis: ""))
            default:
                j -= 1; a += 1; result.append(Edit(operation: "insertion", referenceIndex: i, hypothesisIndex: j, reference: "", hypothesis: h[j]))
            }
            boundaries[i] = j
        }
        boundaries[r.count] = h.count
        referenceBoundaries = boundaries
        substitutions = s; deletions = d; insertions = a; edits = result.reversed()
    }
    var summary: String {
        String(format: "WER %.2f%% (%d substitutions + %d deletions + %d insertions) / %d reference words", wer * 100, substitutions, deletions, insertions, referenceWords)
    }
    var markdown: String {
        ([summary, "", "Normalization: \(Self.normalization). Zero-based word positions; expected → generated.", "", "| Operation | Reference position | Generated position | Expected | Generated |", "|---|---:|---:|---|---|"] + edits.map {
            "| \($0.operation) | \($0.referenceIndex) | \($0.hypothesisIndex) | \($0.reference) | \($0.hypothesis) |"
        }).joined(separator: "\n") + "\n"
    }
}
