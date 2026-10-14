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
        // Upstream b11597, source cb55ffe6e2147eb15f4bede1f60d11246715754f.
        // SwiftPM verifies this digest before using matching llama/GGML headers and code.
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b11597/llama-b11597-xcframework.zip",
            checksum: "4e757338d5a49158b8e608f91e02d35b16b257b361cc22601d0fec70f6976788"
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
