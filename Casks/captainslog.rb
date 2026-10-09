cask "captainslog" do
  version "0.3.1"
  sha256 "66d58d44f33623a4f59d848e40481688c3857ec5f9e0f23cf566af16b4a7ea64"

  url "https://github.com/vnglst/CaptainsLog/releases/download/v#{version}/CaptainsLog-#{version}.zip"
  name "Captain's Log"
  desc "Local-only voice memo pipeline for Apple Silicon"
  homepage "https://github.com/vnglst/CaptainsLog"

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "CaptainsLog.app"
  binary "#{appdir}/CaptainsLog.app/Contents/MacOS/cl"

  # Homebrew quarantines downloads; remove that attribute from this app so the
  # ad-hoc signed GUI and CLI can run without a Developer ID notarization.
  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/CaptainsLog.app"],
        base:           :appdir,
        writable_paths: ["CaptainsLog.app"],
        writable_base:  :appdir
  end

  uninstall quit: "nl.koenvangilst.CaptainsLog"

  # Remove only models downloaded into CaptainsLog's managed locations. Keep
  # logs, configuration, and models stored in user-selected external folders.
  zap trash: [
    "~/Library/Application Support/CaptainsLog/models",
    "~/Library/Caches/CaptainsLog/models",
  ]
end
