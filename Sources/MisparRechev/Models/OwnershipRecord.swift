import Foundation

/// A single ownership-transfer record from the "היסטוריית כלי רכב פרטיים (2)"
/// resource (`bb2355dc`). A plate has one of these per ownership period since
/// 2017, sorted ascending by `baalut_dt`.
struct OwnershipRecord: Decodable, Hashable {
    let mispar_rechev: Int
    /// תאריך תחילת הבעלות בפורמט YYYYMM (למשל 202106 = יוני 2021).
    let baalut_dt: Int?
    /// סוג בעלות (פרטי / סוחר / ליסינג / חברה / השכרה …).
    let baalut: String?

    var ownerType: String? {
        baalut?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}