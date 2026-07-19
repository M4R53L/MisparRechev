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
  - **מפרט טכני** — סוג דלק, נפח מנוע, משקל, קבוצת זיהום (1–15).
  - **רישוי ובדיקות** — תוקף טסט ורישיון עם סטטוס צבעוני (בתוקף / עומד לפוג / פג).
  - **היסטוריה ובעלות** — סוג בעלות, קילומטראז' אחרון, דגלי שינויים (צבע/מבנה/גוף/צמיג).
- Search history of recently-looked-up plates.
- Share / export a text summary of the report.
- 24-hour local cache to respect rate limits (data refreshes ~daily).
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
- `1234567` — טויוטה קורולה הייבריד (widely used example).
- `5569379` — קיה RIO 2012 with an **open recall** (as of 2026-07) — shows the
  red recall-warning card. The dataset refreshes daily, so the recall may
  eventually be performed and the card disappear.
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