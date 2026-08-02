import SwiftUI

/// Print-oriented, fixed-width recomposition of the full report for PDF
/// export: plain stacks, forced-light styling, no interactive controls.
/// Rendered by `PDFReportRenderer` (595pt wide ≈ A4 width at 72dpi).
struct PDFReportView: View {
    static let pageWidth: CGFloat = 595

    let result: LookupResult
    /// The date stamped in the footer (injectable for deterministic tests).
    var generatedAt: Date = .now

    private var vehicle: Vehicle { result.vehicle }
    private var spec: VehicleSpec? { result.spec }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if vehicle.isDeregistered { deregisteredBox }
            if !result.recalls.isEmpty { recallsBox }
            section("פרטים בסיסיים", rows: basicRows)
            section("מפרט טכני", rows: techRows)
            safetySection
            section("רישוי ובדיקות", rows: licensingRows)
            historySection
            priceSection
            footer
        }
        .padding(32)
        .frame(width: Self.pageWidth, alignment: .leading)
        .background(Color.white)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text(String(vehicle.mispar_rechev))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textOnPlate)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.Colors.plateYellow)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.Colors.plateBorder, lineWidth: 2)
                )
            Text(vehicle.displayName)
                .font(.system(size: 20, weight: .bold))
            HStack(spacing: 6) {
                if let manufacturer = vehicle.manufacturer { Text(manufacturer) }
                if vehicle.manufacturer != nil, vehicle.year != nil { Text("·") }
                if let year = vehicle.year { Text(year) }
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Warning boxes

    private var deregisteredBox: some View {
        warningBox(
            title: "ירד מהכביש — ביטול סופי",
            lines: ["תאריך ביטול: \(PlateDates.displayDate(vehicle.bitul_dt) ?? vehicle.bitul_dt ?? "—")",
                    "הנתונים בדוח הם הרשומה האחרונה שנשמרה במאגר"]
        )
    }

    private var recallsBox: some View {
        warningBox(
            title: result.recalls.count > 1
                ? "ריקולים פתוחים · \(result.recalls.count)"
                : "ריקול פתוח",
            lines: result.recalls.map { recall in
                let what = [recall.category, recall.details].compactMap { $0 }
                    .joined(separator: " — ")
                let opened = PlateDates.displayDate(recall.TAARICH_PTICHA)
                    .map { " (נפתח ב־\($0))" } ?? ""
                return "• \(what.isEmpty ? "פרטים אצל היבואן" : what)\(opened)"
            }
        )
    }

    private func warningBox(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.danger)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.Colors.danger.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.Colors.danger.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - Row sections

    private func section(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Divider()
            ForEach(rows, id: \.0) { row in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(row.0)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 140, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var basicRows: [(String, String)] {
        compact([
            ("יצרן", vehicle.manufacturer),
            ("דגם", vehicle.model),
            ("שנת ייצור", vehicle.year),
            ("צבע", vehicle.tzeva_rechev),
            ("סוג רכב", vehicle.vehicleType),
            ("ארץ ייצור", vehicle.countryOfManufacture),
            ("יבוא", vehicle.importType),
            ("רמת גימור", vehicle.ramat_gimur),
            ("מספר שלדה", vehicle.chassis)
        ])
    }

    private var techRows: [(String, String)] {
        compact([
            ("סוג דלק", vehicle.sug_delek_nm),
            ("הספק", spec?.horsepower.map { "\($0) כ״ס" }),
            ("נפח מנוע", (vehicle.nefach_manoa ?? spec?.displacementCC).map { "\($0) סמ״ק" }),
            ("תיבת הילוכים", spec?.gearbox),
            ("הנעה", spec?.driveType),
            ("טכנולוגיית הנעה", spec?.driveTechnology),
            ("מרכב", spec?.bodyType),
            ("דלתות", spec?.doors.map(String.init)),
            ("מושבים", spec?.seats.map(String.init)),
            ("משקל כולל", grossWeight.map { "\($0) ק״ג" }),
            ("משקל עצמי", vehicle.ownWeight.flatMap { $0 > 0 ? "\($0) ק״ג" : nil }),
            ("דגם מנוע", vehicle.engineModel),
            ("מספר מנוע", vehicle.engineNumber),
            ("פליטת CO2", spec?.co2Display.map { "\($0) גרם/ק״מ" }),
            ("קבוצת זיהום", vehicle.kvutzat_zihum.map { "\($0) / 15" })
        ])
    }

    private var grossWeight: Int? {
        vehicle.mishkal_kolel.flatMap { $0 > 0 ? $0 : nil } ?? spec?.grossWeightKg
    }

    @ViewBuilder
    private var safetySection: some View {
        let level = vehicle.ramat_eivzur_betihuty ?? spec?.safetyEquipmentLevel
        let rows = compact([
            ("רמת אבזור בטיחותי", level.map { "\($0) / 8" }),
            ("כריות אוויר", spec?.airbagCount.map(String.init)),
            ("ABS", spec?.hasABS.map { $0 ? "יש" : "אין" }),
            ("בקרת יציבות", spec?.hasStabilityControl.map { $0 ? "יש" : "אין" }),
            ("מערכות סיוע", (spec?.safetyFeatures.isEmpty == false)
                ? spec?.safetyFeatures.joined(separator: ", ") : nil)
        ])
        if !rows.isEmpty {
            section("בטיחות ומערכות סיוע", rows: rows)
        }
    }

    private var licensingRows: [(String, String)] {
        compact([
            ("תוקף טסט", dateWithValidity(vehicle.tokef_dt)),
            ("תוקף רישיון", dateWithValidity(vehicle.tokef_rishuy)),
            ("מבחן אחרון", vehicle.mivchan_acharon_dt.flatMap { PlateDates.displayDate($0) ?? $0 }),
            ("מועד עלייה לכביש", vehicle.moed_aliya_lakvish.flatMap { PlateDates.displayDate($0) ?? $0 }),
            ("סוג בעלות", vehicle.ownershipType)
        ])
    }

    @ViewBuilder
    private var historySection: some View {
        let ownershipLines: [(String, String)] = result.ownership.compactMap { record in
            guard let start = SearchViewModel.displayMonthYear(record.baalut_dt) else { return nil }
            return (start, record.ownerType ?? "—")
        }
        let rows = compact([
            ("קילומטראז׳ אחרון", result.mileage?.mileageKm),
            ("מקור בעלות", result.mileage?.ownershipSource),
            ("שינויים שדווחו", (result.mileage?.changeLabels.isEmpty == false)
                ? result.mileage?.changeLabels.joined(separator: ", ") : nil)
        ])
        if !ownershipLines.isEmpty || !rows.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text("היסטוריה ובעלות")
                    .font(.system(size: 14, weight: .bold))
                Divider()
                ForEach(Array(ownershipLines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("מ\(line.0)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        Text(line.1)
                            .font(.system(size: 12, weight: .medium))
                        Spacer(minLength: 0)
                    }
                }
                ForEach(rows, id: \.0) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.0)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        Text(row.1)
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var priceSection: some View {
        let amounts = result.prices.compactMap(\.mehir).filter { $0 > 0 }
        let listPrice: String? = {
            guard let min = amounts.min(), let max = amounts.max() else { return nil }
            return min == max
                ? PriceEstimator.formatted(min)
                : "\(PriceEstimator.formatted(min))–\(PriceEstimator.formatted(max))"
        }()
        let estimate: String? = {
            guard result.prices.count == 1,
                  let newPrice = result.prices.first?.mehir,
                  let year = vehicle.shnat_yitzur,
                  let value = PriceEstimator.estimatedValue(newPrice: newPrice,
                                                           productionYear: year)
            else { return nil }
            return PriceEstimator.formatted(value)
        }()
        let rows = compact([
            ("מחיר מחירון כחדש", listPrice),
            ("שווי מוערך כיום", estimate),
            ("יבואן", result.prices.count == 1 ? result.prices.first?.importer : nil)
        ])
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                section("מחירון", rows: rows)
                if estimate != nil {
                    Text("השווי המוערך הוא אומדן גס לפי פחת ממוצע בלבד — אינו תחליף למחירון מקצועי")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
            Text("הופק ב־\(formattedGeneratedAt) · מקור הנתונים: data.gov.il — משרד התחבורה")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }

    private var formattedGeneratedAt: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "d בMMMM yyyy"
        return formatter.string(from: generatedAt)
    }

    // MARK: - Helpers

    private func compact(_ rows: [(String, String?)]) -> [(String, String)] {
        rows.compactMap { label, value in value.map { (label, $0) } }
    }

    private func dateWithValidity(_ dateString: String?) -> String? {
        guard let dateString, !dateString.isEmpty else { return nil }
        let display = PlateDates.displayDate(dateString) ?? dateString
        let word: String
        switch PlateDates.validity(of: dateString) {
        case .valid: word = "בתוקף"
        case .expiringSoon: word = "עומד לפוג"
        case .expired: word = "פג תוקף"
        case .unknown: return display
        }
        return "\(display) — \(word)"
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
