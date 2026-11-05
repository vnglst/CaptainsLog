import Foundation

extension Tools {
    func testEvalReview() throws {
        let timing: EvalItem = ["transcription": [
            ["text": "one two", "offsets": ["from": 0, "to": 2000]],
            ["text": "three four", "offsets": ["from": 2000, "to": 4000]],
            ["text": "five six", "offsets": ["from": 4000, "to": 6000]]]]
        let clean = "one two three four five six"
        try require(differencePassages(reference: clean, transcript: clean, comparison: clean, timing: timing, identifier: "test", duration: 6).isEmpty, "Clean transcripts generated error passages")
        let differences = try differencePassages(reference: clean, transcript: "one changed three four five six", comparison: clean, timing: timing, identifier: "test", duration: 6)
        try require(differences.count == 1 && differences[0]["reference_end_word"] as? Int == 2 && differences[0]["model_errors"] as? [Int] == [1, 0], "Difference outside the old checklist was not selected precisely")
        try require((differences[0]["title"] as? String)?.contains(": wording or spelling to verify") == true, "Passage title must describe the wording, not the model")
        let repeatedTiming: EvalItem = ["transcription": [
            ["text": "one two", "offsets": ["from": 0, "to": 2000]],
            ["text": "extra", "offsets": ["from": 2000, "to": 2100]],
            ["text": "other", "offsets": ["from": 2000, "to": 2100]],
            ["text": "three four five six", "offsets": ["from": 2100, "to": 6000]]]]
        let repeated = try differencePassages(reference: clean, transcript: clean, comparison: "one two extra other three four five six", timing: repeatedTiming, identifier: "repeat", duration: 6)
        try require(repeated.count == 1 && (repeated[0]["title"] as? String)?.contains(": possible added or repeated words") == true, "Collapsed reference words created duplicate or one-word review titles")
        let tail = try differencePassages(reference: clean, transcript: clean + " invented tail", comparison: clean, timing: timing, identifier: "test", duration: 6)
        try require(tail.count == 1 && tail[0]["reference_start_word"] as? Int == 4, "Final insertion was omitted")
        let secondTiming: EvalItem = ["transcription": [["text": "one two three changed five six", "offsets": ["from": 0, "to": 6000]]]]
        try require(differencePassages(reference: clean, transcript: clean, comparison: "one two three changed five six", timing: secondTiming, identifier: "test", duration: 6)[0]["model_errors"] as? [Int] == [0, 1], "Comparison-only difference was omitted")
        let run = try temporary("captainslog-listening-review-")
        defer { try? fm.removeItem(at: run) }
        let eval = Evaluator(self)
        let oldPassage: EvalItem = ["id": "old", "short_id": "P1", "start_seconds": 10.0, "end_seconds": 20.0, "reference": "original script"]
        let newPassage: EvalItem = ["id": "new", "short_id": "P1", "reference": "Owner confirmed wording"]
        let confirmed: [String: EvalItem] = ["old": ["status": "corrected", "words": "Owner confirmed wording"]]
        try require(inheritedReviewPassages(passages: [newPassage], source: [oldPassage], decisions: confirmed, edits: []) == ["new"], "Unchanged audio with applied owner correction did not carry forward")
        try require(inheritedReviewPassages(passages: [newPassage], source: [oldPassage], decisions: confirmed, edits: [["kind": "replacement", "original_start": 19.0, "original_end": 25.0]]).isEmpty, "Replacement overlap incorrectly inherited verification")
        try require(inheritedReviewPassages(passages: [["id": "new", "short_id": "P1", "reference": "different wording"]], source: [oldPassage], decisions: confirmed, edits: []).isEmpty, "Changed reference incorrectly inherited verification")
        try require(inheritedReviewPassages(passages: [newPassage], source: [oldPassage], decisions: ["old": ["status": "uncertain"]], edits: []).isEmpty, "Uncertain prior passage incorrectly inherited verification")
        var item = try eval.cases(["transcribe"], "tng-nl01-vrije-dag-enterprise-corrected")[0]
        let expected = run.appendingPathComponent("fixtures/expected.md"), output = run.appendingPathComponent("generated.md")
        try copy(eval.file(item, "expected"), expected)
        let text = try read(expected).replacingOccurrences(of: "foldertje", with: "updated-transcript-word")
        try write(output, text); item["expected"] = expected.path; item["output"] = output.path
        try json(run.appendingPathComponent("manifest.json"), [item])
        let app = try prepareEvalReview(run)!
        func recordings() throws -> [EvalItem] { (try json(app.appendingPathComponent("recordings.json")) as! EvalItem)["recordings"] as! [EvalItem] }
        let first = try recordings()[0], passages = first["passages"] as! [EvalItem]
        try require(first["app_transcript"] as? String == text && passages.count == 12, "Review must use the selected run's fresh transcript and stored fixture timings")
        try require(fm.fileExists(atPath: app.appendingPathComponent("app.js").path), "Review app resource missing")
        try require(!read(app.appendingPathComponent("index.html")).contains("onlyDifferences"), "Review still exposes a text-differences toggle")
        let audio = app.appendingPathComponent(first["audio"] as! String)
        try require(hash(audio) == hash(eval.file(item, "input")), "Review audio copy changed")
        let server = try EvalReviewServer(root: app, port: 0); defer { server.stop() }
        let host = "127.0.0.1:\(server.port)", headers = ["host": host, "content-type": "application/json", "origin": "http://" + host]
        func request(_ method: String, _ route: String, _ value: EvalItem? = nil, _ custom: [String: String]? = nil) throws -> ReviewResponse {
            try server.response(method: method, path: route, headers: custom ?? headers, body: value.map { try JSONSerialization.data(withJSONObject: $0) } ?? Data())
        }
        try require(request("GET", "/review-passages.mjs").status == 200, "Review queue module is not served")
        var value: EvalItem = ["id": passages[0]["id"]!, "status": "corrected", "words": "owner-supplied test wording", "notes": "test only", "context": passages[0]["context"]!]
        try require(request("POST", "/api/state", value).status == 200, "Review correction save failed")
        let stateFile = app.appendingPathComponent("review-state.json")
        var savedBytes = try Data(contentsOf: stateFile)
        let loaded = try JSONSerialization.jsonObject(with: request("GET", "/api/state").body) as! EvalItem
        try require((loaded["reviews"] as? [String: EvalItem])?.count == 1, "Saved review did not reload")
        let overview = try JSONSerialization.jsonObject(with: request("GET", "/api/reviews").body) as! EvalItem
        let entries = overview["reviews"] as! [EvalItem]
        try require(entries.count == 1 && entries[0]["verified"] as? Int == 1 && entries[0]["total"] as? Int == 12, "Overview lost live saved progress")
        let sibling = run.appendingPathComponent("second-review"); try mkdir(sibling)
        try json(sibling.appendingPathComponent("recordings.json"), ["recordings": [["id": "second", "title": "Second review", "passages": [["id": "second-passage"]]]]])
        let catalog = run.appendingPathComponent("sessions.json")
        try json(catalog, [["root": app.path, "url": "http://127.0.0.1:8777"], ["root": sibling.path, "url": "http://127.0.0.1:8778"]])
        let shared = try EvalReviewServer(root: app, port: 0, catalog: catalog); defer { shared.stop() }
        let sharedResponse = try shared.response(method: "GET", path: "/api/reviews", headers: ["host": "127.0.0.1:\(shared.port)"])
        let sharedData = try JSONSerialization.jsonObject(with: sharedResponse.body) as! EvalItem
        try require((sharedData["reviews"] as? [EvalItem])?.count == 2, "Overview omitted a related review session")
        try require(Data(contentsOf: stateFile) == savedBytes, "Overview changed saved owner decisions")
        var completed = loaded
        var completedReviews: [String: EvalItem] = [:]
        for passage in passages { completedReviews[passage["id"] as! String] = ["status": "matches", "context": passage["context"]!] }
        let lastID = passages.last!["id"] as! String
        completedReviews[lastID] = ["status": "uncertain", "context": passages.last!["context"]!, "accepted_take_id": "selected-take"]
        completed["reviews"] = completedReviews
        completed["consolidations"] = [["recording_id": first["id"]!, "reference_sha256": first["reference_sha256"]!, "audio_sha256": "corrected-audio", "selections": [lastID: "selected-take"]]]
        try json(stateFile, completed)
        try json(sibling.appendingPathComponent("recordings.json"), ["recordings": [["id": "second", "title": "Second review", "audio_sha256": "corrected-audio", "passages": [["id": "second-passage", "short_id": passages.last!["short_id"]!]]]]])
        func summary() throws -> EvalItem {
            let response = try shared.response(method: "GET", path: "/api/reviews", headers: ["host": "127.0.0.1:\(shared.port)"])
            return ((try JSONSerialization.jsonObject(with: response.body) as! EvalItem)["reviews"] as! [EvalItem])[0]
        }
        let finished = try summary()
        try require(finished["complete"] as? Bool == true && finished["resolved"] as? Int == 12 && (finished["replaced_passages"] as? [String]) == [lastID] && finished["followup"] as? EvalItem != nil, "Exported replacement did not logically finish first review or link follow-up")
        completedReviews[lastID]?["accepted_take_id"] = "unsaved-new-selection"; completed["reviews"] = completedReviews; try json(stateFile, completed)
        try require(summary()["complete"] as? Bool == false, "Unexported replacement incorrectly completed review")
        completedReviews[lastID] = ["status": "matches", "context": passages.last!["context"]!]; completed["reviews"] = completedReviews; try json(stateFile, completed)
        try require(summary()["complete"] as? Bool == true, "All verified passages did not complete review")
        try savedBytes.write(to: stateFile)
        _ = try prepareEvalReview(run)
        try require(Data(contentsOf: stateFile) == savedBytes, "Regeneration overwrote owner decisions")
        var bad = value; bad["words"] = ""
        try require(request("POST", "/api/state", bad).status == 400, "Empty correction accepted")
        bad = value; bad["id"] = "unknown"
        try require(request("POST", "/api/state", bad).status == 400, "Unknown passage accepted")
        bad = value; bad.removeValue(forKey: "context")
        try require(request("POST", "/api/state", bad).status == 409, "Stale browser context accepted")
        var remote = headers; remote["origin"] = "http://unrelated.example"
        try require(request("POST", "/api/state", value, remote).status == 403, "Cross-origin save accepted")
        let range = try request("GET", "/" + (first["audio"] as! String), nil, ["host": host, "range": "bytes=2-5"])
        try require(range.status == 206 && range.offset == 2 && range.length == 4, "Audio seek range incorrect")
        let suffix = try request("GET", "/" + (first["audio"] as! String), nil, ["host": host, "range": "bytes=-3"])
        try require(suffix.status == 206 && suffix.length == 3, "Audio suffix range incorrect")
        try require(request("GET", "/" + (first["audio"] as! String), nil, ["host": host, "range": "bytes=999999999-"]).status == 416, "Invalid audio range accepted")
        try require(request("GET", "/%2e%2e/manifest.json").status == 400 && request("GET", "/review-state.json").status == 404, "Review exposed files outside its public assets")
        let escape = app.appendingPathComponent("assets/audio/escape.m4a")
        try fm.createSymbolicLink(at: escape, withDestinationURL: eval.file(item, "input"))
        try require(request("GET", "/assets/audio/escape.m4a").status == 404, "Review served an escaping symlink")
        DispatchQueue.global().async { try? server.serve() }
        let downloaded = run.appendingPathComponent("range.bin")
        try self.run(["/usr/bin/curl", "--fail", "--silent", "--max-time", "5", "--range", "2-5", "--output", downloaded.path, "http://\(host)/\(first["audio"]!)"], quiet: true)
        try require(Data(contentsOf: downloaded) == Data(contentsOf: audio).subdata(in: 2..<6), "HTTP audio range body incorrect")
        let payload = run.appendingPathComponent("post.json"), postResult = run.appendingPathComponent("post-result.json")
        try json(payload, value)
        try self.run(["/usr/bin/curl", "--fail", "--silent", "--max-time", "5", "-H", "Content-Type: application/json", "--data-binary", "@" + payload.path, "--output", postResult.path, "http://\(host)/api/state"], quiet: true)
        try require((try json(postResult) as? EvalItem)?["words"] as? String == "owner-supplied test wording", "HTTP review save body was not preserved")
        savedBytes = try Data(contentsOf: stateFile)
        let comparison = run.appendingPathComponent("comparison"); try mkdir(comparison)
        try write(comparison.appendingPathComponent("tng-nl01-vrije-dag-enterprise-corrected.txt"), "Separate comparison transcript")
        _ = try prepareEvalReview(run, comparison: comparison)
        try require(recordings()[0]["second_transcript"] as? String == "Separate comparison transcript", "Comparison import failed")
        _ = try prepareEvalReview(run)
        try require(recordings()[0]["second_transcript"] as? String == "Separate comparison transcript", "Regeneration lost a saved comparison")
        let derived = run.appendingPathComponent("differences")
        try mkdir(derived)
        var derivedItem = item
        for key in ["expected", "output"] {
            let copyURL = derived.appendingPathComponent(key + ".md")
            try copy(eval.file(item, key), copyURL); derivedItem[key] = copyURL.path
        }
        try json(derived.appendingPathComponent("manifest.json"), [derivedItem])
        let comparisonText = comparison.appendingPathComponent("tng-nl01-vrije-dag-enterprise-corrected.txt")
        let timingFile = comparison.appendingPathComponent("tng-nl01-vrije-dag-enterprise-corrected.json")
        let identityFile = comparison.appendingPathComponent("tng-nl01-vrije-dag-enterprise-corrected.run.json")
        try json(timingFile, ["transcription": [["text": "Separate comparison transcript", "offsets": ["from": 0, "to": (first["duration"] as! Double) * 1000]]]])
        var identity: EvalItem = ["audio_sha256": try hash(eval.file(item, "input")), "output_sha256": try hash(comparisonText), "timing_sha256": try hash(timingFile)]
        try json(identityFile, identity)
        let generatedApp = try prepareEvalReview(derived, comparison: comparison, differencesOnly: true)!
        let generatedRecordings = (try json(generatedApp.appendingPathComponent("recordings.json")) as! EvalItem)["recordings"] as! [EvalItem]
        let generated = generatedRecordings[0]["passages"] as! [EvalItem]
        try require(generated.count == 1 && generated[0]["short_id"] as? String == "E01", "Difference mode reused the fixed checklist")
        try require(Data(contentsOf: stateFile) == savedBytes, "Derived difference review changed completed owner decisions")
        let titlesFile = derived.appendingPathComponent("review-titles.json")
        let generatedContext = generated[0]["context"] as! EvalItem
        var titleRecord: EvalItem = ["audio_sha256": identity["audio_sha256"]!, "reference_sha256": try hash(expected), "output_sha256": try hash(eval.file(derivedItem, "output")), "comparison_sha256": identity["output_sha256"]!, "passages": [generated[0]["id"] as! String: ["title": "Opening: possible omitted words", "reference_start_word": generatedContext["reference_start_word"]!, "reference_end_word": generatedContext["reference_end_word"]!]]]
        try json(titlesFile, [eval.string(item, "name"): titleRecord])
        _ = try prepareEvalReview(derived)
        func generatedTitle() throws -> String {
            let records = (try json(generatedApp.appendingPathComponent("recordings.json")) as! EvalItem)["recordings"] as! [EvalItem]
            return (records[0]["passages"] as! [EvalItem])[0]["title"] as! String
        }
        try require(generatedTitle() == "Opening: possible omitted words", "Pinned descriptive review title was ignored")
        titleRecord["output_sha256"] = "stale-output"; try json(titlesFile, [eval.string(item, "name"): titleRecord])
        _ = try prepareEvalReview(derived)
        try require(generatedTitle() != "Opening: possible omitted words" && generatedTitle().contains(":"), "Stale review title was applied or naming convention was lost")
        let derivedServer = try EvalReviewServer(root: generatedApp, port: 0, catalog: catalog)
        defer { derivedServer.stop() }
        let derivedOverview = try derivedServer.response(method: "GET", path: "/api/reviews", headers: ["host": "127.0.0.1:\(derivedServer.port)"])
        let scopedReviews = (try JSONSerialization.jsonObject(with: derivedOverview.body) as! EvalItem)["reviews"] as! [EvalItem]
        try require(scopedReviews.count == 1 && scopedReviews[0]["current"] as? Bool == true, "Discrepancy overview re-added unrelated historical reviews")
        let siblingData = try Data(contentsOf: sibling.appendingPathComponent("recordings.json"))
        let completedContext = passages[0]["context"]!
        try json(sibling.appendingPathComponent("recordings.json"), ["recordings": [["id": "completed-history", "title": "Completed recording", "passages": [["id": "completed-passage", "context": completedContext]]]]])
        let historyState = sibling.appendingPathComponent("review-state.json")
        try json(historyState, ["reviews": ["completed-passage": ["status": "matches", "context": completedContext]]])
        let historyBytes = try Data(contentsOf: historyState)
        let withCompleted = try derivedServer.response(method: "GET", path: "/api/reviews", headers: ["host": "127.0.0.1:\(derivedServer.port)"])
        let completedEntries = (try JSONSerialization.jsonObject(with: withCompleted.body) as! EvalItem)["reviews"] as! [EvalItem]
        try require(completedEntries.count == 2 && completedEntries.contains { $0["recording_id"] as? String == "completed-history" && $0["complete"] as? Bool == true }, "Overview removed completed history instead of keeping its completed state")
        try require(Data(contentsOf: historyState) == historyBytes, "Overview rewrote the completed review")
        try siblingData.write(to: sibling.appendingPathComponent("recordings.json"))
        try fm.removeItem(at: historyState)
        _ = try prepareEvalReview(derived)
        try copy(expected, eval.file(derivedItem, "output"))
        try write(comparisonText, read(expected))
        try json(timingFile, ["transcription": [["text": try read(expected), "offsets": ["from": 0, "to": (first["duration"] as! Double) * 1000]]]])
        identity["output_sha256"] = try hash(comparisonText); identity["timing_sha256"] = try hash(timingFile)
        try json(identityFile, identity)
        _ = try prepareEvalReview(derived)
        let matchingData = (try json(generatedApp.appendingPathComponent("recordings.json")) as! EvalItem)["recordings"] as! [EvalItem]
        try require((matchingData[0]["passages"] as! [EvalItem]).isEmpty, "Matching models fell back to a fixed checklist")
        identity["audio_sha256"] = "wrong-audio"; try json(identityFile, identity)
        do { _ = try prepareEvalReview(derived); throw ToolFailure("Wrong comparison audio was accepted") }
        catch { try require(String(describing: error).contains("different audio"), "Wrong audio comparison failure") }
        try write(expected, read(expected) + " A changed reference.")
        _ = try prepareEvalReview(run)
        let changed = try recordings()[0]["passages"] as! [EvalItem]
        try require(changed.count == 1 && changed[0]["short_id"] as? String == "Full", "Stale reference timing offsets were reused")
        let after = try JSONSerialization.jsonObject(with: request("GET", "/api/state").body) as! EvalItem
        try require((after["reviews"] as? [String: EvalItem])?.isEmpty == true && (after["archived_reviews"] as? [String: EvalItem])?.count == 1 && Data(contentsOf: stateFile) == savedBytes, "Reference changes reused or discarded saved verification")
        value["id"] = changed[0]["id"]; value["context"] = changed[0]["context"]
        try require(request("POST", "/api/state", value).status == 200, "New reference review could not save")
        let outputSnapshot = run.appendingPathComponent("review/suites/transcribe/tng-nl01-vrije-dag-enterprise-corrected/output.md")
        try copy(output, outputSnapshot); try fm.removeItem(at: output)
        _ = try prepareEvalReview(run)
        try require(recordings()[0]["app_transcript"] as? String == text, "Saved output snapshot was not reused after external generated output disappeared")
        let outside = try temporary("captainslog-outside-review-"); defer { try? fm.removeItem(at: outside) }
        let unrelated = outside.appendingPathComponent("fixture-copy.m4a"); try copy(eval.file(item, "input"), unrelated)
        var outsideItem = item; outsideItem["input"] = unrelated.path
        do { _ = try prepareEvalReview(run, items: [outsideItem]); throw ToolFailure("Unrelated file read by review preparation") }
        catch { try require(String(describing: error).contains("must belong to an evaluation run"), "Wrong review file-admission error") }
        let badAudio = run.appendingPathComponent("bad.m4a"); try write(badAudio, "not the fixture")
        var wrong = item; wrong["input"] = badAudio.path
        do { _ = try prepareEvalReview(run, items: [wrong]); throw ToolFailure("Unknown review audio accepted") }
        catch { try require(String(describing: error).contains("does not match the synthetic fixture"), "Wrong audio admission error") }
        try require(prepareEvalReview(run, items: [["stage": "filename"]]) == nil, "Text-only run pretended to contain audio")
        print("PASS: listening review preparation, fresh transcripts, comparison persistence, saved decisions, changed references, HTTP audio ranges and synthetic-audio admission")
    }
}
