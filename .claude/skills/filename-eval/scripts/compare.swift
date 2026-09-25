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
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func validateFilename(_ filename: String) -> [String] {
    var issues: [String] = []
    
    if !filename.hasSuffix(".md") {
        issues.append("Missing .md extension")
    }
    
    let name = filename.hasSuffix(".md")
        ? String(filename.dropLast(3))
        : filename
    
    let parts = name.split(separator: "-", omittingEmptySubsequences: false)
    
    if parts.isEmpty || parts[0].count != 4 || Int(parts[0]) == nil {
        issues.append("Missing or invalid year prefix")
    }
    if parts.count < 2 || parts[1].count != 2 || Int(parts[1]) == nil {
        issues.append("Missing or invalid month prefix")
    }
    if parts.count < 3 || parts[2].count != 2 || Int(parts[2]) == nil {
        issues.append("Missing or invalid day prefix")
    }
    
    let slugParts = parts.dropFirst(3)
    let slugWordCount = slugParts.count
    if slugWordCount < 3 {
        issues.append("Slug too short: \(slugWordCount) words (min 3)")
    }
    if slugWordCount > 8 {
        issues.append("Slug too long: \(slugWordCount) words (max 8)")
    }
    
    let slug = slugParts.joined(separator: "-")
    let kebabRegex = try? NSRegularExpression(pattern: "^[a-z0-9]+(-[a-z0-9]+)*$", options: [])
    if let regex = kebabRegex {
        let range = NSRange(slug.startIndex..., in: slug)
        if regex.firstMatch(in: slug, options: [], range: range) == nil {
            issues.append("Slug is not valid kebab-case")
        }
    }
    
    return issues
}

func main() {
    let opts = parseArgs()
    guard !opts.expectedPath.isEmpty, !opts.generatedPath.isEmpty else {
        print("Usage: swift compare.swift --expected <path> --generated <path>")
        exit(1)
    }
    
    guard let expected = readFile(opts.expectedPath) else {
        print("ERROR: Cannot read expected file: \(opts.expectedPath)")
        exit(1)
    }
    guard let generated = readFile(opts.generatedPath) else {
        print("ERROR: Cannot read generated file: \(opts.generatedPath)")
        exit(1)
    }
    
    print("# Filename Comparison")
    print("")
    print("**Expected**: `\(expected)`")
    print("**Generated**: `\(generated)`")
    print("")
    
    print("## Exact Match")
    print("")
    if expected == generated {
        print("✅ Filenames match exactly")
    } else {
        print("❌ Filenames differ")
    }
    print("")
    
    print("## Generated Validation")
    print("")
    let issues = validateFilename(generated)
    if issues.isEmpty {
        print("✅ All checks pass")
    } else {
        for issue in issues {
            print("- ❌ \(issue)")
        }
    }
    print("")
    
    print("## Expected Validation")
    print("")
    let expectedIssues = validateFilename(expected)
    if expectedIssues.isEmpty {
        print("✅ All checks pass")
    } else {
        for issue in expectedIssues {
            print("- ❌ \(issue)")
        }
    }
    print("")
    
    print("## Word Count")
    print("")
    let genName = generated.hasSuffix(".md") ? String(generated.dropLast(3)) : generated
    let genSlugParts = genName.split(separator: "-").dropFirst(3)
    print("Generated slug: \(genSlugParts.count) words")
    let expName = expected.hasSuffix(".md") ? String(expected.dropLast(3)) : expected
    let expSlugParts = expName.split(separator: "-").dropFirst(3)
    print("Expected slug: \(expSlugParts.count) words")
    print("")
    
    print("## Notes")
    print("")
    print("- This script checks format only. Topic relevance and hallucination must be verified manually by reading the input content.")
}

main()
