# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MisparRechev (מספר רכב) — an iOS app (SwiftUI, Swift 5, iOS 17+, Hebrew, forced RTL) that looks up Israeli vehicles by license-plate number against Israel's free, key-less open-data portal (data.gov.il). No backend: the app calls the CKAN `datastore_search` API directly over HTTPS.

## Commands

The `.xcodeproj` is **generated** from `project.yml` via XcodeGen and is gitignored. Re-run `xcodegen generate` after editing `project.yml` or adding/removing/moving source files, or builds will be stale.

```bash
# Regenerate the Xcode project (required after project.yml/file-layout changes)
xcodegen generate

# Build
xcodebuild build -scheme MisparRechev -destination 'platform=iOS Simulator,name=iPhone 17'

# Run all tests
xcodebuild test -scheme MisparRechev -destination 'platform=iOS Simulator,name=iPhone 17'

# Run a single test class / test
xcodebuild test -scheme MisparRechev -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MisparRechevTests/VehicleDecodingTests
xcodebuild test -scheme MisparRechev -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MisparRechevTests/VehicleDecodingTests/testDecodesPrimaryVehicleFromFixture
```

Note: README examples say `name=iPhone 15`, but only iPhone 17-series simulators are installed on this machine — use an available device (`xcrun simctl list devices available`).

There is no lint command. `MisparRechevTests` has two suites: `VehicleDecodingTests` runs offline against JSON fixtures in `Tests/MisparRechevTests/Fixtures/`; `LiveNetworkTests` hits the live data.gov.il API and auto-skips when the network is unavailable.

## Architecture

Flow: `MisparRechevApp` (@main) → `RootView` switches on `LookupState` → screens in `Views/`.

- `ViewModels/SearchViewModel.swift` — `@Observable` state machine (`LookupState`: empty / loading / loaded / error). Owns plate input validation (6–8 digits), in-flight task cancellation, search-history persistence, and all date parsing/formatting helpers (API dates arrive in several formats; `ValidityStatus` drives test/license expiry colors).
- `Networking/VehicleService.swift` — async lookup: vehicle + mileage + ownership fetched concurrently (`async let`); the two history fetches are optional and never fail the primary result. `DataGovEndpoint.swift` holds all resource IDs and URL builders. `VehicleService+Preview.swift` provides a fixture-backed service for SwiftUI previews.
- `Models/` — `Codable` structs matching CKAN responses (`DataGovResponse<Record>` generic envelope in `APIResponse.swift`). Field names deliberately mirror the API's Hebrew-transliterated snake_case (`mispar_rechev`, `tozeret_nm`, …).
- `DesignSystem/` — `Theme.swift` plus reusable styled components (InfoCard, StatusBadge, PollutionScale, PlateField…), all authored for RTL/Hebrew.
- `Persistence/SearchHistoryStore.swift` — recent plates via UserDefaults (value-type store; mutations return a new value which the view model saves).

### data.gov.il specifics (verified quirks — don't "fix" these)

- **Dataset fallback strategy:** the primary private/commercial resource is tried first; on not-found, four fallback datasets (public vehicles, personal imports, motorcycles, heavy trucks) are queried **concurrently, first hit wins** — the categories are disjoint. Real network/decoding errors from the primary fetch are never masked by fallbacks.
- **`filters` queries send the plate as a JSON string** (`{"mispar_rechev":"5970065"}`) even though the field is numeric — that's what the API expects.
- **The ownership resource (`bb2355dc…`) is full-text indexed only**: it must be queried with `q=<plate>` (not `filters`), then filtered client-side to the exact `mispar_rechev` to drop false positives, and sorted ascending by `baalut_dt` (YYYYMM int).
- **The recalls resource (`36bf1404…`) uses an UPPERCASE filter field**: `filters={"MISPAR_RECHEV":"…"}` (plate still a JSON string; lowercase returns a Validation Error). A plate can have multiple open recalls — query with a generous limit, never 1. A record means an open, unperformed recall; absence means none.
- **New-car prices (`39f455bf…`) join on four keys**: `tozeret_cd` + `degem_cd` + `sug_degem` + `shnat_yitzur` (values as JSON strings) → normally exactly one record with `mehir` (₪ importer list price). Fallback-dataset vehicles (imports/motorcycles/heavy trucks) lack `degem_cd` → no price, section hidden. The used-car value shown is a crude in-app depreciation estimate — the real used-car guide (Levi Yitzhak) is proprietary with no public API.
- The mileage (`56063a99…`) and ownership resources are **different datasets**, not paginated halves. Both cover only private vehicles since 2017 — many plates legitimately have no history, and the UI silently hides that section.
- Engine displacement / weights are not in the primary resource; their rows are hidden when nil.
- README.md documents all resource IDs, verified field names, and **known test plates** (e.g. `5970065` known-good, `3256880` full ownership timeline, `9441873` personal import, `17070204` public bus, `5569379` open recall, `0000000` not-found).

## Conventions

- UI text is Hebrew (`Resources/Localizable.strings`, development language `he`); RTL is forced via `INFOPLIST_KEY_UIForceRTL` in `project.yml`.
- `Nemotron.md` and `MEMORY.md` at the repo root are context files maintained by another AI assistant — don't treat them as authoritative project docs (README.md is), and don't edit them unless asked.
