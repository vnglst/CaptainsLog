import CoreText
import SwiftUI

/// Swift 6.4's macOS SDK also declares a `State` macro, but the standalone
/// Command Line Tools do not ship its implementation. Referencing the original
/// property-wrapper type through an alias keeps command-line builds working.
public typealias CLState<Value> = SwiftUI.State<Value>

// MARK: - Font Registration

public enum LCARSFonts {
    public static let registered: Bool = {
        guard let url = Bundle.module.url(forResource: "Antonio-VariableFont_wght", withExtension: "ttf") else {
            return false
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return true
    }()

    static func antonio(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        _ = registered
        return .custom("Antonio", size: size).weight(weight)
    }
}

// MARK: - Color Palette (Violet)

extension Color {
    // Primary accent colors
    static let lcarsOrange = Color(hex: "#E89B3C")   // primary: rail, record button
    static let lcarsWheat  = Color(hex: "#C8A97E")   // secondary: titles, active state
    static let lcarsRusset = Color(hex: "#A86B9E")   // error/stop, recording state
    static let lcarsPlum   = Color(hex: "#9966CC")   // tertiary accent
    static let lcarsSteel  = Color(hex: "#6688CC")   // quaternary accent
    static let lcarsDusty  = Color(hex: "#C8A97E")   // dusty warm — same as wheat in violet

    // Surfaces
    static let lcarsVoid   = Color(hex: "#07070a")   // window background
    static let lcarsPanel  = Color(hex: "#0f0b08")   // card / dock backgrounds
    static let lcarsDark   = Color(hex: "#1a1613")   // subtle inset backgrounds
    static let lcarsDim2   = Color(hex: "#2a2520")   // dividers, inactive cells

    // Text
    static let lcarsInk    = Color(hex: "#f3e9d8")   // warm off-white body text
    static let lcarsDim    = Color(hex: "#8a8173")   // muted metadata text

    // Aliases for backward-compat with legacy code paths
    static let lcarsAmber      = lcarsOrange
    static let lcarsAmberDim   = lcarsWheat.opacity(0.6)
    static let lcarsPurple     = lcarsPlum
    static let lcarsBackground = lcarsVoid
    static let lcarsCard       = lcarsPanel
    static let lcarsCardHover  = lcarsDark
    static let lcarsRed        = lcarsRusset
    static let lcarsBorder     = lcarsWheat.opacity(0.2)

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - Spacing tokens

enum LCARSSpacing {
    static let xs: CGFloat = 4
    static let s:  CGFloat = 6
    static let m:  CGFloat = 10
    static let l:  CGFloat = 16
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
}

// MARK: - Legacy component shims (used by SettingsView / FirstRunView until redesigned)

struct LCARSCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color.lcarsPanel)
    }
}

struct LCARSCardStroke: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8).strokeBorder(Color.lcarsWheat.opacity(0.2), lineWidth: 1)
    }
}

struct LCARSCapsuleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Capsule().strokeBorder(Color.lcarsWheat.opacity(0.2), lineWidth: 1))
    }
}

extension View {
    func lcarsCapsule() -> some View { modifier(LCARSCapsuleStyle()) }
}

struct LCARSDivider: View {
    var body: some View {
        HStack(spacing: LCARSSpacing.s) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.lcarsWheat.opacity(0.3))
                .frame(height: 2)
            Circle()
                .fill(Color.lcarsWheat.opacity(0.4))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, LCARSSpacing.xxl)
    }
}

struct LCARSButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, LCARSSpacing.l)
                .padding(.vertical, LCARSSpacing.m)
                .background(isDisabled ? Color.lcarsWheat.opacity(0.15) : Color.lcarsOrange)
                .foregroundStyle(isDisabled ? Color.lcarsDim : Color.lcarsVoid)
                .clipShape(Capsule())
        }
        .disabled(isDisabled)
    }
}

struct LCARSSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, LCARSSpacing.l)
                .padding(.vertical, LCARSSpacing.m)
                .background(Capsule().strokeBorder(Color.lcarsWheat.opacity(0.2), lineWidth: 1))
        }
    }
}

enum LCARSFont {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static let title   = mono(22, weight: .medium)
    static let body    = mono(13)
    static let caption = mono(11)
}

struct PromptField: View {
    @Binding var text: String
    let placeholder: String
    var isMonospaced: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(isMonospaced ? LCARSFont.mono(12) : .system(size: 13))
                    .foregroundStyle(Color.lcarsDim)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.visible)
                .font(isMonospaced ? LCARSFont.mono(12) : .system(size: 13))
                .lineSpacing(isMonospaced ? 5 : 4)
                .foregroundStyle(Color.lcarsInk)
                .tint(Color.lcarsAmber)
                .frame(minHeight: 80, maxHeight: 220)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(LCARSCard())
        .overlay(LCARSCardStroke())
    }
}
