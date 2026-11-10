# Native runtime

Agent reference; read the relevant sections for the work at hand.
See [repository instructions](../AGENTS.md) for policy.

The development and release configurations both use the checksum-verified upstream
`llama-b11723-xcframework.zip` (llama.cpp revision
`31288c9c66e59377f7788d920678a565bb89dd37`). SwiftPM verifies SHA-256
`c3911a2dba69e68e87e0306090cd3999a642f8caaf29a7587e2d5685bce1a9f8`
before resolving the matching llama/GGML headers and framework. The universal
macOS slice contains arm64 and x86_64 code; CaptainsLog builds arm64 with deployment
target macOS 26.0. Upstream built the framework for macOS 13.3 with SDK 26.4
(Apple clang 21.0.0, clang-2100.0.123.102; linker 1266.8), so it is compatible
with the app's higher minimum. Its Release
configuration enables Metal, embedded Metal shaders and Accelerate BLAS,
disables OpenMP and native-host tuning, and merges GGML into the framework.
No separate libomp or Homebrew runtime is loaded.

Reproducibility here means identical prebuilt native code and headers across clean
resolutions, local builds and releases. It does not promise identical app signatures,
ZIP timestamps or a byte-identical rebuild of upstream's compiler output. Run
`make tests-runtime` to independently download, verify and compare two
clean unsigned framework extractions. Packaging runs the `check-runtime` tooling command
to reject external runtime paths and verify the app/CLI deployment target.

Two upstream Swift packages are retained in `Vendor/` with only dependency
manifest patches, allowing the newest Swift Crypto and yyjson releases.
See [vendored package provenance](../Vendor/README.md) before refreshing them.

To upgrade the runtime, select an immutable upstream release and source commit,
verify the release asset's SHA-256 independently, update the URL/checksum/revision
in `Package.swift` and this description, and refresh that revision's MIT and native helper license notices under
`Resources/licenses/llama.cpp/`. Review upstream `build-xcframework.sh` at the
pinned commit for build flags and deployment requirements. Then run the runtime
check, clean debug and release builds, deterministic tests, packaging/signature
checks and sequential fixture evaluations before committing. Changing system
llama.cpp, GGML or libomp installations has no effect on the selected artifact.
