import SwiftUI

/// Last reported mileage + engine number.
struct MileageView: View {
    let history: VehicleHistory

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let km = history.mileageKm {
                InfoRow(label: "קילומטראז׳", value: km,
                        systemImage: "speedometer", monospaced: true)
            } else {
                InfoRow(label: "קילומטראז׳", value: "קילומטראז׳ לא מדווח")
            }
            if let manoa = history.mispar_manoa, !manoa.isEmpty {
                InfoRow(label: "מספר מנוע", value: manoa,
                        systemImage: "gearshape.2.fill", monospaced: true)
            }
        }
    }
}

#Preview {
    MileageView(history: .preview)
        .padding()
        .background(Theme.Colors.background)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}
