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
        // Upstream b11609, source fcac19079f3f2985fe74ed845f0880e7e9a8030a.
        // SwiftPM verifies this digest before using matching llama/GGML headers and code.
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b11609/llama-b11609-xcframework.zip",
            checksum: "e802079e8fe7b5523f272e8a6fc15344572229a5ea6a6292b12184c1f45103b0"
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
