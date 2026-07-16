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
            case .loaded(let vehicle, let mileage, let ownership):
                ResultView(viewModel: viewModel, vehicle: vehicle,
                           mileage: mileage, ownership: ownership)
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