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
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.1.1"),
        .package(path: "Vendor/swift-transformers"),
        .package(path: "Vendor/swift-huggingface"),
    ],
    targets: [
        .target(
            name: "CaptainsLogCore",
            dependencies: [
                "llama",
                "CSQLiteVec",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "Hub", package: "swift-transformers"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ]
        ),
        // Upstream b11723, source 31288c9c66e59377f7788d920678a565bb89dd37.
        // SwiftPM verifies this digest before using matching llama/GGML headers and code.
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b11723/llama-b11723-xcframework.zip",
            checksum: "c3911a2dba69e68e87e0306090cd3999a642f8caaf29a7587e2d5685bce1a9f8"
        ),
        .target(
            name: "CSQLiteVec",
            path: "Sources/CSQLiteVec",
            sources: ["sqlite-vec.c"],
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
            dependencies: ["CaptainsLogCore"]
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
