import Foundation

/// The shared chronological ordering used by the CLI and Logs view.
enum EntryDate {
    static func resolve(stem: String, latestPath: String, audioPath: String) -> Date? {
        let fields = metadata(at: latestPath)
        let recordingDay = String(stem.prefix(10))
        let recordingTime = stem.count >= 15 ? String(stem.dropFirst(11).prefix(4)) : ""
        let time = validTime(fields["recording_time"] ?? "") ?? validTime(recordingTime) ?? "00:00"
        if let day = fields["date"], let date = parse(day: day, time: time) {
            return date
        }
        if let date = parse(day: recordingDay, time: validTime(recordingTime) ?? "00:00") {
            return date
        }
        // Prefer the source file's creation date; processing may create newer artifacts.
        for path in [audioPath, latestPath] {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let date = attributes[.creationDate] as? Date {
                return date
            }
        }
        return nil
    }

    private static func parse(day: String, time: String) -> Date? {
        guard day.count == 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.isLenient = false
        let value = "\(day) \(time)"
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }

    private static func validTime(_ value: String) -> String? {
        let digits = value.replacingOccurrences(of: ":", with: "")
        guard (value.count == 4 || (value.count == 5 && value.dropFirst(2).first == ":")),
              digits.count == 4, digits.allSatisfy(\.isNumber),
              let hour = Int(digits.prefix(2)), let minute = Int(digits.suffix(2)),
              hour < 24, minute < 60 else { return nil }
        return "\(digits.prefix(2)):\(digits.suffix(2))"
    }

    private static func metadata(at path: String) -> [String: String] {
        guard URL(fileURLWithPath: path).pathExtension.lowercased() == "md",
              let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
        let lines = content.components(separatedBy: .newlines)
        guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else { return [:] }
        var fields: [String: String] = [:]
        for line in lines[1..<end] {
            // Only top-level scalar fields; body text and nested dates are unrelated.
            guard line.hasPrefix("date:") || line.hasPrefix("recording_time:"),
                  let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon])
            var value = String(line[line.index(after: colon)...])
                .components(separatedBy: " #").first!
                .trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            fields[key] = value
        }
        return fields
    }
}
