import Foundation

extension Tools {
    func testReviewSessions() throws {
        let base = try temporary("captainslog-review-resume-")
        defer { try? fm.removeItem(at: base) }
        let file = base.appendingPathComponent("last.json"), catalog = base.appendingPathComponent("catalog.json")
        let first = base.appendingPathComponent("first"), second = base.appendingPathComponent("second")
        for run in [first, second] {
            try write(run.appendingPathComponent("review-app/index.html"), "saved review")
            try json(run.appendingPathComponent("review-app/recordings.json"), ["recordings": []])
        }
        try require(latestReviewSession(file: file, catalog: catalog, searchRoots: []) == nil, "Missing review should be explicit")
        try rememberReviewSession(first, port: 8777, location: ["view": "overview"], file: file)
        try rememberReviewSession(second, port: 8779, location: ["recording": "book & chapter", "passage": "E04"], file: file)
        let latest = try latestReviewSession(file: file, catalog: catalog, searchRoots: [])!
        try require(latest.run == second.resolvingSymlinksInPath().standardizedFileURL && latest.port == 8779, "Latest session or its port was lost")
        try rememberReviewSession(second, port: 8780, file: file)
        try require(reviewSessionLocation(second, file: file)["passage"] as? String == "E04", "Reopening erased the saved passage")
        let url = reviewBrowserURL(run: second, port: 8780, file: file)
        try require(url.contains("127.0.0.1:8780") && url.contains("book%20%26%20chapter") && url.contains("E04"), "Resume URL did not preserve and encode the saved passage")
        try json(catalog, [["root": first.appendingPathComponent("review-app").path, "url": "http://127.0.0.1:8777"], ["root": base.appendingPathComponent("deleted/review-app").path, "url": "http://127.0.0.1:8778"]])
        try fm.removeItem(at: second.appendingPathComponent("review-app/recordings.json"))
        try require(latestReviewSession(file: file, catalog: catalog, searchRoots: [])?.run == first.resolvingSymlinksInPath().standardizedFileURL, "Deleted session blocked the latest valid review")
        try fm.removeItem(at: file); try fm.removeItem(at: catalog)
        try require(latestReviewSession(file: file, catalog: catalog, searchRoots: [base])?.run == first.resolvingSymlinksInPath().standardizedFileURL, "Saved review discovery failed on a fresh checkout")
        print("PASS: latest review, port and passage restoration, stale-session fallback and saved-review discovery")
    }
}
