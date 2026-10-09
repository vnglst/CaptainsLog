import Foundation
import CryptoKit
import Darwin

struct ToolFailure: Error, CustomStringConvertible {
    let description: String
    let status: Int32
    init(_ message: String, status: Int32 = 1) { description = message; self.status = status }
}
struct CommandResult { let status: Int32; let output: String }
final class Tools {
    let fm = FileManager.default
    let root: URL
    var environment: [String: String]
    init(root: URL? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
        self.root = root ?? environment["CAPTAINS_LOG_TOOLS_ROOT"].map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    func path(_ value: String) -> URL { value.hasPrefix("/") ? URL(fileURLWithPath: value) : root.appendingPathComponent(value) }
    func exists(_ value: String) -> Bool { fm.fileExists(atPath: path(value).path) }
    func mkdir(_ url: URL) throws { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
    func read(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }
    func write(_ url: URL, _ value: String) throws { try mkdir(url.deletingLastPathComponent()); try value.write(to: url, atomically: true, encoding: .utf8) }
    func json(_ url: URL) throws -> Any { try JSONSerialization.jsonObject(with: Data(contentsOf: url)) }
    func json(_ url: URL, _ value: Any) throws { try mkdir(url.deletingLastPathComponent()); try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: url); let f = try FileHandle(forWritingTo: url); try f.seekToEnd(); try f.write(contentsOf: Data([10])); try f.close() }
    func copy(_ source: URL, _ destination: URL) throws { try mkdir(destination.deletingLastPathComponent()); if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }; try fm.copyItem(at: source, to: destination) }
    func temporary(_ prefix: String, in directory: URL? = nil) throws -> URL { let url = (directory ?? fm.temporaryDirectory).appendingPathComponent(prefix + UUID().uuidString); try mkdir(url); return url }
    func files(_ directory: URL, recursive: Bool = false) -> [URL] {
        guard fm.fileExists(atPath: directory.path) else { return [] }
        let candidates = recursive ? (fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? []) : ((try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])) ?? [])
        return candidates.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.sorted { $0.path < $1.path }
    }
    func hash(_ file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        var digest = SHA256()
        while try autoreleasepool(invoking: {
            guard let data = try handle.read(upToCount: 1_048_576), !data.isEmpty else { return false }
            digest.update(data: data)
            return true
        }) {}
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func hashes(_ files: [URL]) throws -> [String: String] { try Dictionary(uniqueKeysWithValues: files.sorted { $0.path < $1.path }.map { ($0.path, try hash($0)) }) }
    func isolated(_ directory: URL) throws {
        let data = directory.appendingPathComponent("data"), config = directory.appendingPathComponent("config.json")
        try mkdir(data); try json(config, ["schemaVersion": 1, "dataDir": data.path])
        environment["CAPTAINS_LOG_CONFIG_PATH"] = config.path; environment["CAPTAINS_LOG_DATA_DIR"] = data.path
    }
    @discardableResult func run(_ args: [String], quiet: Bool = false, allowFailure: Bool = false, log: URL? = nil, environment overrides: [String: String] = [:], directory: URL? = nil) throws -> CommandResult {
        try require(!args.isEmpty, "Missing command")
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env"); process.arguments = args
        process.currentDirectoryURL = directory ?? root; process.environment = environment.merging(overrides) { _, new in new }
        process.standardOutput = pipe; process.standardError = pipe; process.standardInput = FileHandle.standardInput
        var logger: FileHandle?
        if let log { try mkdir(log.deletingLastPathComponent()); fm.createFile(atPath: log.path, contents: nil); logger = try FileHandle(forWritingTo: log) }
        defer { try? logger?.close() }
        try process.run(); var output = Data()
        while let chunk = try pipe.fileHandleForReading.read(upToCount: 65536), !chunk.isEmpty {
            output.append(chunk); try logger?.write(contentsOf: chunk)
            if !quiet { FileHandle.standardOutput.write(chunk) }
        }
        process.waitUntilExit()
        let result = CommandResult(status: process.terminationStatus, output: String(decoding: output, as: UTF8.self))
        if !allowFailure && result.status != 0 { throw ToolFailure("Command failed (\(result.status)): \(args.joined(separator: " "))" + (log.map { "; see \($0.path)" } ?? ""), status: result.status) }
        return result
    }
    func capture(_ args: [String]) throws -> String {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env"); process.arguments = args
        process.currentDirectoryURL = root; process.environment = environment
        process.standardOutput = pipe; process.standardError = FileHandle.standardError
        try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        try require(process.terminationStatus == 0, "Failed: " + args.joined(separator: " "))
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func require(_ condition: @autoclosure () throws -> Bool, _ message: String, status: Int32 = 1) throws { if try !condition() { throw ToolFailure(message, status: status) } }
    func match(_ pattern: String, _ text: String, group: Int = 0) -> String? { guard let regex = try? NSRegularExpression(pattern: pattern), let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), group < m.numberOfRanges, let range = Range(m.range(at: group), in: text) else { return nil }; return String(text[range]) }
    func sameFiles(_ first: URL, _ second: URL) throws -> Bool {
        let a = files(first, recursive: true), b = files(second, recursive: true)
        let relative: (URL, URL) -> String = { $0.path.replacingOccurrences(of: $1.path + "/", with: "") }
        let ah = try Dictionary(uniqueKeysWithValues: a.map { (relative($0, first), try hash($0)) })
        let bh = try Dictionary(uniqueKeysWithValues: b.map { (relative($0, second), try hash($0)) })
        return ah == bh
    }
}
