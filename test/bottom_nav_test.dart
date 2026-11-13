// ============================================================================
//  ENNVO — BOTTOM NAVIGATION WIDGET TEST
//
//  Checks the behaviour the web app's `BottomNav.tsx` specifies: the five
//  destinations, the badge, the two skins and the tap handling.
// ============================================================================

import 'package:ennvo/core/nav/page_type.dart';
import 'package:ennvo/core/perf/device_tier.dart';
import 'package:ennvo/core/providers.dart';
import 'package:ennvo/core/storage/app_prefs.dart';
import 'package:ennvo/shared/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppPrefs> _fakePrefs([String navStyle = 'glass']) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('ennvo_nav_style', navStyle);
  return AppPrefs(prefs);
}

Widget _wrap(AppPrefs prefs, Widget child) {
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWith((ref) => prefs),
      deviceProfileProvider.overrideWithValue(
        profileForTesting(ramBytes: 8 * 1024 * 1024 * 1024, cores: 8),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows the five destinations', (tester) async {
    final prefs = await _fakePrefs();
    await tester.pumpWidget(
      _wrap(
        prefs,
        Scaffold(
          body: EnnvoBottomNav(
            currentPage: AppPage.home,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('reports the tapped destination', (tester) async {
    final prefs = await _fakePrefs();
    AppPage? selected;

    await tester.pumpWidget(
      _wrap(
        prefs,
        Scaffold(
          body: EnnvoBottomNav(
            currentPage: AppPage.home,
            onSelect: (page) => selected = page,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox'));
    await tester.pump();

    expect(selected, AppPage.messages);
  });

  testWidgets('shows the inbox badge', (tester) async {
    final prefs = await _fakePrefs();
    await tester.pumpWidget(
      _wrap(
        prefs,
        Scaffold(
          body: EnnvoBottomNav(
            currentPage: AppPage.home,
            onSelect: (_) {},
            messageCount: 3,
            notificationCount: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('hides the bar when asked', (tester) async {
    final prefs = await _fakePrefs();
    await tester.pumpWidget(
      _wrap(
        prefs,
        Scaffold(
          body: EnnvoBottomNav(
            currentPage: AppPage.home,
            onSelect: (_) {},
            isHidden: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNothing);
  });

  testWidgets('the classic skin also renders every destination', (
    tester,
  ) async {
    final prefs = await _fakePrefs('classic');
    await tester.pumpWidget(
      _wrap(
        prefs,
        Scaffold(
          body: EnnvoBottomNav(
            currentPage: AppPage.home,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
