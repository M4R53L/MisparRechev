import Foundation

/// Everything a successful lookup returns. Only `vehicle` is required — the
/// optional parts degrade to `nil`/empty when their datasets don't cover the
/// plate, and their fetch failures never break the primary result.
struct LookupResult: Equatable {
    let vehicle: Vehicle
    let mileage: VehicleHistory?
    let ownership: [OwnershipRecord]
    let recalls: [RecallRecord]
    let prices: [NewCarPrice]
}
