# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MisparRechev (מספר רכב) — an iOS app (SwiftUI, Swift 5, iOS 17+, Hebrew, forced RTL) that looks up Israeli vehicles by license-plate number against Israel's free, key-less open-data portal (data.gov.il). No backend: the app calls the CKAN `datastore_search` API directly over HTTPS.

## Commands

The `.xcodeproj` is **generated** from `project.yml` via XcodeGen and is gitignored. Re-run `xcodegen generate` after editing `project.yml` or adding/removing/moving source files, or builds will be stale. The app's and widget's `Info.plist` + `.entitlements` files are also XcodeGen-generated (and gitignored) — change them only via the `info:`/`entitlements:` blocks in `project.yml`, never by editing the generated files.

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

Flow: `MisparRechevApp` (@main) → `RootView` (a `NavigationStack`: `SearchView` is the root, and loading/report/error are one pushed destination driven by `LookupState`; popping calls `viewModel.goBack()`) → screens in `Views/`. First launch presents `Views/OnboardingView.swift` as a full-screen cover (flag `hasSeenOnboarding` in UserDefaults; launch with `-hasSeenOnboarding YES` to skip, as the UI tests do). `Views/SettingsView.swift` is the gear sheet on the search screen.

- `ViewModels/SearchViewModel.swift` — `@Observable` state machine (`LookupState`: empty / loading / loaded / error). Owns plate input validation (6–8 digits), in-flight task cancellation, search-history persistence, and all date parsing/formatting helpers (API dates arrive in several formats; `ValidityStatus` drives test/license expiry colors).
- `Networking/VehicleService.swift` — async lookup: vehicle + mileage + ownership fetched concurrently (`async let`); the two history fetches are optional and never fail the primary result. `DataGovEndpoint.swift` holds all resource IDs and URL builders. `VehicleService+Preview.swift` provides a fixture-backed service for SwiftUI previews.
- `Models/` — `Codable` structs matching CKAN responses (`DataGovResponse<Record>` generic envelope in `APIResponse.swift`). Field names deliberately mirror the API's Hebrew-transliterated snake_case (`mispar_rechev`, `tozeret_nm`, …).
- `DesignSystem/` — `Theme.swift` (Dynamic Type text-style fonts, grouped backgrounds) plus reusable components, all authored for RTL/Hebrew. The plate is the app's signature object: every plate goes through `PlateChrome` (`PlateView` read-only, `PlateField` input) with the blue IL strip pinned to the physical left. Surfaces are flat (no card shadows or strokes; `cardShadow()` is for the plate and floating notices only). Buttons use `PrimaryButtonStyle` / `SecondaryButtonStyle`; `PlateKeyButtonStyle` is onboarding-only.
- `Utilities/CarBrand.swift` — maps the registry's `tozeret_nm` (maker + factory country, often truncated) by prefix to a clean brand name and a logo in `Assets.xcassets/Brands/<slug>` (PNG thumbs from the MIT `car-logos-dataset`; the marks are their owners' trademarks). Unknown makers get a monogram via `BrandLogo`.
- `Persistence/SearchHistoryStore.swift` — recent plates via UserDefaults (value-type store; mutations return a new value which the view model saves). Same value-type pattern: `SnapshotStore.swift` (full `LookupResult` snapshots as one JSON file in Application Support, cap 40 — powers stale-while-revalidate history taps and the offline fallback) and `MyCarStore.swift` (the pinned "הרכב שלי" in App-Group UserDefaults `group.il.misparrechev.shared`, `.standard` fallback).
- `Networking/MyCarRefresher.swift` — the my-car pipeline (recall-diff notifications, 30/7/0-day test reminders at 09:00, BGAppRefresh task `il.misparrechev.app.refresh`, widget timeline reloads). Pure helpers (`reminderDates`, `newRecallIDs`) are unit-tested; BG tasks never fire in the simulator (test on device via the LLDB `_simulateLaunchForTaskWithIdentifier` trick).
- `Sources/MisparRechevWidgets/` — the widget extension. It compiles exactly two files from the app tree: `Persistence/MyCarStore.swift` + `Utilities/PlateDates.swift` — both MUST stay Foundation-only (no SwiftUI/model-layer imports). `PlateDates` owns date parsing/validity; `SearchViewModel` keeps same-named forwarding statics so call sites didn't change.
- `SearchViewModel.shared` is the app's live instance — the App Shortcut intent (`Intents/LookupPlateIntent.swift`) and `misparrechev://` deep links (widget tap) drive the UI through it.
- `Utilities/PDFReportRenderer.swift` + `Views/PDFReportView.swift` — vector single-page PDF export; the RTL/he/light environment must be applied to the rendered content itself (ImageRenderer inherits nothing).

### data.gov.il specifics (verified quirks — don't "fix" these)

- **Dataset fallback strategy:** the primary private/commercial resource is tried first; on not-found, four fallback datasets (public vehicles, personal imports, motorcycles, heavy trucks) are queried **concurrently, first hit wins** — the categories are disjoint. Real network/decoding errors from the primary fetch are never masked by fallbacks.
- **`filters` queries send the plate as a JSON string** (`{"mispar_rechev":"5970065"}`) even though the field is numeric — that's what the API expects.
- **The ownership resource (`bb2355dc…`) is full-text indexed only**: it must be queried with `q=<plate>` (not `filters`), then filtered client-side to the exact `mispar_rechev` to drop false positives, and sorted ascending by `baalut_dt` (YYYYMM int).
- **The recalls resource (`36bf1404…`) uses an UPPERCASE filter field**: `filters={"MISPAR_RECHEV":"…"}` (plate still a JSON string; lowercase returns a Validation Error). A plate can have multiple open recalls — query with a generous limit, never 1. A record means an open, unperformed recall; absence means none.
- **New-car prices (`39f455bf…`) join on four keys**: `tozeret_cd` + `degem_cd` + `sug_degem` + `shnat_yitzur` (values as JSON strings) → normally exactly one record with `mehir` (₪ importer list price). Fallback-dataset vehicles (imports/motorcycles/heavy trucks) lack `degem_cd` → no price, section hidden. The used-car value shown is a crude in-app depreciation estimate — the real used-car guide (Levi Yitzhak) is proprietary with no public API.
- **Model specs (`142afde2…`) join on four keys** (`tozeret_cd`+`degem_cd`+`sug_degem`+`shnat_yitzur`) → normally one record with `koah_sus` (hp), gearbox/drive/body, seats/doors, airbags, towing, CO2 and ~19 driver-assist 0/1 flags. Displacement there is spelled `nefah_manoa` (the primary resource says `nefach_manoa`); CO2 fields are complementary (`kamut_CO2` NEDC-era vs `CO2_WLTP`) and decoded as `Double` (floats occur); `nikud_betihut` is a float — deliberately not decoded (`VehicleSpec` would fail on `Int`). No `degem_cd` → no spec; the extra rows and the safety card hide.
- **Deregistered vehicles (ביטול סופי) live in three era-split resources** (`851ecab1…` current / `4e6b9724…` 2010–2016 / `ec8cbc34…` 2000–2009), filter-indexed by lowercase `mispar_rechev`. Queried concurrently (first hit wins) ONLY after the primary + all fallbacks miss. Records decode as `Vehicle` — `bitul_dt` (non-nil only there) is the deregistered marker (`vehicle.isDeregistered` → red banner). No `sug_degem` → price/spec joins skip naturally. Test plate: `1442562`.
- **WLTP electric range comes from the EEA, not data.gov.il** (no Israeli resource publishes range). `Networking/ElectricRangeService.swift` queries DiscoData (`discodata.eea.europa.eu/sql` — free, key-less SQL-over-HTTPS) against the EU car-registration tables: `Cn` ↔ `kinuy_mishari`, `Zr` = WLTP range km (registration-weighted mode, never MIN/MAX — member states typo it), BEVs filter `UPPER(Ft)='ELECTRIC'` + trim via `Ep (KW)` ≈ `koah_sus`×0.7355, PHEVs filter `UPPER(Fm)='P'` and ignore power. `Zr` exists only from ~2021; 2023+ live in per-year tables whose version-suffixed names change when the EEA republishes (`ElectricRange.tableName`). Optional fetch — nil hides the row, failures never break the lookup.
- The mileage (`56063a99…`) and ownership resources are **different datasets**, not paginated halves. Both cover only private vehicles since 2017 — many plates legitimately have no history, and the UI silently hides that section.
- Engine displacement / weights are not in the primary resource; their rows are hidden when nil.
- README.md documents all resource IDs, verified field names, and **known test plates** (e.g. `5970065` known-good, `3256880` full ownership timeline, `9441873` personal import, `17070204` public bus, `94230401` open recall as of 2026-11 (recalls close once performed; `5569379` no longer has one), `0000000` not-found).

## Conventions

- UI text is Hebrew (inline literals; `Resources/he.lproj/` holds `Localizable.strings` + `InfoPlist.strings`, development language `he`). Build `Text` from a plain `String` or `Text(verbatim:)` when concatenating Hebrew with dates/numbers: an interpolated `LocalizedStringKey` isolates each argument and scrambles RTL word order. No em dashes or middle-dot separators in visible copy; RTL is forced via `INFOPLIST_KEY_UIForceRTL` in `project.yml`.
- `Nemotron.md` and `MEMORY.md` at the repo root are context files maintained by another AI assistant — don't treat them as authoritative project docs (README.md is), and don't edit them unless asked.
