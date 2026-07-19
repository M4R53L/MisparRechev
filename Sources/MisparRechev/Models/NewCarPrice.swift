import Foundation

/// A new-car importer list-price record from the "יבואנים ומחירוני רכב חדש"
/// resource (`39f455bf`). Joined to a vehicle on
/// (`tozeret_cd`, `degem_cd`, `sug_degem`, `shnat_yitzur`) — normally exactly
/// one record per model/trim/year.
struct NewCarPrice: Codable, Identifiable, Equatable, Hashable {
    /// מחיר מחירון יבואן בש"ח (לרכב חדש בשנת הייצור).
    let mehir: Int?
    /// שם היבואן (למשל "כלמוביל מרצדס").
    let shem_yevuan: String?
    let kinuy_mishari: String?
    let shnat_yitzur: Int?
    let tozeret_cd: Int?
    let degem_cd: Int?

    var id: String {
        "\(tozeret_cd ?? 0)-\(degem_cd ?? 0)-\(shnat_yitzur ?? 0)-\(mehir ?? 0)"
    }

    var importer: String? {
        shem_yevuan?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
