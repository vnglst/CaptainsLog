#!/usr/bin/env swift

import Foundation

// Quick comparison helper - outputs raw word differences
// AGENT: Use this as a starting point, but VERIFY by reading the files yourself
// Usage: swift compare.swift --expected <path> --generated <path>

struct Config {
    let expectedPath: String
    let generatedPath: String
}

func parseArgs() -> Config? {
    let args = CommandLine.arguments
    var expectedPath: String?
    var generatedPath: String?
    
    var i = 1
    while i < args.count {
        switch args[i] {
        case "--expected":
            i += 1
            expectedPath = i < args.count ? args[i] : nil
        case "--generated":
            i += 1
            generatedPath = i < args.count ? args[i] : nil
        default:
            break
        }
        i += 1
    }
    
    guard let expected = expectedPath,
          let generated = generatedPath else {
        return nil
    }
    
    return Config(expectedPath: expected, generatedPath: generated)
}

func normalize(_ text: String) -> [String] {
    // First, normalize newlines to spaces before filtering
    let withSpaces = text
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
    
    let allowed = CharacterSet.letters
        .union(.decimalDigits)
        .union(CharacterSet(charactersIn: "'"))
        .union(CharacterSet.whitespaces)
    
    let filtered = withSpaces.unicodeScalars
        .filter { allowed.contains($0) }
        .map { String($0) }
        .joined()
    
    return filtered.lowercased()
        .components(separatedBy: .whitespaces)
        .filter { !$0.isEmpty }
}

func compare(expected: String, generated: String) -> (substitutions: [(String, String)], missing: [String], extra: [String]) {
    let expWords = normalize(expected)
    let genWords = normalize(generated)
    
    var substitutions: [(String, String)] = []
    var missing: [String] = []
    var extra: [String] = []
    
    var eIdx = 0
    var gIdx = 0
    
    while eIdx < expWords.count && gIdx < genWords.count {
        if expWords[eIdx] == genWords[gIdx] {
            eIdx += 1
            gIdx += 1
        } else {
            var found = false
            for look in 1...3 {
                let eNext = eIdx + look
                let gNext = gIdx + look
                if eNext < expWords.count && gNext < genWords.count &&
                   expWords[eNext] == genWords[gNext] {
                    for i in 0..<look {
                        substitutions.append((expWords[eIdx + i], genWords[gIdx + i]))
                    }
                    eIdx += look
                    gIdx += look
                    found = true
                    break
                }
            }
            
            if !found {
                if gIdx + 1 < genWords.count && expWords[eIdx] == genWords[gIdx + 1] {
                    extra.append(genWords[gIdx])
                    gIdx += 1
                } else if eIdx + 1 < expWords.count && expWords[eIdx + 1] == genWords[gIdx] {
                    missing.append(expWords[eIdx])
                    eIdx += 1
                } else {
                    substitutions.append((expWords[eIdx], genWords[gIdx]))
                    eIdx += 1
                    gIdx += 1
                }
            }
        }
    }
    
    while eIdx < expWords.count {
        missing.append(expWords[eIdx])
        eIdx += 1
    }
    while gIdx < genWords.count {
        extra.append(genWords[gIdx])
        gIdx += 1
    }
    
    return (substitutions, missing, extra)
}

// MARK: - Main

guard let config = parseArgs() else {
    print("Usage: compare.swift --expected <path> --generated <path>")
    print("")
    print("NOTE: This is a heuristic tool. Always verify output by reading the files yourself.")
    print("The script may miss word merges (e.g., 'uitgang vijf' → 'uitgangvijf') or other issues.")
    exit(1)
}

guard let expected = try? String(contentsOfFile: config.expectedPath, encoding: .utf8) else {
    print("Error: Could not read expected file: \(config.expectedPath)")
    exit(1)
}

guard let generated = try? String(contentsOfFile: config.generatedPath, encoding: .utf8) else {
    print("Error: Could not read generated file: \(config.generatedPath)")
    exit(1)
}

let (substitutions, missing, extra) = compare(expected: expected, generated: generated)

print("=== WORD DIFFERENCES (verify manually) ===")
print("")
print("SUBSTITUTIONS:")
for (exp, gen) in substitutions {
    print("  '\(exp)' → '\(gen)'")
}

if !missing.isEmpty {
    print("")
    print("MISSING WORDS:")
    for word in missing {
        print("  - \(word)")
    }
}

if !extra.isEmpty {
    print("")
    print("ADDED WORDS:")
    for word in extra {
        print("  + \(word)")
    }
}

print("")
print("=== IMPORTANT ===")
print("This is automated output. READ THE FILES YOURSELF to verify.")
print("Expected: \(config.expectedPath)")
print("Generated: \(config.generatedPath)")
