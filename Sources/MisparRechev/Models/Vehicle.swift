import Foundation

/// A single vehicle record from the primary data.gov.il vehicle registry
/// resource (`053cea08-09bc-40ec-8f7a-156f0677aff3`).
///
/// Every field except `mispar_rechev` is optional: the resource is large and
/// not every plate exposes every field. Missing fields render as "—" or hide
/// their row, so the UI degrades gracefully.
struct Vehicle: Decodable, Identifiable, Equatable {
    /// מספר רישוי — the license-plate number (primary key).
    let mispar_rechev: Int
    /// יצרן (manufacturer, e.g. "טויוטה", "מזדה יפן").
    let tozeret_nm: String?
    /// כינוי מסחרי / דגם מסחרי (e.g. "קורולה הייבריד").
    let kinuy_mishari: String?
    /// סוג דגם (קוד, למשל "P").
    let sug_degem: String?
    /// שם דגם.
    let degem_nm: String?
    /// שנת ייצור.
    let shnat_yitzur: Int?
    /// צבע הרכב.
    let tzeva_rechev: String?
    /// סוג דלק (בנזין / דיזל / חשמלי / היברידי / גפ"מ …) — שם תיאורי.
    let sug_delek_nm: String?
    /// נפח מנוע בסמ"ק (לא מוחזר תמיד במאגר זה).
    let nefach_manoa: Int?
    /// משקל כולל מותר (ק"ג) (לא מוחזר תמיד במאגר זה).
    let mishkal_kolel: Int?
    /// משקל עצמי (ק"ג) (לא מוחזר תמיד במאגר זה).
    let mishkal_aa: Int?
    /// קבוצת זיהום (1–15; 15 = מזהם ביותר לפי הסקלה הישראלית הישנה).
    let kvutzat_zihum: Int?
    /// רמת גימור.
    let ramat_gimur: String?
    /// רמת איבזור בטיחות (ערך מספרי, למשל 2; יכול להיות null).
    let ramat_eivzur_betihuty: Int?
    /// תוקף טסט (תאריך, מחרוזת, למשל "2027-05-24").
    let tokef_dt: String?
    /// תוקף רישיון (תאריך, מחרוזת) — לא תמיד זמין במאגר זה.
    let tokef_rishuy: String?
    /// מועד עלייה לכביש (רישום ראשון בישראל, למשל "2008-5").
    let moed_aliya_lakvish: String?
    /// תאריך מבחן אחרון (למשל "2026-05-24").
    let mivchan_acharon_dt: String?
    /// סוג בעלות (פרטי / חכר / השכרה / אחר) — זמין ישירות מהמאגר הראשי.
    let baalut: String?
    /// מספר שלדה / VIN (מחרוזת מזהה שלדה).
    let misgeret: String?
    /// מספר בעלים (כאשר זמין).
    let mispar_baalim: Int?

    // Cross-resource variants (imports / motorcycles / heavy trucks / public).
    // These carry the same concept under different field names across datasets.
    // No default values: a default would make the synthesized Decodable init
    // skip decoding them.
    /// מספר שלדה / VIN in the personal-import resource.
    let shilda: String?
    /// מספר שלדה in the heavy-truck resource.
    let mispar_shilda: String?
    /// משקל עצמי (ק"ג) in the heavy-truck resource.
    let mishkal_azmi: Int?
    /// סוג רכב תיאורי (למשל "פרטי נוסעים", "אוטובוס ציבורי…", "אופנוע").
    let sug_rechev_nm: String?
    /// קבוצת סוג רכב (משאיות, למשל "מסחרי").
    let kvutzat_sug_rechev: String?
    /// ארץ ייצור (למשל "גרמניה").
    let tozeret_eretz_nm: String?
    /// סוג יבוא (למשל "יבוא אישי-משומש").
    let sug_yevu: String?
    /// דגם מנוע (למשל "M276").
    let degem_manoa: String?
    /// מספר מנוע.
    let mispar_manoa: String?

    var id: Int { mispar_rechev }

    /// Display name — commercial model if present, else manufacturer, else plate.
    var displayName: String {
        kinuy_mishari?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        ?? tozeret_nm?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        ?? "מספר רכב \(mispar_rechev)"
    }

    /// Manufacturer for display, falling back to the commercial name's leading
    /// token when the manufacturer field is empty.
    var manufacturer: String? {
        tozeret_nm?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    var model: String? {
        kinuy_mishari?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        ?? degem_nm?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    var year: String? {
        guard let shnat_yitzur else { return nil }
        return String(shnat_yitzur)
    }

    /// סוג בעלות מתוך המאגר הראשי (למשל "פרטי").
    var ownershipType: String? {
        baalut?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// מספר שלדה / VIN — coalesced across resources (misgeret / shilda / mispar_shilda).
    var chassis: String? {
        [misgeret, shilda, mispar_shilda]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
            .first
    }

    /// משקל עצמי — coalesced (mishkal_aa / mishkal_azmi).
    var ownWeight: Int? { mishkal_aa ?? mishkal_azmi }

    /// סוג רכב — coalesced (sug_rechev_nm / kvutzat_sug_rechev).
    var vehicleType: String? {
        (sug_rechev_nm ?? kvutzat_sug_rechev)?
            .trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// ארץ ייצור.
    var countryOfManufacture: String? {
        tozeret_eretz_nm?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// סוג יבוא (רק לרכב מיובא).
    var importType: String? {
        sug_yevu?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// דגם מנוע.
    var engineModel: String? {
        degem_manoa?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// מספר מנוע.
    var engineNumber: String? {
        mispar_manoa?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

private extension String {
    /// `nil` when empty/whitespace-only, otherwise `self`.
    var nonEmpty: String? { isEmpty ? nil : self }
}