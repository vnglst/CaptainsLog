import Foundation

struct CategoryFilter {
    // Exclusions make newly configured or discovered categories selected by default.
    private(set) var excluded = Set<String>()
    var includesAll: Bool { excluded.isEmpty }

    static func key(for path: String) -> String {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
        return parent.deletingLastPathComponent().lastPathComponent == "logs"
            ? parent.lastPathComponent : "uncategorized"
    }

    func includes(_ category: String) -> Bool { !excluded.contains(category) }
    func includes(path: String) -> Bool { includes(Self.key(for: path)) }

    mutating func select(_ category: String, selected: Bool) {
        if selected { excluded.remove(category) }
        else { excluded.insert(category) }
    }
    mutating func selectAll() { excluded.removeAll() }
}
