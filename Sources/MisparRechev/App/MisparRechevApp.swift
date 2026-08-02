import SwiftUI

@main
struct MisparRechevApp: App {
    @State private var viewModel = SearchViewModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register the App Shortcuts ("בדיקת רכב") with the system.
        MisparRechevShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he_IL"))
                .tint(Theme.Colors.primary)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Refresh the pinned car's status when it's stale, then
                // re-read the shared store so the UI reflects it.
                Task {
                    await MyCarRefresher.shared.refreshIfNeeded()
                    viewModel.reloadMyCar()
                }
            case .background:
                MyCarRefresher.scheduleAppRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(MyCarRefresher.taskIdentifier)) {
            await MyCarRefresher.shared.refresh()
            MyCarRefresher.scheduleAppRefresh()
        }
    }

    /// misparrechev://my-car → open the pinned car (widget tap);
    /// misparrechev://plate/<digits> → look up that plate.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "misparrechev" else { return }
        switch url.host {
        case "my-car":
            if let plate = viewModel.pinnedPlate {
                viewModel.searchFromHistory(plate: plate)
            }
        case "plate":
            let digits = url.pathComponents.dropFirst().first?.filter(\.isNumber) ?? ""
            if !digits.isEmpty {
                viewModel.plateInput = digits
                viewModel.search()
            }
        default:
            break
        }
    }
}
