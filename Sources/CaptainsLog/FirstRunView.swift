import SwiftUI

struct FirstRunView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            topBar
            body_
        }
        .frame(width: 720, height: 780)
        .background(Color.lcarsVoid)
        .preferredColorScheme(.dark)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .top, spacing: 6) {
            LCARSElbow(color: .lcarsOrange, width: 150, height: 94, radius: 44, direction: .topLeft, thickness: 34)

            VStack(alignment: .leading, spacing: 8) {
                // Title row
                HStack(spacing: 6) {
                    HStack {
                        Spacer()
                        Text("WELCOME ABOARD")
                            .font(LCARSFonts.antonio(18, weight: .semibold))
                            .foregroundStyle(.black)
                            .tracking(18 * 0.14)
                            .lineLimit(1)
                            .padding(.trailing, 20)
                    }
                    .frame(height: 34)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0, bottomLeadingRadius: 0,
                            bottomTrailingRadius: 17, topTrailingRadius: 17
                        )
                        .fill(Color.lcarsOrange)
                    )

                    LCARSPill(label: "FIRST LAUNCH", color: .lcarsWheat, height: 34, pad: 14)
                }

                // Breadcrumb row
                HStack(spacing: 6) {
                    LCARSCell(label: "STEP 1", color: .lcarsRusset, height: 18, width: 80)
                    LCARSCell(label: "CHOOSE DATA FOLDER", color: .lcarsDusty, height: 18, width: 160)
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.lcarsDark)
                        .frame(height: 18)
                }
            }
            .padding(.trailing, 14)
        }
        .padding(.top, 38)
        .padding(.leading, 10)
    }

    // MARK: - Body

    private var body_: some View {
        HStack(alignment: .top, spacing: 6) {
            leftRail
            content
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.top, 6)
        .frame(height: 600)
    }

    // MARK: - Left rail

    private var leftRail: some View {
        VStack(spacing: 4) {
            LCARSCell(label: "● WELCOME", color: .lcarsOrange, height: 60, width: 150, align: .trailing)
            LCARSCell(label: "○ READY", color: Color(hex: "#2a2520"), textColor: .black, height: 36, width: 150, align: .trailing)

            Spacer().frame(height: 14)

            LCARSCell(label: "OFFLINE",   color: .lcarsRusset, height: 22, width: 150, align: .trailing)
            LCARSCell(label: "PRIVATE",   color: .lcarsPlum,   height: 22, width: 150, align: .trailing)
            LCARSCell(label: "ON-DEVICE", color: .lcarsSteel,  height: 22, width: 150, align: .trailing)

            Spacer()

            LCARSElbow(color: .lcarsOrange, width: 150, height: 60, radius: 44, direction: .bottomLeft, thickness: 34)
        }
        .frame(width: 150)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading
            folderSection
            Spacer()
            navButtons
        }
        .padding(.top, 4)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your voice.")
                    .font(LCARSFonts.antonio(34, weight: .medium))
                    .foregroundStyle(Color.lcarsInk)
                Text("Structured.")
                    .font(LCARSFonts.antonio(34, weight: .medium))
                    .foregroundStyle(Color.lcarsInk)
                Text("On this Mac. Only.")
                    .font(LCARSFonts.antonio(34, weight: .medium))
                    .foregroundStyle(Color.lcarsOrange)
            }
            .tracking(34 * 0.04)
            .lineSpacing(2)

            Text("CaptainsLog transcribes, cleans, names and enriches your recordings entirely on this machine. Nothing leaves your Mac. Choose where your logs will live — any folder, including an Obsidian vault or synced drive.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color(hex: "#a9a090"))
                .lineSpacing(6)
                .frame(maxWidth: 480, alignment: .leading)
        }
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                LCARSCell(label: "DATA FOLDER", color: .lcarsWheat, height: 24, width: 150, align: .leading)
                Rectangle()
                    .fill(Color.lcarsDim2)
                    .frame(height: 2)
            }
            .padding(.bottom, 10)

            // Folder picker row
            HStack(spacing: 14) {
                Text("▣")
                    .font(.system(size: 24, design: .monospaced))
                    .foregroundStyle(Color.lcarsOrange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(shortenedPath(appState.dataDir))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.lcarsInk)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(folderMeta)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.lcarsDim)
                        .tracking(10 * 0.05)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    appState.pickDataDirectory()
                } label: {
                    LCARSPill(label: "CHOOSE…", color: .lcarsOrange, height: 30, pad: 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.lcarsPanel)

            Text("Each recording becomes a Markdown file with its audio alongside. Change this anytime in Settings.")
                .font(.system(size: 12))
                .foregroundStyle(Color.lcarsDim)
                .lineSpacing(5)
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.top, 10)
        }
    }

    private var navButtons: some View {
        HStack(spacing: 8) {
            Button {
                NSApp.terminate(nil)
            } label: {
                LCARSPill(label: "QUIT", color: Color.lcarsDim2, textColor: .black, height: 40, pad: 20)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                appState.completeFirstRun()
                dismiss()
            } label: {
                LCARSPill(label: "BEGIN →", color: .lcarsOrange, height: 40, pad: 22)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func shortenedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private var folderMeta: String {
        let url = URL(fileURLWithPath: appState.dataDir)
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: url.path)
        let free = (attrs?[.systemFreeSize] as? Int64) ?? 0
        let gb = Double(free) / 1_073_741_824
        let freeStr = gb > 0 ? String(format: "%.0f GB FREE", gb) : "UNKNOWN FREE"
        return "EMPTY FOLDER · \(freeStr) · APFS"
    }
}
