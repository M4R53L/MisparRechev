import Foundation

/// Fetches vehicle data from data.gov.il (no API key, HTTPS, direct).
///
/// - Primary registration spec, with a public-vehicles fallback on not-found.
/// - Mileage + change flags (optional).
/// - Ownership-transfer timeline (optional, possibly multiple entries).
/// The optional fetches never break the primary result.
final class VehicleService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Looks up a vehicle by plate. Throws `VehicleError`.
    func lookup(plate: Int) async throws
        -> (vehicle: Vehicle, mileage: VehicleHistory?, ownership: [OwnershipRecord]) {
        try Task.checkCancellation()

        async let vehicleTask = fetchVehicle(plate: plate)
        async let mileageTask = fetchMileage(plate: plate)
        async let ownershipTask = fetchOwnership(plate: plate)

        let vehicle = try await vehicleTask
        let mileage = await mileageTask
        let ownership = await ownershipTask
        return (vehicle, mileage, ownership)
    }

    // MARK: - Vehicle (primary, with public fallback)

    /// Primary private/commercial dataset, falling back (concurrently, first
    /// hit wins) to public / personal-import / motorcycle / heavy-truck when
    /// the primary dataset doesn't contain the plate. Network/decoding errors
    /// from the primary fetch are never masked by the fallback.
    private func fetchVehicle(plate: Int) async throws -> Vehicle {
        do {
            return try await fetchFirst(
                Vehicle.self,
                url: DataGovEndpoint.searchURL(resourceID: DataGovEndpoint.primaryResourceID, plate: plate)
            )
        } catch VehicleError.notFound {
            return try await fetchVehicleFallback(plate: plate)
        }
    }

    /// Searches the fallback resources concurrently and returns the first that
    /// contains the plate (the categories are disjoint, so any hit is correct).
    /// Throws `.notFound` if none has it.
    private func fetchVehicleFallback(plate: Int) async throws -> Vehicle {
        try await withThrowingTaskGroup(of: Vehicle?.self) { group in
            for resourceID in DataGovEndpoint.fallbackResourceIDs {
                group.addTask { [self] in
                    try? await self.fetchFirst(
                        Vehicle.self,
                        url: DataGovEndpoint.searchURL(resourceID: resourceID, plate: plate)
                    )
                }
            }
            for try await result in group {
                if let vehicle = result { return vehicle }
            }
            throw VehicleError.notFound
        }
    }

    // MARK: - Mileage / change flags (optional)

    private func fetchMileage(plate: Int) async -> VehicleHistory? {
        try? await fetchFirst(
            VehicleHistory.self,
            url: DataGovEndpoint.searchURL(resourceID: DataGovEndpoint.mileageResourceID, plate: plate)
        )
    }

    // MARK: - Ownership timeline (optional, full-text `q`)

    /// Returns ownership transfers for the plate, ascending by `baalut_dt`.
    /// Uses `q` (the resource is not filter-indexed) and keeps only records
    /// whose `mispar_rechev` exactly matches, to avoid full-text false positives.
    private func fetchOwnership(plate: Int) async -> [OwnershipRecord] {
        let url = DataGovEndpoint.searchURLWithQuery(
            resourceID: DataGovEndpoint.ownershipResourceID, plate: plate
        )
        guard let records = try? await fetchRecords(OwnershipRecord.self, url: url) else { return [] }
        return records
            .filter { $0.mispar_rechev == plate }
            .sorted { ($0.baalut_dt ?? 0) < ($1.baalut_dt ?? 0) }
    }

    // MARK: - Generic CKAN request helpers

    /// Decodes a `datastore_search` response and returns all records (possibly
    /// empty). Throws `.network` / `.server` / `.decoding` on real failures.
    private func fetchRecords<Record: Decodable>(_ type: Record.Type, url: URL) async throws -> [Record] {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            throw VehicleError.network(urlError)
        }

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw VehicleError.server("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        let decoded: DataGovResponse<Record>
        do {
            decoded = try JSONDecoder().decode(DataGovResponse<Record>.self, from: data)
        } catch {
            throw VehicleError.decoding(String(describing: error))
        }

        guard decoded.success == true else {
            throw VehicleError.server("CKAN success=false")
        }
        return decoded.result?.records ?? []
    }

    /// Returns the first record, or throws `.notFound` when there are none.
    private func fetchFirst<Record: Decodable>(_ type: Record.Type, url: URL) async throws -> Record {
        let records = try await fetchRecords(Record.self, url: url)
        guard let first = records.first else { throw VehicleError.notFound }
        return first
    }
}