import SwiftUI
import UIKit

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

    /// User-entered current value for this plate (nil → automatic estimate).
    /// Loaded from / saved to `PriceOverrideStore`.
    @State private var manualPrice: Int?

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
            .navigationTitle(PlateFormat.dashed(vehicle.mispar_rechev))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    pinButton
                    ShareLink(item: shareSummary,
                              subject: Text("פרטי רכב"),
                              message: Text("פרטי רכב מספר \(vehicle.mispar_rechev)")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("שיתוף פרטי הרכב")
                }
            }
            .overlay(alignment: .top) {
                if showsCopiedNotice {
                    copiedNotice
                        .padding(.top, Theme.Spacing.s)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $isShowingCompare) {
                CompareFromResultSheet(
                    currentPlate: vehicle.mispar_rechev,
                    currentResult: fullResult,
                    history: viewModel.history.entries
                )
            }
            .sensoryFeedback(.success, trigger: viewModel.isPinned(vehicle.mispar_rechev)) { _, pinned in pinned }
            .onChange(of: manualPrice) { _, newValue in
                PriceOverrideStore.load()
                    .setting(newValue, for: vehicle.mispar_rechev)
                    .save()
                // Keep the pre-generated report in sync with the edited value.
                pdfURL = try? PDFReportRenderer.render(result: fullResult,
                                                       manualValue: newValue)
            }
            .task(id: vehicle.mispar_rechev) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showsCopiedNotice = true
                }
                manualPrice = PriceOverrideStore.load().value(for: vehicle.mispar_rechev)
                // Pre-generate the PDF report so the share button is instant.
                pdfURL = try? PDFReportRenderer.render(result: fullResult,
                                                       manualValue: manualPrice)
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: Theme.Motion.durationStandard)) {
                    showsCopiedNotice = false
                }
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    hero
                    if case .snapshot(let savedAt) = freshness {
                        SnapshotNoticeBanner(savedAt: savedAt)
                    }
                    if vehicle.isDeregistered {
                        DeregisteredBannerView(bitulDate: vehicle.bitul_dt)
                    }
                    if !recalls.isEmpty {
                        RecallWarningView(recalls: recalls)
                    }
                    testStatus
                    keyFacts
                }
                if !prices.isEmpty {
                    PriceView(prices: prices, vehicle: vehicle, manualValue: $manualPrice)
                }
                ownershipSection
                licensingSection
                rowsSection("הרכב", systemImage: "car.fill", rows: carRows)
                rowsSection("מנוע והנעה", systemImage: "engine.combustion.fill", rows: engineRows)
                rowsSection("משקל וגרירה", systemImage: "scalemass.fill", rows: weightRows)
                environmentSection
                safetySection
                identifiersSection
                footerActions
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    // MARK: - Copied-to-clipboard notice

    private var copiedNotice: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(.caption, weight: .semibold))
            Text("המספר הועתק ללוח")
                .font(Theme.Typography.captionBold)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(Capsule().fill(.regularMaterial))
        .cardShadow()
        .accessibilityLabel("מספר הרכב הועתק ללוח")
    }

    // MARK: - Hero

    /// Who the car is: maker badge, make + model, year and trim, and the plate.
    private var hero: some View {
        VStack(spacing: Theme.Spacing.l) {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                BrandLogo(brand: vehicle.brand, fallbackName: vehicle.manufacturer, size: 64)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(vehicle.reportTitle)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = heroSubtitle {
                        Text(subtitle)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            PlateView(number: String(vehicle.mispar_rechev))
                .frame(maxWidth: .infinity)

            if let importType = vehicle.importType {
                Text([importType, vehicle.countryOfManufacture].compactMap { $0 }.joined(separator: ", "))
                    .font(Theme.Typography.captionBold)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Colors.surface)
        )
    }

    /// "2008, רמת גימור S" — year and trim under the title.
    private var heroSubtitle: String? {
        var parts: [String] = []
        if let year = vehicle.year { parts.append(year) }
        if let trim = vehicle.trimLevel { parts.append("רמת גימור \(trim)") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
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
        }
        .accessibilityLabel(pinned ? "בטל הצמדה כרכב שלי" : "הצמד כרכב שלי")
    }

    // MARK: - Test status

    /// The answer most people open the report for: is the annual test valid,
    /// until when, and how many days are left.
    @ViewBuilder
    private var testStatus: some View {
        if !vehicle.isDeregistered, let raw = vehicle.tokef_dt, let date = SearchViewModel.parse(raw) {
            let status = SearchViewModel.validity(of: raw)
            let days = Calendar.current.dateComponents(
                [.day], from: Calendar.current.startOfDay(for: .now), to: date).day ?? 0
            let color = Self.color(for: status)

            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: status == .expired ? "xmark.seal.fill"
                      : status == .expiringSoon ? "exclamationmark.triangle.fill"
                      : "checkmark.seal.fill")
                    .font(.system(.title, weight: .semibold))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(status == .expired ? "הטסט פג תוקף"
                         : status == .expiringSoon ? "הטסט עומד לפוג" : "הטסט בתוקף")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    // verbatim: a localized format would isolate each argument
                    // and break the right-to-left word order.
                    Text(verbatim: (status == .expired ? "פג ב־" : "עד ")
                         + (SearchViewModel.displayDate(raw) ?? raw))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer(minLength: Theme.Spacing.s)

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(abs(days))")
                        .font(Theme.Typography.figure)
                        .foregroundStyle(color)
                    Text(days >= 0 ? "ימים נותרו" : "ימים באיחור")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .accessibilityElement(children: .combine)
        }
    }

    private static func color(for status: ValidityStatus) -> Color {
        switch status {
        case .valid:        return Theme.Colors.success
        case .expiringSoon: return Theme.Colors.warning
        case .expired:      return Theme.Colors.danger
        case .unknown:      return Theme.Colors.neutral
        }
    }

    // MARK: - Key facts

    private struct Fact: Identifiable {
        let label: String
        let value: String
        var unit: String? = nil
        let systemImage: String
        var id: String { label }
    }

    /// The facts a buyer scans first. Shown as one or two full rows of three,
    /// never a ragged grid.
    private var facts: [Fact] {
        var all: [Fact] = []
        if let year = vehicle.year {
            all.append(Fact(label: "שנת ייצור", value: year, systemImage: "calendar"))
        }
        if let fuel = vehicle.sug_delek_nm?.trimmingCharacters(in: .whitespaces), !fuel.isEmpty {
            all.append(Fact(label: "דלק", value: fuel,
                            systemImage: fuel.contains("חשמל") ? "bolt.fill" : "fuelpump.fill"))
        }
        if let hp = spec?.horsepower {
            all.append(Fact(label: "הספק", value: String(hp), unit: "כ״ס",
                            systemImage: "gauge.with.needle.fill"))
        }
        if let gearbox = spec?.gearbox {
            all.append(Fact(label: "תיבת הילוכים", value: gearbox,
                            systemImage: "gearshift.layout.sixspeed"))
        }
        if let color = vehicle.tzeva_rechev?.trimmingCharacters(in: .whitespaces), !color.isEmpty {
            all.append(Fact(label: "צבע", value: color, systemImage: "paintpalette.fill"))
        }
        if let km = mileage?.mileageKm {
            all.append(Fact(label: "ק״מ בטסט אחרון", value: km, systemImage: "road.lanes"))
        }
        if let range = electricRangeKm {
            all.append(Fact(label: "טווח חשמלי", value: String(range), unit: "ק״מ",
                            systemImage: "battery.100percent"))
        }
        if let seats = spec?.seats {
            all.append(Fact(label: "מושבים", value: String(seats), systemImage: "carseat.left.fill"))
        }
        if all.count >= 6 { return Array(all.prefix(6)) }
        if all.count >= 3 { return Array(all.prefix(3)) }
        return []
    }

    @ViewBuilder
    private var keyFacts: some View {
        let facts = self.facts
        if !facts.isEmpty {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s),
                                     count: 3),
                      spacing: Theme.Spacing.s) {
                ForEach(facts) { fact in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Image(systemName: fact.systemImage)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(height: 24)
                            .accessibilityHidden(true)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(fact.value)
                                .font(Theme.Typography.figure)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            if let unit = fact.unit {
                                Text(unit)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                        Text(fact.label)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                            .fill(Theme.Colors.surface)
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(fact.label): \(fact.value) \(fact.unit ?? "")")
                }
            }
        }
    }

    // MARK: - Row sections

    private struct Row: Identifiable {
        let label: String
        let value: String
        var unit: String? = nil
        var numeric = false
        var id: String { label }
    }

    private func row(_ label: String, _ value: String?, unit: String? = nil,
                     numeric: Bool = false) -> Row? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return Row(label: label, value: value, unit: unit, numeric: numeric)
    }

    private func row(_ label: String, _ value: Int?, unit: String? = nil) -> Row? {
        guard let value else { return nil }
        return Row(label: label, value: String(value), unit: unit, numeric: true)
    }

    /// A titled group of label/value rows; the whole group hides when none of
    /// its rows has data.
    @ViewBuilder
    private func rowsSection(_ title: String, systemImage: String, rows: [Row?]) -> some View {
        let present = rows.compactMap { $0 }
        if !present.isEmpty {
            InfoCard(title: title, systemImage: systemImage) {
                ForEach(present) { r in
                    InfoRow(label: r.label, value: r.value, unit: r.unit, monospaced: r.numeric)
                }
            }
        }
    }

    /// Engine cc / gross weight exist in both the registration record and the
    /// model-spec sheet; the registration value wins, the spec fills gaps.
    private var displacementCC: Int? { vehicle.nefach_manoa ?? spec?.displacementCC }
    private var grossWeightKg: Int? {
        vehicle.mishkal_kolel.flatMap { $0 > 0 ? $0 : nil } ?? spec?.grossWeightKg
    }

    private var carRows: [Row?] {
        [row("יצרן", vehicle.manufacturer),
         row("דגם", vehicle.model),
         row("רמת גימור", vehicle.trimLevel),
         row("שנת ייצור", vehicle.year, numeric: true),
         row("צבע", vehicle.tzeva_rechev),
         row("סוג רכב", vehicle.vehicleType),
         row("מרכב", spec?.bodyType),
         row("דלתות", spec?.doors),
         row("מושבים", spec?.seats),
         row("ארץ ייצור", vehicle.countryOfManufacture),
         row("סוג יבוא", vehicle.importType)]
    }

    private var engineRows: [Row?] {
        [row("סוג דלק", vehicle.sug_delek_nm),
         row("הספק", spec?.horsepower, unit: "כ״ס"),
         row("נפח מנוע", displacementCC, unit: "סמ״ק"),
         row("טווח חשמלי (WLTP)", electricRangeKm, unit: "ק״מ"),
         row("תיבת הילוכים", spec?.gearbox),
         row("הנעה", spec?.driveType),
         row("טכנולוגיית הנעה", spec?.driveTechnology),
         row("דגם מנוע", vehicle.engineModel)]
    }

    private var weightRows: [Row?] {
        [row("משקל כולל", grossWeightKg, unit: "ק״ג"),
         row("משקל עצמי", vehicle.ownWeight.flatMap { $0 > 0 ? $0 : nil }, unit: "ק״ג"),
         row("כושר גרירה עם בלמים", spec?.towingWithBrakesKg, unit: "ק״ג"),
         row("כושר גרירה ללא בלמים", spec?.towingWithoutBrakesKg, unit: "ק״ג")]
    }

    // MARK: - Licensing

    @ViewBuilder
    private var licensingSection: some View {
        let onRoad = vehicle.moed_aliya_lakvish.flatMap { raw -> String? in
            raw.isEmpty ? nil : (SearchViewModel.displayDate(raw) ?? raw)
        }
        let lastTest = vehicle.mivchan_acharon_dt.flatMap { raw -> String? in
            raw.isEmpty ? nil : (SearchViewModel.displayDate(raw) ?? raw)
        }
        let hasAny = vehicle.tokef_dt != nil || vehicle.tokef_rishuy != nil
            || onRoad != nil || lastTest != nil || vehicle.ownershipType != nil
        if hasAny {
            InfoCard(title: "רישוי ובדיקות", systemImage: "doc.text.fill") {
                if vehicle.tokef_dt != nil {
                    rowWithBadge(label: "תוקף טסט", date: vehicle.tokef_dt,
                                 validity: SearchViewModel.validity(of: vehicle.tokef_dt))
                }
                if vehicle.tokef_rishuy != nil {
                    rowWithBadge(label: "תוקף רישיון", date: vehicle.tokef_rishuy,
                                 validity: SearchViewModel.validity(of: vehicle.tokef_rishuy))
                }
                InfoRow(label: "מבחן אחרון", value: lastTest, monospaced: true)
                InfoRow(label: "מועד עלייה לכביש", value: onRoad, monospaced: true)
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
    }

    // MARK: - History

    @ViewBuilder
    private var ownershipSection: some View {
        let hasOwnership = !ownership.isEmpty
        let hasChanges = mileage?.changeLabels.isEmpty == false
        let hasMileageRecord = mileage?.mileageKm != nil || mileage?.engineNumber != nil
        let hasContent = hasOwnership || hasChanges || hasMileageRecord

        if hasContent {
            InfoCard(title: "היסטוריה ובעלות", systemImage: "clock.arrow.circlepath") {
                OwnershipHistoryView(ownership: ownership, vehicle: vehicle, mileage: mileage)
                if let m = mileage, m.mileageKm != nil || m.engineNumber != nil {
                    Divider()
                    MileageView(history: m)
                }
            }
        }
    }

    // MARK: - Environment

    @ViewBuilder
    private var environmentSection: some View {
        if vehicle.kvutzat_zihum != nil || spec?.co2Display != nil {
            InfoCard(title: "סביבה", systemImage: "leaf.fill") {
                InfoRow(label: "פליטת CO2", value: spec?.co2Display,
                        unit: "גרם/ק״מ", monospaced: true)
                if vehicle.kvutzat_zihum != nil {
                    PollutionScale(value: vehicle.kvutzat_zihum)
                }
            }
        }
    }

    // MARK: - Safety

    /// Airbags/ABS/ESC, the 0–8 safety-equipment level, and the driver-assist
    /// systems the model ships with. Hidden entirely when the spec sheet is
    /// missing and the registration has no safety level.
    @ViewBuilder
    private var safetySection: some View {
        let level = vehicle.ramat_eivzur_betihuty ?? spec?.safetyEquipmentLevel
        let features = spec?.safetyFeatures ?? []
        if spec != nil || level != nil {
            InfoCard(title: "בטיחות ומערכות סיוע", systemImage: "shield.lefthalf.filled") {
                if level != nil {
                    SafetyEquipmentScale(value: level)
                }
                InfoRow(label: "כריות אוויר", value: spec?.airbagCount.map { String($0) },
                        monospaced: true)
                InfoRow(label: "ABS", value: spec?.hasABS.map { $0 ? "יש" : "אין" })
                InfoRow(label: "בקרת יציבות", value: spec?.hasStabilityControl.map { $0 ? "יש" : "אין" })
                if !features.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("מערכות סיוע מתקדמות")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        FlowLayout(spacing: 6) {
                            ForEach(features, id: \.self) { feature in
                                FeatureChip(text: feature)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Identifiers

    /// Chassis / engine / model codes. Long-press a row to copy its value.
    @ViewBuilder
    private var identifiersSection: some View {
        let rows = [row("מספר שלדה", vehicle.chassis, numeric: true),
                    row("מספר מנוע", vehicle.engineNumber, numeric: true),
                    row("קוד דגם", vehicle.degem_nm, numeric: true)].compactMap { $0 }
        if !rows.isEmpty {
            InfoCard(title: "מספרים מזהים", systemImage: "number") {
                ForEach(rows) { r in
                    InfoRow(label: r.label, value: r.value, monospaced: true)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = r.value
                            } label: {
                                Label("העתקה", systemImage: "doc.on.doc")
                            }
                        }
                }
            }
        }
    }

    // MARK: - Footer actions

    private var footerActions: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                if let pdfURL {
                    ShareLink(item: pdfURL,
                              preview: SharePreview("דוח רכב \(vehicle.mispar_rechev)",
                                                    image: Image(systemName: "doc.richtext"))) {
                        Label("דוח PDF", systemImage: "doc.richtext")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("יצוא דוח PDF ושיתופו")
                }

                Button {
                    isShowingCompare = true
                } label: {
                    Label("השוואה", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("השוואה מול רכב אחר")
            }

            Button {
                viewModel.reset()
            } label: {
                Label("חיפוש חדש", systemImage: "magnifyingglass")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("התחל חיפוש חדש")

            Text("המידע מגיע ממאגרי משרד התחבורה באתר data.gov.il")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.xs)
        }
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
        if let t = vehicle.trimLevel    { lines.append("רמת גימור: \(t)") }
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
            if let manual = manualPrice {
                lines.append("שווי מעודכן: \(PriceEstimator.formatted(manual)) (הוזן ידנית)")
            } else if let year = vehicle.shnat_yitzur,
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
                .foregroundStyle(Theme.Colors.success)
            Text(text)
                .font(Theme.Typography.captionBold)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.Colors.background))
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
