# P.U.L.S.E. — UI Audit (Nov 2026 build)

Source: 31 Android screenshots (412 dp-class phone, 47–48 % battery, demo account). Each finding has an ID that maps to `PHASE_5_UI_AUDIT_FIXES.md`. P0 = wrong data or broken visuals, P1 = inconsistency, P2 = polish.

## Overall impression

The base is strong. The cream and forest palette, Lora headings and Inter data give the app a calm, credible look, and the card rhythm is consistent. What lets it down is a set of small inconsistencies that together make it feel unfinished: three different status vocabularies, colours that don't carry meaning (red bars for good scores, blue and purple accents outside the palette), two data disagreements between tabs, and some truncated labels. Fixing these will do more for "professional" than any redesign.

## Screen by screen

### Sign-in
- The hero photo is visibly low resolution (bee wing edges are blocky). → **F24**
- The value carousel shows a title but no page indicator, although the README specifies dots. → **F25**
- Good: the logo badge overlapping the photo edge, the clear primary action, and the quiet demo link.

### Home
- The delta row renders two arrows: `▴ ▲ 19 since last assessment`. → **F05**
- The summary caption truncates: "Average across your latest assessme… View reports →". → **F23**
- The CTA says "4 quick steps" while the stepper shows 4 steps plus Review. → **F06**
- The Four Parameters card uses Low / Moderate, while Results uses Critical / Fair / Ideal for the same scores. → **F08**
- Parameter icons use four unrelated colours (orange, orange, blue, red). → **F28**
- Location card photos look soft or pixelated. → **F24**
- The event title truncates ("Pollinator Garden Works…"). → **F26**
- New (Phase 4): a sensor button in the header and the Field sensor card under the summary.

### Monitor: New Assessment (all steps)
- The header block (title, subtitle, faded bee photo), the location card and the step indicator use about 38 % of the screen before the first input, and the photo sits behind the subtitle text. → **F13**
- The location name truncates ("Community Gard…") because the tier chip shares its line. The chip also has no score. → **F15**
- The active step label truncates ("Environme…"). → **F14**
- Step 1: the visits counter shows "—" with an awkward hint. → **F17**. The selected duration chip's check mark is dark on dark. → **F16**
- Step 2: the Habitat score shows 77.5, while Review shows 78 for the same value. → **F04**
- Step 3: CO₂ 80 ppm is accepted as Suitable with no hint (outdoor air is about 420 ppm). → **F27**. The section "Sensor & Ambient Readings" is the natural home for the soil panel (Phase 4).
- Step 4: clean. The suggestion "Based on your selections we suggest: Low · Apply" works well.
- Review: "Environ." is abbreviated in the score strip → **F18**. Risk shows "LOW" in caps → **F19**. A sparkle sits on the ENHANCE badge → **F11**.

### Results
- The gauge needle crosses the "/100" next to the score. → **F03**
- The status bar icons are white on cream and almost invisible (also on Locations, Community and Profile). → **F02**
- The app bar turns grey-green on scroll. → **F12**
- Potential Risk 90 ("Low Risk") draws a red bar, and Environmental draws a blue bar. → **F09**
- The AI insights card is purple (icon, chip, button) and has two headings ("AI insights" and "AI Ecological Insights"). → **F10**
- The trend chart repeats "14 Nov" and clips the last label. → **F07**
- The footer buttons have unequal widths, and "New assessment" is cramped. → **F20**
- Calculation check: 15×0.30 + 77.5×0.30 + 100×0.20 + 90×0.20 = 65.75 → 66 ENHANCE. Correct.

### Record an action (sheet)
- Clean. No change.

### Locations
- **Data mismatch:** the list shows 2 sites (Home and the picker show 3). Community Garden is shown as PROTECT (latest is 66 ENHANCE), and Janvi's House as "No data yet" (it has 39 RESTORE). → **F01 (P0)**
- The cards show only a tier chip, with no score or date, and a lot of empty space. → **F21**

### Community
- Clean. The concern card reads well in the alert palette. The status bar issue applies here too (F02).

### Profile & Settings
- The Gemini card exposes developer details: model IDs, RPD limits, "Save to SQLite", "Stored locally in mobile SQLite database". → **F22**
- The header card shows the role but not the organisation. → **F29**
- The app bar tint changes on scroll. → **F12**
- New (Phase 4): the Field sensor card above the Gemini card.

## Summary table

| ID | Screen | Priority | One-line fix |
|---|---|---|---|
| F01 | Locations | P0 | Same data source as Home; update latestPhi in the submit batch; show every location |
| F02 | Results/Locations/Community/Profile | P0 | Dark status bar icons globally |
| F03 | Results | P0 | Score text below the needle pivot |
| F04 | Step 2 / Review / Results | P0 | One sub-score formatter |
| F05 | Home | P0 | Single delta arrow |
| F06 | Home | P0 | "4 steps and a review" |
| F07 | Results | P0 | De-duplicate and pad trend axis labels |
| F08 | Home / Results | P1 | One status vocabulary |
| F09 | Results / Home | P1 | Bars use the tier colour for their score |
| F10 | Results | P1 | Insights card in the brand palette, one heading |
| F11 | Review / Results | P1 | No sparkle on tier badges |
| F12 | Results / Profile | P1 | No scroll tint on app bars |
| F13 | Monitor | P1 | Collapsing header, pinned location + steps, image masked |
| F14 | Monitor | P1 | Step labels never truncate |
| F15 | Monitor | P1 | Tier chip moves to the address line, with the score |
| F16 | Monitor | P1 | Visible check on selected chips |
| F17 | Monitor | P1 | Counter placeholder and hint copy |
| F18 | Review | P1 | Full "Environment" label |
| F19 | Review | P1 | Sentence case "Low" |
| F20 | Results | P1 | Equal footer buttons |
| F21 | Locations | P1 | Score chip + last assessed date |
| F22 | Profile | P1 | Plain copy; technical details collapsed |
| F23 | Home | P2 | Caption wraps; separate "View reports" |
| F24 | Sign-in / Home | P2 | Higher-resolution images |
| F25 | Sign-in | P2 | Carousel dots |
| F26 | Home | P2 | Event title on 2 lines |
| F27 | Step 3 | P2 | Soft CO₂ plausibility hint |
| F28 | Home / Steps / Results | P2 | Unified icon treatment |
| F29 | Profile | P2 | Show the organisation |
