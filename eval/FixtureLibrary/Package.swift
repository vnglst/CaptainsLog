// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EvalFixtureLibrary",
    platforms: [.macOS(.v26)],
    products: [.library(name: "EvalFixtureLibrary", targets: ["EvalFixtureLibrary"])],
    targets: [
        .target(name: "EvalFixtureLibrary"),
        .executableTarget(name: "fixture-library-checks", dependencies: ["EvalFixtureLibrary"]),
    ]
)
