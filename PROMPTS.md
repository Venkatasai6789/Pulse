# Antigravity prompts – paste in this order

Give one prompt per agent task. After each one, run the app on your phone (`flutter run`) and check it before moving on. Prompts marked **[parallel]** can go to separate agents in Agent Manager at the same time, once Prompt 2 is done.

When something looks off, send a screenshot of your phone next to the design image and say exactly what's different. That works much better than long text.

---

## Prompt 1 – Foundation (≈30 min)

> Read SPEC.md fully and look at every image in /designs. The files in lib/core, lib/models, lib/data and lib/theme already exist. Don't rewrite them; build on them.
>
> Do this step only:
> 1. Make sure pubspec.yaml has the packages from SPEC section 8 and registers `assets/images/`.
> 2. Run `flutter test` and fix only compile errors, if any. The test expectations must not change.
> 3. Create `lib/main.dart`: `Provider<ApiService>(create: (_) => MockApiService())`, plus a `ChangeNotifier` AuthState (current user, login, signUp, logout) and `MaterialApp.router` with `AppTheme.light()`.
> 4. Create `lib/router.dart` with go_router: auth routes (splash, welcome, login, signup) and a `StatefulShellRoute.indexedStack` with 5 tabs (Home, Monitor, Locations, Community, Profile) plus routes for results/:id, location/:id, location/new, reports, report-concern, post/new. Redirect to welcome when logged out.
> 5. Create reusable widgets in `lib/widgets/`: `PulseCard`, `PressableScale`, `SectionHeader`, `ScoreChip`, `TierBadge`, `EmptyState`, `LeafLoader`, `PhiGauge` (CustomPainter semicircle, 5 tier segments, animated needle and arc, count-up number; props: phi, size, animate) and `ParameterCard`.
> 6. Placeholder screens with titles so navigation works end to end.
>
> Show me the plan first, then build. Run on Android and confirm there are no errors.

## Prompt 2 – Auth screens (≈20 min)

> Build Splash, Welcome, Login and Sign up as described in SPEC section 3 (A1–A4), in the P.U.L.S.E. style: cream background, forest-green headings in Lora, header_bee.jpg on Welcome, rounded inputs and pill buttons from the theme. Validate fields (email format, password min 6, confirm matches) with inline errors. Show `ApiException` messages in a snackbar. Splash checks `currentUser()` and routes. Add subtle entrance animations with flutter_animate.

## Prompt 3 – Home [parallel] (≈40 min)

> Build the Home tab to match /designs/01_home.jpg, adapted to a 390 px phone as described in SPEC section 3 row 1. Use real data from ApiService (locations, latest assessments, posts) with proper empty states exactly like the design shows when there's no data. The overview gauge uses PhiGauge with the average of the latest PHI per location, and the legend lists all 5 tiers. Add pull-to-refresh and a staggered entrance. Tapping a location goes to location/:id. "Start a New Assessment" goes to the Monitor tab.

## Prompt 4 – New Assessment stepper [parallel] (≈60 min)

> Build the Monitor tab (New Assessment) from /designs/02_new_assessment.jpg as the 4-step stepper plus Review described in SPEC section 4. Keep the design's section look: numbered green circle, icon, light green header strip. Hold the state in an `Assessment` draft object; `assessment.clear(field)` resets a field. Nothing is preselected except duration = 5. Show live Suitable/Moderate/Stressful chips under the environment fields. The Risk Level dropdown is user-selected, with the `suggestedRiskLevel` hint under it. "Save as Draft" calls `saveDraft`. "Calculate PHI" is enabled only when `missingFields` is empty, shows "N fields left" otherwise, calls `submitAssessment`, shows LeafLoader for at least 800 ms, then `context.go('/results/<id>')`. The Android back button goes to the previous step. Accept a `locationId` query parameter to preselect a location.

## Prompt 5 – Results [parallel] (≈50 min)

> Build results/:id to match /designs/04_results.jpg, using the gauge style from /designs/05_phi_gauge.jpg, adapted to a phone in the exact order given in SPEC section 5. Everything comes from the stored assessment and `lib/core/recommendations.dart` (tierInfo, labels, explainScore, nextSteps). Nothing is hard-coded. Include the red High Risk banner when `result.highRiskAlert` is true, the category name under the tier badge, the parameter weights on each card, the expandable "How PHI is calculated" line with the real numbers, the fl_chart trend for this location, and the "Record an action taken" bottom sheet. Animate the gauge and progress bars on first show.

## Prompt 6 – Locations [parallel] (≈40 min)

> Build the Locations tab list, Register Location (/designs/03_register_location.jpg, no map widget; "Use my current location" with geolocator, handling permission denied gracefully) and Location detail as described in SPEC section 3 rows 3, 5 and 6. Photos via image_picker with thumbnails and remove. Add a Hero animation on the location photo from the list to the detail page. The detail page shows the latest PHI gauge, trend chart, history list (tap opens Results), drafts, and "Start new assessment" which opens Monitor with this location preselected.

## Prompt 7 – Community + Report a Concern (≈40 min)

> Build the Community tab from /designs/06_community.jpg, adapted to a phone as described in SPEC section 3 rows 7 and 8: hero banner (community_hero.jpg), filter chips, horizontal Upcoming Events (from posts with category event and a future eventDate), post cards with animated like, the ⋮ menu with Report post (reason dialog, then `reportPost`, then the post disappears with an animation), a Community Initiatives card, a Report a Concern card and form, and a "+ New post" FAB with a create-post form (event fields appear when category = Event).

## Prompt 8 – Reports & Profile (≈30 min)

> Build Reports & Analytics and Profile & Settings as described in SPEC section 3 rows 9 and 10, in the same visual style. Reports: location dropdown, PHI trend line, grouped bar chart of the 4 parameters for the last 3 assessments, and a past-assessments table. Profile: editable name and organisation, links to Reports, an About PHI page (formula, weights, tiers, prototype-ranges note), Privacy & community guidelines, Logout.

## Prompt 9 – Polish pass (≈30 min)

> Go through SPEC section 9 (feel and polish checklist) on every screen and fix what's missing. Then test at 360 px width and text scale 1.3 and fix any overflow. Set the app name to "P.U.L.S.E." and the package to com.pulse.app, and add a launcher icon with flutter_launcher_icons (green background, bee). Run `flutter test` and `flutter analyze` and fix all errors.

## Prompt 10 – Release APK

> Run `flutter build apk --release` and fix any build errors. Tell me the APK path.
