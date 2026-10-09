// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CaptainsLogTools",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "captainslog-tools", targets: ["Tools"])],
    dependencies: [.package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")],
    targets: [.executableTarget(name: "Tools", dependencies: [.product(name: "Yams", package: "Yams")])]
)
