# Phase 2 accessible design-system implementation

## Canonical foundations

`packages/design_system/tokens/design_tokens.json` is the editable source for
brand colours, the 4 px spacing scale, radii, motion durations, responsive
breakpoints and type families. `tool/generate_tokens.dart` renders the checked-in
`lib/src/generated_tokens.dart`; `dart run melos run verify` rejects stale output.

The light and dark Material 3 themes use:

- Plus Jakarta Sans for display text;
- Inter for body and control text;
- JetBrains Mono with tabular figures for identifiers and monetary values;
- Noto Sans Tamil as the Tamil glyph fallback.

Brand teal remains the primary colour. Navy is its foreground because that pair
has a 4.91:1 contrast ratio; white on the same teal would be 3.49:1 and is not
used for normal button text.

## Shared widget contract

The public package barrel exposes:

- primary, secondary, tertiary and destructive buttons;
- labelled text input with hint, helper and announced error support;
- neutral, information, success, warning and danger status pills with icon and
  semantic text cues;
- section, KPI/metric and commerce-product cards;
- loading, empty, error, offline-stale and permission-denied state panels;
- a responsive catalogue containing only synthetic content.

Controls have at least 48 x 48 logical-pixel targets. Cards retain explicit
borders in both themes, status is not colour-only, errors can be live regions,
and layouts wrap rather than clipping at 130% text.

## A11Y-001 evidence

`planext4u_design_system_test.dart` verifies the minimum interaction target,
semantic status label and icon, every common application state at 130% text,
and Flutter's Android tap-target, labelled-target and text-contrast guidelines
against the visible phone catalogue.

This automated gate complements, but does not replace, the release-candidate
TalkBack, VoiceOver and external-keyboard walkthrough required by the Phase 1
test strategy.

## GOLDEN-001 evidence

Eight committed PNG baselines exercise the catalogue at these combinations:

| Viewport | Theme | Text scale |
| --- | --- | --- |
| 390 x 844 phone | light and dark | 1.0 and 1.3 |
| 768 x 1024 tablet | light and dark | 1.0 and 1.3 |

Each baseline includes English plus a long Tamil fixture. Tests load the exact
bundled typefaces and Material Icons, preventing Flutter's block-shaped test
font from becoming an accidental approved baseline.

Run from `packages/design_system`:

```sh
flutter test test/planext4u_design_system_test.dart
flutter test test/planext4u_design_system_golden_test.dart
```

## Bundled font provenance

All font directories contain their upstream Open Font License text.

| Font asset | SHA-256 |
| --- | --- |
| `PlusJakartaSans-wght.ttf` | `89b3fb38aa0d275d7a731d0d817a4f1622b316b4d7fbdedcf02ee9099ff68bc8` |
| `Inter-opsz-wght.ttf` | `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031` |
| `JetBrainsMono-wght.ttf` | `48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda` |
| `NotoSansTamil-wdth-wght.ttf` | `aa3a9b321f4b0bb2c40203ffbde9af89713227866e0e13f76e5b9eeea727cf88` |
