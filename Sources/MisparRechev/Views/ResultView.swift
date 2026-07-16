import SwiftUI

/// Main result screen shown after a successful lookup.
struct ResultView: View {
    @Bindable var viewModel: SearchViewModel
    let vehicle: Vehicle
    let mileage: VehicleHistory?
    let ownership: [OwnershipRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                hero
                basicInfo
                technicalInfo
                licensingTests
                ownershipSection
                footerActions
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: Theme.Spacing.m) {
            yellowPlate(String(vehicle.mispar_rechev))

            VStack(spacing: Theme.Spacing.xs) {
                Text(vehicle.displayName)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: Theme.Spacing.s) {
                    if let m = vehicle.manufacturer {
                        Text(m)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if vehicle.manufacturer != nil, vehicle.year != nil {
                        Text("•").foregroundStyle(Theme.Colors.textTertiary)
                    }
                    if let y = vehicle.year {
                        Text(y)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .monospacedDigit()
                    }
                }

                if let importType = vehicle.importType {
                    Text("\(importType) · \(vehicle.countryOfManufacture ?? "")")
                        .font(Theme.Typography.captionBold)
                        .foregroundStyle(Theme.Colors.primary)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(
                            Capsule().fill(Theme.Colors.primary.opacity(0.12))
                        )
                        .padding(.top, Theme.Spacing.xs)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
    }

    private func yellowPlate(_ plate: String) -> some View {
        Text(plate)
            .font(Theme.Typography.plate)
            .foregroundStyle(Theme.Colors.textOnPlate)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .frame(minWidth: 240)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.plate, style: .continuous)
                    .fill(Theme.Colors.plateYellow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.plate, style: .continuous)
                    .strokeBorder(Theme.Colors.plateBorder, lineWidth: 2)
            )
            .cardShadow()
            .accessibilityLabel("מספר רישוי \(plate)")
    }

    // MARK: - Sections

    private var basicInfo: some View {
        InfoCard(title: "פרטים בסיסיים", systemImage: "car.fill") {
            InfoRow(label: "יצרן",       value: vehicle.manufacturer)
            InfoRow(label: "דגם",         value: vehicle.model)
            InfoRow(label: "שנת ייצור",   value: vehicle.year, monospaced: true)
            InfoRow(label: "צבע",         value: vehicle.tzeva_rechev)
            InfoRow(label: "סוג רכב",     value: vehicle.vehicleType)
            InfoRow(label: "ארץ ייצור",   value: vehicle.countryOfManufacture)
        }
    }

    private var technicalInfo: some View {
        InfoCard(title: "מפרט טכני", systemImage: "wrench.and.screwdriver.fill") {
            InfoRow(label: "סוג דלק",     value: vehicle.sug_delek_nm)
            InfoRow(label: "נפח מנוע",    value: vehicle.nefach_manoa.map { String($0) },
                    unit: vehicle.nefach_manoa != nil ? "סמ״ק" : nil,
                    monospaced: true)
            InfoRow(label: "משקל כולל",   value: vehicle.mishkal_kolel.flatMap { $0 > 0 ? String($0) : nil },
                    unit: vehicle.mishkal_kolel.flatMap { $0 > 0 ? "ק״ג" : nil },
                    monospaced: true)
            InfoRow(label: "משקל עצמי",   value: vehicle.ownWeight.flatMap { $0 > 0 ? String($0) : nil },
                    unit: vehicle.ownWeight.flatMap { $0 > 0 ? "ק״ג" : nil },
                    monospaced: true)
            InfoRow(label: "דגם מנוע",     value: vehicle.engineModel)
            InfoRow(label: "מספר מנוע",   value: vehicle.engineNumber, monospaced: true)
            InfoRow(label: "מספר שלדה",   value: vehicle.chassis, monospaced: true)
            PollutionScale(value: vehicle.kvutzat_zihum)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    private var licensingTests: some View {
        InfoCard(title: "רישוי ובדיקות", systemImage: "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                if vehicle.tokef_dt != nil {
                    rowWithBadge(label: "תוקף טסט",
                                 date: vehicle.tokef_dt,
                                 validity: SearchViewModel.validity(of: vehicle.tokef_dt))
                }
                if vehicle.tokef_rishuy != nil {
                    rowWithBadge(label: "תוקף רישיון",
                                 date: vehicle.tokef_rishuy,
                                 validity: SearchViewModel.validity(of: vehicle.tokef_rishuy))
                }
                if let moed = vehicle.moed_aliya_lakvish,
                   let formatted = SearchViewModel.displayDate(moed) {
                    InfoRow(label: "מועד עלייה לכביש", value: formatted, monospaced: true)
                } else if let raw = vehicle.moed_aliya_lakvish, !raw.isEmpty {
                    InfoRow(label: "מועד עלייה לכביש", value: raw, monospaced: true)
                }
                if let miv = vehicle.mivchan_acharon_dt, !miv.isEmpty {
                    InfoRow(label: "מבחן אחרון", value: SearchViewModel.displayDate(miv) ?? miv,
                            monospaced: true)
                }
                InfoRow(label: "סוג בעלות", value: vehicle.ownershipType)
            }
        }
    }

    @ViewBuilder
    private func rowWithBadge(label: String, date: String?, validity: ValidityStatus) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer(minLength: Theme.Spacing.s)
            StatusBadge(dateString: date, status: validity)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var ownershipSection: some View {
        let hasOwnership = !ownership.isEmpty
        let hasChanges = mileage?.changeLabels.isEmpty == false
        let hasMileageRecord = mileage?.mileageKm != nil || mileage?.engineNumber != nil
        let hasContent = hasOwnership || hasChanges || hasMileageRecord

        if hasContent {
            InfoCard(title: "היסטוריה ובעלות", systemImage: "person.2.fill") {
                OwnershipHistoryView(ownership: ownership, vehicle: vehicle, mileage: mileage)
                if let m = mileage, m.mileageKm != nil || m.engineNumber != nil {
                    Divider().padding(.vertical, Theme.Spacing.xs)
                    MileageView(history: m)
                }
            }
        }
    }

    // MARK: - Footer actions

    private var footerActions: some View {
        VStack(spacing: Theme.Spacing.m) {
            ShareLink(item: shareSummary,
                      subject: Text("פרטי רכב"),
                      message: Text("פרטי רכב מספר \(vehicle.mispar_rechev)")) {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "square.and.arrow.up")
                    Text("שיתוף")
                }
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .strokeBorder(Theme.Colors.primary, lineWidth: 1.5)
                )
            }
            .accessibilityLabel("שיתוף פרטי הרכב")

            Button {
                viewModel.reset()
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "magnifyingglass")
                    Text("חיפוש חדש")
                }
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnPrimary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .fill(Theme.Colors.primary)
                )
            }
            .accessibilityLabel("התחל חיפוש חדש")
        }
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Share summary

    private var shareSummary: String {
        var lines: [String] = []
        lines.append("פרטי רכב — מספר רישוי \(vehicle.mispar_rechev)")
        if let m = vehicle.manufacturer { lines.append("יצרן: \(m)") }
        if let d = vehicle.model        { lines.append("דגם: \(d)") }
        if let y = vehicle.year         { lines.append("שנת ייצור: \(y)") }
        if let c = vehicle.tzeva_rechev { lines.append("צבע: \(c)") }
        if let f = vehicle.sug_delek_nm  { lines.append("סוג דלק: \(f)") }
        if let cc = vehicle.nefach_manoa { lines.append("נפח מנוע: \(cc) סמ״ק") }
        if let k = vehicle.kvutzat_zihum { lines.append("קבוצת זיהום: \(k)") }
        if let b = vehicle.ownershipType { lines.append("סוג בעלות: \(b)") }
        if let v = vehicle.chassis       { lines.append("מספר שלדה: \(v)") }
        if let t = vehicle.vehicleType   { lines.append("סוג רכב: \(t)") }
        if let c = vehicle.countryOfManufacture { lines.append("ארץ ייצור: \(c)") }
        if let i = vehicle.importType     { lines.append("יבוא: \(i)") }
        if let em = vehicle.engineModel  { lines.append("דגם מנוע: \(em)") }
        if let en = vehicle.engineNumber { lines.append("מספר מנוע: \(en)") }
        if let t = SearchViewModel.displayDate(vehicle.tokef_dt) {
            lines.append("תוקף טסט: \(t)")
        }
        if let r = SearchViewModel.displayDate(vehicle.tokef_rishuy) {
            lines.append("תוקף רישיון: \(r)")
        }
        if !ownership.isEmpty {
            lines.append("היסטוריית בעלות:")
            for rec in ownership {
                let start = SearchViewModel.displayMonthYear(rec.baalut_dt) ?? "—"
                lines.append("  - \(rec.ownerType ?? "—") מ\(start)")
            }
        }
        if let m = mileage {
            if let km = m.mileageKm        { lines.append("קילומטראז׳: \(km)") }
            if let src = m.ownershipSource { lines.append("מקור בעלות: \(src)") }
            if !m.changeLabels.isEmpty     { lines.append("שינויים: \(m.changeLabels.joined(separator: ", "))") }
        }
        lines.append("— מקור: data.gov.il")
        return lines.joined(separator: "\n")
    }
}

#Preview {
    ResultView(
        viewModel: SearchViewModel(),
        vehicle: .preview,
        mileage: .preview,
        ownership: [
            .init(mispar_rechev: 5970065, baalut_dt: 200806, baalut: "פרטי"),
            .init(mispar_rechev: 5970065, baalut_dt: 201905, baalut: "סוחר"),
            .init(mispar_rechev: 5970065, baalut_dt: 201906, baalut: "פרטי")
        ]
    )
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}
