import Foundation

extension Tools {
    func bundleRuntime(_ args: [String]) throws {
        try require(args.count >= 3, "usage: bundle-runtime PRODUCTS APP EXECUTABLE...")
        let products = path(args[0]), app = path(args[1]), framework = products.appendingPathComponent("llama.framework")
        try require(fm.fileExists(atPath: framework.path), "Error: pinned SwiftPM runtime missing: \(framework.path)")
        let destination = app.appendingPathComponent("Contents/Frameworks/llama.framework")
        try mkdir(destination.deletingLastPathComponent()); try run(["ditto", framework.path, destination.path])
        for executable in args.dropFirst(2) {
            let text = try capture(["otool", "-l", executable])
            var inRpath = false
            for line in text.components(separatedBy: .newlines) {
                if line.contains("cmd LC_RPATH") { inRpath = true }
                if inRpath, let rpath = match(#"^\s*path (.*?) \(offset"#, line, group: 1) {
                    if rpath.hasPrefix(products.path + "/") { try run(["install_name_tool", "-delete_rpath", rpath, executable]) }
                    inRpath = false
                }
            }
            try run(["install_name_tool", "-add_rpath", "@executable_path/../Frameworks", executable])
        }
    }
    func checkRuntime(_ args: [String]) throws {
        try require(args.count == 1, "usage: check-runtime APP_BUNDLE")
        let app = path(args[0]), framework = app.appendingPathComponent("Contents/Frameworks/llama.framework/llama")
        try require(fm.fileExists(atPath: framework.path), "Pinned framework binary missing")
        try run(["lipo", "-verify_arch", "arm64", framework.path])
        let load = try capture(["otool", "-l", framework.path])
        let minimums = load.components(separatedBy: .newlines).compactMap { match(#"^\s*minos (\d+)\.(\d+)"#, $0) }
        try require(!minimums.isEmpty, "Runtime deployment minimum is missing")
        for minimum in minimums {
            let version = minimum.split(separator: " ").last!.split(separator: ".").compactMap { Int($0) }
            try require(version[0] < 26 || (version[0] == 26 && version[1] == 0), "Runtime deployment minimum exceeds macOS 26.0")
        }
        let symbols = try capture(["nm", "-gj", framework.path]).components(separatedBy: .newlines)
        for backend in ["cpu", "metal"] { try require(symbols.contains("_ggml_backend_\(backend)_init"), "Missing \(backend) backend export") }
        let executables = ["CaptainsLog", "cl"].map { app.appendingPathComponent("Contents/MacOS/\($0)").path }
        for binary in executables + [framework.path] {
            let dependencies = try capture(["otool", "-L", binary])
            for line in dependencies.components(separatedBy: .newlines) where line.first?.isWhitespace == true && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let dependency = line.trimmingCharacters(in: .whitespaces)
                try require(["@rpath/llama.framework/Versions/Current/llama", "/System/Library/", "/usr/lib/"].contains { dependency.hasPrefix($0) }, "Unexpected external runtime dependency in \(binary): \(dependency)")
            }
            let commands = try capture(["otool", "-l", binary])
            try require(!["/opt/homebrew", "/usr/local", "/Cellar/", "/.build/"].contains { commands.contains($0) }, "Build-machine path remains in \(binary)")
            if executables.contains(binary) {
                try require(dependencies.contains("@rpath/llama.framework/Versions/Current/llama"), "Pinned framework dependency missing")
                try require(match(#"cmd LC_BUILD_VERSION[\s\S]{0,160}\bminos 26\.0\n"#, commands) != nil, "Executable deployment minimum must be macOS 26.0")
                try require(commands.contains("@executable_path/../Frameworks"), "Bundle-relative framework search path missing")
            }
        }
        print("Packaged app and CLI use the pinned framework with no build-machine runtime paths.")
    }
    func testRuntime() throws {
        let manifest = try read(path("Package.swift"))
        guard let url = match(#"url: \"(https:.*?xcframework\.zip)\""#, manifest, group: 1), let checksum = match(#"checksum: \"([a-f0-9]{64})\""#, manifest, group: 1) else { throw ToolFailure("Pinned runtime URL/checksum missing") }
        try require(match(#"pkgConfig:.*\"(llama|ggml)\"|\.brew.*(llama\.cpp|ggml|libomp)|/opt/homebrew|/usr/local"#, manifest) == nil, "System-installed native runtime fallback detected in Package.swift.")
        let temp = try temporary("captainslog-runtime-"); defer { try? fm.removeItem(at: temp) }
        var frameworks: [URL] = []
        for name in ["first", "second"] {
            let archive = temp.appendingPathComponent(name + ".zip"), folder = temp.appendingPathComponent(name)
            try run(["curl", "--fail", "--location", "--silent", "--show-error", url, "-o", archive.path])
            let actual = try hash(archive); try require(actual == checksum, "Runtime archive checksum differs from pin")
            try mkdir(folder); try run(["ditto", "-x", "-k", archive.path, folder.path])
            let framework = folder.appendingPathComponent("build-apple/llama.xcframework/macos-arm64_x86_64/llama.framework")
            for header in ["llama.h", "ggml.h"] { try require(fm.fileExists(atPath: framework.appendingPathComponent("Headers/\(header)").path), "Runtime header missing: \(header)") }
            try run(["lipo", "-verify_arch", "arm64", framework.appendingPathComponent("llama").path])
            try run(["codesign", "--remove-signature", framework.appendingPathComponent("llama").path], quiet: true, allowFailure: true)
            frameworks.append(framework.appendingPathComponent("Versions/A"))
        }
        let identical = try sameFiles(frameworks[0], frameworks[1]); try require(identical, "Independent runtime extractions differ")
        print("Two independent verified extractions produce identical unsigned native artifacts.")
    }
    func buildApp() throws {
        try require(try capture(["uname", "-m"]) == "arm64", "CaptainsLog release builds require an Apple Silicon Mac.")
        let version = try read(path("VERSION")).trimmingCharacters(in: .whitespacesAndNewlines)
        let products = path(try capture(["swift", "build", "-c", "release", "--show-bin-path"]))
        print("==> Building release app and CLI (\(version))...")
        try run(["swift", "build", "-c", "release", "--product", "CaptainsLogApp"])
        try run(["swift", "build", "-c", "release", "--product", "cl"])
        for name in ["CaptainsLogApp", "cl"] { try require(fm.fileExists(atPath: products.appendingPathComponent(name).path), "Expected build output missing: \(name)") }
        let app = path("dist/CaptainsLog.app"), resources = app.appendingPathComponent("Contents/Resources"), macos = app.appendingPathComponent("Contents/MacOS")
        if fm.fileExists(atPath: app.path) { try fm.removeItem(at: app) }
        try mkdir(resources); try mkdir(macos)
        let executable = macos.appendingPathComponent("CaptainsLog"), cli = macos.appendingPathComponent("cl")
        try copy(products.appendingPathComponent("CaptainsLogApp"), executable); try copy(products.appendingPathComponent("cl"), cli)
        try bundleRuntime([products.path, app.path, executable.path, cli.path]); try checkRuntime([app.path])
        if exists("Resources/AppIcon.icns") { try copy(path("Resources/AppIcon.icns"), resources.appendingPathComponent("AppIcon.icns")) }
        else { print("Warning: Resources/AppIcon.icns not found. Run make icons to generate.") }
        if exists("prompts") { try run(["ditto", path("prompts").path, resources.appendingPathComponent("prompts").path]) }
        let notices = resources.appendingPathComponent("ThirdPartyLicenses")
        for name in ["LICENSE", "THIRD-PARTY-NOTICES.md"] { try copy(path(name), resources.appendingPathComponent(name)) }
        for name in ["LICENSE-MIT", "LICENSE-APACHE"] { try copy(path("Sources/CSQLiteVec/\(name)"), notices.appendingPathComponent("sqlite-vec/\(name)")) }
        for name in ["LICENSE", "THIRD-PARTY-LICENSES.txt"] { try copy(path("Sources/NativeRuntime/\(name)"), notices.appendingPathComponent("llama.cpp/\(name)")) }
        let checkouts = path(".build/checkouts")
        for file in files(checkouts, recursive: true) {
            let name = file.lastPathComponent.uppercased()
            if name == "LICENSE" || name.hasPrefix("LICENSE.") || name == "NOTICE" || name.hasPrefix("NOTICE.") || name == "NOTICES" || name.hasPrefix("COPYING") {
                let relative = String(file.path.dropFirst(checkouts.path.count + 1)); try copy(file, notices.appendingPathComponent("SwiftPackages/\(relative)"))
            }
        }
        let revision = (try? capture(["git", "rev-parse", "--short", "HEAD"])) ?? "unknown"
        let plist: [String: Any] = ["CFBundleDevelopmentRegion":"en", "CFBundleExecutable":"CaptainsLog", "CFBundleIconFile":"AppIcon", "CFBundleIdentifier":"nl.koenvangilst.CaptainsLog", "CFBundleInfoDictionaryVersion":"6.0", "CFBundleName":"CaptainsLog", "CFBundleDisplayName":"Captain's Log", "CFBundlePackageType":"APPL", "CFBundleShortVersionString":version, "CFBundleVersion":version, "GitCommitHash":revision, "LSMinimumSystemVersion":"26.0", "LSApplicationCategoryType":"public.app-category.productivity", "NSHighResolutionCapable":true, "NSMicrophoneUsageDescription":"Captain's Log records voice memos from your selected microphone. Audio is processed on-device and never leaves your Mac.", "NSHumanReadableCopyright":"Koen van Gilst"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
        for file in files(notices, recursive: true) { try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
        try run(["xattr", "-cr", app.path]); try run(["codesign", "--force", "--sign", "-", app.appendingPathComponent("Contents/Frameworks/llama.framework").path])
        try run(["codesign", "--force", "--deep", "--sign", "-", app.path]); try run(["codesign", "--verify", "--deep", "--strict", app.path]); try run(["codesign", "--verify", "--strict", cli.path])
        let archive = path("dist/CaptainsLog-\(version).zip"), tempArchive = URL(fileURLWithPath: archive.path + ".tmp")
        try run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app.path, tempArchive.path])
        if fm.fileExists(atPath: archive.path) { try fm.removeItem(at: archive) }; try fm.moveItem(at: tempArchive, to: archive)
        print("App: \(app.path)\nArchive: \(archive.path)\n\(try hash(archive))  \(archive.path)")
    }
    func makeIconset() throws {
        let temp = try temporary("captainslog-icons-"); defer { try? fm.removeItem(at: temp) }
        let iconset = temp.appendingPathComponent("AppIcon.iconset"), source = temp.appendingPathComponent("icon-1024.png")
        try mkdir(iconset); try mkdir(path("Resources")); try run(["swift", "scripts/make-icon.swift", source.path])
        for size in [16,32,128,256,512] {
            for scale in [1,2] {
                let filename = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
                if size * scale == 1024 { try copy(source, iconset.appendingPathComponent(filename)) }
                else { try run(["sips", "-z", String(size * scale), String(size * scale), source.path, "--out", iconset.appendingPathComponent(filename).path], quiet: true) }
            }
        }
        try run(["iconutil", "-c", "icns", iconset.path, "-o", path("Resources/AppIcon.icns").path]); print("Wrote Resources/AppIcon.icns")
    }
}
