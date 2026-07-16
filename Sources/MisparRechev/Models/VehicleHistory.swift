import Foundation

/// A record from the "היסטוריית כלי רכב פרטיים" resources
/// (`56063a99-…` / `bb2355dc-…`). Covers private vehicles tracked since 2017:
/// last test mileage, change flags, first registration date, and ownership
/// source name. Many older/missing plates simply aren't in this dataset.
///
/// Every field except `mispar_rechev` is optional so the UI hides unavailable
/// data. The change flags are 0/1 integers in the source (coerced to `Bool`).
struct VehicleHistory: Decodable, Identifiable, Equatable {
    let mispar_rechev: Int
    /// מספר מנוע.
    let mispar_manoa: String?
    /// קילומטראז' בבדיקת הרישוי האחרונה.
    let kilometer_test_aharon: Int?
    /// שינוי מבנה (0/1).
    let shinui_mivne_ind: Int?
    /// התקנת גפ"מ (0/1).
    let gapam_ind: Int?
    /// שינוי צבע (0/1).
    let shnui_zeva_ind: Int?
    /// שינוי צמיג (0/1).
    let shinui_zmig_ind: Int?
    /// תאריך רישום ראשון (למשל "2017-03-16 00:00:00").
    let rishum_rishon_dt: String?
    /// מקוריות / שם בעלות (לעיתים ריק).
    let mkoriut_nm: String?

    var id: Int { mispar_rechev }

    var ownershipSource: String? {
        mkoriut_nm?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    var engineNumber: String? {
        mispar_manoa?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    var mileageKm: String? {
        guard let kilometer_test_aharon else { return nil }
        return "\(kilometer_test_aharon) ק\"מ"
    }

    // MARK: - Change flags (coerced from 0/1 ints)

    var structuralChange: Bool { (shinui_mivne_ind ?? 0) != 0 }
    var lpgInstalled: Bool { (gapam_ind ?? 0) != 0 }
    var colorChange: Bool { (shnui_zeva_ind ?? 0) != 0 }
    var tireChange: Bool { (shinui_zmig_ind ?? 0) != 0 }

    /// Change flags collapsed into a compact list of human-readable labels
    /// (only flags that are set). Empty when no reported changes.
    var changeLabels: [String] {
        var labels: [String] = []
        if structuralChange { labels.append("שינוי מבנה") }
        if lpgInstalled { labels.append("התקנת גפ״מ") }
        if colorChange { labels.append("שינוי צבע") }
        if tireChange { labels.append("שינוי צמיג") }
        return labels
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}