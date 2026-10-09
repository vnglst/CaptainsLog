import Foundation
import Yams

extension Tools {
    func yamlMapping(_ text: String) throws -> [String: Any] {
        var documents = try Yams.compose_all(yaml: text)
        var roots: [Node] = []
        while let node = documents.next() { roots.append(node) }
        if let error = documents.error {
            if String(describing: error).contains("duplicated key") { throw ToolFailure("duplicate YAML keys") }
            throw error
        }
        try require(roots.count == 1 && roots[0].mapping != nil, "expected one YAML mapping")
        var anchors = Set<ObjectIdentifier>()
        func safe(_ node: Node) throws {
            if let anchor = node.anchor { try require(anchors.insert(ObjectIdentifier(anchor)).inserted, "YAML aliases are not permitted") }
            switch node {
            case .alias: throw ToolFailure("YAML aliases are not permitted")
            case .scalar: try require(["tag:yaml.org,2002:str", "tag:yaml.org,2002:int", "tag:yaml.org,2002:float", "tag:yaml.org,2002:bool", "tag:yaml.org,2002:null"].contains(node.tag.rawValue), "non-basic YAML type")
            case .sequence(let sequence): for value in sequence { try safe(value) }
            case .mapping(let mapping):
                var keys = Set<String>()
                for pair in mapping {
                    try require(pair.key.scalar != nil && pair.key.tag.rawValue == "tag:yaml.org,2002:str", "frontmatter keys must be scalar strings")
                    let key = pair.key.string!
                    try require(keys.insert(key).inserted, "duplicate YAML keys")
                    try safe(pair.value)
                }
            }
        }
        try safe(roots[0])
        guard let value = roots[0].any as? [String: Any] else { throw ToolFailure("expected one YAML mapping") }
        return value
    }
    func frontmatter(_ output: String, strict: Bool = false) throws -> (String, String) {
        let pattern = strict ? "(?s)\\A---\\n(.*?)\\n---\\n\\n(.*)\\z" : "(?s)\\A---\\r?\\n(.*?)\\r?\\n---\\r?\\n\\r?\\n(.*)\\z"
        guard let yaml = match(pattern, output, group: 1), let body = match(pattern, output, group: 2) else { throw ToolFailure("missing YAML frontmatter or body separator") }
        return (yaml, body)
    }
    func expectedFrontmatter(_ url: URL) throws -> [String: Any] {
        guard let yaml = match("(?s)\\A---\\r?\\n(.*?)\\r?\\n---", try read(url), group: 1) else { throw ToolFailure("expected file has no frontmatter") }
        return try yamlMapping(yaml)
    }
    func validateCaseInput(_ url: URL, _ settings: [String: Any]) throws {
        guard let value = settings["sha256"] else { return }
        try require(value is String && match("\\A[0-9a-f]{64}\\z", value as? String ?? "") != nil, "invalid fixture SHA256")
        try require(try hash(url) == value as? String, "regression fixture changed: \(url.path)")
    }
    func validateEnrichCases(_ manifest: URL, _ input: URL) throws {
        guard let cases = try json(manifest) as? [String: [String: Any]] else { throw ToolFailure("case manifest differs from enrichment inputs") }
        let names = files(input).filter { $0.pathExtension == "md" }.map { $0.deletingPathExtension().lastPathComponent }.sorted()
        try require(cases.keys.sorted() == names, "case manifest differs from enrichment inputs")
        for name in names { try validateCaseInput(input.appendingPathComponent(name + ".md"), cases[name]!) }
    }
    @discardableResult func validateEnrich(_ input: String, _ output: String, _ expected: [String: Any]) throws -> [String: Any] {
        let (yaml, body) = try frontmatter(output)
        try require(body.utf8.elementsEqual(input.utf8), "source body changed")
        try require(yaml.utf8.count <= 12000, "metadata exceeds 12000 bytes")
        let value = try yamlMapping(yaml)
        let keys = ["date", "recording_time", "language", "categories", "tags", "persons", "projects", "companies", "entities", "summary"]
        try require(value.keys.sorted() == keys.sorted(), "unexpected or missing schema keys")
        for key in ["date", "recording_time", "language", "summary"] { try require(value[key] is String && !(value[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(key) must be nonempty text") }
        for key in ["date", "recording_time"] { try require(value[key] as? String == expected[key] as? String, "\(key) differs from supplied value") }
        try require((value["summary"] as! String).count <= 3000, "summary exceeds 3000 characters")
        var lists: [String: [String]] = [:]
        for key in ["categories", "tags", "persons", "projects", "companies", "entities"] {
            guard let list = value[key] as? [String], list.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw ToolFailure("\(key) must contain strings") }
            try require(list.count <= 64, "\(key) exceeds 64 items")
            let normalized = list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            try require(Set(normalized).count == normalized.count, "duplicate \(key)")
            lists[key] = normalized
        }
        try require(!lists["categories"]!.isEmpty && Set(lists["categories"]!).isSubset(of: ["personal", "work", "side-project"]), "invalid categories")
        try require((value["language"] as! String).lowercased() == (expected["language"] as? String)?.lowercased(), "language differs from fixture expectation")
        try require((3...8).contains(lists["tags"]!.count), "expected 3 to 8 tags")
        let named = Set(["persons", "projects", "companies"].flatMap { lists[$0]! })
        try require(named.isDisjoint(with: lists["entities"]!), "entity duplicates a person, project or company")
        return value
    }
    func testEnrichValidator() throws {
        let input = try read(path("eval/enrich/input/01_work_week.md")), expected = try expectedFrontmatter(path("eval/enrich/expected/01_work_week.md"))
        var passed = 0
        func check(_ name: String, _ failure: String? = nil, _ mutate: (inout [String: Any], inout String) throws -> String?) throws {
            var data = expected, body = input
            let raw = try mutate(&data, &body)
            let output = try raw ?? "---\n" + Yams.dump(object: data) + "---\n\n" + body
            do { try validateEnrich(input, output, expected); if failure != nil { throw ToolFailure("\(name): accepted invalid output") } }
            catch { guard let failure, String(describing: error).contains(failure) else { throw ToolFailure("\(name): \(error)") } }
            passed += 1; print("PASS: \(name)")
        }
        try check("valid fixture") { _, _ in nil }
        try check("wrong date", "date differs") { d, _ in d["date"] = "2024-01-01"; return nil }
        try check("wrong time", "recording_time differs") { d, _ in d["recording_time"] = "09:00"; return nil }
        try check("body mutation", "source body changed") { _, b in b += "added text"; return nil }
        try check("missing summary", "schema keys") { d, _ in d.removeValue(forKey: "summary"); return nil }
        try check("unexpected key", "schema keys") { d, _ in d["extra"] = "text"; return nil }
        try check("empty summary", "summary must be nonempty") { d, _ in d["summary"] = " "; return nil }
        try check("repeated summary", "summary exceeds") { d, _ in d["summary"] = String(repeating: "Repeated sentence. ", count: 200); return nil }
        try check("unquoted colon becomes mapping", "entities must contain strings") { d, _ in d["entities"] = [["Star Trek": "The Next Generation"]]; return nil }
        try check("scalar list", "projects must contain strings") { d, _ in d["projects"] = "FinanceHub"; return nil }
        try check("duplicate list item", "duplicate projects") { d, _ in d["projects"] = (d["projects"] as! [String]) + ["financehub"]; return nil }
        try check("cross-field duplicate", "entity duplicates") { d, _ in d["entities"] = (d["entities"] as! [String]) + ["FinanceHub"]; return nil }
        try check("runaway entity list", "entities exceeds") { d, _ in d["entities"] = (1...65).map { "Entity \($0)" }; return nil }
        try check("oversized metadata", "metadata exceeds") { d, _ in d["entities"] = [String(repeating: "x", count: 12000)]; return nil }
        try check("invalid category", "invalid categories") { d, _ in d["categories"] = ["imaginary"]; return nil }
        try check("empty categories", "invalid categories") { d, _ in d["categories"] = [String](); return nil }
        try check("legal category differences require semantic review") { d, _ in d["categories"] = ["work"]; return nil }
        try check("wrong language", "language differs") { d, _ in d["language"] = "Dutch"; return nil }
        try check("too many tags", "3 to 8 tags") { d, _ in d["tags"] = (1...9).map { "tag-\($0)" }; return nil }
        let yaml = try Yams.dump(object: expected)
        try check("duplicate schema key", "duplicate YAML keys") { _, _ in "---\n" + yaml + "summary: duplicate\n---\n\n" + input }
        try check("missing completion/body delimiter", "missing YAML frontmatter") { _, _ in "---\n" + yaml }
        try check("multiple YAML documents", "expected one YAML mapping") { _, _ in "---\n" + yaml + "...\n---\nsummary: second\n---\n\n" + input }
        let dir = try temporary("enrich-fixture-integrity-"); defer { try? fm.removeItem(at: dir) }
        let file = dir.appendingPathComponent("fixture.md"), manifest = dir.appendingPathComponent("cases.json")
        try write(file, input); try json(manifest, ["fixture": ["sha256": hash(file)]])
        try validateEnrichCases(manifest, dir); passed += 1; print("PASS: recorded fixture fingerprint")
        try write(file, input + "\n")
        do { try validateEnrichCases(manifest, dir); throw ToolFailure("accepted a reformatted regression fixture") } catch { try require(String(describing: error).contains("regression fixture changed"), "Wrong fingerprint failure") }
        passed += 1; print("PASS: even a trailing newline changes regression fixture identity")
        try write(file, input); try write(dir.appendingPathComponent("unlisted.md"), input)
        do { try validateEnrichCases(manifest, dir); throw ToolFailure("accepted input missing from manifest") } catch { try require(String(describing: error).contains("case manifest differs"), "Wrong manifest failure") }
        passed += 1; print("PASS: every input must have recorded case settings")
        print("\(passed) enrichment validation checks passed.")
    }
    func testEnrichEval() throws {
        let cl = environment["CAPTAINS_LOG_EVAL_CL"] ?? path(".build/debug/cl").path
        try require(fm.isExecutableFile(atPath: cl), "Build cl before running this model-free check.", status: 2)
        let dir = try temporary("enrich-eval-checks-", in: path("tmp")); try isolated(dir)
        try testEnrichValidator(); try validateEnrichCases(path("eval/enrich/cases.json"), path("eval/enrich/input"))
        print("PASS: enrichment case manifest and regression fixture fingerprints")
        for seed in ["0", "42", "4294967294"] {
            let result = try run([cl, "enrich", "--input", "eval/enrich/input/01_work_week.md", "--seed", seed, "--print-prompt"], quiet: true, log: dir.appendingPathComponent("seed-\(seed).txt"))
            try require(result.output.contains("FinanceHub"), "Valid seed prompt lacks fixture content: \(seed)")
        }
        for seed in ["-1", "4294967295", "4294967296"] {
            let result = try run([cl, "enrich", "--input", "eval/enrich/input/01_work_week.md", "--seed", seed, "--print-prompt"], quiet: true, allowFailure: true, log: dir.appendingPathComponent("invalid-\(seed).txt"))
            try require(result.status != 0 && match("Error:.*(seed|Seed)", result.output) != nil, "Invalid seed was accepted: \(seed)")
        }
        print("PASS: seed boundaries and reserved random-seed rejection; no model loaded.")
    }
}
