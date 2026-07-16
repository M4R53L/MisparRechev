import Foundation

/// data.gov.il CKAN DataStore endpoints and resource ids.
enum DataGovEndpoint {
    static let base = URL(string: "https://data.gov.il/api/3/action/datastore_search")!

    /// מספרי רישוי של כלי רכב פרטיים ומסחריים — primary registration & spec
    /// (private cars ≥1996, light commercial ≤3500kg ≥1998).
    static let primaryResourceID = "053cea08-09bc-40ec-8f7a-156f0677aff3"

    /// כלי רכב ציבוריים פעילים — fallback for buses, taxis, heavy commercial
    /// and other public vehicles not present in the primary dataset.
    static let publicResourceID = "cf29862d-ca25-4691-84f6-1be60dcb4a1e"

    /// כלי רכב ביבוא אישי — personally-imported vehicles.
    static let personalImportResourceID = "03adc637-b6fe-402b-9937-7c3d3afc9140"

    /// כלי רכב דו-גלגליים — motorcycles / two-wheelers.
    static let motorcycleResourceID = "bf9df4e2-d90d-4c0a-a400-19e15af8e95f"

    /// כלי רכב מעל 3.5 טון וחסרי קוד דגם — heavy trucks / no-model-code vehicles.
    static let heavyTruckResourceID = "cd3acc5c-03c3-4c89-9c54-d40f93c0d790"

    /// Fallback resources searched (concurrently, first hit wins) when the
    /// primary private/commercial dataset doesn't contain the plate. The
    /// categories are disjoint, so any hit is the authoritative record.
    static let fallbackResourceIDs: [String] = [
        publicResourceID,
        personalImportResourceID,
        motorcycleResourceID,
        heavyTruckResourceID
    ]

    /// היסטוריית כלי רכב פרטיים (1) — last mileage + change flags (2017+).
    /// Queried with an exact `filters` match; one record per plate (or none).
    static let mileageResourceID = "56063a99-8a3e-4ff4-912e-5966c0279bad"

    /// היסטוריית כלי רכב פרטיים (2) — ownership-transfer timeline (2017+).
    /// Returns MULTIPLE records per plate (one per transfer), each with
    /// `baalut_dt` (YYYYMM) and `baalut` (פרטי/סוחר/ליסינג/חברה). This resource
    /// is full-text indexed only — it MUST be queried with `q`, not `filters`.
    static let ownershipResourceID = "bb2355dc-9ec7-4f06-9c3f-3344672171da"

    /// Builds a `datastore_search` URL filtered by an exact `mispar_rechev`.
    ///
    /// The plate is sent as a JSON **string** even though the field is numeric,
    /// which is what data.gov.il expects in the `filters` parameter.
    static func searchURL(resourceID: String, plate: Int) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        let filters = #"{"mispar_rechev":"\#(plate)"}"#
        components.queryItems = [
            URLQueryItem(name: "resource_id", value: resourceID),
            URLQueryItem(name: "filters", value: filters),
            URLQueryItem(name: "limit", value: "1")
        ]
        return components.url!
    }

    /// Builds a `datastore_search` URL using a full-text `q` query for the
    /// plate. Used for the ownership resource, which is not filter-indexed.
    static func searchURLWithQuery(resourceID: String, plate: Int, limit: Int = 100) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "resource_id", value: resourceID),
            URLQueryItem(name: "q", value: String(plate)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return components.url!
    }
}