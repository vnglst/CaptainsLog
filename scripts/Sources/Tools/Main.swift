import Foundation
import Darwin

@main enum Main {
    static func main() {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if ProcessInfo.processInfo.environment["CAPTAINS_LOG_TOOL_FIXTURE_KIND"] == "release" { try Tools().releaseFixture(args); return }
            if ProcessInfo.processInfo.environment["CAPTAINS_LOG_TOOL_FIXTURE_KIND"] == "eval", ["swift", "otool", "cl"].contains(URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent) { try Tools().evalFixture(args); return }
            guard let command = args.first else { throw ToolFailure("Specify a tooling command") }
            let tools = Tools(); FileManager.default.changeCurrentDirectoryPath(tools.root.path)
            try tools.dispatch(command, Array(args.dropFirst()))
        } catch let error as ToolFailure { FileHandle.standardError.write(Data((error.description + "\n").utf8)); exit(error.status) }
        catch { FileHandle.standardError.write(Data(("Tool error: \(error)\n").utf8)); exit(1) }
    }
}
extension Tools {
    func dispatch(_ command: String, _ args: [String]) throws {
        switch command {
        case "isolated-check": let temp = try temporary("captainslog-check-"); defer { try? fm.removeItem(at: temp) }; try isolated(temp); try run(args)
        case "evals": try evals(args)
        case "test-evals": try testEvals()
        case "test-coverage": try testCoverage(args)
        case "test-release-tooling": try testReleaseTooling()
        case "test-enrich-eval": try testEnrichEval()
        case "test-enrich-validator": try testEnrichValidator()
        case "eval-pipeline": try evalPipeline(args)
        case "test-updates": try testUpdates()
        case "test-model-smoke": try testModelSmoke()
        case "test-recorder-hardware": try testRecorder()
        case "test-ui": try testUI(args)
        case "build-app": try buildApp()
        case "bundle-runtime": try bundleRuntime(args)
        case "check-runtime": try checkRuntime(args)
        case "test-runtime": try testRuntime()
        case "make-iconset": try makeIconset()
        default: throw ToolFailure("Unknown tooling command: \(command)")
        }
    }
}
