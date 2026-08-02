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

    /// כלי רכב שירדו מהכביש ובסטטוס ביטול סופי — three era-split, disjoint,
    /// filter-indexed resources (lowercase `mispar_rechev`, plate as a JSON
    /// string). Queried only after the primary + fallbacks all miss; a record
    /// carries near-full vehicle fields plus `bitul_dt` (cancellation date).
    static let deregisteredResourceIDs: [String] = [
        "851ecab1-0622-4dbe-a6c7-f950cf82abf9", // current era (~1.19M records)
        "4e6b9724-4c1e-43f0-909a-154d4cc4e046", // 2010–2016
        "ec8cbc34-72e1-4b69-9c48-22821ba0bd6c"  // 2000–2009
    ]

    /// היסטוריית כלי רכב פרטיים (1) — last mileage + change flags (2017+).
    /// Queried with an exact `filters` match; one record per plate (or none).
    static let mileageResourceID = "56063a99-8a3e-4ff4-912e-5966c0279bad"

    /// היסטוריית כלי רכב פרטיים (2) — ownership-transfer timeline (2017+).
    /// Returns MULTIPLE records per plate (one per transfer), each with
    /// `baalut_dt` (YYYYMM) and `baalut` (פרטי/סוחר/ליסינג/חברה). This resource
    /// is full-text indexed only — it MUST be queried with `q`, not `filters`.
    static let ownershipResourceID = "bb2355dc-9ec7-4f06-9c3f-3344672171da"

    /// כלי רכב שלא ביצעו ריקול (קריאת שירות) — open, unperformed recalls.
    /// Filter-indexed, but by UPPERCASE `MISPAR_RECHEV` (unlike every other
    /// resource); plate still sent as a JSON string. A plate can have several
    /// open recalls, so query with a generous limit (not 1). Updated daily.
    static let recallResourceID = "36bf1404-0be4-49d2-82dc-2f1ead4a8b93"

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

    /// יבואנים ומחירוני רכב חדש — importer list prices for new cars
    /// (1996–present). Joined on (tozeret_cd, degem_cd, sug_degem,
    /// shnat_yitzur), which normally yields exactly one record. Vehicles from
    /// the fallback datasets lack `degem_cd`, so they have no price.
    static let priceResourceID = "39f455bf-6db0-4926-859d-017f34eacbcb"

    /// Builds a `datastore_search` URL for the new-car price resource,
    /// filtered on the four model-identity keys (values as JSON strings, per
    /// the usual data.gov.il quirk).
    static func priceSearchURL(tozeretCd: Int, degemCd: Int, sugDegem: String,
                               year: Int, limit: Int = 8) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        let filters = #"{"tozeret_cd":"\#(tozeretCd)","degem_cd":"\#(degemCd)","sug_degem":"\#(sugDegem)","shnat_yitzur":"\#(year)"}"#
        components.queryItems = [
            URLQueryItem(name: "resource_id", value: priceResourceID),
            URLQueryItem(name: "filters", value: filters),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return components.url!
    }

    /// מאגר דגמי רכב — per-model/trim/year spec sheet (horsepower, gearbox,
    /// drive, body, seats, airbags, safety-assist flags). Joined on the same
    /// four model-identity keys as the price resource; normally one record.
    static let specResourceID = "142afde2-6228-49f9-8a29-9b6c3a0cbe40"

    /// Builds a `datastore_search` URL for the model-spec resource, filtered
    /// on the four model-identity keys (values as JSON strings, per the usual
    /// data.gov.il quirk).
    static func specSearchURL(tozeretCd: Int, degemCd: Int, sugDegem: String,
                              year: Int, limit: Int = 8) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        let filters = #"{"tozeret_cd":"\#(tozeretCd)","degem_cd":"\#(degemCd)","sug_degem":"\#(sugDegem)","shnat_yitzur":"\#(year)"}"#
        components.queryItems = [
            URLQueryItem(name: "resource_id", value: specResourceID),
            URLQueryItem(name: "filters", value: filters),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return components.url!
    }

    /// Builds a `datastore_search` URL for the recall resource, whose filter
    /// field is UPPERCASE `MISPAR_RECHEV` (plate as a JSON string, as always).
    static func recallSearchURL(plate: Int, limit: Int = 32) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        let filters = #"{"MISPAR_RECHEV":"\#(plate)"}"#
        components.queryItems = [
            URLQueryItem(name: "resource_id", value: recallResourceID),
            URLQueryItem(name: "filters", value: filters),
            URLQueryItem(name: "limit", value: String(limit))
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