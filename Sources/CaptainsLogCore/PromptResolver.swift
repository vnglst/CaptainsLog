import Foundation

/// Resolves a prompt path, checking bundle Resources first (for .app), then falling back to relative path (for CLI).
public func resolvePromptPath(_ path: String) -> URL? {
    // If it's an absolute path and exists, use it directly
    if path.hasPrefix("/") {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            return url
        }
    }

    // Check bundle Resources (for .app bundle)
    if let bundlePath = Bundle.main.path(forResource: path, ofType: nil) {
        return URL(fileURLWithPath: bundlePath)
    }

    // Check just the filename in bundle Resources
    let filename = URL(fileURLWithPath: path).lastPathComponent
    if let bundlePath = Bundle.main.path(forResource: filename, ofType: nil,
                                          inDirectory: "prompts") {
        return URL(fileURLWithPath: bundlePath)
    }

    // Fall back to relative path from working directory (for CLI usage)
    let relativeURL = URL(fileURLWithPath: path)
    if FileManager.default.fileExists(atPath: relativeURL.path) {
        return relativeURL
    }

    return nil
}
