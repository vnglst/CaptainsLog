import Foundation

struct Options {
    var expectedPath: String = ""
    var generatedPath: String = ""
}

func parseArgs() -> Options {
    var opts = Options()
    let args = CommandLine.arguments
    var i = 1
    while i < args.count {
        switch args[i] {
        case "--expected":
            i += 1
            if i < args.count { opts.expectedPath = args[i] }
        case "--generated":
            i += 1
            if i < args.count { opts.generatedPath = args[i] }
        default:
            break
        }
        i += 1
    }
    return opts
}

func readFile(_ path: String) -> String? {
    return try? String(contentsOfFile: path, encoding: .utf8)
}

func extractFrontmatter(_ content: String) -> [String: [String]] {
    var result: [String: [String]] = [:]
    let lines = content.components(separatedBy: .newlines)
    guard lines.count >= 3, lines[0].trimmingCharacters(in: .whitespaces) == "---" else {
        return result
    }
    
    var i = 1
    var currentKey: String? = nil
    var currentValues: [String] = []
    
    while i < lines.count {
        let line = lines[i]
        if line.trimmingCharacters(in: .whitespaces) == "---" {
            if let key = currentKey {
                result[key] = currentValues
            }
            break
        }
        
        if line.hasPrefix("  - ") || line.hasPrefix("- ") {
            let value = line.replacingOccurrences(of: "  - ", with: "")
                .replacingOccurrences(of: "- ", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !value.isEmpty && value != "[]" {
                currentValues.append(value)
            }
        } else if line.contains(":") {
            if let key = currentKey {
                result[key] = currentValues
            }
            let parts = line.split(separator: ":", maxSplits: 1)
            currentKey = String(parts[0]).trimmingCharacters(in: .whitespaces)
            currentValues = []
            if parts.count > 1 {
                let val = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty && !val.hasPrefix("\n") && val != "[]" {
                    // Strip surrounding quotes if present
                    var cleanVal = val
                    if cleanVal.hasPrefix("\"") && cleanVal.hasSuffix("\"") {
                        cleanVal = String(cleanVal.dropFirst().dropLast())
                    }
                    if !cleanVal.isEmpty {
                        currentValues.append(cleanVal)
                    }
                }
            }
        }
        i += 1
    }
    
    if let key = currentKey, result[key] == nil {
        result[key] = currentValues
    }
    
    return result
}

func compareLists(expected: [String], generated: [String]) -> (missing: [String], extra: [String]) {
    let expSet = Set(expected.map { $0.lowercased() })
    let genSet = Set(generated.map { $0.lowercased() })
    let missing = expected.filter { !genSet.contains($0.lowercased()) }
    let extra = generated.filter { !expSet.contains($0.lowercased()) }
    return (missing, extra)
}

func main() {
    let opts = parseArgs()
    guard !opts.expectedPath.isEmpty, !opts.generatedPath.isEmpty else {
        print("Usage: swift compare.swift --expected <path> --generated <path>")
        exit(1)
    }
    
    guard let expectedRaw = readFile(opts.expectedPath) else {
        print("ERROR: Cannot read expected file: \(opts.expectedPath)")
        exit(1)
    }
    guard let generatedRaw = readFile(opts.generatedPath) else {
        print("ERROR: Cannot read generated file: \(opts.generatedPath)")
        exit(1)
    }
    
    let expected = extractFrontmatter(expectedRaw)
    let generated = extractFrontmatter(generatedRaw)
    
    let listKeys = ["categories", "tags", "persons", "projects", "companies", "entities"]
    let stringKeys = ["date", "recording_time", "language", "summary"]
    let allKeys = Set(listKeys + stringKeys)
    
    print("# Enrich Comparison")
    print("")
    
    for key in allKeys.sorted() {
        let expVals = expected[key] ?? []
        let genVals = generated[key] ?? []
        
        print("## \(key.capitalized)")
        print("")
        
        if listKeys.contains(key) {
            let (missing, extra) = compareLists(expected: expVals, generated: genVals)
            if missing.isEmpty && extra.isEmpty {
                print("✅ Match (\(expVals.count) items)")
            } else {
                if !missing.isEmpty {
                    print("**Missing from generated:**")
                    for v in missing {
                        print("- \(v)")
                    }
                }
                if !extra.isEmpty {
                    print("**Extra in generated:**")
                    for v in extra {
                        print("- \(v)")
                    }
                }
            }
        } else {
            let expStr = expVals.first ?? "(empty)"
            let genStr = genVals.first ?? "(empty)"
            if expStr.lowercased() == genStr.lowercased() {
                print("✅ Match")
            } else {
                print("**Expected**: \(expStr)")
                print("**Generated**: \(genStr)")
            }
        }
        print("")
    }
    
    print("## Notes")
    print("")
    print("- This script performs case-insensitive list comparison. Semantic quality (e.g. summary accuracy, whether tags are truly grounded) must be verified manually by reading the input content.")
    print("- Keys present in only one file are shown as empty in the other.")
}

main()
