import 'package:flutter/material.dart';

export 'generated_tokens.dart';

import 'generated_tokens.dart';

/// Text styles that are semantic rather than tied to a screen.
abstract final class Planext4uTextStyles {
  static const identifier = TextStyle(
    fontFamily: Planext4uTypography.identifierFamily,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
