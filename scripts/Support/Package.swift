// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "ToolSupport", platforms: [.macOS(.v26)], products: [.library(name: "ToolSupport", targets: ["ToolSupport"])], targets: [.target(name: "ToolSupport")])
