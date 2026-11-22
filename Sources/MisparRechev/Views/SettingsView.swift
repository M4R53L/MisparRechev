import SwiftUI

/// Settings and help: the pinned car, the guide, stored data and where the
/// information comes from.
struct SettingsView: View {
    @Bindable var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Onboarding.seenKey) private var hasSeenOnboarding = true
    @State private var isConfirmingClear = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let car = viewModel.myCar.car {
                        HStack {
                            Text(car.title)
                            Spacer()
                            PlateView(number: String(car.plate), size: .compact)
                        }
                        Button("הסרת הרכב שלי", role: .destructive) {
                            viewModel.unpinCar()
                        }
                    } else {
                        Text("עדיין לא נבחר רכב. פתחו דוח של רכב והקישו על הכוכב.")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                } header: {
                    Text("הרכב שלי")
                } footer: {
                    Text("לרכב שסומן נשלחות תזכורות 30 ו־7 ימים לפני שהטסט פג, והתראה כשנפתח ריקול חדש.")
                }

                Section("עזרה") {
                    Button {
                        dismiss()
                        // Present the guide once this sheet has finished closing.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            hasSeenOnboarding = false
                        }
                    } label: {
                        Label("הצגת המדריך מחדש", systemImage: "play.circle")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingClear = true
                    } label: {
                        Label("מחיקת החיפושים האחרונים", systemImage: "trash")
                    }
                    .disabled(viewModel.history.entries.isEmpty)
                } header: {
                    Text("המידע שלי")
                } footer: {
                    Text("החיפושים נשמרים במכשיר הזה בלבד. האפליקציה לא אוספת מידע אישי.")
                }

                Section("אודות") {
                    Link(destination: URL(string: "https://data.gov.il")!) {
                        Label("מקור המידע: data.gov.il", systemImage: "building.columns")
                    }
                    Link(destination: URL(string: "https://m4r53l.github.io/MisparRechev-privacy")!) {
                        Label("מדיניות פרטיות ותמיכה", systemImage: "hand.raised")
                    }
                    LabeledContent("גרסה", value: version)
                }
            }
            .navigationTitle("הגדרות")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סיום") { dismiss() }
                }
            }
            .confirmationDialog("למחוק את כל החיפושים האחרונים?",
                                isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("מחיקת ההיסטוריה", role: .destructive) { viewModel.clearHistory() }
                Button("ביטול", role: .cancel) {}
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
    }
}

#Preview {
    SettingsView(viewModel: SearchViewModel())
}
