# Phase 5 — Fixes to Existing Screens (from the screenshot audit)

Scope: only the items listed here. Each fix has an ID that matches `docs/UI_AUDIT.md`. Make one commit per ID (or per small group), with the ID in the commit message, so any fix can be reverted on its own.

Rules for this phase:
- Fix the defect, not the surrounding screen. No layout redesigns beyond what's written.
- If an existing test asserts the buggy behaviour (for example a duplicate arrow), name the test, explain why, and update only that assertion.
- Take before/after screenshots for every ID, at 360 dp and 412 dp.

Priority: **P0** = wrong data or broken visuals (must do). **P1** = consistency that makes the app look unfinished (must do). **P2** = polish (do it if it's small and safe; otherwise list it as skipped with a reason).

---

## P0: correctness

**F01 · The Locations tab shows wrong and missing data** *(Locations screen vs Home vs Monitor picker)*
Observed: Home says 3 locations, and the Monitor picker lists Community Garden (IMPROVE), Janvi's House (RESTORE) and Medhaansh's House (No PHI). The Locations tab lists only **2**: Community Garden as **PROTECT** (its latest is 66 ENHANCE) and Janvi's House as **"No data yet"** (it has 39 RESTORE). Medhaansh's House is missing.
Do:
1. Find the data source for each screen. The Locations list is probably reading a cached or old `latestPhi`, or a different query or filter.
2. Make the Locations list use the **same repository call** as Home and the picker.
3. Check that the assessment submit `WriteBatch` updates `locations/{id}.latestPhi`, `latestTier` and `lastAssessedAt` in the same batch. If it doesn't, add those fields to the batch (keeping it atomic). For older locations where the field is missing, derive the value from the newest submitted assessment at read time.
4. Find why Medhaansh's House is filtered out (a null photo, a null PHI, an owner filter?). Show every location the user owns. "No PHI yet" is a valid state.
5. Add a test: after submitting an assessment, the Locations list, the Home "Your Locations" reel and the picker all show the same PHI and tier for that location.

**F02 · Status bar icons are invisible on several screens**
Observed: on Results, Locations, Community and Profile, the status bar icons (time, battery, signal) are white on the cream background and nearly unreadable. They're correct on Home and Monitor.
Do: set `systemOverlayStyle: SystemUiOverlayStyle.dark` (dark icons, transparent status bar) in the global `AppBarTheme`. For screens without an AppBar, wrap the scaffold in `AnnotatedRegion<SystemUiOverlayStyle>`. Keep light icons only on the Splash and Sign-in hero, where the background is dark or a photo.

**F03 · The Results gauge needle overlaps the score**
Observed: the needle crosses the "/100" next to "66".
Do: move the score text block below the needle pivot. The number sits centred under the arc's baseline, with "/100" on the same line in muted 16 sp. Alternatively, shorten the needle to 70 % of the radius and add a cream disc behind the number. The needle must never cross text at any value from 0 to 100. Add a golden test at values 5, 50 and 95.

**F04 · The same sub-score is displayed with different rounding**
Observed: Habitat is 77.5 on Step 2 and on Results, but **78** on the Review score strip.
Do: use `formatSubScore` (Phase 2) for every sub-score label: Step 2 Habitat score, Step 3 Environmental score, the Review mini strip, the Results parameter cards, and the Home Four Parameters list. The PHI total stays an integer.

**F05 · Home shows a duplicated delta arrow**
Observed: the PHI summary reads `▴ ▲ 19 since last assessment` (two arrow glyphs).
Do: keep one arrow icon (`Icons.arrow_upward_rounded` / `downward`, 14 dp, in the leaf or alert colour) followed by the text. Show "No change since last assessment" for 0 and a neutral dash when there's no previous assessment.

**F06 · Step count in the Home CTA is wrong**
Observed: "Takes about 5 minutes · 4 quick steps", but the stepper has 4 input steps plus Review.
Do: change the copy to "About 5 minutes · 4 steps and a review".

**F07 · The trend chart x-axis repeats a label and clips the last one**
Observed: "14 Nov" appears twice (two assessments on the same day), and the last label is cut off at the right edge.
Do: reserve right padding (`maxX` padding, or `rightTitles` with 16 dp reserved size). Show a label only when the date differs from the previous point's. For same-day points, show the time ("7:41 PM") in the tooltip, not on the axis. With more than 6 points, show at most 5 evenly spaced labels.

---

## P1: consistency

**F08 · Status words differ between Home and Results**
Observed: Home uses Low / Moderate. Results uses Critical / Fair / Ideal / Low Risk for similar values.
Do: add one helper, `scoreBand(double)`, in `lib/core/score_format.dart`: ≥ 80 **Good**, 60–79 **Fair**, 40–59 **Moderate**, 20–39 **Low**, < 20 **Critical**. Use it for Activity, Habitat and Environmental on both Home and Results. Risk keeps its own words: Low risk / Moderate risk / High risk. Each chip's colour is the PHI tier colour for that band.

**F09 · Progress bar colours don't mean anything**
Observed: Potential Risk at 90 ("Low Risk", which is good) draws a **red** bar. Environmental draws a **blue** bar, which isn't in the palette. Home's bars are orange or green.
Do: every sub-score bar uses the tier colour for its score (the same 5-tier colours as the gauge). The track is `sage`. No blue anywhere.

**F10 · The AI insights card uses an off-brand purple and repeats its title**
Observed: purple sparkle icon, purple "ADVISORY ONLY" chip, purple "Generate insights" button, and two headings ("AI insights" and "AI Ecological Insights").
Do: use the forest icon `Icons.lightbulb_outline_rounded` on a sage circle. The title is "Ecological insights" (Lora 18). The chip is "Advisory" with a sage background and forest text. The button is the standard forestDark stadium. Remove the second heading and keep the one-line disclaimer under the title in muted 13 sp (not italic). Keep the footer "AI-generated · may be inaccurate · model: …" in 12 sp muted. Tip bullets use a forest `lightbulb` icon, not purple.

**F11 · Sparkle icons on tier badges**
Observed: "✦ ENHANCE" badges on the Review live preview and on Results.
Do: remove the sparkle and match Home's plain tier badge (tier colour at 15 % opacity as the background, tier colour text, 12 dp radius, uppercase Inter 12 w700, letter spacing 0.6).

**F12 · App bars change colour on scroll**
Observed: on Results and Profile, the app bar turns grey-green when the content scrolls under it (Material 3 surface tint).
Do: in the global `AppBarTheme`, set `backgroundColor: AppColors.cream`, `surfaceTintColor: Colors.transparent`, and `scrolledUnderElevation: 0`. Show a 1 px sageBorder bottom divider only when scrolled (`notificationPredicate`).

**F13 · The Monitor header uses too much height, and the bee image collides with the subtitle**
Observed: the title, subtitle, faded bee photo, location card and step indicator take about 38 % of the screen before any input. The photo sits behind the word "surroundings".
Do:
- Convert the top area into a `CustomScrollView` / `NestedScrollView` header. The title block collapses on scroll, and the **location card + step indicator stay pinned**, compacted to 56 dp location row + 64 dp steps.
- Constrain the bee image to the right 35 % of the header, with a left-to-right fade mask (`ShaderMask`) so it never sits under text. Hide it below 380 dp width.
- The subtitle stays on a single line at 360 dp ("Record what you see at this site"). Shorter copy is allowed.

**F14 · The active step label truncates**
Observed: "Environme…" when the Environment step is active (bold makes it wider).
Do: wrap each step label in `FittedBox(fit: BoxFit.scaleDown)` with a fixed width per tab, and indicate the active step with colour and the filled icon instead of a weight change.

**F15 · The location name truncates in the picker card**
Observed: "Community Gard…" because the tier chip sits on the same line.
Do: move the tier chip to the address line (`Alwarpet, Chennai · [58 · IMPROVE]`) and let the name use the full width, wrapping to 2 lines max. Show the score in the chip, the same as the Home location cards.

**F16 · The check icon is invisible on the selected duration chip**
Observed: the "5 min" selected chip has a dark check on the dark fill.
Do: set `checkmarkColor: Colors.white` on the selected `ChoiceChip`, or drop the check and rely on the fill. Apply this to every selected chip of this style (duration, weather).

**F17 · The visits counter shows a dash and the hint is awkward**
Observed: the counter shows "—", with the hint 'Tap + or tap "—" to type a number'.
Do: keep a blank initial state (the field is required, so 0 must be a deliberate entry), but show a muted placeholder `0` in the counter. The hint becomes "Use + and −, or tap the number to type it". Long-press auto-repeat stays as it is.

**F18 · Abbreviated label on the Review strip**
Observed: "Environ." in the mini score strip.
Do: show "Environment" using `FittedBox(scaleDown)`. If it still doesn't fit at 360 dp, use two lines.

**F19 · Shouting case on Review**
Observed: Risk Level is "LOW" in caps, while every other value is sentence case.
Do: "Low". Caps are kept only for tier badges.

**F20 · Unequal Results footer buttons**
Observed: "View location" and "New assessment" have different widths, and "New assessment" crowds its edges.
Do: a `Row` of two `Expanded` children with 12 dp between them, the same 52 dp height, and labels `FittedBox(scaleDown)`. "Record an action taken" stays full width above them.

**F21 · Locations cards are missing their data**
Observed: each card shows only a tier chip, leaving a large empty area. The README says the card should show the score and the last assessed date.
Do: the chip shows `66 · ENHANCE` (the same component as Home), and the right side of the second line shows the last assessed date in muted text ("Today", "3 days ago", "14 Nov"). The empty state stays as it is. After Phase 4, the sensor glyph appears after the name when a node is linked.

**F22 · Developer details exposed on Profile**
Observed: the Gemini card lists model IDs, RPD limits and "SQLite". The save button reads "Save to SQLite". The subtitle reads "Stored locally in mobile SQLite database".
Do: subtitle "Stored on this device only". Button "Save key". Move the model list, RPD, fallback order and quota-reset text into a collapsed `ExpansionTile` titled "Technical details". Behaviour doesn't change.

---

## P2: polish

**F23 · Truncated caption on Home:** "Average across your latest assessme… View reports →". Put "View reports" as a separate right-aligned text button on its own row, and let the caption wrap.
**F24 · Low-resolution images:** the sign-in bee hero and the location card photos look pixelated. Use hero assets at least 1080 px wide, set `cacheWidth` to the display size × device pixel ratio, and use `FilterQuality.medium`. Location thumbnails come from the 480 px base64 thumbnails, so render them no larger than 480 px physical and use the full image where one exists.
**F25 · The sign-in carousel shows no page indicator:** the README specifies dots. Add 3 dots (6 dp, active 18 dp pill in forest, inactive sageBorder) under the carousel title.
**F26 · The Home event title truncates** ("Pollinator Garden Works…"): allow 2 lines.
**F27 · Implausible CO₂ is accepted silently:** 80 ppm scores as Suitable, but outdoor air is about 420 ppm. Keep the scoring unchanged and add a soft honey hint under the field when the value is under 300: "Outdoor air is usually around 400 ppm. Check the reading." Don't block submission.
**F28 · Multicolour parameter icons** (orange bug, pink flower, blue thermometer, red triangle) on Home, the Step headers and Results. Unify them: icon in forest on a sage circle, and keep the risk triangle in alert only inside the high-risk banner. Skip this if the Walkthrough shows it affects more than the icon widgets.
**F29 · Profile header card:** it shows the Role but not the Organisation, although the profile has one. Add the organisation line in muted text when it's set.

---

## Done when

- All P0 and P1 items are fixed, with before/after screenshots.
- P2 items are fixed or listed as skipped with a reason.
- F01 and F03 have tests (the data consistency test and the gauge goldens).
- `flutter test` is green. Any changed assertions are listed with the fix ID that justifies them.
