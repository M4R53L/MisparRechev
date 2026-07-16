import SwiftUI

@main
struct MisparRechevApp: App {
    @State private var viewModel = SearchViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he_IL"))
                .tint(Theme.Colors.primary)
        }
    }
}