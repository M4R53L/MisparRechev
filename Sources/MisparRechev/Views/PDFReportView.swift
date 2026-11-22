import SwiftUI

/// Print-oriented, fixed-width recomposition of the report for PDF export.
/// It follows the on-screen report (maker badge, plate, test status, headline
/// facts, grouped sections) but is laid out for paper: fixed point sizes,
/// forced-light colours, no shadows, and the sections flowed into two columns.
/// Rendered by `PDFReportRenderer` (595pt wide ≈ A4 width at 72dpi).
struct PDFReportView: View {
    static let pageWidth: CGFloat = 595

    let result: LookupResult
    /// User-entered current value (from `PriceOverrideStore`); when set it
    /// replaces the automatic depreciation estimate in the price section.
    var manualValue: Int? = nil
    /// The date stamped on the report (injectable for deterministic tests).
    var generatedAt: Date = .now

    private var vehicle: Vehicle { result.vehicle }
    private var spec: VehicleSpec? { result.spec }

    // Paper palette: fixed values, independent of the device appearance.
    private static let ink = Color(white: 0.07)
    private static let muted = Color(white: 0.42)
    private static let panel = Color(white: 0.955)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            masthead
            header
            if vehicle.isDeregistered { deregisteredBox }
            if !result.recalls.isEmpty { recallsBox }
            testStatus
            facts
            columns
            footer
        }
        .padding(32)
        .frame(width: Self.pageWidth, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(Self.ink)
    }

    // MARK: - Masthead (document name + date)

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: "דוח רכב")
                .font(.system(size: 11, weight: .bold))
            Spacer()
            Text(verbatim: "הופק ב־" + formattedGeneratedAt)
                .font(.system(size: 10))
                .foregroundStyle(Self.muted)
        }
    }

    // MARK: - Header (who the car is)

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            BrandLogo(brand: vehicle.brand, fallbackName: vehicle.manufacturer, size: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: vehicle.reportTitle)
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = headerSubtitle {
                    Text(verbatim: subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Self.muted)
                }
            }

            Spacer(minLength: 12)

            PlateChrome(stripWidth: 24, cornerRadius: 8, rim: 2) {
                Text(verbatim: PlateFormat.dashed(vehicle.mispar_rechev))
                    .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.Colors.textOnPlate)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
            }
            .frame(width: 196)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Self.panel))
    }

    private var headerSubtitle: String? {
        var parts: [String] = []
        if let year = vehicle.year { parts.append(year) }
        if let trim = vehicle.trimLevel { parts.append("רמת גימור \(trim)") }
        if let importType = vehicle.importType { parts.append(importType) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Warning boxes

    private var deregisteredBox: some View {
        warningBox(
            title: "ירד מהכביש (ביטול סופי)",
            lines: ["תאריך ביטול: \(PlateDates.displayDate(vehicle.bitul_dt) ?? vehicle.bitul_dt ?? "לא ידוע")",
                    "הנתונים בדוח הם הרשומה האחרונה שנשמרה במאגר"]
        )
    }

    private var recallsBox: some View {
        warningBox(
            title: result.recalls.count > 1
                ? "\(result.recalls.count) ריקולים פתוחים"
                : "ריקול פתוח",
            lines: result.recalls.map { recall in
                let what = [recall.category, recall.details].compactMap { $0 }
                    .joined(separator: ": ")
                let opened = PlateDates.displayDate(recall.TAARICH_PTICHA)
                    .map { " (נפתח ב־\($0))" } ?? ""
                return "\(what.isEmpty ? "פרטים אצל היבואן" : what)\(opened)"
            }
        )
    }

    private func warningBox(title: String, lines: [String]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.danger)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.danger)
                ForEach(lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(.system(size: 10.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Colors.danger.opacity(0.10))
        )
    }

    // MARK: - Test status

    @ViewBuilder
    private var testStatus: some View {
        if !vehicle.isDeregistered, let raw = vehicle.tokef_dt, let date = PlateDates.parse(raw) {
            let status = PlateDates.validity(of: raw, now: generatedAt)
            let calendar = Calendar.current
            let days = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: generatedAt), to: date).day ?? 0
            let color: Color = status == .expired ? Theme.Colors.danger
                : status == .expiringSoon ? Theme.Colors.warning : Theme.Colors.success

            HStack(spacing: 12) {
                Image(systemName: status == .expired ? "xmark.seal.fill"
                      : status == .expiringSoon ? "exclamationmark.triangle.fill"
                      : "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: status == .expired ? "הטסט פג תוקף"
                         : status == .expiringSoon ? "הטסט עומד לפוג" : "הטסט בתוקף")
                        .font(.system(size: 14, weight: .bold))
                    Text(verbatim: (status == .expired ? "פג ב־" : "עד ")
                         + (PlateDates.displayDate(raw) ?? raw))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Self.muted)
                }
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: String(abs(days)))
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                    Text(verbatim: days >= 0 ? "ימים נותרו ביום הפקת הדוח" : "ימים באיחור ביום הפקת הדוח")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Self.muted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.12))
            )
        }
    }

    // MARK: - Headline facts

    @ViewBuilder
    private var facts: some View {
        let facts = result.headlineFacts
        if !facts.isEmpty {
            HStack(spacing: 8) {
                ForEach(facts) { fact in
                    VStack(alignment: .leading, spacing: 3) {
                        Image(systemName: fact.systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Self.muted)
                            .frame(height: 14)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(verbatim: fact.value)
                                .font(.system(size: 14, weight: .bold, design: .rounded)
                                    .monospacedDigit())
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            if let unit = fact.unit {
                                Text(verbatim: unit)
                                    .font(.system(size: 9))
                                    .foregroundStyle(Self.muted)
                            }
                        }
                        Text(verbatim: fact.label)
                            .font(.system(size: 9))
                            .foregroundStyle(Self.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Self.panel)
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Grouped sections, flowed into two columns

    private struct Row: Identifiable {
        let label: String
        let value: String
        /// Long values (lists) sit under their label instead of beside it.
        var stacked = false
        var id: String { label }
    }

    private struct Group: Identifiable {
        let title: String
        let systemImage: String
        let rows: [Row]
        var note: String? = nil
        var id: String { title }
        /// Rough height in row units, used to balance the two columns.
        var weight: Int {
            rows.reduce(2) { $0 + ($1.stacked ? 1 + max(1, $1.value.count / 34) : 1) }
                + (note == nil ? 0 : 2)
        }
    }

    private func group(_ title: String, _ systemImage: String,
                       _ rows: [(String, String?)], stacked: Set<String> = [],
                       note: String? = nil) -> Group? {
        let present: [Row] = rows.compactMap { label, value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return Row(label: label, value: value, stacked: stacked.contains(label))
        }
        return present.isEmpty ? nil
            : Group(title: title, systemImage: systemImage, rows: present, note: note)
    }

    private var grossWeight: Int? {
        vehicle.mishkal_kolel.flatMap { $0 > 0 ? $0 : nil } ?? spec?.grossWeightKg
    }

    /// Same groups, in the same order, as the on-screen report.
    private var groups: [Group] {
        let ownershipRows: [(String, String?)] = result.ownership.enumerated().compactMap { index, record in
            guard let start = SearchViewModel.displayMonthYear(record.baalut_dt) else { return nil }
            // Unique labels: the same month can open two ownership records.
            return ("\(index + 1). מ\(start)", record.ownerType ?? "לא ידוע")
        }
        let features = spec?.safetyFeatures ?? []
        let level = vehicle.ramat_eivzur_betihuty ?? spec?.safetyEquipmentLevel

        return [
            group("רישוי ובדיקות", "doc.text.fill", [
                ("תוקף טסט", vehicle.tokef_dt.flatMap { PlateDates.displayDate($0) ?? $0 }),
                ("תוקף רישיון", vehicle.tokef_rishuy.flatMap { PlateDates.displayDate($0) ?? $0 }),
                ("מבחן אחרון", vehicle.mivchan_acharon_dt.flatMap { PlateDates.displayDate($0) ?? $0 }),
                ("מועד עלייה לכביש", vehicle.moed_aliya_lakvish.flatMap { PlateDates.displayDate($0) ?? $0 }),
                ("סוג בעלות", vehicle.ownershipType)
            ]),
            group("היסטוריה ובעלות", "clock.arrow.circlepath", ownershipRows + [
                ("קילומטראז׳ בטסט אחרון", result.mileage?.mileageKm),
                ("מקור בעלות", result.mileage?.ownershipSource),
                ("שינויים שדווחו", (result.mileage?.changeLabels.isEmpty == false)
                    ? result.mileage?.changeLabels.joined(separator: ", ") : nil)
            ], stacked: ["שינויים שדווחו"]),
            priceGroup,
            group("הרכב", "car.fill", [
                ("יצרן", vehicle.manufacturer),
                ("דגם", vehicle.model),
                ("רמת גימור", vehicle.trimLevel),
                ("שנת ייצור", vehicle.year),
                ("צבע", vehicle.tzeva_rechev),
                ("סוג רכב", vehicle.vehicleType),
                ("מרכב", spec?.bodyType),
                ("דלתות", spec?.doors.map(String.init)),
                ("מושבים", spec?.seats.map(String.init)),
                ("ארץ ייצור", vehicle.countryOfManufacture),
                ("סוג יבוא", vehicle.importType)
            ]),
            group("מנוע והנעה", "engine.combustion.fill", [
                ("סוג דלק", vehicle.sug_delek_nm),
                ("הספק", spec?.horsepower.map { "\($0) כ״ס" }),
                ("נפח מנוע", (vehicle.nefach_manoa ?? spec?.displacementCC).map { "\($0) סמ״ק" }),
                ("טווח חשמלי (WLTP)", result.electricRangeKm.map { "\($0) ק״מ" }),
                ("תיבת הילוכים", spec?.gearbox),
                ("הנעה", spec?.driveType),
                ("טכנולוגיית הנעה", spec?.driveTechnology),
                ("דגם מנוע", vehicle.engineModel)
            ]),
            group("משקל וגרירה", "scalemass.fill", [
                ("משקל כולל", grossWeight.map { "\($0) ק״ג" }),
                ("משקל עצמי", vehicle.ownWeight.flatMap { $0 > 0 ? "\($0) ק״ג" : nil }),
                ("כושר גרירה עם בלמים", spec?.towingWithBrakesKg.map { "\($0) ק״ג" }),
                ("כושר גרירה ללא בלמים", spec?.towingWithoutBrakesKg.map { "\($0) ק״ג" })
            ]),
            group("סביבה", "leaf.fill", [
                ("פליטת CO2", spec?.co2Display.map { "\($0) גרם/ק״מ" }),
                ("קבוצת זיהום", vehicle.kvutzat_zihum.map { "\($0) מתוך 15" })
            ]),
            group("בטיחות ומערכות סיוע", "shield.lefthalf.filled", [
                ("רמת אבזור בטיחותי", level.map { "\($0) מתוך 8" }),
                ("כריות אוויר", spec?.airbagCount.map(String.init)),
                ("ABS", spec?.hasABS.map { $0 ? "יש" : "אין" }),
                ("בקרת יציבות", spec?.hasStabilityControl.map { $0 ? "יש" : "אין" }),
                ("מערכות סיוע", features.isEmpty ? nil : features.joined(separator: ", "))
            ], stacked: ["מערכות סיוע"]),
            group("מספרים מזהים", "number", [
                ("מספר שלדה", vehicle.chassis),
                ("מספר מנוע", vehicle.engineNumber),
                ("קוד דגם", vehicle.degem_nm)
            ])
        ].compactMap { $0 }
    }

    private var priceGroup: Group? {
        let autoEstimate: Int? = {
            guard result.prices.count == 1,
                  let newPrice = result.prices.first?.mehir,
                  let year = vehicle.shnat_yitzur
            else { return nil }
            return PriceEstimator.estimatedValue(newPrice: newPrice, productionYear: year)
        }()
        let value = manualValue ?? autoEstimate
        return group("מחירון", "shekelsign.circle.fill", [
            (manualValue == nil ? "שווי מוערך כיום" : "שווי מעודכן (הוזן ידנית)",
             value.map(PriceEstimator.formatted)),
            ("יבואן", result.prices.count == 1 ? result.prices.first?.importer : nil)
        ], note: value == nil ? nil
            : manualValue == nil
                ? "אומדן גס לפי פחת ממוצע בלבד. אינו תחליף למחירון מקצועי."
                : "הוזן ידנית על־פי מחירון חיצוני.")
    }

    /// Splits the groups into two columns of similar height, keeping their
    /// reading order (first column top to bottom, then the second).
    private var columnGroups: ([Group], [Group]) {
        let all = groups
        let total = all.reduce(0) { $0 + $1.weight }
        var first: [Group] = []
        var running = 0
        for g in all {
            // Take the group if doing so lands closer to half than stopping.
            if first.count < all.count - 1,
               abs(running + g.weight - total / 2) <= abs(running - total / 2) || first.isEmpty {
                first.append(g)
                running += g.weight
            } else {
                break
            }
        }
        return (first, Array(all.dropFirst(first.count)))
    }

    private var columns: some View {
        let split = columnGroups
        return HStack(alignment: .top, spacing: 20) {
            column(split.0)
            column(split.1)
        }
    }

    private func column(_ groups: [Group]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups) { g in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: g.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Self.muted)
                        Text(verbatim: g.title)
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    Rectangle().fill(Self.ink).frame(height: 1)

                    ForEach(g.rows) { row in
                        if row.stacked {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: row.label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Self.muted)
                                Text(verbatim: row.value)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(verbatim: row.label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Self.muted)
                                Spacer(minLength: 6)
                                Text(verbatim: row.value)
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if let note = g.note {
                        Text(verbatim: note)
                            .font(.system(size: 9))
                            .foregroundStyle(Self.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Footer

    private var footer: some View {
        Text(verbatim: "מקור הנתונים: מאגרי משרד התחבורה באתר data.gov.il. הדוח משקף את המידע ביום הפקתו.")
            .font(.system(size: 9))
            .foregroundStyle(Self.muted)
            .padding(.top, 4)
    }

    private var formattedGeneratedAt: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "d בMMMM yyyy"
        return formatter.string(from: generatedAt)
    }
}

#Preview {
    ScrollView {
        PDFReportView(result: LookupResult(vehicle: .preview, spec: .preview,
                                           mileage: .preview,
                                           ownership: [], recalls: [.preview],
                                           prices: [.preview]))
    }
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}
