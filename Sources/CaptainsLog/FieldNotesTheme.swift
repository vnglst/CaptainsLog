import SwiftUI

/// Semantic visual primitives for the Field Notes UI migration.
///
/// These tokens intentionally describe purpose rather than a historic visual theme so
/// recording, processing, and destructive states keep a consistent meaning everywhere.
enum FieldNotes {
    enum ColorToken {
        static let canvas = Color(hex: "#0D0E0D")
        static let surface = Color(hex: "#161715")
        static let raisedSurface = Color(hex: "#1C1D1B")
        static let stroke = Color(hex: "#30312E")
        static let primaryText = Color(hex: "#F1EEE7")
        static let secondaryText = Color(hex: "#B8B5AD")
        static let tertiaryText = Color(hex: "#85847E")
        static let amber = Color(hex: "#F5B544")
        static let mutedAmber = Color(hex: "#B88937")
        static let success = Color(hex: "#8FBD78")
        static let danger = Color(hex: "#D96859")
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 10
        static let card: CGFloat = 12
        static let dock: CGFloat = 22
    }

    enum Typography {
        static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        static func body(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        static func metadata(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

struct FieldNotesSurface: ViewModifier {
    enum Elevation { case flat, raised, floating }

    var elevation: Elevation = .raised
    var radius: CGFloat = FieldNotes.Radius.card

    func body(content: Content) -> some View {
        content
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(FieldNotes.ColorToken.stroke, lineWidth: 1)
            )
            .shadow(
                color: elevation == .floating ? .black.opacity(0.24) : .clear,
                radius: elevation == .floating ? 18 : 0,
                y: elevation == .floating ? 8 : 0
            )
    }

    @ViewBuilder
    private var background: some View {
        switch elevation {
        case .flat:
            FieldNotes.ColorToken.surface
        case .raised, .floating:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(FieldNotes.ColorToken.raisedSurface)
        }
    }
}

extension View {
    func fieldNotesSurface(
        _ elevation: FieldNotesSurface.Elevation = .raised,
        radius: CGFloat = FieldNotes.Radius.card
    ) -> some View {
        modifier(FieldNotesSurface(elevation: elevation, radius: radius))
    }
}

struct FieldNotesButton: View {
    enum Kind { case primary, secondary, destructive }

    let title: String
    var kind: Kind = .primary
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FieldNotes.Typography.body(13, weight: .medium))
                .foregroundStyle(foreground)
                .padding(.horizontal, FieldNotes.Spacing.m)
                .frame(minHeight: 34)
                .background(background)
                .overlay(
                    RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous)
                        .strokeBorder(border, lineWidth: kind == .primary && !isDisabled ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityAddTraits(isDisabled ? .isStaticText : .isButton)
    }

    private var foreground: Color {
        if isDisabled { return FieldNotes.ColorToken.tertiaryText }
        return kind == .primary || kind == .destructive ? FieldNotes.ColorToken.canvas : FieldNotes.ColorToken.primaryText
    }

    private var border: Color {
        if isDisabled { return FieldNotes.ColorToken.stroke }
        return kind == .destructive ? FieldNotes.ColorToken.danger : FieldNotes.ColorToken.stroke
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: FieldNotes.Radius.control, style: .continuous)
            .fill(fill)
    }

    private var fill: Color {
        guard !isDisabled else { return FieldNotes.ColorToken.surface }
        switch kind {
        case .primary: return FieldNotes.ColorToken.amber
        case .secondary: return FieldNotes.ColorToken.raisedSurface
        case .destructive: return FieldNotes.ColorToken.danger
        }
    }
}

struct FieldNotesStatus: View {
    enum State { case processed, active, paused, failed }

    let state: State
    var label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(FieldNotes.Typography.body(12, weight: .medium))
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch state {
        case .processed: return FieldNotes.ColorToken.success
        case .active: return FieldNotes.ColorToken.amber
        case .paused: return FieldNotes.ColorToken.tertiaryText
        case .failed: return FieldNotes.ColorToken.danger
        }
    }
}

/// A compact audio-native signature that represents level, playback, or recorded audio.
struct FieldNotesAudioRuler: View {
    var level: Float = 0
    var color: Color = FieldNotes.ColorToken.amber
    var height: CGFloat = 24
    var count = 48
    var seed = 1

    static func tickHeights(seed: Int, count: Int, height: CGFloat) -> [CGFloat] {
        // `seed` may come from Swift's arbitrary `hashValue`, which can be negative
        // or near `Int.max`. Use an unsigned wrapping generator so a visual detail
        // can never crash the application through checked integer overflow.
        var state = UInt64(bitPattern: Int64(seed))
        return (0..<max(0, count)).map { _ in
            state = state &* 1_103_515_245 &+ 12_345
            let value = CGFloat(state % 233_280) / 233_280
            return max(2, height * (0.18 + value * 0.72))
        }
    }

    private var ticks: [CGFloat] {
        Self.tickHeights(seed: seed, count: count, height: height)
    }

    var body: some View {
        let active = CGFloat(max(0.08, min(1, level)))
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                Capsule()
                    .fill(color)
                    .frame(width: 2, height: tick * active)
                    .opacity(level > 0 ? 0.9 : 0.28)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .animation(.easeOut(duration: 0.08), value: level)
    }
}
