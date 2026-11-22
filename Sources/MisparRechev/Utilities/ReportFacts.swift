import Foundation

/// One of the headline facts a buyer scans first (year, fuel, power…).
struct ReportFact: Identifiable, Equatable {
    let label: String
    let value: String
    var unit: String? = nil
    let systemImage: String
    var id: String { label }
}

extension LookupResult {
    /// The headline facts, shared by the on-screen report and the PDF so both
    /// lead with the same things. Returned as full rows of three (6 or 3
    /// facts), or empty when there is too little data for a row.
    var headlineFacts: [ReportFact] {
        var all: [ReportFact] = []
        if let year = vehicle.year {
            all.append(ReportFact(label: "שנת ייצור", value: year, systemImage: "calendar"))
        }
        if let fuel = vehicle.sug_delek_nm?.trimmingCharacters(in: .whitespaces), !fuel.isEmpty {
            all.append(ReportFact(label: "דלק", value: fuel,
                                  systemImage: fuel.contains("חשמל") ? "bolt.fill" : "fuelpump.fill"))
        }
        if let hp = spec?.horsepower {
            all.append(ReportFact(label: "הספק", value: String(hp), unit: "כ״ס",
                                  systemImage: "gauge.with.needle.fill"))
        }
        if let gearbox = spec?.gearbox {
            all.append(ReportFact(label: "תיבת הילוכים", value: gearbox,
                                  systemImage: "gearshift.layout.sixspeed"))
        }
        if let color = vehicle.tzeva_rechev?.trimmingCharacters(in: .whitespaces), !color.isEmpty {
            all.append(ReportFact(label: "צבע", value: color, systemImage: "paintpalette.fill"))
        }
        if let km = mileage?.kilometer_test_aharon, km > 0 {
            all.append(ReportFact(label: "בטסט האחרון",
                                  value: km.formatted(.number.locale(Locale(identifier: "en_US"))),
                                  unit: "ק״מ", systemImage: "road.lanes"))
        }
        if let range = electricRangeKm {
            all.append(ReportFact(label: "טווח חשמלי", value: String(range), unit: "ק״מ",
                                  systemImage: "battery.100percent"))
        }
        if let seats = spec?.seats {
            all.append(ReportFact(label: "מושבים", value: String(seats),
                                  systemImage: "carseat.left.fill"))
        }
        if all.count >= 6 { return Array(all.prefix(6)) }
        if all.count >= 3 { return Array(all.prefix(3)) }
        return []
    }
}
