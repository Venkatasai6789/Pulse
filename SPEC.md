# P.U.L.S.E. – Build Spec for the Flutter App (v1, UI + mock data)

P.U.L.S.E. (Pollinator Unified Landscape and Sustainability Ecosystem) lets people register locations, record observations, and get an automatically calculated Pollinator Health Index (PHI, 0–100) with a recommendation.

This build is the **Android app with the complete UI**. The backend comes later from another developer. Until then every screen talks to `lib/data/api_service.dart` (`MockApiService`, stored on the phone). **Screens must never read or write storage directly.**

## 1. Ground rules for the agent

1. Don't change `lib/core/phi.dart` or `lib/core/recommendations.dart` without being asked. They hold the client's formulas and are covered by tests. Run `flutter test` after any change near them.
2. All PHI values come from `calculatePhi()`. Never hard-code a score anywhere in the UI.
3. Empty is not zero. Form fields start empty, with nothing preselected, and the user can't submit until `assessment.missingFields` is empty.
4. Submitted assessments are read-only. New assessments create new records.
5. Use the colours and radii in `lib/theme/app_theme.dart`. Headings use Lora (serif, bold) and body text uses Inter.
6. Designs are in `/designs`. They're laptop layouts, so adapt them to a phone (390 × 844) using section 3. Match the look (colours, cards, icons, imagery, tone), not the desktop grid.
7. Use local images from `assets/images/` only, never network images.
8. Allowed packages are in section 8. Ask before adding anything else.

## 2. Navigation

- **Auth flow** (no session): Splash → Welcome → Login / Sign up → Home.
- **Main app**: a bottom `NavigationBar` (forest green) with 5 tabs: **Home · Monitor · Locations · Community · Profile**.
  - Monitor = New Assessment.
  - Results opens after "Calculate PHI" and from any history item. It's also reachable from Home.
  - Reports & Analytics opens from Profile and from the Home "Average PHI" card.
- `go_router` with a `StatefulShellRoute` for the tabs so each tab keeps its own stack.
- Page transitions: fade + slight slide up (250 ms). Use a `Hero` on the location photo and on the PHI gauge.

## 3. Screens

| # | Screen | Design | Notes |
|---|---|---|---|
| A1 | Splash | — | Logo (bee + leaves), "P.U.L.S.E.", tagline "Understanding Pollinators. Inspiring Action." Checks `currentUser()` and routes. |
| A2 | Welcome | — | header_bee image, tagline, "Get Started" (sign up) and "I already have an account" (login). |
| A3 | Login | — | Email, password (show/hide), Login button, link to Sign up. Show errors from `ApiException` in a snackbar. |
| A4 | Sign up | — | Full name, email, password (min 6), confirm password, optional organisation. |
| 1 | Home | `01_home.jpg` | "Good morning/afternoon/evening, {firstName}!" with header_bee image. 4 stat cards in a 2×2 grid (Total Locations, Total Assessments, Average PHI, Community Members: use number of posts' distinct authors). Dark green "Start a New Assessment" banner. Your Locations (horizontal or vertical list with photo, area, latest PHI chip or "No data yet"). Pollinator Health Overview: average-PHI half gauge plus a **5-tier legend**. The Four Parameters: 2×2 grid with averages of latest scores. Recent Activity (last 3 submitted). Empty states match the design ("— / 100", "No recent activity yet"). |
| 2 | New Assessment (Monitor) | `02_new_assessment.jpg` | Location picker at top, then a **4-step stepper** with a progress bar: (1) Pollinator Activity, (2) Habitat Quality, (3) Environmental Conditions, (4) Potential Risk, then a **Review** step. "Save as Draft" on every step, "Calculate PHI" on Review (disabled until complete, showing "N fields left"). Details in section 4. |
| 3 | Register Location | `03_register_location.jpg` | Name*, Type* (`locationTypes`), Address/Area*, "Use my current location" button (geolocator, fills lat/lng and shows "Location captured ✓"; **no map widget**), Description, photo upload (image_picker, up to 5, thumbnails with remove), Managed by Me / Organisation (+ name field). Info card "Why Register a Location?". Cancel / Save Location. |
| 4 | Results | `04_results.jpg` + `05_phi_gauge.jpg` | Section 5. |
| 5 | Locations list | — | Cards with photo, name, type, area, latest PHI chip with tier colour, last assessed date. FAB "+ Add location". |
| 6 | Location detail | — | Hero photo, name, type, address, latest PHI gauge, "Start new assessment" (preselects this location), PHI trend chart, assessment history list (date, PHI, tier chip), draft list. |
| 7 | Community | `06_community.jpg` | community_hero banner. Filter chips: All Posts, Initiatives, Events, Resources, Reports. Upcoming Events horizontal cards (date tile SAT 24 MAY style). Post cards: avatar with initial, author, time ago · type, title, body, image, like (animated), comment count, share (share sheet optional), ⋮ menu → Report post (reason dialog) / Hide. "Community Initiatives" card. "Report a Concern" card → form. FAB "+ New post" (category, title, body, optional image, event date/time/place when category = Event). |
| 8 | Report a Concern | — | Area description*, checkboxes (pesticide, chemical, traffic/pollution, other), description*, observed date*, photos. A note says this records a *potential* concern and is not laboratory-confirmed contamination. |
| 9 | Reports & Analytics | — | Location dropdown. PHI trend line chart (fl_chart). Grouped bars comparing the 4 parameter scores across the last 3 assessments. Table of past assessments, where tapping opens Results. |
| 10 | Profile & Settings | — | Avatar (initials), name, email, organisation (editable). Links: Reports & Analytics, About PHI (formula, weights, tiers, and a note that ranges are prototype values), Privacy & community guidelines (static text), Logout. App version. |

## 4. New Assessment details

**Step 1 – Pollinator Activity**
- Number of pollinator visits* (integer keyboard, 0–500)
- Date & time* (date picker then time picker, default empty)
- Observation duration* (dropdown 5/10/15/20/30 min, default 5)
- Weather conditions* (dropdown, `weatherOptions`)
- Optional photo
- Collapsible "Observation protocol" tip: watch a marked 2 m × 2 m area for 5 minutes, ideally 10–11 AM in good weather.
- Soft warning (not an error) if the time is outside 10–11 AM or the weather is rain/windy: "Counts may be lower than usual in these conditions."

**Step 2 – Habitat Quality**
- Flowers*, Nesting spaces*, Shelter*: three segmented buttons each, Low / Medium / High, **none selected at start**, with illustration icons as in the design.
- Water*: Absent / Present, none selected.

**Step 3 – Environmental Conditions**
- Temperature °C* (−20 to 60, decimals allowed), Humidity %* (0–100), CO₂ ppm* (0–10000).
- Under each field, once valid, show a live chip: Suitable / Moderate / Stressful, coloured, from `temperatureScore` / `humidityScore` / `co2Score`.
- Inline error text for out-of-range values. The field stays empty in the model while invalid.

**Step 4 – Potential Environmental/Chemical Risk**
- Checkboxes: Nearby pesticide spraying, Nearby chemical use, Heavy traffic or pollution, Other concerns.
- **Risk Level* dropdown (user selects Low / Moderate / High, as in the design).** Under it, show a hint: "Based on your selections we suggest: {suggestedRiskLevel}". It's only a hint; don't auto-select.
- Description of concern, approximate date/time observed, additional notes, optional photos.
- Footer note: "P.U.L.S.E. records potential risk indicators. It does not detect specific chemicals or pesticide residues."

**Review step**
- A summary card per parameter with an "Edit" link back to its step.
- A live preview of the four sub-scores and the PHI. Optional but nice, since it reuses `calculatePhi`.
- "Calculate PHI" calls `api.submitAssessment()`, shows a short loading animation (bee or leaf, about 800 ms minimum), then routes to Results and replaces the stack so Back goes to Home.

Autosave the draft when the user leaves the screen. On re-entry, offer "Continue your draft for {location}?"

## 5. Results screen

From top to bottom:
1. Header "Assessment Results", subtitle, location name and assessment date and time.
2. **High Risk alert banner** (red, warning icon) if `result.highRiskAlert`: "High risk observation recorded. A high overall PHI does not rule out a serious local concern. Consider investigating and reporting it." It shows regardless of tier.
3. **PHI gauge**: semicircle with 5 coloured segments (tier colours), needle and arc animating from 0 to the PHI (1.2 s, easeOutCubic). The number counts up at the same time. "91 / 100 PHI".
4. Tier badge (PROTECT, with a shield icon), **category name** ("Pollinator Paradise"), recommendation text.
5. "Why this score?" card: `explainScore()`.
6. Four parameter cards (2×2 grid on a phone): icon, name, **weight (30% / 30% / 20% / 20%)**, score "/ 100" (1 decimal max, e.g. 86.7), label chip (`activityLabel`, `habitatLabel`, `environmentLabel`, `riskLabel`), detail lines (e.g. "18 pollinator visits in 5 minutes", "Flowers: High · Nesting: Medium…", "29°C | 61% humidity | 610 ppm CO₂", "Risk level: Low"), an animated progress bar, and a footnote ("Score based on number of visits" and so on).
7. "How PHI is calculated" expandable: shows the actual numbers, e.g. `(90 × 0.30) + (85 × 0.30) + (100 × 0.20) + (90 × 0.20) = 90.5 → 91`.
8. PHI Trend (last 3–6 assessments for this location, fl_chart line with area fill).
9. "What to do next?": `nextSteps()` with check icons.
10. "Record an action taken" button → bottom sheet (date + note) → `addActionTaken`. The list of actions is shown below.
11. Buttons: Download Report (v1: show "Coming soon" snackbar), View Location Details.

## 6. Scoring rules (implemented in `lib/core/phi.dart`)

- Activity = (visits per 5 min ÷ 20) × 100, capped at 100. Visits are normalised by duration.
- Habitat = average of Flowers, Nesting, Shelter (Low 25 / Medium 60 / High 90) and Water (Present 100 / Absent 0).
- Temperature: 18–30 → 100. 15 ≤ T < 18 or 30 < T ≤ 34 → 60. Otherwise 20.
- Humidity: 50–70 → 100. 35 ≤ H < 50 or 70 < H ≤ 85 → 60. Otherwise 20.
- CO₂: < 800 → 100. 800–1000 → 60. > 1000 → 20.
- Environmental = average of the three.
- Risk: user-selected Low 90 / Moderate 50 / High 10.
- PHI = A×0.30 + H×0.30 + E×0.20 + R×0.20, **rounded half up**. The tier comes from the rounded PHI: 80–100 PROTECT, 60–79 ENHANCE, 40–59 IMPROVE, 20–39 RESTORE, 0–19 INVESTIGATE.
- With real inputs the PHI can only range from 12 to 96.
- These are prototype ranges, not universal biological thresholds. Say so on the About PHI screen.

Tier colours: PROTECT #2E7D32, ENHANCE #7CB342, IMPROVE #F9A825, RESTORE #EF6C00, INVESTIGATE #C62828.

## 7. Data contract (for the backend developer)

Models are in `lib/models/models.dart`. The JSON field names there **are** the contract: `AppUser`, `Location`, `Assessment` (with nested `riskIndicators`, `result`, `actionsTaken`), `Post`, `ConcernReport`. Enums are sent as their names (`"low"`, `"present"`, `"submitted"`, `"protect"`). Dates are ISO-8601 strings.

The service interface is in `lib/data/api_service.dart` (`ApiService`). The backend developer implements `HttpApiService implements ApiService` and swaps it in `main.dart`. Notes for him:
- Store `result.version` (`proto-1`) with each assessment, so old PHIs stay reproducible after the ranges change.
- The server should recalculate the PHI from inputs on submit and never trust a client-sent score. `phi.dart` is the reference implementation.
- Photo paths are local file paths today. With a backend, upload them and store URLs.
- `MockApiService` keeps passwords locally for the demo only. Real auth must be proper (hashed passwords or a managed auth provider).

## 8. Packages

```
go_router, provider, google_fonts, flutter_animate, fl_chart,
image_picker, geolocator, shared_preferences, intl
```
Dev: `flutter_test` (built in), `flutter_launcher_icons` (optional, for the app icon).

## 9. Feel and polish checklist

- Every tappable card gives press feedback (scale 0.97, 120 ms) plus `HapticFeedback.selectionClick()` on selections.
- Lists animate in with a stagger (`flutter_animate`, fade + slideY 0.1, 40 ms interval).
- Loading states use a skeleton shimmer or a small leaf spinner, never a blank screen.
- Empty states have an illustration, one line of text and an action button.
- Keyboard: numeric keyboards for numbers, "Next" moves between fields, and tapping outside dismisses.
- Use SafeArea everywhere. No overflow at 360 px width or with large system fonts (test text scale 1.3).
- Pull-to-refresh on Home, Locations, Community.
- Android back button behaves correctly in the stepper (goes to the previous step first).
- App name "P.U.L.S.E.", package `com.pulse.app`, a green launcher icon with a bee.
