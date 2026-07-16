import SwiftUI

/// Israeli yellow license-plate style numeric input.
///
/// Uses a **real, visible `TextField`** (not a hidden one) so it reliably
/// becomes first responder and accepts typing. Digits-only, numeric keyboard,
/// large monospaced digits centered on the yellow plate — RTL.
struct PlateField: View {
    @Binding var text: String
    /// Triggered when the user taps the clear (×) button.
    var onClear: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    private let maxDigits = 8

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            // Label — in RTL, leading = right.
            Text("מספר רישוי")
                .font(Theme.Typography.captionBold)
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ZStack(alignment: .topTrailing) {
                plate
                if !text.isEmpty {
                    clearButton
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                }
            }
        }
    }

    // MARK: - Plate (the actual input)

    private var plate: some View {
        // A visible TextField is the reliable way to accept input — it focuses
        // on tap and shows the keyboard. Styled to look like the yellow plate.
        TextField("", text: $text,
                  prompt: Text("0000000")
                      .font(Theme.Typography.plate)
                      .foregroundStyle(Theme.Colors.textOnPlate.opacity(0.35)))
            .keyboardType(.numberPad)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .font(Theme.Typography.plate)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.Colors.textOnPlate)
            .tint(Theme.Colors.textOnPlate)
            .lineLimit(1)
            .focused($isFocused)
            .frame(minWidth: 240, minHeight: 56)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.plate, style: .continuous)
                    .fill(Theme.Colors.plateYellow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.plate, style: .continuous)
                    .strokeBorder(Theme.Colors.plateBorder, lineWidth: 2)
            )
            .cardShadow()
            .accessibilityLabel("מספר רישוי")
            .accessibilityValue(text.isEmpty ? "ריק" : text)
    }

    private var clearButton: some View {
        Button {
            text = ""
            onClear?()
            isFocused = true // return focus to the field for another entry
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.Colors.textOnPlate, .white.opacity(0.9))
                .padding(6)
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