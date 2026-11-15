// ============================================================================
//  ENNVO — NAVIGATION AND REELS REGRESSION TESTS
//
//  These lock in the fixes the reels rebuild left behind:
//
//    • the navigation bar is the *same* bar on every page — it paints itself
//      dark on the reels feed, but it never turns into a different bar
//    • the messages page keeps the navigation, and so does the chat
//    • the system back gesture closes the chat before it closes the page
//    • the reels page shows the brand mark instead of a flat black screen
//      while the first video is on the wire
//    • a plain MP4 is never handed to the player as an HLS stream, which is
//      what kept the reels black
// ============================================================================

import 'dart:async';

import 'package:ennvo/core/nav/page_type.dart';
import 'package:ennvo/core/perf/device_tier.dart';
import 'package:ennvo/core/providers.dart';
import 'package:ennvo/core/storage/app_prefs.dart';
import 'package:ennvo/core/theme/app_theme.dart';
import 'package:ennvo/core/theme/tokens.dart';
import 'package:ennvo/data/models/post.dart';
import 'package:ennvo/features/reels/reels_page.dart';
import 'package:ennvo/features/reels/widgets/reel_video.dart';
import 'package:ennvo/features/shell/app_shell.dart';
import 'package:ennvo/shared/widgets/bottom_nav.dart';
import 'package:ennvo/shared/widgets/brand_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// A Pixel-class phone: 1080 x 2340 at a 3x pixel ratio.
const Size _phone = Size(1080, 2340);

Future<AppPrefs> _buildPrefs({bool dark = false}) async {
  SharedPreferences.setMockInitialValues(
    dark ? {'ennvo_theme_mode': 'dark'} : {'ennvo_theme_mode': 'light'},
  );
  final instance = await SharedPreferences.getInstance();
  return AppPrefs(instance);
}

/// The base overrides every test needs.
ProviderContainer _container(AppPrefs prefs) => ProviderContainer(
  overrides: [
    prefsProvider.overrideWith((ref) => prefs),
    deviceProfileProvider.overrideWithValue(
      profileForTesting(ramBytes: 8 * 1024 * 1024 * 1024, cores: 8),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  Widget? child,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: EnnvoTheme.light(),
        darkTheme: EnnvoTheme.dark(),
        home: child ?? const AppShell(),
      ),
    ),
  );
  await tester.pump();
}

/// The widths of the pill shaped containers inside the navigation bar.
List<double> _pillWidths(WidgetTester tester) {
  final pills = find
      .descendant(
        of: find.byType(EnnvoBottomNav),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).borderRadius ==
                  BorderRadius.circular(AppRadius.pill),
        ),
      )
      .evaluate();

  return [
    for (final element in pills)
      (element.renderObject as RenderBox?)?.size.width ?? 0,
  ];
}

void main() {
  testWidgets('the navigation bar is the same floating bar on the reels feed', (
    tester,
  ) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);
    await _pump(tester, container);

    // The reels feed is the home page.
    expect(find.byType(EnnvoBottomNav), findsOneWidget);

    // It is the floating pill, not a full width bar: every pill inside the
    // navigation is narrower than the bar itself.
    expect(_pillWidths(tester), isNotEmpty);
    for (final width in _pillWidths(tester)) {
      expect(
        width,
        lessThanOrEqualTo(AppSizes.bottomNavPillMaxWidth),
        reason: 'the navigation must stay the floating pill',
      );
    }
  });

  testWidgets('the messages page keeps the navigation bar', (tester) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);
    await _pump(tester, container);

    container.read(navControllerProvider).pushPage(AppPage.messages);
    // The reels feed runs forever (the disc spins, the marquee scrolls), so
    // the tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(EnnvoBottomNav), findsOneWidget);
    expect(find.bySemanticsLabel('Inbox'), findsOneWidget);
  });

  testWidgets('the chat keeps the navigation bar', (tester) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);
    await _pump(tester, container);

    container.read(navControllerProvider).pushPage(AppPage.messages);
    // The reels feed runs forever (the disc spins, the marquee scrolls), so
    // the tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Opening a conversation must not take the navigation away.
    container.read(openConversationProvider.notifier).state = 'demo-1';
    // The reels feed runs forever (the disc spins, the marquee scrolls), so
    // the tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(EnnvoBottomNav), findsOneWidget);
    expect(find.bySemanticsLabel('Inbox'), findsOneWidget);
  });

  testWidgets('the back gesture closes the chat before the page', (
    tester,
  ) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);
    await _pump(tester, container);

    container.read(navControllerProvider).pushPage(AppPage.messages);
    // The reels feed runs forever (the disc spins, the marquee scrolls), so
    // the tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    container.read(openConversationProvider.notifier).state = 'demo-1';
    // The reels feed runs forever (the disc spins, the marquee scrolls), so
    // the tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.pageBack();
    // The reels feed runs forever (the disc spins, the marquee scrolls), so
    // the tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // The chat is gone, but the user is still on the messages page.
    expect(container.read(openConversationProvider), isNull);
    expect(container.read(navControllerProvider).currentPage, AppPage.messages);
  });

  testWidgets('the reels page shows the brand mark while it loads', (
    tester,
  ) async {
    final prefs = await _buildPrefs();

    // A feed that never answers keeps the page in its loading state.
    final feed = StreamController<List<AppPost>>();
    addTearDown(feed.close);

    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWith((ref) => prefs),
        deviceProfileProvider.overrideWithValue(
          profileForTesting(ramBytes: 8 * 1024 * 1024 * 1024, cores: 8),
        ),
        reelsProvider.overrideWith((ref) => feed.stream),
      ],
    );
    await _pump(tester, container, child: const ReelsPage());
    await tester.pump();

    expect(find.byType(EnnvoBrandMark), findsOneWidget);
  });

  test('a plain MP4 is not played as an HLS stream', () {
    expect(
      ReelVideo.formatHintFor('https://cdn.ennvo.app/reel/r1.mp4'),
      isNull,
    );
    expect(
      ReelVideo.formatHintFor('https://cdn.ennvo.app/reel/r1.m3u8'),
      VideoFormat.hls,
    );
  });
}
