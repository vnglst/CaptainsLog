// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "EvaluationTools",
    platforms: [.macOS(.v26)],
    products: [.library(name: "EvaluationTools", targets: ["EvaluationTools"])],
    dependencies: [.package(path: "../../scripts/Support"), .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")],
    targets: [.target(name: "EvaluationTools", dependencies: [.product(name: "ToolSupport", package: "Support"), .product(name: "Yams", package: "Yams")], resources: [.copy("Resources/EvalReview")])]
)
