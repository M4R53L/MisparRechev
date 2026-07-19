import Foundation

/// A single open-recall record from the "כלי רכב שלא ביצעו ריקול (קריאת שירות)"
/// resource (`36bf1404`). Presence of a record means the vehicle has an open
/// recall it has not performed yet; a plate can have several. Absence means no
/// open recall (none issued, or already fixed).
///
/// Unlike the other resources, field names here are UPPERCASE — properties
/// mirror the API names exactly, per the project convention.
struct RecallRecord: Codable, Identifiable, Equatable, Hashable {
    let MISPAR_RECHEV: Int
    /// מזהה קריאת הריקול.
    let RECALL_ID: Int?
    /// סוג ריקול (למשל "תקלה סידרתית בטיחותית").
    let SUG_RECALL: String?
    /// קטגוריית התקלה (למשל "מנוע ומערכותיו").
    let SUG_TAKALA: String?
    /// תיאור חופשי של התקלה.
    let TEUR_TAKALA: String?
    /// תאריך פתיחת הריקול (למשל "2025-03-12").
    let TAARICH_PTICHA: String?

    var id: Int { RECALL_ID ?? MISPAR_RECHEV }

    var recallType: String? {
        SUG_RECALL?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    var category: String? {
        SUG_TAKALA?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    var details: String? {
        TEUR_TAKALA?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
