// ============================================================================
//  ENNVO — GOLDEN SCREENSHOTS
//
//  Renders the real screens at a phone size and writes them as PNG files, so
//  the native build can be compared against the production web build.
//
//  Run with:  flutter test --update-goldens
//
//  The comparison is skipped on CI: the goldens are rasterised on Windows and
//  the runners rasterise differently, so a pixel comparison would fail for
//  the wrong reason. The rendering still happens there, so a layout
//  regression is still caught.
// ============================================================================

import 'dart:io';

import 'package:ennvo/core/perf/device_tier.dart';
import 'package:ennvo/core/providers.dart';
import 'package:ennvo/core/storage/app_prefs.dart';
import 'package:ennvo/features/auth/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Pixel-class phone: 1080 x 2340 at a 3x pixel ratio.
const Size _phone = Size(1080, 2340);

bool get _isCI => Platform.environment['CI'] == 'true';

/// Loads the brand fonts, so the goldens show the real typography instead
/// of the test placeholder font.
Future<void> _loadFonts() async {
  const families = {
    'Outfit': [
      'assets/fonts/Outfit-600.ttf',
      'assets/fonts/Outfit-700.ttf',
      'assets/fonts/Outfit-800.ttf',
      'assets/fonts/Outfit-900.ttf',
    ],
    'PlusJakartaSans': [
      'assets/fonts/PlusJakartaSans-600.ttf',
      'assets/fonts/PlusJakartaSans-700.ttf',
      'assets/fonts/PlusJakartaSans-800.ttf',
    ],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

Future<AppPrefs> _buildPrefs({bool dark = false}) async {
  SharedPreferences.setMockInitialValues(
    dark ? {'ennvo_theme_mode': 'dark'} : {'ennvo_theme_mode': 'light'},
  );
  final instance = await SharedPreferences.getInstance();
  return AppPrefs(instance);
}

Widget _harness(AppPrefs prefs, Widget child, {bool dark = false}) {
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWith((ref) => prefs),
      deviceProfileProvider.overrideWithValue(
        profileForTesting(ramBytes: 8 * 1024 * 1024 * 1024, cores: 8),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: child,
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('auth screen', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs();
    await tester.pumpWidget(_harness(prefs, const AuthPage()));
    await tester.pumpAndSettle();

    if (_isCI) return;
    await expectLater(
      find.byType(AuthPage),
      matchesGoldenFile('goldens/auth_light.png'),
    );
  });

  testWidgets('auth screen in dark mode', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs(dark: true);
    await tester.pumpWidget(
      _harness(prefs, const AuthPage(), dark: true),
    );
    await tester.pumpAndSettle();

    if (_isCI) return;
    await expectLater(
      find.byType(AuthPage),
      matchesGoldenFile('goldens/auth_dark.png'),
    );
  });
}
