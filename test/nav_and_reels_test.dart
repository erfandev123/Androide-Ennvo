// ============================================================================
//  ENNVO — NAVIGATION AND REELS REGRESSION TESTS
//
//  These lock in the fixes the reels rebuild left behind:
//
//    • the navigation bar is the *same* bar on every page — it paints itself
//      dark on the reels feed, but it never turns into a different bar
//    • the messages page keeps the navigation, and a conversation opens as
//      a page of its own, without the navigation on top of it
//    • the reels page shows the reels right away, even while the network is
//      still answering
//    • a plain MP4 is never handed to the player as an HLS stream, which is
//      what kept the reels black
//    • the comment composer stays on screen when the keyboard is up
// ============================================================================

import 'dart:async';

import 'package:ennvo/core/nav/page_type.dart';
import 'package:ennvo/core/perf/device_tier.dart';
import 'package:ennvo/core/providers.dart';
import 'package:ennvo/core/storage/app_prefs.dart';
import 'package:ennvo/core/theme/app_theme.dart';
import 'package:ennvo/core/theme/tokens.dart';
import 'package:ennvo/data/models/message.dart';
import 'package:ennvo/data/models/post.dart';
import 'package:ennvo/features/reels/models/reel_comment.dart';
import 'package:ennvo/features/reels/reels_page.dart';
import 'package:ennvo/features/reels/widgets/comments_sheet.dart';
import 'package:ennvo/features/reels/widgets/reel_card.dart';
import 'package:ennvo/features/reels/widgets/reel_video.dart';
import 'package:ennvo/features/reels/widgets/share_sheet.dart';
import 'package:ennvo/features/shell/app_shell.dart';
import 'package:ennvo/shared/widgets/bottom_nav.dart';
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
    // The inbox is real now: seed a conversation so the chat tests have
    // somebody to talk to without a backend.
    conversationsProvider.overrideWith(
      (ref) => Stream.value(<Conversation>[
        Conversation(
          id: 'dm-arif',
          participantIds: const ['me', 'demo-a'],
          participantNames: const {'me': 'Me', 'demo-a': 'Arif Hasan'},
          participantAvatars: const {'me': '', 'demo-a': ''},
          lastMessage: 'Hello!',
          unreadCount: const {'me': 0},
          updatedAt: DateTime.now(),
        ),
      ]),
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

/// The reels feed runs forever — the disc spins, the marquee scrolls — so
/// the tree never settles and the tests have to pump by hand.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
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
    await _settle(tester);

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
    await _settle(tester);

    expect(find.byType(EnnvoBottomNav), findsOneWidget);
    expect(find.bySemanticsLabel('Inbox'), findsOneWidget);
  });

  testWidgets('the chat opens as its own page, without the navigation bar', (
    tester,
  ) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);
    await _pump(tester, container);

    container.read(navControllerProvider).pushPage(AppPage.messages);
    await _settle(tester);

    // The conversation list keeps the navigation.
    expect(find.byType(EnnvoBottomNav), findsOneWidget);

    // Opening a conversation opens a page of its own: the navigation is not
    // on top of the chat.
    await tester.tap(find.text('Arif Hasan').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The chat is open ...
    expect(find.byTooltip('Back'), findsOneWidget);

    // ... and the navigation belongs to the route *below* it, so there is
    // no bar on top of the conversation.
    final navRoute = ModalRoute.of(
      tester.element(find.byType(EnnvoBottomNav)),
    );
    expect(navRoute?.isCurrent, isFalse);
  });

  testWidgets('the back gesture closes the chat and returns to the list', (
    tester,
  ) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);
    await _pump(tester, container);

    container.read(navControllerProvider).pushPage(AppPage.messages);
    await _settle(tester);

    await tester.tap(find.text('Arif Hasan').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // The chat is gone and the list is back, with its navigation.
    expect(find.byTooltip('Back'), findsNothing);
    final navRoute = ModalRoute.of(
      tester.element(find.byType(EnnvoBottomNav)),
    );
    expect(navRoute?.isCurrent, isTrue);
    expect(container.read(navControllerProvider).currentPage, AppPage.messages);
  });

  testWidgets('the reels page shows the reels right away, even offline', (
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

    // The page is never an empty screen: the local reels are on screen
    // while the network is still answering.
    expect(find.byType(ReelCard), findsOneWidget);
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

  test('a photo post is not handed to the video player', () {
    final photo = AppPost(
      id: 'p1',
      authorId: 'a',
      authorName: 'A',
      authorAvatar: '',
      text: '',
      media: const ['https://cdn.ennvo.app/photos/one.jpg'],
      type: PostType.post,
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(),
    );
    expect(photo.mediaIsImage, isTrue);
    expect(photo.videoUrl, isNull);

    final video = AppPost(
      id: 'p2',
      authorId: 'a',
      authorName: 'A',
      authorAvatar: '',
      text: '',
      media: const ['https://cdn.ennvo.app/reels/one.mp4'],
      type: PostType.reel,
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(),
    );
    expect(video.mediaIsImage, isFalse);
    expect(video.videoUrl, 'https://cdn.ennvo.app/reels/one.mp4');
  });

  testWidgets('the comment composer stays on screen with the keyboard up', (
    tester,
  ) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);

    // The keyboard covers the lower third of the screen (300 logical pixels
    // of a 780 pixel tall phone).
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);

    await _pump(
      tester,
      container,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ReelCommentsSheet(
                  comments: const <ReelComment>[],
                  onSubmit: (text, replyTo) async {},
                  onToggleLike: (comment) {},
                  onDelete: (comment) {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The input is above the keyboard, not behind it.
    final input = find.byType(TextField).first;
    expect(input, findsOneWidget);
    final box = tester.getRect(input);

    // 780 logical pixels of screen, 300 of keyboard: the input has to sit
    // above 480.
    expect(box.bottom, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the comment sheet does not move when the keyboard opens', (
    tester,
  ) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);

    await _pump(
      tester,
      container,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ReelCommentsSheet(
                  comments: const <ReelComment>[],
                  onSubmit: (text, replyTo) async {},
                  onToggleLike: (comment) {},
                  onDelete: (comment) {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final before = tester.getRect(find.byType(ReelCommentsSheet));

    // The keyboard comes up.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final after = tester.getRect(find.byType(ReelCommentsSheet));

    // The sheet keeps its place: the screen behind it does not go up, only
    // the composer floats above the keyboard.
    expect(after.top, before.top);
    expect(after.height, before.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the comment sheet fits a phone', (tester) async {    final prefs = await _buildPrefs();
    final container = _container(prefs);

    await _pump(
      tester,
      container,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ReelCommentsSheet(
          comments: const <ReelComment>[],
          onSubmit: (text, replyTo) async {},
          onToggleLike: (comment) {},
          onDelete: (comment) {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the share sheet fits a phone', (tester) async {
    final prefs = await _buildPrefs();
    final container = _container(prefs);

    await _pump(
      tester,
      container,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ReelShareSheet(
          targets: const [
            ShareTarget(id: '1', name: 'Arif Hasan', isOnline: true),
            ShareTarget(id: '2', name: 'Tania Akter'),
            ShareTarget(id: '3', name: 'Rafi Ahmed'),
            ShareTarget(id: '4', name: 'Mim', isOnline: true),
          ],
          onSend: (selected, message) async {},
          onRepost: () {},
          onSave: () {},
          onCopyLink: () async {},
          onAddStory: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
