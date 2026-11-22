import SwiftUI

/// App shell: the search screen is the navigation root, and a lookup
/// (loading, report or error) is pushed on top of it. The push is driven by
/// `SearchViewModel.state`, so deep links, the App Shortcut and the widget
/// keep steering the UI through the view model.
struct RootView: View {
    @Bindable var viewModel: SearchViewModel
    @AppStorage(Onboarding.seenKey) private var hasSeenOnboarding = false

    /// The last non-empty state, kept so the pushed screen still has content
    /// while it animates away after the state returns to `.empty`.
    @State private var lastLookup: LookupState = .empty

    private var isLookupPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state != .empty },
            set: { presented in
                if !presented, viewModel.state != .empty { viewModel.goBack() }
            }
        )
    }

    private var isOnboardingPresented: Binding<Bool> {
        Binding(get: { !hasSeenOnboarding }, set: { hasSeenOnboarding = !$0 })
    }

    var body: some View {
        NavigationStack {
            SearchView(viewModel: viewModel)
                .navigationDestination(isPresented: isLookupPresented) {
                    lookupScreen(for: viewModel.state == .empty ? lastLookup : viewModel.state)
                }
        }
        .onChange(of: viewModel.state, initial: true) { _, state in
            if state != .empty { lastLookup = state }
        }
        .sensoryFeedback(trigger: viewModel.state) { _, state in
            switch state {
            case .loaded: return .success
            case .error:  return .error
            default:      return nil
            }
        }
        .fullScreenCover(isPresented: isOnboardingPresented) {
            OnboardingView { plate in
                hasSeenOnboarding = true
                if let plate {
                    viewModel.plateInput = plate
                    viewModel.search()
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "he_IL"))
            .tint(Theme.Colors.primary)
        }
    }

    @ViewBuilder
    private func lookupScreen(for state: LookupState) -> some View {
        switch state {
        case .empty:
            Theme.Colors.background.ignoresSafeArea()
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
}

#Preview {
    RootView(viewModel: SearchViewModel(history: .init()))
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}
