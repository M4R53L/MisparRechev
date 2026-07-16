import SwiftUI

/// The hero / empty state. Title, plate field, search button, and a recent-history list.
struct SearchView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                plateAndButton
                historySection
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "car.2.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .accessibilityHidden(true)
                Text("מספר רכב")
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Text("בדיקת פרטי רכב לפי מספר רישוי ממאגרי משרד התחבורה")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plate + search button

    private var plateAndButton: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            PlateField(text: $viewModel.plateInput)

            Button {
                viewModel.search()
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "magnifyingglass")
                    Text("חיפוש")
                }
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .fill(viewModel.canSearch ? Theme.Colors.primary
                                                  : Theme.Colors.neutral)
                )
            }
            .disabled(!viewModel.canSearch)
            .accessibilityHint("מבצע חיפוש לפי מספר הרישוי שהוזן")
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        if !viewModel.history.entries.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Text("חיפושים אחרונים")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Button(role: .destructive) {
                        viewModel.clearHistory()
                    } label: {
                        Text("נקה היסטוריה")
                            .font(Theme.Typography.captionBold)
                    }
                }
                .padding(.bottom, Theme.Spacing.xs)

                VStack(spacing: 0) {
                    ForEach(viewModel.history.entries) { entry in
                        Button {
                            viewModel.search(plate: entry.plate)
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.Colors.primary)
                                Text(format(plate: entry.plate))
                                    .font(Theme.Typography.monoValue)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Text(relativeTime(entry.timestamp))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(.vertical, Theme.Spacing.m)
                            .padding(.horizontal, Theme.Spacing.m)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {   // trailing = right in LTR; SwiftUI mirrors for RTL
                            Button(role: .destructive) {
                                viewModel.removeHistory(plate: entry.plate)
                            } label: { Label("מחק", systemImage: "trash") }
                        }
                        if entry.id != viewModel.history.entries.last?.id {
                            Divider().padding(.leading, Theme.Spacing.l)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                        .fill(Theme.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(0.5), lineWidth: 0.5)
                )
                .cardShadow()
            }
        }
    }

    // MARK: - Helpers

    private func format(plate: Int) -> String { String(plate) }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "he_IL")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}
