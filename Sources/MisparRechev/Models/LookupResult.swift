import Foundation

/// Everything a successful lookup returns. Only `vehicle` is required — the
/// optional parts degrade to `nil`/empty when their datasets don't cover the
/// plate, and their fetch failures never break the primary result.
///
/// Codable so `SnapshotStore` can persist whole results for offline viewing.
struct LookupResult: Codable, Equatable {
    let vehicle: Vehicle
    let spec: VehicleSpec?
    let mileage: VehicleHistory?
    let ownership: [OwnershipRecord]
    let recalls: [RecallRecord]
    let prices: [NewCarPrice]
    /// WLTP electric range (km) for EVs / plug-in hybrids, from the EEA's EU
    /// registration data (see `ElectricRange`). Defaulted so pre-existing
    /// call sites and stored snapshots keep working.
    var electricRangeKm: Int? = nil
}
