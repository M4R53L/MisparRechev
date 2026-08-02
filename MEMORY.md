# Memory
<!-- Maintained automatically by Nemotron Chat. Manual edits below may be rewritten. -->
- Project "MisparRechev" is an iOS app (SwiftUI, Hebrew, RTL) for Israeli vehicle plate lookup, by GitHub user M4R53L.
- IN PROGRESS (chat ended mid-task): approved plan to fix camera scanner not recognizing plates — edits only to `Sources/MisparRechev/Utilities/PlateRecognizer.swift`, `PlateScannerView.swift`, `Tests/MisparRechevTests/PlateRecognizerTests.swift` (no new files, no xcodegen regen); `PlateRecognizer.swift` line-merging edits were applied, but `PlateScannerView.swift` changes (merged candidates, tap-line accept, main-thread hop, live candidate pill) and new tests are not confirmed done.
- Scanner pipeline: `PlateScannerSheet`/`PlateScannerView.swift` hosts VisionKit `DataScannerViewController` → `Coordinator.consider(allItems)` → `PlateRecognizer.bestCandidate(in:)` → `onPlateFound` dismisses sheet → `viewModel.search()` fires instantly.
- Scanner root cause (diagnosed): VisionKit returns plate digit groups as separate items ("123","45","678") while per-item matching required 6–8 digits across ≥2 groups, so nothing ever matched; tap-to-accept had the same flaw; non-canonical reads needed 2–3 consecutive identical frames; gray rectangles = `isHighlightingEnabled` (OCR was working).
- Agreed fix approach: merge same-line recognized items into combined transcripts before matching, accept canonical plate shapes instantly, show live "detected" candidate pill with tap-to-confirm, add tests.
- `PlateRecognizer` (`Sources/MisparRechev/Utilities/PlateRecognizer.swift`) extracts Israeli plates (6–8 digits, often hyphen/middle-dot grouped) from OCR transcripts; its tests are pure logic, run on simulator, no camera needed.
- App structure: `RootView` switches between `SearchView`/`LoadingView`/`ResultView`/`ErrorView` in `Sources/MisparRechev/Views/`; `SearchView` has title, plate field, search button, recent-history list, and two-plate comparison via sheet.
- `PlateField` uses a real, visible `TextField` (not hidden) so it reliably becomes first responder.
- `DataFreshness` enum distinguishes live fetch vs stored offline snapshot (with save date) and drives the "מוצג מידע שמור" banner.
- Test suite in `Tests/MisparRechevTests/` includes `PlateRecognizerTests`, `CompareMetricsTests`, `LiveNetworkTests`, `MyCarRefresherTests`, `MyCarStoreTests`.
- Result screen (`Sources/MisparRechev/Views/ResultView.swift`) card order: היסטוריה ובעלות, רישוי ובדיקות, פרטים בסיסיים, מפרט טכני, footer actions; hero (yellow plate) stays at top.
- README documents test plate 5970065 for verifying the result screen.
- GitHub repo (private): `git@github.com:M4R53L/MisparRechev.git`; remote `origin` set, `main` tracks `origin/main`, initial commit pushed.
- Uses XcodeGen: `project.yml` committed, generated `MisparRechev.xcodeproj/` gitignored; `.gitignore` also excludes DerivedData, xcuserdata, .DS_Store, SPM/build artifacts.
- `LICENSE` is MIT, credited to M4R53L; repo root also contains `CLAUDE.md` (8.3 KB) and `MEMORY.md`.
- `gh` CLI is not installed; user creates GitHub repos manually on github.com/new.
- Open question: `Nemotron.md` (AI-assistant context file) is currently committed; user may want it removed and gitignored.
- `Nemotron.md` build/test command references `name=iPhone 15`, but only iPhone 17 series simulators on iOS 26.5 are installed; command needs updating to use an available simulator.
