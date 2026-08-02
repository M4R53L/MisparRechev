import SwiftUI

/// Main result screen shown after a successful lookup.
struct ResultView: View {
    @Bindable var viewModel: SearchViewModel
    let vehicle: Vehicle
    let spec: VehicleSpec?
    let mileage: VehicleHistory?
    let ownership: [OwnershipRecord]
    let recalls: [RecallRecord]
    let prices: [NewCarPrice]
    let electricRangeKm: Int?
    let freshness: DataFreshness

    @State private var isShowingCompare = false
    @State private var pdfURL: URL?

    /// Transient "plate copied to clipboard" toast, shown once per result.
    @State private var showsCopiedNotice = false

    /// The full result rebuilt from this view's parts — used by the compare
    /// sheet and the PDF report.
    private var fullResult: LookupResult {
        LookupResult(vehicle: vehicle, spec: spec, mileage: mileage,
                     ownership: ownership, recalls: recalls,
                     prices: prices, electricRangeKm: electricRangeKm)
    }

    var body: some View {
        scrollContent
            .overlay(alignment: .topLeading) { backButton }
            .overlay(alignment: .bottom) {
                if showsCopiedNotice {
                    copiedNotice
                        .padding(.bottom, Theme.Spacing.l)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $isShowingCompare) {
                CompareFromResultSheet(
                    currentPlate: vehicle.mispar_rechev,
                    currentResult: fullResult,
                    history: viewModel.history.entries
                )
            }
            .task(id: vehicle.mispar_rechev) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showsCopiedNotice = true
                }
                // Pre-generate the PDF report so the share button is instant.
                pdfURL = try? PDFReportRenderer.render(result: fullResult)
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: Theme.Motion.durationStandard)) {
                    showsCopiedNotice = false
                }
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if case .snapshot(let savedAt) = freshness {
                    SnapshotNoticeBanner(savedAt: savedAt)
                }
                hero
                if vehicle.isDeregistered {
                    DeregisteredBannerView(bitulDate: vehicle.bitul_dt)
                }
                if !recalls.isEmpty {
                    RecallWarningView(recalls: recalls)
                }
                if !prices.isEmpty {
                    PriceView(prices: prices, vehicle: vehicle)
                }
                ownershipSection
                licensingTests
                basicInfo
                technicalInfo
                safetySection
                footerActions
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    // MARK: - Back navigation (floating arrow)

    /// Floating circular back button, pinned top-leading (top-right in RTL).
    /// `chevron.backward` mirrors automatically with the layout direction.
    /// Returns to the search screen keeping the plate in the field.
    private var backButton: some View {
        Button {
            viewModel.goBack()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.Colors.divider, lineWidth: 0.5))
                .cardShadow()
                .contentShape(Circle())
        }
        .padding(.leading, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .accessibilityLabel("חזרה לחיפוש")
    }

    // MARK: - Copied-to-clipboard notice

    private var copiedNotice: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("המספר הועתק ללוח")
                .font(Theme.Typography.captionBold)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Theme.Colors.divider, lineWidth: 0.5))
        .cardShadow()
        .accessibilityLabel("מספר הרכב הועתק ללוח")
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
        .overlay(alignment: .topTrailing) { pinButton }
    }

    /// Star toggle pinning this vehicle as "הרכב שלי".
    private var pinButton: some View {
        let pinned = viewModel.isPinned(vehicle.mispar_rechev)
        return Button {
            if pinned {
                viewModel.unpinCar()
            } else {
                viewModel.pinCurrentCar()
            }
        } label: {
            Image(systemName: pinned ? "star.fill" : "star")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(pinned ? Theme.Colors.primary : Theme.Colors.textTertiary)
                .padding(Theme.Spacing.s)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(pinned ? "בטל הצמדה כרכב שלי" : "הצמד כרכב שלי")
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

    /// Engine cc / gross weight exist in both the registration record and the
    /// model-spec sheet; the registration value wins, the spec fills gaps.
    private var displacementCC: Int? { vehicle.nefach_manoa ?? spec?.displacementCC }
    private var grossWeightKg: Int? {
        vehicle.mishkal_kolel.flatMap { $0 > 0 ? $0 : nil } ?? spec?.grossWeightKg
    }

    private var technicalInfo: some View {
        InfoCard(title: "מפרט טכני", systemImage: "wrench.and.screwdriver.fill") {
            Group {
                InfoRow(label: "סוג דלק",     value: vehicle.sug_delek_nm)
                InfoRow(label: "הספק",        value: spec?.horsepower.map { String($0) },
                        unit: "כ״ס", monospaced: true)
                InfoRow(label: "טווח חשמלי (WLTP)", value: electricRangeKm.map { String($0) },
                        unit: "ק״מ", monospaced: true)
                InfoRow(label: "נפח מנוע",    value: displacementCC.map { String($0) },
                        unit: "סמ״ק", monospaced: true)
                InfoRow(label: "תיבת הילוכים", value: spec?.gearbox)
                InfoRow(label: "הנעה",        value: spec?.driveType)
                InfoRow(label: "טכנולוגיית הנעה", value: spec?.driveTechnology)
                InfoRow(label: "מרכב",        value: spec?.bodyType)
                InfoRow(label: "דלתות",       value: spec?.doors.map { String($0) },
                        monospaced: true)
                InfoRow(label: "מושבים",      value: spec?.seats.map { String($0) },
                        monospaced: true)
            }
            Group {
                InfoRow(label: "משקל כולל",   value: grossWeightKg.map { String($0) },
                        unit: "ק״ג", monospaced: true)
                InfoRow(label: "משקל עצמי",   value: vehicle.ownWeight.flatMap { $0 > 0 ? String($0) : nil },
                        unit: vehicle.ownWeight.flatMap { $0 > 0 ? "ק״ג" : nil },
                        monospaced: true)
                InfoRow(label: "כושר גרירה (עם בלמים)",
                        value: spec?.towingWithBrakesKg.map { String($0) },
                        unit: "ק״ג", monospaced: true)
                InfoRow(label: "כושר גרירה (ללא בלמים)",
                        value: spec?.towingWithoutBrakesKg.map { String($0) },
                        unit: "ק״ג", monospaced: true)
                InfoRow(label: "דגם מנוע",     value: vehicle.engineModel)
                InfoRow(label: "מספר מנוע",   value: vehicle.engineNumber, monospaced: true)
                InfoRow(label: "מספר שלדה",   value: vehicle.chassis, monospaced: true)
                InfoRow(label: "פליטת CO2",   value: spec?.co2Display,
                        unit: "גרם/ק״מ", monospaced: true)
            }
            PollutionScale(value: vehicle.kvutzat_zihum)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    /// Safety card: airbags/ABS/ESC, the 0–8 safety-equipment level, and the
    /// driver-assist systems the model ships with. Hidden entirely when the
    /// spec sheet is missing and the registration has no safety level.
    @ViewBuilder
    private var safetySection: some View {
        let level = vehicle.ramat_eivzur_betihuty ?? spec?.safetyEquipmentLevel
        let features = spec?.safetyFeatures ?? []
        if spec != nil || level != nil {
            InfoCard(title: "בטיחות ומערכות סיוע", systemImage: "checkmark.shield.fill") {
                InfoRow(label: "כריות אוויר", value: spec?.airbagCount.map { String($0) },
                        monospaced: true)
                InfoRow(label: "ABS", value: spec?.hasABS.map { $0 ? "יש" : "אין" })
                InfoRow(label: "בקרת יציבות", value: spec?.hasStabilityControl.map { $0 ? "יש" : "אין" })
                if level != nil {
                    SafetyEquipmentScale(value: level)
                        .padding(.top, Theme.Spacing.xs)
                }
                if !features.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("מערכות סיוע מתקדמות")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        FlowLayout(spacing: 6) {
                            ForEach(features, id: \.self) { feature in
                                FeatureChip(text: feature)
                            }
                        }
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
            }
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

            if let pdfURL {
                ShareLink(item: pdfURL,
                          preview: SharePreview("דוח רכב \(vehicle.mispar_rechev)",
                                                image: Image(systemName: "doc.richtext"))) {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "doc.badge.arrow.up")
                        Text("יצוא דוח PDF")
                    }
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            .strokeBorder(Theme.Colors.primary, lineWidth: 1.5)
                    )
                }
                .accessibilityLabel("יצוא דוח PDF ושיתופו")
            }

            Button {
                isShowingCompare = true
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("השווה עם רכב אחר")
                }
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .strokeBorder(Theme.Colors.primary, lineWidth: 1.5)
                )
            }
            .accessibilityLabel("השוואה מול רכב אחר")

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
        if vehicle.isDeregistered {
            let when = SearchViewModel.displayDate(vehicle.bitul_dt).map { " (\($0))" } ?? ""
            lines.append("סטטוס: ירד מהכביש — ביטול סופי\(when)")
        }
        if let m = vehicle.manufacturer { lines.append("יצרן: \(m)") }
        if let d = vehicle.model        { lines.append("דגם: \(d)") }
        if let y = vehicle.year         { lines.append("שנת ייצור: \(y)") }
        if let c = vehicle.tzeva_rechev { lines.append("צבע: \(c)") }
        if let f = vehicle.sug_delek_nm  { lines.append("סוג דלק: \(f)") }
        if let hp = spec?.horsepower     { lines.append("הספק: \(hp) כ״ס") }
        if let er = electricRangeKm      { lines.append("טווח חשמלי (WLTP): \(er) ק״מ") }
        if let cc = displacementCC       { lines.append("נפח מנוע: \(cc) סמ״ק") }
        if let g = spec?.gearbox         { lines.append("תיבת הילוכים: \(g)") }
        if let d = spec?.driveType       { lines.append("הנעה: \(d)") }
        if let b = spec?.bodyType        { lines.append("מרכב: \(b)") }
        if let a = spec?.airbagCount     { lines.append("כריות אוויר: \(a)") }
        if let k = vehicle.kvutzat_zihum { lines.append("קבוצת זיהום: \(k)") }
        if let co2 = spec?.co2Display    { lines.append("פליטת CO2: \(co2) גרם/ק״מ") }
        if let level = vehicle.ramat_eivzur_betihuty ?? spec?.safetyEquipmentLevel {
            lines.append("רמת אבזור בטיחותי: \(level) מתוך 8")
        }
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
        for recall in recalls {
            let what = [recall.category, recall.details].compactMap { $0 }.joined(separator: " — ")
            lines.append("ריקול פתוח: \(what.isEmpty ? "פרטים אצל היבואן" : what)")
        }
        if prices.count == 1, let newPrice = prices.first?.mehir, newPrice > 0 {
            lines.append("מחיר מחירון כחדש: \(PriceEstimator.formatted(newPrice))")
            if let year = vehicle.shnat_yitzur,
               let estimate = PriceEstimator.estimatedValue(newPrice: newPrice, productionYear: year) {
                lines.append("שווי מוערך כיום: \(PriceEstimator.formatted(estimate)) (הערכה בלבד)")
            }
        }
        lines.append("— מקור: data.gov.il")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Snapshot notice (offline / stale data)

/// Compact warning strip shown when the report comes from a stored snapshot
/// rather than a live fetch.
private struct SnapshotNoticeBanner: View {
    let savedAt: Date

    private var formatted: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "he_IL")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: savedAt)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
            Text("מוצג מידע שמור מ־\(formatted)")
                .font(Theme.Typography.captionBold)
        }
        .foregroundStyle(Theme.Colors.warning)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, Theme.Spacing.s)
        .padding(.horizontal, Theme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .fill(Theme.Colors.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .strokeBorder(Theme.Colors.warning.opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Feature chip (safety-assist systems present on the model)

private struct FeatureChip: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(Theme.Typography.captionBold)
        }
        .foregroundStyle(Theme.Colors.success)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.Colors.success.opacity(0.12)))
        .accessibilityLabel("מערכת סיוע: \(text)")
    }
}

#Preview {
    ResultView(
        viewModel: SearchViewModel(),
        vehicle: .preview,
        spec: .preview,
        mileage: .preview,
        ownership: [
            .init(mispar_rechev: 5970065, baalut_dt: 200806, baalut: "פרטי"),
            .init(mispar_rechev: 5970065, baalut_dt: 201905, baalut: "סוחר"),
            .init(mispar_rechev: 5970065, baalut_dt: 201906, baalut: "פרטי")
        ],
        recalls: [.preview],
        prices: [.preview],
        electricRangeKm: nil,
        freshness: .live
    )
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}
