import SwiftUI

/// Full-row preferences with native Toggle accessibility and keyboard focus.
struct FieldNotesToggleStyle: ToggleStyle {
    enum Appearance { case `switch`, checkbox }
    var appearance: Appearance = .switch

    func makeBody(configuration: Configuration) -> some View {
        Preference(configuration: configuration, appearance: appearance)
    }

    private struct Preference: View {
        let configuration: ToggleStyleConfiguration
        let appearance: Appearance
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @FocusState private var focused: Bool
        @CLState private var hovered = false

        var body: some View {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                    configuration.isOn.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    configuration.label
                        .frame(maxWidth: .infinity, alignment: .leading)
                    indicator.frame(width: 44, height: 28)
                }
                .padding(12)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FieldNotes.ColorToken.primaryText.opacity(hovered && isEnabled ? 0.035 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(FieldNotes.ColorToken.amber.opacity(focused ? 1 : 0), lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .focused($focused)
            .onHover { hovered = $0 }
            .opacity(isEnabled ? 1 : 0.55)
            .accessibilityRepresentation {
                // The custom drawing remains a true switch/checkbox for VoiceOver.
                switch appearance {
                case .switch:
                    Toggle(isOn: configuration.$isOn) { configuration.label }
                        .toggleStyle(.switch)
                        .disabled(!isEnabled)
                case .checkbox:
                    Toggle(isOn: configuration.$isOn) { configuration.label }
                        .toggleStyle(.checkbox)
                        .disabled(!isEnabled)
                }
            }
        }

        @ViewBuilder
        private var indicator: some View {
            switch appearance {
            case .switch:
                Capsule()
                    .fill(configuration.isOn ? FieldNotes.ColorToken.amber : FieldNotes.ColorToken.surface)
                    .overlay(Capsule().strokeBorder(configuration.isOn
                        ? FieldNotes.ColorToken.amber : FieldNotes.ColorToken.tertiaryText, lineWidth: 1))
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? FieldNotes.ColorToken.canvas : FieldNotes.ColorToken.secondaryText)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(FieldNotes.ColorToken.primaryText)
                                    .opacity(configuration.isOn ? 1 : 0)
                            }
                            .frame(width: 20, height: 20)
                            .padding(2)
                    }
                    .frame(width: 44, height: 24)
            case .checkbox:
                RoundedRectangle(cornerRadius: 5)
                    .fill(configuration.isOn ? FieldNotes.ColorToken.amber : FieldNotes.ColorToken.surface)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(configuration.isOn
                        ? FieldNotes.ColorToken.amber : FieldNotes.ColorToken.tertiaryText, lineWidth: 1))
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(FieldNotes.ColorToken.canvas)
                            .opacity(configuration.isOn ? 1 : 0)
                    }
                    .frame(width: 20, height: 20)
            }
        }
    }
}
