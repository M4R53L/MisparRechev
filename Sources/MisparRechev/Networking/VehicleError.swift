import Foundation

/// Errors surfaced by `VehicleService`, mapped to friendly Hebrew messages
/// via `localizedDescription`.
enum VehicleError: LocalizedError, Equatable {
    case invalidPlate
    case notFound
    case network(URLError)
    case decoding(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidPlate:
            return "מספר רישוי לא תקין. יש להזין 6–8 ספרות."
        case .notFound:
            return "לא נמצא רכב עם מספר הרישוי שהוזן: לא במאגרי הרכב הפעיל (פרטי, מסחרי, ציבורי, אופנועים, יבוא אישי) ולא במאגר כלי הרכב שירדו מהכביש. ייתכן שהמספר שגוי."
        case .network(let urlError):
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "אין חיבור לאינטרנט. נא לבדוק את הרשת ולנסות שוב."
            case .timedOut:
                return "החיבור לשרת ארך זמן רב. נא לנסות שוב."
            default:
                return "שגיאת רשת. נא לנסות שוב מאוחר יותר."
            }
        case .decoding:
            return "התקבלו נתונים בפורמט לא צפוי. נא לנסות שוב."
        case .server:
            return "שירות הנתונים אינו זמין כעת. נא לנסות שוב מאוחר יותר."
        }
    }

    static func == (lhs: VehicleError, rhs: VehicleError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidPlate, .invalidPlate), (.notFound, .notFound):
            return true
        case (.network(let a), .network(let b)):
            return a.code == b.code
        case (.decoding(let a), .decoding(let b)):
            return a == b
        case (.server(let a), .server(let b)):
            return a == b
        default:
            return false
        }
    }
}