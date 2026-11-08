// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "CaptainsLogTools",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "captainslog-tools", targets: ["Tools"])],
    dependencies: [.package(path: "../Packages/ToolSupport"), .package(path: "../eval/tools"), .package(path: "../Packages/FixtureLibrary")],
    targets: [.executableTarget(name: "Tools", dependencies: [.product(name: "ToolSupport", package: "ToolSupport"), .product(name: "EvaluationTools", package: "tools"), .product(name: "EvalFixtureLibrary", package: "FixtureLibrary")])]
)
