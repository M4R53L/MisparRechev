import Foundation

/// WLTP electric driving range for EVs and plug-in hybrids.
///
/// Israel's data.gov.il publishes no range data at all, so this is the one
/// value sourced elsewhere: the European Environment Agency's per-registration
/// database of every new car registered in the EU ("Monitoring of CO2
/// emissions from passenger cars"), exposed through DiscoData — a free,
/// key-less SQL-over-HTTPS JSON endpoint, same trust model as data.gov.il:
/// `https://discodata.eea.europa.eu/sql?query=<SQL>`.
///
/// Israeli vehicles are European type-approvals (`sug_tkina_nm` "אירופאית"),
/// so the EEA commercial name (`Cn`) matches `kinuy_mishari` directly
/// ("MODEL 3", "ATTO 3", …).
///
/// Verified quirks (don't "fix" these):
/// - The range column is `Zr` (km, WLTP), populated from ~2021 — the WLTP
///   era. Member states report it inconsistently (typos, omissions), so the
///   value is aggregated: most-registered value wins, never MIN/MAX.
/// - BEVs are filtered with `UPPER(Ft) = 'ELECTRIC'`; plug-in hybrids with
///   `UPPER(Fm) = 'P'` (fuel *mode* plug-in — covers petrol and diesel).
/// - `Ep (KW)` is motor power for BEVs (≈ hp × 0.7355) and disambiguates
///   trims sharing one `Cn` (Model 3 SR vs LR). For PHEVs it's the
///   combustion engine's power, which doesn't match the Israeli spec's
///   system horsepower — PHEVs aggregate across the whole model instead.
/// - Years 2010–2022 live in the consolidated `[latest].[co2cars]` table
///   (needs a `[Year]` filter); 2023+ are per-year tables whose names embed
///   the data-format version and change when the EEA republishes.
enum ElectricRange {

    enum Kind {
        case battery
        case plugInHybrid
    }

    // MARK: - Vehicle classification

    /// `.battery` / `.plugInHybrid` when the vehicle is chargeable, else nil
    /// (includes regular hybrids — they have no plug-in range). The spec's
    /// drive technology is authoritative; the registration's fuel type covers
    /// spec-less vehicles (fallback datasets).
    static func kind(vehicle: Vehicle, spec: VehicleSpec?) -> Kind? {
        let tech = spec?.technologiat_hanaa_nm?.uppercased() ?? ""
        if tech.contains("PLUG") { return .plugInHybrid }
        if tech.contains("חשמלי") { return .battery }
        if vehicle.sug_delek_nm?.trimmingCharacters(in: .whitespacesAndNewlines) == "חשמל" {
            return .battery
        }
        return nil
    }

    // MARK: - Query building

    /// `kinuy_mishari` normalized for embedding in the SQL literal: uppercased,
    /// whitespace-collapsed, restricted to a safe character set (this also
    /// drops LIKE wildcards and quotes). nil when too little remains to match.
    static func queryName(from kinuy: String?) -> String? {
        guard let kinuy else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ./+-")
        let scalars = kinuy.uppercased().unicodeScalars.filter { allowed.contains($0) }
        let collapsed = String(String.UnicodeScalarView(scalars))
            .split(separator: " ")
            .joined(separator: " ")
        return collapsed.count >= 2 ? collapsed : nil
    }

    /// DiscoData table holding a production year's registrations; nil before
    /// the WLTP era (no `Zr` data worth querying). Years beyond the newest
    /// published table clamp to it — EU registrations lag model years.
    static func tableName(forYear year: Int) -> String? {
        switch year {
        case ..<2021: return nil
        case 2021, 2022: return "[CO2Emission].[latest].[co2cars]"
        case 2023: return "[CO2Emission].[latest].[co2cars_2023Fv28]"
        case 2024: return "[CO2Emission].[latest].[co2cars_2024Pv29]"
        default: return "[CO2Emission].[latest].[co2cars_2025Pv31]"
        }
    }

    /// Only the consolidated 2010–2022 table spans years and needs the filter.
    static func needsYearFilter(_ year: Int) -> Bool { year <= 2022 }

    /// Aggregation query: one row per (motor power, range) with a registration
    /// count, most-registered first.
    static func queryURL(table: String, name: String, kind: Kind, year: Int?) -> URL {
        var sql = "SELECT [Ep (KW)] AS ep, Zr AS zr, COUNT(*) AS n FROM \(table)"
        sql += " WHERE UPPER(Cn) LIKE '%\(name)%' AND Zr IS NOT NULL"
        sql += kind == .battery ? " AND UPPER(Ft) = 'ELECTRIC'" : " AND UPPER(Fm) = 'P'"
        if let year { sql += " AND [Year] = \(year)" }
        sql += " GROUP BY [Ep (KW)], Zr ORDER BY n DESC"

        var components = URLComponents(string: "https://discodata.eea.europa.eu/sql")!
        components.queryItems = [
            URLQueryItem(name: "query", value: sql),
            URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "nrOfHits", value: "200")
        ]
        return components.url!
    }

    // MARK: - Response

    struct Row: Decodable, Equatable {
        let ep: Double?
        let zr: Double
        let n: Int
    }

    struct Response: Decodable {
        let results: [Row]?
    }

    // MARK: - Value selection

    /// Picks the range from the aggregated rows: keeps plausible values,
    /// narrows to the trim whose EU motor power matches the Israeli
    /// horsepower when that helps, then returns the most-registered value
    /// (registration-count weighted mode — outlier typos lose naturally).
    static func pick(rows: [Row], horsepower: Int?, kind: Kind) -> Int? {
        let plausible: ClosedRange<Double> = kind == .battery ? 100...800 : 15...200
        var candidates = rows.filter { plausible.contains($0.zr) && $0.n > 0 }

        if kind == .battery, let hp = horsepower, hp > 0 {
            let targetKW = Double(hp) * 0.7355
            let tolerance = max(10, targetKW * 0.08)
            let close = candidates.filter { row in
                guard let ep = row.ep else { return false }
                return abs(ep - targetKW) <= tolerance
            }
            if !close.isEmpty { candidates = close }
        }

        guard !candidates.isEmpty else { return nil }
        var weights: [Int: Int] = [:]
        for row in candidates {
            weights[Int(row.zr.rounded()), default: 0] += row.n
        }
        return weights.max { ($0.value, $0.key) < ($1.value, $1.key) }?.key
    }

    // MARK: - Fetch

    /// Fetches the WLTP range for the vehicle, or nil (row hidden) when the
    /// vehicle isn't chargeable, predates the WLTP era, or the EEA has no
    /// match. Tries the production year first, then the following year —
    /// EU registrations of a model year often peak the year after.
    static func fetch(vehicle: Vehicle, spec: VehicleSpec?, session: URLSession) async -> Int? {
        guard let kind = kind(vehicle: vehicle, spec: spec),
              let name = queryName(from: vehicle.kinuy_mishari),
              let year = vehicle.shnat_yitzur else { return nil }

        var triedTables: Set<String> = []
        for candidateYear in [year, year + 1] {
            guard let table = tableName(forYear: candidateYear),
                  triedTables.insert(table).inserted || needsYearFilter(candidateYear) else { continue }
            let url = queryURL(table: table, name: name, kind: kind,
                               year: needsYearFilter(candidateYear) ? candidateYear : nil)
            guard let rows = try? await fetchRows(url: url, session: session) else { continue }
            if let km = pick(rows: rows, horsepower: spec?.koah_sus, kind: kind) {
                return km
            }
        }
        return nil
    }

    private static func fetchRows(url: URL, session: URLSession) async throws -> [Row] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data).results ?? []
    }
}
