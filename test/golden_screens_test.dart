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
import 'package:ennvo/core/theme/app_theme.dart';
import 'package:ennvo/features/auth/auth_page.dart';
import 'package:ennvo/features/create/camera_page.dart';
import 'package:ennvo/features/messages/messages_page.dart';
import 'package:ennvo/features/reels/models/reel_comment.dart';
import 'package:ennvo/features/reels/reels_page.dart';
import 'package:ennvo/features/reels/widgets/comments_sheet.dart';
import 'package:ennvo/features/reels/widgets/share_sheet.dart';
import 'package:ennvo/features/shell/app_shell.dart';
import 'package:ennvo/shared/widgets/brand_splash.dart';
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

/// Loads the pictures of the app into the picture cache.
///
/// The loading of an asset is real file reading, and a widget test only
/// lets it happen inside `runAsync`. Without this the pictures are simply
/// not on the screen of the golden.
Future<void> _precacheAssets(
  WidgetTester tester,
  List<String> names,
) async {
  await tester.runAsync(() async {
    for (final name in names) {
      try {
        await precacheImage(AssetImage(name), tester.binding.rootElement!);
      } catch (_) {
        // A missing picture must not fail the render.
      }
    }
  });
  await tester.pump(const Duration(milliseconds: 200));
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
      // The real app theme, so the goldens show the shipped appearance.
      theme: EnnvoTheme.light(),
      darkTheme: EnnvoTheme.dark(),
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
    await _precacheAssets(tester, const [
      'assets/brand/ennvo_logo.png',
    ]);

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

  testWidgets('reels screen', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs();
    await tester.pumpWidget(_harness(prefs, const ReelsPage()));
    // Let the welcome card time out so the golden shows the feed itself.
    await tester.pump(const Duration(milliseconds: 5000));
    await _precacheAssets(tester, const [
      'assets/demo/reels/r1.jpg',
      'assets/demo/reels/r2.jpg',
    ]);

    if (_isCI) return;
    await expectLater(
      find.byType(ReelsPage),
      matchesGoldenFile('goldens/reels.png'),
    );
  });

  testWidgets('messages screen', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs();
    await tester.pumpWidget(_harness(prefs, const MessagesPage()));
    await tester.pump(const Duration(milliseconds: 600));

    if (_isCI) return;
    await expectLater(
      find.byType(MessagesPage),
      matchesGoldenFile('goldens/messages.png'),
    );
  });

  testWidgets('the comment sheet', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs();
    await tester.pumpWidget(
      _harness(
        prefs,
        Scaffold(
          backgroundColor: Colors.black,
          body: ReelCommentsSheet(
            comments: demoComments('demo'),
            onSubmit: (text, replyTo) async {},
            onToggleLike: (comment) {},
            onDelete: (comment) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    if (_isCI) return;
    await expectLater(
      find.byType(ReelCommentsSheet),
      matchesGoldenFile('goldens/comments_sheet.png'),
    );
  });

  testWidgets('the share sheet', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs();
    await tester.pumpWidget(
      _harness(
        prefs,
        Scaffold(
          backgroundColor: Colors.black,
          body: ReelShareSheet(
            targets: const [
              ShareTarget(id: '1', name: 'Arif Hasan', isOnline: true),
              ShareTarget(id: '2', name: 'Tania Akter'),
              ShareTarget(id: '3', name: 'Rafi Ahmed', isOnline: true),
              ShareTarget(id: '4', name: 'Mim'),
              ShareTarget(id: '5', name: 'Nila Rahman'),
            ],
            onSend: (selected) async {},
            onRepost: () {},
            onSave: () {},
            onCopyLink: () async {},
            onAddStory: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    if (_isCI) return;
    await expectLater(
      find.byType(ReelShareSheet),
      matchesGoldenFile('goldens/share_sheet.png'),
    );
  });

  testWidgets('the app shell on the reels feed', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs();
    await tester.pumpWidget(_harness(prefs, const AppShell()));
    // Let the feed settle so the picture itself is visible.
    await tester.pump(const Duration(milliseconds: 5000));

    if (_isCI) return;
    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('goldens/shell_reels.png'),
    );
  });

  testWidgets('the splash screen', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs();
    await tester.pumpWidget(
      _harness(
        prefs,
        const Scaffold(
          backgroundColor: kEnnvoPurple,
          body: EnnvoSplash(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _precacheAssets(tester, const [
      'assets/brand/ennvo_logo_on_black.png',
    ]);

    if (_isCI) return;
    await expectLater(
      find.byType(EnnvoSplash),
      matchesGoldenFile('goldens/splash.png'),
    );
  });

  testWidgets('the comment sheet in dark mode', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs(dark: true);
    await tester.pumpWidget(
      _harness(
        prefs,
        Scaffold(
          backgroundColor: Colors.black,
          body: ReelCommentsSheet(
            comments: demoComments('demo'),
            onSubmit: (text, replyTo) async {},
            onToggleLike: (comment) {},
            onDelete: (comment) {},
          ),
        ),
        dark: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    if (_isCI) return;
    await expectLater(
      find.byType(ReelCommentsSheet),
      matchesGoldenFile('goldens/comments_sheet_dark.png'),
    );
  });

  testWidgets('the share sheet in dark mode', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs(dark: true);
    await tester.pumpWidget(
      _harness(
        prefs,
        Scaffold(
          backgroundColor: Colors.black,
          body: ReelShareSheet(
            targets: const [
              ShareTarget(id: '1', name: 'Arif Hasan', isOnline: true),
              ShareTarget(id: '2', name: 'Tania Akter'),
              ShareTarget(id: '3', name: 'Rafi Ahmed', isOnline: true),
              ShareTarget(id: '4', name: 'Mim'),
              ShareTarget(id: '5', name: 'Nila Rahman'),
            ],
            onSend: (selected) async {},
            onRepost: () {},
            onSave: () {},
            onCopyLink: () async {},
            onAddStory: () {},
          ),
        ),
        dark: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    if (_isCI) return;
    await expectLater(
      find.byType(ReelShareSheet),
      matchesGoldenFile('goldens/share_sheet_dark.png'),
    );
  });

  testWidgets('the upload camera', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prefs = await _buildPrefs();
    await tester.pumpWidget(_harness(prefs, const CameraPage()));
    await tester.pump(const Duration(milliseconds: 300));

    if (_isCI) return;
    await expectLater(
      find.byType(CameraPage),
      matchesGoldenFile('goldens/camera.png'),
    );
  });
}
