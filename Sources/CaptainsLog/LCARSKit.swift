import SwiftUI

// MARK: - LCARSElbow
// The signature LCARS "L" corner piece — two overlapping rectangles
// both sharing a single large radius on the outer corner.
// The overlap forms a solid L without any gap at the inner joint.

struct LCARSElbow: View {
    var color: Color = .lcarsOrange
    var width: CGFloat = 110
    var height: CGFloat = 74
    var radius: CGFloat = 36
    var direction: Direction = .topLeft
    var thickness: CGFloat = 26

    enum Direction { case topLeft, topRight, bottomLeft, bottomRight }

    var body: some View {
        ZStack {
            // Horizontal bar — fills full width at top or bottom
            outerRoundedRect
                .fill(color)
                .frame(width: width, height: thickness)
                .frame(width: width, height: height, alignment: isTop ? .top : .bottom)

            // Vertical bar — fills full height at left or right
            outerRoundedRect
                .fill(color)
                .frame(width: thickness, height: height)
                .frame(width: width, height: height, alignment: isLeft ? .leading : .trailing)
        }
        .frame(width: width, height: height)
    }

    private var isTop:  Bool { direction == .topLeft  || direction == .topRight }
    private var isLeft: Bool { direction == .topLeft  || direction == .bottomLeft }

    // Each bar uses the same outer-corner radius; the inner corners stay sharp.
    private var outerRoundedRect: UnevenRoundedRectangle {
        switch direction {
        case .topLeft:
            return UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 0, topTrailingRadius: 0)
        case .topRight:
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 0, topTrailingRadius: radius)
        case .bottomLeft:
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius,
                                          bottomTrailingRadius: 0, topTrailingRadius: 0)
        case .bottomRight:
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                          bottomTrailingRadius: radius, topTrailingRadius: 0)
        }
    }
}

// MARK: - LCARSCell
// Rectangular color block used as a label strip — no corner rounding.

struct LCARSCell: View {
    let label: String
    var color: Color = .lcarsOrange
    var textColor: Color = .black
    var height: CGFloat = 26
    var width: CGFloat? = nil
    var align: Alignment = .trailing
    var fontSize: CGFloat? = nil

    var body: some View {
        Text(label)
            .font(LCARSFonts.antonio(fontSize ?? max(8, height * 0.48), weight: .medium))
            .foregroundStyle(textColor)
            .tracking(height * 0.06)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(maxWidth: width ?? .infinity, maxHeight: .infinity, alignment: align)
            .frame(height: height)
            .background(color)
            .frame(width: width)
    }
}

// MARK: - LCARSPill
// Fully rounded capsule label — same display font as Cell.

struct LCARSPill: View {
    let label: String
    var color: Color = .lcarsOrange
    var textColor: Color = .black
    var height: CGFloat = 26
    var pad: CGFloat = 12

    var body: some View {
        Text(label)
            .font(LCARSFonts.antonio(height * 0.48, weight: .medium))
            .foregroundStyle(textColor)
            .tracking(height * 0.04)
            .lineLimit(1)
            .padding(.horizontal, pad)
            .frame(height: height)
            .background(Capsule().fill(color))
    }
}

// MARK: - WaveformBars
// Visualizes audio level as a bell-curve-enveloped bar chart.
// Deterministic seed ensures stable bar heights; level scales the amplitude.
// When level == 0 (idle), bars render at 25% opacity.

struct WaveformBars: View {
    var level: Float = 0      // 0…1 normalized audio level
    var color: Color = .lcarsOrange
    var height: CGFloat = 28
    var count: Int = 48
    var seed: Int = 1

    private var bars: [CGFloat] {
        var s = seed
        return (0..<count).map { i in
            s = (s * 9301 + 49297) % 233280
            let r = CGFloat(s) / 233280
            let centerDist = abs(CGFloat(i) - CGFloat(count) / 2) / (CGFloat(count) / 2)
            let env: CGFloat = 1 - centerDist * 0.6
            return max(2, (0.25 + r * 0.75) * height * env)
        }
    }

    var body: some View {
        let scale = CGFloat(max(0.08, level))
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, h in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: h * scale)
                    .opacity(level > 0 ? (0.5 + (h / height) * 0.5) : 0.25)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.06), value: level)
    }
}

// MARK: - StageDots
// Pipeline segment bars showing transcription through enrichment.

struct StageDots: View {
    enum SegState { case done, active, queued, paused }

    let stages: [SegState]   // 5 elements: [TRN, CLN, CAT, NAM, ENR]
    var compact: Bool = true

    private let labels = ["TRN", "CLN", "CAT", "NAM", "ENR"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(segColor(stages[safe: i] ?? .queued))
                        .frame(width: compact ? 18 : 26, height: 4)
                    if !compact {
                        Text(labels[i])
                            .font(LCARSFonts.antonio(8))
                            .foregroundStyle(Color.lcarsInk)
                            .tracking(1.2)
                    }
                }
            }
        }
    }

    private func segColor(_ state: SegState) -> Color {
        switch state {
        case .done:   return .lcarsOrange
        case .active: return .lcarsWheat
        case .queued: return Color(hex: "#2a2520")
        case .paused: return .lcarsRusset
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
