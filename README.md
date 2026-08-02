# מספר רכב — Israeli Car Info Lookup (iOS)

A simple, polished iOS app (SwiftUI, Hebrew, RTL) that looks up any Israeli
vehicle by its license-plate number (מספר רישוי) and shows its details, pulled
live from Israel's **free, public, no-API-key** open-data portal
[data.gov.il](https://data.gov.il).

> נבנה בעברית ומימין לשמאל. כל המידע מגיע ממשרד התחבורה דרך פורטל הנתונים
> הפתוחים של ממשלת ישראל — ללא מפתח API וללא תשלום.

## Features

- Enter a 7-digit plate → instant vehicle report.
- Grouped, color-coded result cards:
  - **פרטים בסיסיים** — יצרן, דגם, שנת ייצור, צבע.
  - **מפרט טכני** — סוג דלק, הספק (כ״ס), נפח מנוע, תיבת הילוכים, הנעה, מרכב,
    דלתות/מושבים, משקל, כושר גרירה, פליטת CO2, קבוצת זיהום (1–15).
  - **בטיחות ומערכות סיוע** — כריות אוויר, ABS, בקרת יציבות, רמת אבזור
    בטיחותי (0–8) ומערכות הסיוע המתקדמות שבדגם.
  - **רישוי ובדיקות** — תוקף טסט ורישיון עם סטטוס צבעוני (בתוקף / עומד לפוג / פג).
  - **היסטוריה ובעלות** — סוג בעלות, קילומטראז' אחרון, דגלי שינויים (צבע/מבנה/גוף/צמיג).
  - **מחירון** — מחיר יבואן כחדש ושווי מוערך (מוסתייג).
- **"הרכב שלי"** — pin your car: new-recall alerts and test-expiry reminders
  (local notifications + BGAppRefresh), a status card on the search screen, a
  home-screen **widget**, and a "בדיקת רכב" App Shortcut (Siri / Shortcuts).
- **Deregistered check** — written-off plates (ביטול סופי) resolve with a red
  "ירד מהכביש" banner + their last stored record, instead of "not found".
- **Compare mode** — two plates side-by-side, from history or an open report.
- **Offline snapshots** — every successful lookup is stored (up to 40); history
  taps show instantly and revalidate in the background, and reports stay
  readable offline with a "מוצג מידע שמור" note.
- Search history of recently-looked-up plates.
- Share a text summary, or export a one-page **vector PDF report**.
- Dark-mode-ready, fully RTL, accessibility-conscious.

## Data sources (all free, no key — verified live against data.gov.il)

| Purpose | data.gov.il resource_id |
| --- | --- |
| Vehicle registration & spec (primary) | `053cea08-09bc-40ec-8f7a-156f0677aff3` |
| Public vehicles — fallback (buses, taxis) | `cf29862d-ca25-4691-84f6-1be60dcb4a1e` |
| Personal imports — fallback (יבוא אישי) | `03adc637-b6fe-402b-9937-7c3d3afc9140` |
| Motorcycles — fallback (דו-גלגליים) | `bf9df4e2-d90d-4c0a-a400-19e15af8e95f` |
| Heavy trucks / no model code — fallback | `cd3acc5c-03c3-4c89-9c54-d40f93c0d790` |
| Mileage + change flags (2017+) — queried with `filters` | `56063a99-8a3e-4ff4-912e-5966c0279bad` |
| Ownership-transfer timeline (2017+) — queried with `q` | `bb2355dc-9ec7-4f06-9c3f-3344672171da` |
| Open (unperformed) recalls — queried with `filters`, UPPERCASE field | `36bf1404-0be4-49d2-82dc-2f1ead4a8b93` |
| New-car importer list prices (1996+) — joined on model codes | `39f455bf-6db0-4926-859d-017f34eacbcb` |
| Model spec sheet (hp, gearbox, safety systems) — joined on model codes | `142afde2-6228-49f9-8a29-9b6c3a0cbe40` |
| Deregistered vehicles (ביטול סופי) — current era | `851ecab1-0622-4dbe-a6c7-f950cf82abf9` |
| Deregistered vehicles — 2010–2016 | `4e6b9724-4c1e-43f0-909a-154d4cc4e046` |
| Deregistered vehicles — 2000–2009 | `ec8cbc34-72e1-4b69-9c48-22821ba0bd6c` |

The app tries the **primary** (active private/commercial) dataset first; on a
not-found it queries the **fallback** datasets concurrently (public vehicles,
personal imports, motorcycles, heavy trucks) and returns the first hit — so
buses, taxis, imported cars, motorcycles and heavy trucks all resolve. The two
"history" resources are **different datasets** (not paginated halves):
`56063a99` gives the last mileage + change flags (exact `filters` match, one
record), and `bb2355dc` gives the ownership-transfer timeline (full-text `q`
match, multiple records per plate). Example request:

```
GET https://data.gov.il/api/3/action/datastore_search
    ?resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3
    &filters={"mispar_rechev":"5970065"}
```

The `filters` value is a URL-encoded JSON object; the plate is sent as a
**string** even though `mispar_rechev` is numeric. The response shape is
`{ success, result: { records: [ {...} ] } }`.

### WLTP electric range — EEA (the one non-Israeli source)

No data.gov.il resource publishes driving range, so for EVs and plug-in
hybrids the app queries the **European Environment Agency**'s per-registration
"CO2 emissions from new passenger cars" database via **DiscoData** — a free,
key-less SQL-over-HTTPS JSON endpoint (same trust model as data.gov.il):

```
GET https://discodata.eea.europa.eu/sql
    ?query=SELECT [Ep (KW)] AS ep, Zr AS zr, COUNT(*) AS n FROM ... &p=1&nrOfHits=200
```

Israeli vehicles are European type-approvals, so the EEA commercial name
(`Cn`) matches `kinuy_mishari` directly ("MODEL 3", "ATTO 3"…). Verified
quirks (all encoded in `Networking/ElectricRangeService.swift`):

- The WLTP electric-range column is **`Zr`** (km), populated from ~2021.
  Member states report it inconsistently, so the app takes the
  **registration-count-weighted mode** — never MIN/MAX (typos abound).
- BEVs filter `UPPER(Ft) = 'ELECTRIC'`; plug-in hybrids `UPPER(Fm) = 'P'`.
- `Ep (KW)` disambiguates BEV trims sharing one `Cn` (≈ `koah_sus` × 0.7355);
  for PHEVs it is combustion-engine-only power and is ignored.
- Years 2010–2022: `[CO2Emission].[latest].[co2cars]` (filter `[Year]`);
  2023+: per-year tables (`co2cars_2023Fv28`, `co2cars_2024Pv29`,
  `co2cars_2025Pv31`) whose names embed data versions and change when the
  EEA republishes — update `ElectricRange.tableName` when new years appear.
  The DiscoData catalog is at `https://discodata.eea.europa.eu/md`
  (needs a browser-like User-Agent).

### Field notes (verified)

The **primary** resource returns (Hebrew): `mispar_rechev`, `tozeret_nm`
(יצרן), `kinuy_mishari` (דגם), `sug_degem`, `degem_nm`, `shnat_yitzur`
(שנת ייצור), `tzeva_rechev` (צבע), `sug_delek_nm` (סוג דלק), `kvutzat_zihum`
(קבוצת זיהום 1–15), `ramat_gimur`, `tokef_dt` (תוקף טסט), `mivchan_acharon_dt`
(מבחן אחרון), `baalut` (סוג בעלות — פרטי/חכר/השכרה), `misgeret` (מספר שלדה/VIN),
`moed_aliya_lakvish` (מועד עלייה לכביש, פורמט `yyyy-M`). Engine displacement
(`nefach_manoa`) and weights (`mishkal_kolel`, `mishkal_aa`) are **not** part of
this resource — their rows are hidden when absent.

The **mileage** resource (`56063a99`) returns: `kilometer_test_aharon`
(קילומטראז׳ אחרון), `mispar_manoa` (מספר מנוע), `shinui_mivne_ind` /
`gapam_ind` / `shnui_zeva_ind` / `shinui_zmig_ind` (0/1 flags: שינוי מבנה /
התקנת גפ״מ / שינוי צבע / שינוי צמיג), `rishum_rishon_dt` (תאריך רישום ראשון),
`mkoriut_nm` (מקור בעלות).

The **ownership** resource (`bb2355dc`) returns one record per ownership period:
`baalut_dt` (תאריך תחילת בעלות, פורמט `YYYYMM`) and `baalut` (סוג בעלות:
פרטי / סוחר / ליסינג / חברה). The app renders these as an ascending timeline
with date ranges, the last entry marked "נוכחי". Note: it is **full-text indexed
only** — it must be queried with `q=<plate>` (not `filters`), and the app filters
the results client-side to the exact plate to avoid false positives.

Both history datasets only cover private vehicles tracked since 2017, so many
plates (especially older ones) have **no** history — the app silently hides
that section. Example: `3256880` → פרטי (2017) → סוחר (2021) → פרטי (2021).

The **recalls** resource (`36bf1404`, "כלי רכב שלא ביצעו ריקול") lists open
recalls the vehicle has **not yet performed** — presence of a record means an
open recall; absence means none (or already fixed). Unlike every other
resource its filter field is **UPPERCASE**: `filters={"MISPAR_RECHEV":"..."}`
(still a JSON string). A plate can have several records, so the app queries
with a generous limit. Fields: `RECALL_ID`, `SUG_RECALL` (סוג ריקול),
`SUG_TAKALA` (קטגוריה), `TEUR_TAKALA` (תיאור), `TAARICH_PTICHA`
(תאריך פתיחה, `yyyy-MM-dd`). Updated daily.

The **new-car price** resource (`39f455bf`, "יבואנים ומחירוני רכב חדש") holds
the importer's official list price (`mehir`, ₪) for every marketed
model/trim/year since 1996. It is joined to a vehicle on **four keys** —
`tozeret_cd`, `degem_cd`, `sug_degem`, `shnat_yitzur` — which normally yields
exactly one record (also `shem_yevuan`, the importer). Vehicles resolved from
the fallback datasets (imports, motorcycles, heavy trucks) have no `degem_cd`,
so they show no price. The app derives a **rough current-value estimate** from
the new price (−15% first year, −10%/year after, floored at 5%) — clearly
disclaimed, since the authoritative used-car guide (מחירון לוי יצחק) is
proprietary with no public API; the app links out to it instead.

The **model-spec** resource (`142afde2`, "מאגר דגמי רכב") is the per-model/
trim/year spec sheet, joined on the **same four keys** as the price resource
(normally exactly one record): `koah_sus` (הספק בכ״ס), `nefah_manoa` (נפח
מנוע — note the spelling differs from the primary resource's `nefach_manoa`),
`automatic_ind` (תיבת הילוכים), `hanaa_nm` (4X2/4X4), `merkav` (מרכב),
`mispar_moshavim`/`mispar_dlatot`, `mishkal_kolel`, towing capacities
(`kosher_grira_im_blamim`/`bli_blamim`, 0 = not rated), safety equipment
(`mispar_kariot_avir`, `abs_ind`, `bakarat_yatzivut_ind`,
`ramat_eivzur_betihuty` 0–8), `technologiat_hanaa_nm` ("הנעה רגילה" /
"PLUG IN" / …) and ~19 driver-assist 0/1 flags (`bakarat_stiya_menativ_ind`,
`bakarat_shyut_adaptivit_ind`, `matzlemat_reverse_ind`, …) which the app
renders as chips in the בטיחות card. CO2 comes as complementary fields —
old models have only `kamut_CO2` (NEDC-era), new ones only `CO2_WLTP` — and
both are decoded as `Double` (this resource emits floats). `nikud_betihut`
arrives as a float (e.g. `2.0`) and is deliberately **not** decoded. Vehicles
from the fallback datasets lack `degem_cd`, so they have no spec — the extra
rows and the safety card hide. Example: plate `5970065` → 160 כ״ס, ידנית,
קבריולט, ‎181 g/km; plate `77720101` → 211 כ״ס, אוטומטית, היברידי נטען,
7 כריות אוויר, ‎36 g/km (WLTP).

The **deregistered** package ("כלי רכב שירדו מהכביש ובסטטוס ביטול סופי")
holds vehicles whose registration was finally cancelled, in three era-split,
filter-indexed resources (lowercase `mispar_rechev`, plate as a JSON string):
`851ecab1…` (current era, ~1.2M records), `4e6b9724…` (2010–2016) and
`ec8cbc34…` (2000–2009). Records carry near-full primary-style vehicle fields
plus `bitul_dt` (cancellation timestamp, "2026-07-30 00:00:00") — the app
queries them only after the primary and all fallbacks miss, and renders the
hit as a normal report topped by a red "ירד מהכביש — ביטול סופי" banner.
These records have no `sug_degem`, so the price/spec joins skip naturally.

## Build & run

This repo uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the
`.xcodeproj` is generated from `project.yml` (no checked-in pbxproj).

```bash
# 1. Install XcodeGen (one time)
brew install xcodegen

# 2. Generate the Xcode project
cd MisparRechev
xcodegen generate

# 3. Open & run (iOS 17+ simulator)
open MisparRechev.xcodeproj
```

### Run on a real iPhone

The project uses **automatic code signing**. In Xcode:

1. Add your Apple ID: **Xcode ▸ Settings ▸ Accounts ▸ +**.
2. Select the **MisparRechev** target ▸ **Signing & Capabilities** ▸ tick
   **Automatically manage signing** ▸ pick your **Team** (Personal Team works).
3. Choose your iPhone as the run destination and press ⌘R.
4. On first launch, trust the developer: **Settings ▸ General ▸ VPN & Device
   Management ▸ [your Apple ID] ▸ Trust**.

A free Apple ID is enough (7-day signature, 3-app limit). To persist your team
across regenerations, add `DEVELOPMENT_TEAM: <your team id>` to the
`MisparRechev` target settings in `project.yml`.

The scheme also builds the embedded **widget extension**
(`MisparRechevWidgets`). App ↔ widget data flows through the App Group
`group.il.misparrechev.shared`; this normally provisions even on a free
personal team, but if signing complains, delete the two `entitlements:` blocks
in `project.yml` — the app falls back to standard `UserDefaults` and only the
widget's data-sharing degrades (it shows its "הצמידו רכב" placeholder).
Note: `Sources/*/Info.plist` and `*.entitlements` are **generated by XcodeGen**
from `project.yml` (and gitignored) — never hand-edit them.

> **Fallback (no XcodeGen):** In Xcode → File ▸ New ▸ Project ▸ iOS App
> (Interface: SwiftUI, Language: Swift, bundle id `il.misparrechev.app`).
> Set the development region to `he`, then drag the contents of
> `Sources/MisparRechev/` into the project and `Tests/MisparRechevTests/` into a
> new Unit Testing Bundle.

## Test plates

- `5970065` — מזדה MX-5, 2008. Known-good primary record (no history entry —
  demonstrates the graceful "history hidden" behavior).
- `3256880` — full **היסטוריה ובעלות** section: ownership timeline
  (פרטי → סוחר → פרטי), 159,816 km, and structural + tire change flags.
- `77720101` — מרצדס בנץ C300E with a 4-entry ownership timeline.
- `9441873` — a **personally-imported** Mercedes (יבוא אישי-משומש, גרמניה, 2011)
  from the personal-import fallback dataset, showing the import badge.
- `17070204` — a public bus (הייגר סין, 2025). Not in the primary dataset, so it
  exercises the **public-vehicles fallback** path.
- `1234567` — אלפא רומיאו 159, 2009 (was a Corolla in older docs; the plate was
  re-registered). New-car list price resolves to ₪190,990.
- `5569379` — קיה RIO 2012 with an **open recall** (as of 2026-07) — shows the
  red recall-warning card. The dataset refreshes daily, so the recall may
  eventually be performed and the card disappear.
- `1442562` — a 2007 Toyota that was **finally cancelled** (ביטול סופי,
  2026-07-30). Missed by every active dataset, found in the deregistered one —
  shows the red "ירד מהכביש" banner.
- `0000000` — use to see the "not found" state.

## Run tests

```bash
xcodegen generate
xcodebuild test -scheme MisparRechev -destination 'platform=iOS Simulator,name=iPhone 15'
```

The decoding tests parse captured API responses (`Tests/MisparRechevTests/Fixtures`)
and assert key Hebrew fields survive `Codable` round-tripping.

## Architecture

```
App/                  @main entry, RootView state switch
DesignSystem/         Theme, reusable styled components (authored for RTL/Hebrew)
Models/               Decodable structs matching the CKAN responses
Networking/           Endpoint definitions + async VehicleService
Persistence/          SearchHistoryStore (UserDefaults)
ViewModels/           @Observable SearchViewModel (state machine)
Views/                SwiftUI screens
Resources/            Localizable.strings (he)
```

The app calls data.gov.il **directly over HTTPS** — no backend needed. Both
resources are fetched concurrently (`async let`); a failure of the optional
history resource never blocks the primary result.

## License

MIT.