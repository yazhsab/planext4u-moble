# Planext4u design system

Canonical design tokens, accessible themes and role-neutral Flutter widgets for
the customer, vendor and rider applications.

## Public API

Import the package barrel:

```dart
import 'package:planext4u_design_system/planext4u_design_system.dart';
```

It exposes generated colour, spacing, radius, motion, breakpoint and typography
tokens; light and dark Material 3 themes; shared buttons, fields, status pills,
cards and application-state panels; and `Planext4uWidgetCatalogue` for visual
review. Status never relies on colour alone and interactive controls have a
minimum 48 x 48 logical-pixel target.

## Token workflow

Edit `tokens/design_tokens.json`, then regenerate the Dart authority from the
workspace root:

```sh
dart run packages/design_system/tool/generate_tokens.dart
```

Do not edit `lib/src/generated_tokens.dart` by hand. The root verification gate
runs the generator with `--check` and fails when generated output is stale.

## Verification

Run all package tests through the workspace so package font assets are loaded:

```sh
dart run melos run verify
```

The committed goldens cover phone/tablet, light/dark and text scales 1.0/1.3.
Only regenerate them after intentional visual review:

```sh
cd packages/design_system
flutter test --update-goldens test/planext4u_design_system_golden_test.dart
flutter test test/planext4u_design_system_golden_test.dart
```

The catalogue uses synthetic English and long-form Tamil content. Bundled fonts
are covered by their adjacent Open Font License files.
