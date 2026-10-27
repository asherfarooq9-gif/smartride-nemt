# Plan: iOS-style UI for the SmartRide patient app (round 1)

## Context
The patient home screen looks plain and has real defects: a clipped square behind the Emergency button, about 250px of dead space in the bottom sheet, busy map tiles, pure-black shadows, a thin outlined "Book a Ride" button, and three floating white controls on the map. The user wants an Apple-HIG feel (frosted glass, draggable sheet, grouped lists, large title, spring motion) with no Apple branding, and no paid services.

Design review result (apple-hig-expert contrast checks, ui-ux-pro-max healthcare palette, impeccable, design-taste-frontend, flutter-fix-layout-issues): **keep the colour scheme.** Teal `#0B7777` (patient) and blue `#0B5980` (driver) pass contrast and tell the portals apart. Fix the neutrals, shadows, shapes and layout instead.

## Decisions (confirmed with the user)
- **Map:** keep public OpenStreetMap tiles (no paid provider). Make it look pale with a free `ColorFiltered` tile builder. The OSM usage-policy risk stays and is noted as a pre-scale item.
- **Dark mode:** redo in the same round (iOS-style black and elevated grays).
- **Scope:** first round is design tokens, theme, patient home screen and its navigation. Other screens inherit the new tokens and theme. A second round can roll the style out screen by screen (Book a Ride, My Rides, Profile, Settings, tracking, driver portal). The user did not pick a wider scope, so I assume the recommended one.
- **Font:** keep DM Sans (already distinctive; Inter is the generic default the taste skill warns about).
- **Colours (HIG-checked):** page `#F2F2F7`, card `#FFFFFF`, text `#1C1C1E`, secondary text `#6C6C70` (5.23:1), emergency base `#C62828` (5.62:1), pale teal selected tint `#D8F0F0` (4.5:1). Do not use iOS red `#FF3B30`, gray `#8E8E93`, blue `#007AFF` (all fail 4.5:1).

## Architecture
- **Tokens first** in `packages/smartride_core/lib/src/theme/design_tokens.dart`. Add: radius scale 12 / 20 / 28, hue-tinted shadows (no `Colors.black*`), iOS-style light and dark surfaces. Keep all existing token names so other screens do not break. `kEmergencyButtonShadow` is shared, so grep consumers before changing it.
- **Theme** in `app_theme.dart`: `surfaceTint` transparent, `scrolledUnderElevation` 0, `pageTransitionsTheme` Cupertino on Android for swipe-back, NavigationBar, AppBar and button themes aligned to the new radii. Do not touch the dark AppBar coupling beyond what the tokens need.
- **New shared widgets** in `apps/patient_app/lib/shared/`: `GlassSurface` (BackdropFilter blur with a solid fallback when `MediaQuery.disableAnimations` is on, and a `blur: false` switch). Use on at most two surfaces (top bar and tab bar) because the reference phone (Samsung A07) is low-end.
- **Reuse:** `shared/role_switcher.dart` for the role switch, `portal_drawer`, `activeRideProvider`, `notificationsProvider('patient')`, `url_launcher` for Call 1122, existing `_PulseRing` and reduce-motion handling in `home_screen.dart`, auth-light pattern from `test/features/auth/auth_screens_light_test.dart`.
- **No new paid dependency.** `cupertino_icons` (free) may be added if CupertinoIcons are wanted.
- Record the decision in an ADR under `docs/adr/` ("iOS-style design language, keep teal").

## Tasks (vertical slices, test first, one commit each)
Per the user's repo rules: branch off the current branch, conventional commits, no AI attribution lines, `flutter analyze` and `flutter test` clean before each commit.

### Phase 1: Foundation
- **T1 Tokens.** Add radius scale, tinted shadows and iOS light and dark surfaces. Test: `smartride_core/test/design_tokens_test.dart` asserts every text-on-surface pair is at least 4.5:1 (light and dark) using a small contrast helper. Files: `design_tokens.dart`, new test. Scope S.
- **T2 Theme.** Surface tint off, Cupertino transitions, nav/app bar/button themes use the new radii. Test: `app_theme_test.dart` (page transitions, tint, nav indicator, radii). Files: `app_theme.dart`, test. Scope S.
- **Checkpoint:** analyze, all core and app tests, run the app and confirm every screen still renders (light and dark).

### Phase 2: Home screen
- **T3 Emergency button.** Find and fix the square artifact (pulse ring or shadow layer, to confirm in the running app), flat `#C62828` base with a tinted circular glow, haptic on tap, keep the pulse and reduce-motion path. Test: widget test for semantics label, tap navigates to `/symptoms`, no ring when animations are disabled. File: `home_screen.dart`. Scope S.
- **T4 Pale map.** `ColorFiltered` tile builder (desaturate and lighten), proper User-Agent kept, optional "you are here" dot if `core/location.dart` already exposes a position (else skip). Test: map widget has the filter. Files: `home_screen.dart`, small `pale_map_tiles.dart`. Scope S.
- **T5 GlassSurface widget.** Blur with solid fallback and a high-contrast-safe border. Test: renders a BackdropFilter normally and a solid fill when animations are disabled. File: new `shared/glass_surface.dart`. Scope S.
- **T6 Top bar.** One glass bar: large greeting title, notification bell, segmented Patient | Driver control replacing the dropdown chip (reuse `role_switcher.dart`). Tests: role switch still works, bell badge still shows. Files: `home_screen.dart`, `role_switcher.dart`. Scope M.
- **Checkpoint:** run in the phone-sized Chrome window and on the real phone; check blur performance on the A07.
- **T7 Draggable sheet.** `DraggableScrollableSheet` (peek, half, full) with a grabber, large title, active-ride banner, tinted filled "Book a Ride" button, grouped quick-actions list (Saved places, Last trip, Call 1122 via `url_launcher`). Tests: sheet renders at default size, quick actions navigate, no overflow at 1.3x text scale and 320px width. Files: `home_screen.dart`, split into `home_sheet.dart` to keep files under 800 lines. Scope M.
- **T8 Bottom bar.** Glass `NavigationBar` for the home screen only, grouped-list-style selected pill, 44px+ targets. Test: three tabs navigate. File: `home_screen.dart`. Scope S.

### Phase 3: Dark mode and polish
- **T9 iOS dark.** Retune dark tokens and theme (black background, `#1C1C1E` and `#2C2C2E` cards, brighter teal `#10BEBE`, brighter red). Tests: dark contrast pairs at least 4.5:1, home renders in dark. Files: `design_tokens.dart`, `app_theme.dart`. Scope S.
- **T10 Docs and ADR.** `docs/adr/` entry and a short token table in `docs/`. Scope XS.
- **Checkpoint (final):** `flutter analyze`, `flutter test` for core and app, manual run in light and dark at 320, 412 and 1.3x text scale, screenshots to the user, open the PR.

## Risks
| Risk | Impact | Mitigation |
|---|---|---|
| Blur is slow on low-end Androids | High on the user's A07 | At most two blur surfaces, solid fallback, test on the phone, `blur: false` switch |
| OSM public tiles are for light use only | Medium before launch | Kept by the user's choice for the pilot; recorded in the ADR and audit doc as a pre-scale item |
| Shared token or theme change shifts other screens | Medium | Keep old token names, run all tests, visual check of every screen at the Phase 1 checkpoint |
| `kEmergencyButtonShadow` used elsewhere | Low | Grep consumers before editing |
| `home_screen.dart` already 548 lines | Low | Split sheet and top bar into new files |
| HomeScreen has no tests today | Medium | Add the test scaffold in T3 (router stub, provider overrides, fake notifications, handle FlutterMap tiles) |

## Open questions
- Wider scope for round 2 (all patient screens, then driver) to be decided after round 1.
- Whether to add a pre-scale item to move off public OSM tiles (CARTO, MapTiler or self-hosted).

## Verification (end to end)
1. `cd packages/smartride_core && flutter analyze && flutter test`
2. `cd apps/patient_app && flutter analyze && flutter test` (expect the existing 93 plus new tests, all passing)
3. Start backend and run the app: `flutter run -d web-server --web-port 5000`, open in a 412x860 Chrome app window; check light, dark, 320px wide and 1.3x text scale; confirm sheet drag, Emergency tap, role switch and tabs.
4. On the real phone (Samsung SM-A075F): confirm smooth drag and scrolling with blur on.
5. Contrast: run the HIG checker on any new colour pair added outside the token test.
6. Open a PR with screenshots; do not push or merge without the user's go-ahead.

## Housekeeping
- On approval, save this as `tasks/plan-ios-ui.md` and `tasks/todo-ios-ui.md` (do not overwrite the existing `tasks/plan.md` and `tasks/todo.md` from the audit).
