import Foundation
import Darwin

struct ReviewSession {
    let run: URL
    let port: UInt16
}

extension Tools {
    func reviewSessionKey(_ run: URL) -> String {
        let full = run.resolvingSymlinksInPath().standardizedFileURL.path
        return full.hasPrefix(root.path + "/") ? String(full.dropFirst(root.path.count + 1)) : full
    }
    func reviewSessionLocation(_ run: URL, file: URL) -> EvalItem {
        let state = (try? json(file)) as? EvalItem ?? [:]
        let sessions = state["sessions"] as? [String: EvalItem] ?? [:]
        return sessions[reviewSessionKey(run)]?["location"] as? EvalItem ?? ["view": "overview"]
    }
    func rememberReviewSession(_ run: URL, port: UInt16, location: EvalItem? = nil, file: URL) throws {
        try mkdir(file.deletingLastPathComponent())
        let descriptor = open(file.appendingPathExtension("lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw ToolFailure("Could not save review session") }
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw ToolFailure("Could not lock review session") }
        var state = (try? json(file)) as? EvalItem ?? [:]
        var sessions = state["sessions"] as? [String: EvalItem] ?? [:]
        let key = reviewSessionKey(run)
        var entry = sessions[key] ?? [:]
        entry["port"] = Int(port); entry["opened_at"] = ISO8601DateFormatter().string(from: Date())
        if let location { entry["location"] = location }
        sessions[key] = entry; state["sessions"] = sessions; state["last_run"] = key
        try JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]).write(to: file, options: .atomic)
    }
    func latestReviewSession(file: URL, catalog: URL, searchRoots: [URL]) throws -> ReviewSession? {
        func saved(_ run: URL, port: UInt16 = 8777) -> ReviewSession? {
            let app = run.appendingPathComponent("review-app")
            guard fm.fileExists(atPath: app.appendingPathComponent("index.html").path),
                  fm.fileExists(atPath: app.appendingPathComponent("recordings.json").path) else { return nil }
            return ReviewSession(run: run.resolvingSymlinksInPath().standardizedFileURL, port: port)
        }
        let state = (try? json(file)) as? EvalItem ?? [:]
        if let key = state["last_run"] as? String,
           let sessions = state["sessions"] as? [String: EvalItem],
           let number = sessions[key]?["port"] as? Int, let port = UInt16(exactly: number), port > 0,
           let result = saved(path(key), port: port) { return result }
        for entry in ((try? json(catalog)) as? [EvalItem] ?? []).reversed() {
            guard let folder = entry["root"] as? String, let url = entry["url"] as? String,
                  let components = URLComponents(string: url), ["127.0.0.1", "localhost"].contains(components.host ?? ""),
                  let number = components.port, let port = UInt16(exactly: number), port > 0,
                  let result = saved(URL(fileURLWithPath: folder).deletingLastPathComponent(), port: port) else { continue }
            return result
        }
        let candidates = searchRoots.flatMap { base -> [URL] in
            if base.lastPathComponent == "tmp" {
                return ((try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? [])
                    .map { $0.appendingPathComponent("review-app/recordings.json") }.filter { fm.fileExists(atPath: $0.path) }
            }
            return files(base, recursive: true).filter { $0.path.hasSuffix("/review-app/recordings.json") }
        }.sorted { lhs, rhs in
            let a = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a == b ? lhs.path < rhs.path : a > b
        }
        return candidates.compactMap { saved($0.deletingLastPathComponent().deletingLastPathComponent()) }.first
    }
    func reviewBrowserURL(run: URL, port: UInt16, file: URL) -> String {
        let location = reviewSessionLocation(run, file: file)
        var fragment = URLComponents()
        if let recording = location["recording"] as? String, let passage = location["passage"] as? String {
            fragment.queryItems = [URLQueryItem(name: "recording", value: recording), URLQueryItem(name: "passage", value: passage)]
        } else { fragment.queryItems = [URLQueryItem(name: "view", value: "overview")] }
        return "http://127.0.0.1:\(port)/#" + (fragment.percentEncodedQuery ?? "view=overview")
    }
}
