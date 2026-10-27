# ADR 0001: iOS-style design language for the patient app, keeping the teal brand

- Status: accepted (round 1: tokens, theme and the patient home screen)
- Date: 2026-10-27

## Context

The patient home screen looked plain and had real defects: a glow clipped to a
square behind the SOS button, dead space in the bottom sheet, busy map tiles,
black shadows, an outline-only primary action and three floating controls on the
map. The product owner asked for an Apple-like feel (frosted glass, draggable
sheet, grouped lists, large title) without Apple branding, and no paid services.

Colour was reviewed with the HIG contrast checker. Teal `#0B7777` (patient) and
blue `#0B5980` (driver) pass 4.5:1 on white and tell the two portals apart.
Several stock iOS colours do not: `#FF3B30` (3.55:1 with white text), `#8E8E93`
(3.26:1), `#007AFF` (4.02:1) and `#248A3D` (4.4:1).

## Decision

1. **Keep the colour scheme.** Change neutrals, shadows, shapes and layout.
2. **Tokens live in `packages/smartride_core/lib/src/theme/design_tokens.dart`**
   and screens read colours from the theme's colour scheme (`primaryContainer`,
   `onSurfaceVariant`, `surfaceContainerLow`, `outlineVariant`), not from
   light-only constants, so dark mode and the driver portal work.
3. **Shape scale:** 12 for controls, 20 for cards, 28 for sheets.
4. **Shadows are tinted** (`kShadowInk`), never pure black.
5. **Emergency red is reserved** for the SOS button, emergency actions and
   errors. The SOS base is `#C62828` (5.62:1 with white).
6. **Frosted glass (`GlassSurface`) is used on at most two surfaces per screen**
   (top bar and tab bar), with a solid fallback in high-contrast mode, because
   blur is costly on low-end phones such as the Samsung A07.
7. **Keep DM Sans.** It is already distinctive; switching to Inter would be churn.
8. **Pages use Cupertino transitions on every platform** for swipe-back.
9. **Map:** keep the public OpenStreetMap tiles, made pale with a colour matrix.

## Consequences

- Other screens pick up the new neutrals, radii and theme automatically. Screens
  that hard-code `Colors.white` or light constants (the driver dashboard,
  symptom and tracking screens) still need a pass; that is round 2.
- The public OSM tile server is for light use only. Before real scale, move to a
  hosted tile provider or a self-hosted one. This is a known pre-scale item.
- The dark palette moved from teal-tinted to near-black with gray cards. The old
  dark hint gray failed contrast (about 3:1) and is replaced.
- Contrast is enforced by tests (`design_tokens_test.dart`, `app_theme_test.dart`),
  so a token change that fails 4.5:1 fails the build.

## Token summary

| Role | Light | Dark |
|---|---|---|
| Page | `#F2F2F7` | `#0A0A0C` |
| Card | `#FFFFFF` | `#1C1C1E` |
| Raised card / rows | `#F2F2F7` | `#2C2C2E` |
| Primary text | `#1C1C1E` | `#F2F2F7` |
| Secondary text | `#48484A` | `#AEAEB2` |
| Hint text | `#6C6C70` | `#8E8E93` |
| Divider | `#D1D1D6` | `#3A3A3C` |
| Patient accent | `#0B7777` | `#0B7777` (icons), `#10BEBE` (text) |
| Driver accent | `#0B5980` | `#0B5980` |
| Emergency | `#C62828` | `#FF6961` (text on dark) |
