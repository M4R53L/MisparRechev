import SwiftUI

/// Top-level screen that switches between the lookup states. The individual
/// screens (`SearchView`, `LoadingView`, `ResultView`, `ErrorView`) live in
/// the `Views/` group and are styled by the design system.
struct RootView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            switch viewModel.state {
            case .empty:
                SearchView(viewModel: viewModel)
            case .loading:
                LoadingView()
            case .loaded(let result, let freshness):
                ResultView(viewModel: viewModel, vehicle: result.vehicle,
                           spec: result.spec, mileage: result.mileage,
                           ownership: result.ownership, recalls: result.recalls,
                           prices: result.prices,
                           electricRangeKm: result.electricRangeKm,
                           freshness: freshness)
            case .error(let error):
                ErrorView(viewModel: viewModel, error: error)
            }
        }
        .animation(.easeInOut(duration: Theme.Motion.durationStandard), value: viewModel.state)
        .preferredColorScheme(nil) // respect system; dark-mode-ready via asset colors
    }
}

#Preview {
    RootView(viewModel: SearchViewModel(history: .init()))
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}