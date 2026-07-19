# Memory
<!-- Maintained automatically by Nemotron Chat. Manual edits below may be rewritten. -->
- Project "MisparRechev" is an iOS app (SwiftUI, Hebrew, RTL) for Israeli vehicle plate lookup.
- GitHub repo (private): `git@github.com:M4R53L/MisparRechev.git`, user is M4R53L.
- Remote `origin` is set and `main` branch tracks `origin/main`; initial commit pushed.
- Uses XcodeGen: `project.yml` is committed, the generated `MisparRechev.xcodeproj/` is gitignored.
- `.gitignore` excludes generated xcodeproj, DerivedData, xcuserdata, .DS_Store, SPM/build artifacts.
- `LICENSE` is MIT, credited to M4R53L.
- `gh` CLI is not installed; user creates GitHub repos manually on github.com/new.
- Open question: `Nemotron.md` (AI-assistant context file) is currently committed; user may want it removed and gitignored.
- `Nemotron.md` build/test command references `name=iPhone 15`, but only iPhone 17 series simulators on iOS 26.5 are installed; command needs updating to use an available simulator.
- Result screen (`Sources/MisparRechev/Views/ResultView.swift`) card order changed: היסטוריה ובעלות, then רישוי ובדיקות, then פרטים בסיסיים, then מפרט טכני, then footer actions; hero (yellow plate) stays at top.
- README documents test plate 5970065 for verifying the result screen.
