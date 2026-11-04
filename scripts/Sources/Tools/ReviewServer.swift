import AVFoundation
import Darwin
import Foundation

struct ReviewResponse {
    var status: Int = 200
    var headers: [String: String] = [:]
    var body = Data()
    var file: URL?
    var offset: UInt64 = 0
    var length: UInt64 = 0
}

/// Loopback-only review server. Retakes and consolidated exports stay in the
/// selected run; original fixtures and inference inputs are never overwritten.
final class EvalReviewServer: @unchecked Sendable {
    let root: URL
    let port: UInt16
    let catalog: URL?
    private let listener: Int32
    private let lock = NSLock()
    private var stopped = false
    private let tools = Tools()
    init(root: URL, port: UInt16, catalog: URL? = nil) throws {
        self.catalog = catalog
        self.root = root.resolvingSymlinksInPath()
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw ToolFailure("Could not create review socket") }
        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard bound == 0, listen(descriptor, 16) == 0 else { close(descriptor); throw ToolFailure("Could not listen on 127.0.0.1:\(port): \(String(cString: strerror(errno)))") }
        var actual = sockaddr_in(), size = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &actual) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &size) } }
        self.listener = descriptor
        self.port = UInt16(bigEndian: actual.sin_port)
    }
    deinit { stop() }
    func stop() {
        lock.lock(); defer { lock.unlock() }
        guard !stopped else { return }; stopped = true
        shutdown(listener, SHUT_RDWR); close(listener)
    }
    func serve() throws {
        while true {
            let client = accept(listener, nil, nil)
            if client < 0 {
                lock.lock(); let ending = stopped; lock.unlock()
                if ending { return }; if errno == EINTR { continue }
                throw ToolFailure("Review server accept failed")
            }
            var noSignal: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
            DispatchQueue.global().async { self.connection(client) }
        }
    }
    private func jsonResponse(_ object: Any, status: Int = 200) throws -> ReviewResponse {
        ReviewResponse(status: status, headers: ["Content-Type": "application/json; charset=utf-8"], body: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]))
    }
    private func contexts() throws -> [String: EvalItem] {
        guard let data = try tools.json(root.appendingPathComponent("recordings.json")) as? EvalItem,
              let recordings = data["recordings"] as? [EvalItem] else { throw ToolFailure("Invalid review recordings") }
        var result: [String: EvalItem] = [:]
        for recording in recordings {
            for p in recording["passages"] as? [EvalItem] ?? [] {
                guard let id = p["id"] as? String, let context = p["context"] as? EvalItem, result[id] == nil else { throw ToolFailure("Invalid or duplicate review passage") }
                result[id] = context
            }
        }
        return result
    }
    private func state() throws -> EvalItem {
        let file = root.appendingPathComponent("review-state.json")
        if !tools.fm.fileExists(atPath: file.path) { return ["version": 1, "reviews": EvalItem(), "archived_reviews": EvalItem()] }
        guard let value = try tools.json(file) as? EvalItem, value["version"] as? Int == 1,
              value["reviews"] as? [String: EvalItem] != nil else { throw ToolFailure("Invalid saved review state; original file preserved") }
        return value
    }
    private func sameContext(_ a: EvalItem?, _ b: EvalItem) -> Bool {
        guard let a else { return false }
        return NSDictionary(dictionary: a).isEqual(to: b)
    }
    func response(method: String, path rawPath: String, headers: [String: String], body: Data = Data()) throws -> ReviewResponse {
        guard ["127.0.0.1:\(port)", "localhost:\(port)"].contains(headers["host"] ?? "") else { return try jsonResponse(["error": "Invalid local host"], status: 400) }
        guard let path = String(rawPath.split(separator: "?", maxSplits: 1).first ?? "").removingPercentEncoding,
              !path.contains("\0"), !path.split(separator: "/").contains("..") else { return try jsonResponse(["error": "Invalid path"], status: 400) }
        if path == "/api/reviews", method == "GET" {
            var sessions: [EvalItem] = [["root": root.path, "url": "http://127.0.0.1:\(port)"]]
            if let catalog, let registered = try? tools.json(catalog) as? [EvalItem] { sessions = registered }
            var result: [EvalItem] = []
            for session in sessions {
                guard let folder = session["root"] as? String, let url = session["url"] as? String,
                      url.hasPrefix("http://127.0.0.1:"), let components = URLComponents(string: url), components.host == "127.0.0.1", components.port != nil,
                      let data = try? tools.json(URL(fileURLWithPath: folder).appendingPathComponent("recordings.json")) as? EvalItem else { continue }
                let state = (try? tools.json(URL(fileURLWithPath: folder).appendingPathComponent("review-state.json"))) as? EvalItem ?? [:]
                let saved = state["reviews"] as? [String: EvalItem] ?? [:]
                for recording in data["recordings"] as? [EvalItem] ?? [] {
                    let passages = recording["passages"] as? [EvalItem] ?? []
                    let verified = passages.filter { p in
                        guard let id = p["id"] as? String, let review = saved[id], ["matches", "corrected"].contains(review["status"] as? String ?? ""), let context = p["context"] as? EvalItem else { return false }
                        return sameContext(review["context"] as? EvalItem, context)
                    }.count
                    result.append(["title": recording["title"] ?? "Recording", "recording_id": recording["id"] ?? "", "url": url, "verified": verified, "total": passages.count, "next_passage": passages.first(where: { p in guard let id = p["id"] as? String else { return false }; return !["matches", "corrected"].contains(saved[id]?["status"] as? String ?? "") })?["id"] ?? passages.first?["id"] ?? "", "current": folder == root.path, "audio_sha256": recording["audio_sha256"] ?? "", "reference_sha256": recording["reference_sha256"] ?? "", "passages": passages, "saved": saved, "exports": state["consolidations"] ?? [], "carried_candidates": recording["carried_passages"] ?? []])
                }
            }
            for index in result.indices {
                let entry = result[index], passages = entry["passages"] as? [EvalItem] ?? [], saved = entry["saved"] as? [String: EvalItem] ?? [:]
                let exports = (entry["exports"] as? [EvalItem] ?? []).filter { $0["recording_id"] as? String == entry["recording_id"] as? String && $0["reference_sha256"] as? String == entry["reference_sha256"] as? String }
                var replaced: [String] = [], carried: [String] = [], resolved: [String] = []
                for passage in passages {
                    if let id = passage["id"] as? String, (entry["carried_candidates"] as? [String] ?? []).contains(id), saved[id] == nil { carried.append(id); resolved.append(id); continue }
                    guard let id = passage["id"] as? String, let review = saved[id], let context = passage["context"] as? EvalItem, sameContext(review["context"] as? EvalItem, context) else { continue }
                    if ["matches", "corrected"].contains(review["status"] as? String ?? "") { resolved.append(id); continue }
                    if let take = review["accepted_take_id"] as? String, exports.contains(where: { ($0["selections"] as? [String: String])?[id] == take }) { replaced.append(id); resolved.append(id) }
                }
                result[index]["replaced_passages"] = replaced
                result[index]["carried_passages"] = carried
                result[index]["resolved"] = resolved.count
                result[index]["complete"] = !passages.isEmpty && resolved.count == passages.count
                result[index]["next_passage"] = passages.first(where: { !resolved.contains($0["id"] as? String ?? "") })?["id"] ?? passages.first?["id"] ?? ""
                if let latest = exports.last, let followup = result.first(where: { $0["audio_sha256"] as? String == latest["audio_sha256"] as? String && $0["recording_id"] as? String != entry["recording_id"] as? String }) {
                    var mapping: [String: String] = [:]
                    for passage in passages {
                        if let id = passage["id"] as? String, let next = (followup["passages"] as? [EvalItem] ?? []).first(where: { $0["short_id"] as? String == passage["short_id"] as? String }), let nextID = next["id"] as? String { mapping[id] = nextID }
                    }
                    result[index]["followup"] = ["url": followup["url"] ?? "", "recording_id": followup["recording_id"] ?? "", "next_passage": followup["next_passage"] ?? "", "passages": mapping]
                }
            }
            for index in result.indices { for key in ["saved", "exports", "passages", "carried_candidates"] { result[index].removeValue(forKey: key) } }
            return try jsonResponse(["reviews": result])
        }
        if path == "/api/retakes" { return try saveRetake(method: method, headers: headers, body: body) }
        if path == "/api/consolidate" { return try consolidate(method: method, headers: headers, body: body) }
        if path == "/api/state" {
            lock.lock(); defer { lock.unlock() }
            let currentContexts = try contexts()
            var saved = try state()
            var reviews = saved["reviews"] as? [String: EvalItem] ?? [:]
            if method == "GET" {
                let active = reviews.filter { id, value in currentContexts[id].map { sameContext(value["context"] as? EvalItem, $0) } ?? false }
                var archived = saved["archived_reviews"] as? [String: EvalItem] ?? [:]
                for (id, value) in reviews where active[id] == nil { archived[id + "@inactive-reference"] = value }
                saved["reviews"] = active; saved["archived_reviews"] = archived
                return try jsonResponse(saved)
            }
            guard method == "POST" else { return try jsonResponse(["error": "Method not allowed"], status: 405) }
            guard headers["content-type"]?.lowercased().hasPrefix("application/json") == true,
                  headers["origin"].map({ $0 == "http://" + headers["host"]! }) ?? true else { return try jsonResponse(["error": "Invalid local JSON request"], status: 403) }
            guard body.count <= 100_000, let value = (try? JSONSerialization.jsonObject(with: body)) as? EvalItem,
                  let id = value["id"] as? String, let context = currentContexts[id],
                  let status = value["status"] as? String, ["pending", "matches", "corrected", "uncertain"].contains(status),
                  let words = value["words"] as? String, let notes = value["notes"] as? String,
                  words.count <= 30_000, notes.count <= 30_000,
                  status != "corrected" || !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return try jsonResponse(["error": "Choose a valid passage and write any corrected wording first"], status: 400) }
            guard sameContext(value["context"] as? EvalItem, context) else { return try jsonResponse(["error": "The audio or reference changed. Reload before saving this review."], status: 409) }
            if let previous = reviews[id], !sameContext(previous["context"] as? EvalItem, context) {
                var archived = saved["archived_reviews"] as? [String: EvalItem] ?? [:]
                archived[id + "@" + UUID().uuidString] = previous; saved["archived_reviews"] = archived
            }
            let prior = reviews[id].flatMap { sameContext($0["context"] as? EvalItem, context) ? $0 : nil } ?? [:]
            var takes = prior["retakes"] as? [EvalItem] ?? []
            if let ranges = value["retake_ranges"] as? [String: EvalItem] {
                for (takeID, range) in ranges {
                    guard let index = takes.firstIndex(where: { $0["id"] as? String == takeID }),
                          let start = range["start"] as? Double, let end = range["end"] as? Double,
                          let lower = context["start_seconds"] as? Double, let upper = context["end_seconds"] as? Double,
                          start.isFinite, end.isFinite, start >= lower, end <= upper, start < end else { return try jsonResponse(["error": "Keep each replacement range inside its original passage"], status: 400) }
                    takes[index]["replace_start_seconds"] = start; takes[index]["replace_end_seconds"] = end
                    takes[index]["range_revision"] = (takes[index]["range_revision"] as? Int ?? 0) + 1
                }
            }
            let accepted = value.keys.contains("accepted_take_id") ? value["accepted_take_id"] as? String : prior["accepted_take_id"] as? String
            guard accepted == nil || takes.contains(where: { $0["id"] as? String == accepted }) else { return try jsonResponse(["error": "Unknown replacement take"], status: 400) }
            let issue = value["audio_issue"] as? Bool ?? prior["audio_issue"] as? Bool ?? false
            let entry: EvalItem = ["status": status, "words": words, "notes": notes, "context": context, "audio_issue": issue, "retakes": takes, "accepted_take_id": accepted as Any? ?? NSNull(), "updated_at": ISO8601DateFormatter().string(from: Date())]
            reviews[id] = entry; saved["reviews"] = reviews
            try JSONSerialization.data(withJSONObject: saved, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: root.appendingPathComponent("review-state.json"), options: .atomic)
            return try jsonResponse(entry)
        }
        guard method == "GET" || method == "HEAD" else { return try jsonResponse(["error": "Method not allowed"], status: 405) }
        let relative = path == "/" ? "index.html" : String(path.dropFirst())
        let allowed = ["index.html", "style.css", "app.js", "recordings.json", "audio-capture.mjs", "review-passages.mjs"].contains(relative) || ["assets/audio/", "assets/retakes/", "assets/consolidated/"].contains(where: relative.hasPrefix)
        let file = root.appendingPathComponent(relative).resolvingSymlinksInPath()
        guard allowed, file.path.hasPrefix(root.path + "/"), tools.fm.fileExists(atPath: file.path),
              let size = (try tools.fm.attributesOfItem(atPath: file.path))[.size] as? UInt64 else { return try jsonResponse(["error": "Not found"], status: 404) }
        let types = ["html": "text/html; charset=utf-8", "css": "text/css; charset=utf-8", "js": "text/javascript; charset=utf-8", "mjs": "text/javascript; charset=utf-8", "json": "application/json; charset=utf-8", "m4a": "audio/mp4", "wav": "audio/wav", "mp3": "audio/mpeg", "mov": "video/quicktime", "qt": "video/quicktime", "qta": "video/quicktime"]
        var result = ReviewResponse(headers: ["Content-Type": types[file.pathExtension] ?? "application/octet-stream", "Accept-Ranges": "bytes"], file: file, length: size)
        if let range = headers["range"] {
            guard range.hasPrefix("bytes="), !range.contains(","), size > 0 else { return ReviewResponse(status: 416, headers: ["Content-Range": "bytes */\(size)"]) }
            let parts = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 2 else { return ReviewResponse(status: 416, headers: ["Content-Range": "bytes */\(size)"]) }
            let start: UInt64, end: UInt64
            if parts[0].isEmpty {
                guard let suffix = UInt64(parts[1]), suffix > 0 else { return ReviewResponse(status: 416, headers: ["Content-Range": "bytes */\(size)"]) }
                start = size - min(size, suffix); end = size - 1
            } else {
                guard let first = UInt64(parts[0]), first < size,
                      parts[1].isEmpty || UInt64(parts[1]) != nil else { return ReviewResponse(status: 416, headers: ["Content-Range": "bytes */\(size)"]) }
                start = first; end = min(UInt64(parts[1]) ?? size - 1, size - 1)
                guard end >= start else { return ReviewResponse(status: 416, headers: ["Content-Range": "bytes */\(size)"]) }
            }
            result.status = 206; result.offset = start; result.length = end - start + 1
            result.headers["Content-Range"] = "bytes \(start)-\(end)/\(size)"
        }
        return result
    }
    private func sendAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { bytes in
            var sent = 0
            while sent < bytes.count {
                let amount = Darwin.send(fd, bytes.baseAddress!.advanced(by: sent), bytes.count - sent, 0)
                if amount < 0 && errno == EINTR { continue }
                guard amount > 0 else { throw ToolFailure("Review client disconnected") }; sent += amount
            }
        }
    }
    private func connection(_ fd: Int32) {
        defer { close(fd) }
        var timeout = timeval(tv_sec: 15, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        do {
            var request = Data(), buffer = [UInt8](repeating: 0, count: 8192), headerEnd: Range<Data.Index>?
            while headerEnd == nil && request.count < 65_536 {
                let count = recv(fd, &buffer, buffer.count, 0); guard count > 0 else { return }
                request.append(contentsOf: buffer.prefix(count)); headerEnd = request.range(of: Data("\r\n\r\n".utf8))
            }
            guard let headerEnd else { return }
            let lines = String(decoding: request[..<headerEnd.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
            let first = lines[0].split(separator: " ")
            guard first.count == 3 else { return }
            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                guard let colon = line.firstIndex(of: ":") else { return }
                let key = line[..<colon].lowercased(); guard headers[key] == nil else { return }
                headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            }
            let maximum = first[1] == "/api/retakes" ? 35_000_000 : 100_000
            guard let count = Int(headers["content-length"] ?? "0"), count >= 0, count <= maximum else { return }
            var body = Data(request[headerEnd.upperBound...])
            while body.count < count { let read = recv(fd, &buffer, min(buffer.count, count - body.count), 0); guard read > 0 else { return }; body.append(contentsOf: buffer.prefix(read)) }
            let result: ReviewResponse
            do { result = try response(method: String(first[0]), path: String(first[1]), headers: headers, body: body) }
            catch { result = try jsonResponse(["error": String(describing: error)], status: 500) }
            let length = result.file != nil ? result.length : UInt64(result.body.count)
            var output = "HTTP/1.1 \(result.status) \(HTTPURLResponse.localizedString(forStatusCode: result.status))\r\nContent-Length: \(length)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n"
            for (key, value) in result.headers { output += "\(key): \(value)\r\n" }
            try sendAll(fd, Data((output + "\r\n").utf8))
            if first[0] == "HEAD" { return }
            if let file = result.file {
                let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }; try handle.seek(toOffset: result.offset)
                var left = length
                while left > 0 { guard let chunk = try handle.read(upToCount: Int(min(left, 65_536))), !chunk.isEmpty else { break }; try sendAll(fd, chunk); left -= UInt64(chunk.count) }
            } else { try sendAll(fd, result.body) }
        } catch { /* Disconnects leave the saved review state intact. */ }
    }
}


extension EvalReviewServer {
    private func localJSON(_ method: String, _ headers: [String: String]) -> Bool {
        method == "POST" && headers["content-type"]?.lowercased().hasPrefix("application/json") == true && (headers["origin"].map { $0 == "http://" + (headers["host"] ?? "") } ?? true)
    }
    private func saveRetake(method: String, headers: [String: String], body: Data) throws -> ReviewResponse {
        guard localJSON(method, headers) else { return try jsonResponse(["error": "Use a local JSON recording request"], status: 403) }
        lock.lock(); defer { lock.unlock() }
        guard body.count <= 35_000_000, let value = (try? JSONSerialization.jsonObject(with: body)) as? EvalItem,
              let id = value["id"] as? String, let context = try contexts()[id],
              let encoded = value["audio_base64"] as? String, let data = Data(base64Encoded: encoded), data.count >= 44, data.count <= 20_000_000,
              String(data: data.prefix(4), encoding: .ascii) == "RIFF", String(data: data[8..<12], encoding: .ascii) == "WAVE",
              let start = value["replace_start_seconds"] as? Double, let end = value["replace_end_seconds"] as? Double,
              let lower = context["start_seconds"] as? Double, let upper = context["end_seconds"] as? Double,
              start.isFinite, end.isFinite, start >= lower, end <= upper, start < end else { return try jsonResponse(["error": "Choose a valid passage range and record WAV audio (up to ten minutes)"], status: 400) }
        guard sameContext(value["context"] as? EvalItem, context) else { return try jsonResponse(["error": "The reference changed. Reload before saving this take."], status: 409) }
        let uuid = UUID().uuidString.lowercased(), relative = "assets/retakes/" + uuid + ".wav", file = root.appendingPathComponent(relative)
        try tools.mkdir(file.deletingLastPathComponent()); try data.write(to: file, options: .atomic)
        var valid = false
        defer { if !valid { try? tools.fm.removeItem(at: file) } }
        guard let audio = try? AVAudioFile(forReading: file), audio.processingFormat.channelCount == 1, audio.processingFormat.sampleRate == 16_000 else { return try jsonResponse(["error": "Record mono 16 kHz WAV audio"], status: 400) }
        let duration = Double(audio.length) / audio.processingFormat.sampleRate
        guard duration >= 0.1 && duration <= 600.1 else { return try jsonResponse(["error": "The recording must be between 0.1 seconds and ten minutes"], status: 400) }
        var saved = try state(), reviews = saved["reviews"] as? [String: EvalItem] ?? [:]
        var entry = reviews[id] ?? ["status": "pending", "words": "", "notes": ""]
        if !sameContext(entry["context"] as? EvalItem, context), reviews[id] != nil {
            var archived = saved["archived_reviews"] as? [String: EvalItem] ?? [:]; archived[id + "@" + uuid] = entry; saved["archived_reviews"] = archived
            entry = ["status": "pending", "words": "", "notes": ""]
        }
        let take: EvalItem = ["id": uuid, "audio": relative, "sha256": try tools.hash(file), "duration_seconds": duration, "replace_start_seconds": start, "replace_end_seconds": end, "created_at": ISO8601DateFormatter().string(from: Date())]
        var takes = entry["retakes"] as? [EvalItem] ?? []; takes.append(take)
        entry["retakes"] = takes; entry["audio_issue"] = true; entry["status"] = "uncertain"; entry["context"] = context
        reviews[id] = entry; saved["reviews"] = reviews
        try JSONSerialization.data(withJSONObject: saved, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: root.appendingPathComponent("review-state.json"), options: .atomic)
        valid = true
        return try jsonResponse(entry)
    }
    private func consolidate(method: String, headers: [String: String], body: Data) throws -> ReviewResponse {
        guard localJSON(method, headers), body.count <= 100_000,
              let value = (try? JSONSerialization.jsonObject(with: body)) as? EvalItem,
              let id = value["recording_id"] as? String, let selections = value["selections"] as? [String: String], !selections.isEmpty else { return try jsonResponse(["error": "Select replacement takes before combining"], status: 400) }
        lock.lock()
        let source: URL, splices: [ReviewSplice], referenceHash: String
        do {
            let current = try contexts()
            guard let data = try tools.json(root.appendingPathComponent("recordings.json")) as? EvalItem,
                  let recording = (data["recordings"] as? [EvalItem])?.first(where: { $0["id"] as? String == id }),
                  let relative = recording["audio"] as? String, relative.hasPrefix("assets/audio/"),
                  let originalHash = recording["audio_sha256"] as? String else { throw ToolFailure("Unknown recording") }
            source = root.appendingPathComponent(relative).resolvingSymlinksInPath()
            guard source.path.hasPrefix(root.path + "/assets/audio/"), try tools.hash(source) == originalHash else { throw ToolFailure("The original recording changed") }
            referenceHash = recording["reference_sha256"] as? String ?? ""
            let passages = recording["passages"] as? [EvalItem] ?? [], reviews = try state()["reviews"] as? [String: EvalItem] ?? [:]
            var result: [ReviewSplice] = []
            for (passageID, takeID) in selections {
                guard passages.contains(where: { $0["id"] as? String == passageID }), let entry = reviews[passageID], let context = current[passageID],
                      sameContext(entry["context"] as? EvalItem, context), entry["accepted_take_id"] as? String == takeID,
                      let take = (entry["retakes"] as? [EvalItem])?.first(where: { $0["id"] as? String == takeID }),
                      UUID(uuidString: takeID) != nil, let audio = take["audio"] as? String, audio == "assets/retakes/" + takeID + ".wav",
                      let start = take["replace_start_seconds"] as? Double, let end = take["replace_end_seconds"] as? Double,
                      let expectedHash = take["sha256"] as? String else { throw ToolFailure("A selected take is missing or no longer approved") }
                let file = root.appendingPathComponent(audio).resolvingSymlinksInPath()
                guard file.path.hasPrefix(root.path + "/assets/retakes/"), try tools.hash(file) == expectedHash else { throw ToolFailure("A selected take changed") }
                result.append(ReviewSplice(passageID: passageID, takeID: takeID, start: start, end: end, file: file))
            }
            splices = result
            lock.unlock()
        } catch { lock.unlock(); return try jsonResponse(["error": String(describing: error)], status: 409) }
        let uuid = UUID().uuidString.lowercased(), relative = "assets/consolidated/" + uuid + ".m4a"
        let result: ReviewAudioResult
        do { result = try tools.consolidateReviewAudio(source: source, splices: splices, destination: root.appendingPathComponent(relative)) }
        catch { return try jsonResponse(["error": String(describing: error)], status: 400) }
        let export: EvalItem = ["id": uuid, "recording_id": id, "audio": relative, "edit_map": "assets/consolidated/" + uuid + ".json", "reference_sha256": referenceHash, "audio_sha256": try tools.hash(result.audio), "created_at": ISO8601DateFormatter().string(from: Date()), "selections": selections]
        lock.lock(); defer { lock.unlock() }
        var saved = try state(), exports = saved["consolidations"] as? [EvalItem] ?? []; exports.append(export); saved["consolidations"] = exports
        try JSONSerialization.data(withJSONObject: saved, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: root.appendingPathComponent("review-state.json"), options: .atomic)
        return try jsonResponse(export)
    }
}
