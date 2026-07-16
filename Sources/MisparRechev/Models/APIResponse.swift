import Foundation

/// Generic wrapper for a CKAN `datastore_search` response.
///
/// Shape: `{ "success": true, "result": { "records": [ ... ] } }`.
/// The generic `Record` is the element type of `records`.
struct DataGovResponse<T: Decodable>: Decodable {
    let success: Bool
    let result: ResultBody?

    /// Non-generic inner type; reuses the outer `T` so there is no shadowing.
    struct ResultBody: Decodable {
        let resource_id: String?
        let records: [T]?
        let total: Int?
    }
}