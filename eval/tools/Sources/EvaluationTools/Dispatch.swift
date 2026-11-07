import Foundation
import Darwin
import ToolSupport

public enum EvaluationTools {
    public static func runFixture(_ tools: Tools, _ args: [String]) throws { try tools.evalFixture(args) }
    public static func run(_ tools: Tools, _ command: String, _ args: [String]) throws {
        switch command {
        case "evals": try tools.evals(args)
        case "evals-review": try tools.evalsReview(args)
        case "test-evals": try tools.testEvals()
        case "test-enrich-eval": try tools.testEnrichEval()
        case "test-enrich-validator": try tools.testEnrichValidator()
        case "eval-pipeline": try tools.evalPipeline(args)
        case "score-transcription":
            try tools.require(args.count == 4 && args[0] == "--expected" && args[2] == "--generated", "Usage: score-transcription --expected PATH --generated PATH", status: 2)
            print(try TranscriptionScore(reference: tools.read(tools.path(args[1])), hypothesis: tools.read(tools.path(args[3]))).markdown)
        case "website":
            guard args.count == 1, let port = UInt16(args[0]) else { throw ToolFailure("Usage: website PORT (0–65535)", status: 2) }
            let server = try EvalReviewServer(root: tools.path("website"), port: port, website: true)
            print("Website: http://127.0.0.1:\(server.port)"); fflush(stdout)
            try server.serve()
        default: throw ToolFailure("Unknown tooling command: \(command)")
        }
    }
}
