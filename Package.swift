// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CaptainsLog",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "CaptainsLogCore", targets: ["CaptainsLogCore"]),
        .library(name: "CaptainsLog", targets: ["CaptainsLog"]),
        .executable(name: "cl", targets: ["cl"]),
        .executable(name: "CaptainsLogApp", targets: ["CaptainsLogApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.3"),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "CaptainsLogCore",
            dependencies: [
                "CLlama",
                "CSQLiteVec",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "Hub", package: "swift-transformers"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ],
            linkerSettings: [
                .unsafeFlags(["-L/opt/homebrew/lib"])
            ]
        ),
        .systemLibrary(
            name: "CLlama",
            pkgConfig: "llama",
            providers: [.brew(["llama.cpp"])]
        ),
        .target(
            name: "CSQLiteVec",
            path: "Sources/CSQLiteVec",
            publicHeadersPath: "include",
            cSettings: [
                .define("SQLITE_CORE"),
                .define("SQLITE_VEC_STATIC"),
                .define("SQLITE_VEC_ENABLE_NEON"),
                // Suppress precision warnings from the vendored sqlite-vec source.
                .unsafeFlags(["-Wno-shorten-64-to-32"]),
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "cl",
            dependencies: [
                "CaptainsLogCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "CaptainsLog",
            dependencies: ["CaptainsLogCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "CaptainsLogApp",
            dependencies: ["CaptainsLog"]
        ),
        .executableTarget(
            name: "run-tests",
            dependencies: ["CaptainsLog", "CaptainsLogCore"]
        ),
    ]
)
