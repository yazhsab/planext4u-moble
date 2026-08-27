import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    _loadFont(
      'Plus Jakarta Sans',
      'packages/planext4u_design_system/assets/fonts/plus_jakarta_sans/PlusJakartaSans-wght.ttf',
    ),
    _loadFont(
      'Inter',
      'packages/planext4u_design_system/assets/fonts/inter/Inter-opsz-wght.ttf',
    ),
    _loadFont(
      'JetBrains Mono',
      'packages/planext4u_design_system/assets/fonts/jetbrains_mono/JetBrainsMono-wght.ttf',
    ),
    _loadFont(
      'Noto Sans Tamil',
      'packages/planext4u_design_system/assets/fonts/noto_sans_tamil/NotoSansTamil-wdth-wght.ttf',
    ),
  ]);
  await testMain();
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}
