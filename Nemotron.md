# MisparRechev

An iOS app (SwiftUI, Swift 5, iOS 17+, Hebrew RTL) that looks up any Israeli vehicle by license-plate number against Israel's free, key-less open-data portal data.gov.il. The `.xcodeproj` is generated from `project.yml` via XcodeGen (no checked-in pbxproj), bundle id `il.misparrechev.app`.

## Commands
- Generate Xcode project: `xcodegen generate` (run after any change to `project.yml` or source layout; required before building/testing).
- Run app (simulator): `open MisparRechev.xcodeproj` then ⌘R, or `xcodebuild build -scheme MisparRechev -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Run tests (correctness gate): `xcodegen generate && xcodebuild test -scheme MisparRechev -destination 'platform=iOS Simulator,name=iPhone 15'`.
- No standalone lint command.

## Structure
- `Sources/MisparRechev/App/` — `MisparRechevApp.swift` (`@main`), `RootView.swift` (state switch).
- `Sources/MisparRechev/Networking/` — `DataGovEndpoint.swift` (CKAN endpoint + resource_id definitions), `VehicleService.swift` (async fetch, concurrent fallback datasets), `VehicleService+Preview.swift`, `VehicleError.swift`.
- `Sources/MisparRechev/Models/` — `Vehicle.swift`, `VehicleHistory.swift`, `OwnershipRecord.swift`, `APIResponse.swift` (Codable structs matching CKAN responses).
- `Sources/MisparRechev/ViewModels/SearchViewModel.swift` — `@Observable` state machine.
- `Sources/MisparRechev/Views/`, `DesignSystem/`, `Persistence/` (SearchHistoryStore via UserDefaults), `Resources/` (Hebrew `Localizable.strings`).
- `Tests/MisparRechevTests/` — `VehicleDecodingTests.swift` (Codable round-trips over `Fixtures/` JSON), `LiveNetworkTests.swift` (hits live data.gov.il — needs network).
- `project.yml` — XcodeGen spec; `README.md` documents the data-gov.il resources and test plates.

## Notes
- **Network dependency:** the app and `LiveNetworkTests.swift` call `https://data.gov.il/api/3/action/datastore_search` directly over HTTPS with no API key. No backend. Tests need internet; decoding tests run offline against `Tests/MisparRechevTests/Fixtures`.
- **Fallback dataset strategy:** primary resource `053cea08...` is tried first; on miss, public vehicles / personal imports / motorcycles / heavy-trucks datasets are queried concurrently and the first hit wins (buses, taxis, imports, two-wheelers, heavy trucks all resolve this way). History datasets only cover private vehicles since 2017 — many plates silently hide the history section.
- **Query quirks (verified, see README):** `mispar_rechev` is sent as a **string** inside a URL-encoded JSON `filters` object for the primary/mileage datasets; the ownership dataset (`bb2355dc...`) is full-text-indexed only and must be queried with `q=<plate>` then filtered client-side to avoid false positives.
- **iOS 17+ only** (`deploymentTarget` in `project.yml`); deployment/development language forced to `he` and `INFOPLIST_KEY_UIForceRTL: YES` forces RTL layout regardless of device language.
- **Signing:** automatic code signing (`CODE_SIGN_STYLE: Automatic`); on real device add your Apple ID team in Xcode. To persist a team across `xcodegen` regenerations, add `DEVELOPMENT_TEAM` to the target settings in `project.yml`.
- After editing `project.yml` or adding/removing files, re-run `xcodegen generate` before `xcodebuild`/opening Xcode, or the project will be stale.