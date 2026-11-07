// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "CaptainsLogTools",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "captainslog-tools", targets: ["Tools"])],
    dependencies: [.package(path: "Support"), .package(path: "../eval/tools"), .package(path: "../eval/FixtureLibrary")],
    targets: [.executableTarget(name: "Tools", dependencies: [.product(name: "ToolSupport", package: "Support"), .product(name: "EvaluationTools", package: "tools"), .product(name: "EvalFixtureLibrary", package: "FixtureLibrary")])]
)
