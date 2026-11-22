import SwiftUI

/// The plate you type into: an Israeli plate (yellow, dark rim, blue IL strip)
/// wrapped around a real, visible `TextField` so it reliably takes focus.
/// Digits only, numeric keypad.
struct PlateField: View {
    @Binding var text: String
    /// Triggered when the user taps the clear button.
    var onClear: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        PlateChrome(stripWidth: 34) {
            HStack(spacing: 0) {
                TextField("", text: $text,
                          prompt: Text("00-000-00")
                              .font(Theme.Typography.plate)
                              .foregroundStyle(Theme.Colors.textOnPlate.opacity(0.28)))
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .font(Theme.Typography.plate)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.textOnPlate)
                    .tint(Theme.Colors.textOnPlate)
                    .lineLimit(1)
                    .focused($isFocused)
                    .frame(minHeight: 44)
                    .accessibilityLabel("מספר רישוי")
                    .accessibilityValue(text.isEmpty ? "ריק" : text)

                clearButton
                    .opacity(text.isEmpty ? 0 : 1)
                    .disabled(text.isEmpty)
            }
            .padding(.leading, Theme.Spacing.xxl)   // balances the clear button
            .padding(.trailing, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.m)
        }
        .fixedSize(horizontal: false, vertical: true)
        .cardShadow()
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private var clearButton: some View {
        Button {
            text = ""
            onClear?()
            isFocused = true // return focus to the field for another entry
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Colors.textOnPlate.opacity(0.55))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("נקה מספר רישוי")
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var txt: String = "5970065"
    return VStack(spacing: 20) {
        PlateField(text: $txt)
        PlateField(text: .constant(""))
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}
