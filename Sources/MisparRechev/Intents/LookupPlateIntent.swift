import AppIntents

/// "בדיקת רכב" — App Shortcut (Siri / Shortcuts / Spotlight) that opens the
/// app and runs a plate lookup on the live view model.
struct LookupPlateIntent: AppIntent {
    static let title: LocalizedStringResource = "בדיקת רכב"
    static let description = IntentDescription("בדיקת פרטי רכב לפי מספר רישוי")
    static let openAppWhenRun = true

    @Parameter(title: "מספר רכב")
    var plate: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let viewModel = SearchViewModel.shared
        viewModel.plateInput = plate // didSet sanitizes to digits
        viewModel.search()
        return .result()
    }
}

struct MisparRechevShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LookupPlateIntent(),
            phrases: [
                "בדוק רכב ב\(.applicationName)",
                "בדיקת רכב ב\(.applicationName)"
            ],
            shortTitle: "בדיקת רכב",
            systemImageName: "magnifyingglass"
        )
    }
}
