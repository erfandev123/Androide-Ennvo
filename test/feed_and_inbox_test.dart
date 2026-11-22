// ============================================================================
//  ENNVO — FEED, STORY & INBOX TESTS
//
//  Verifies:
//    • Web-compatible Firestore parsing for Posts, Stories, and Conversations
//    • Feed sorting (promoted first, newest first, reels & deleted excluded)
//    • Messages inbox layout: Stories strip at the top, Activity row directly
//      below Stories, followed by conversations (both light and dark themes)
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ennvo/core/perf/device_tier.dart';
import 'package:ennvo/core/providers.dart';
import 'package:ennvo/core/storage/app_prefs.dart';
import 'package:ennvo/core/theme/app_theme.dart';
import 'package:ennvo/data/models/message.dart';
import 'package:ennvo/data/models/notification.dart';
import 'package:ennvo/data/models/post.dart';
import 'package:ennvo/data/models/user.dart';
import 'package:ennvo/data/services/chat_service.dart';
import 'package:ennvo/data/services/post_service.dart';
import 'package:ennvo/data/services/story_service.dart';
import 'package:ennvo/features/feed/widgets/post_card.dart';
import 'package:ennvo/features/messages/messages_page.dart';
import 'package:ennvo/features/notifications/notifications_page.dart';
import 'package:ennvo/features/profile/profile_page.dart';
import 'package:ennvo/features/reels/models/reel_comment.dart';
import 'package:ennvo/features/reels/widgets/comments_sheet.dart';
import 'package:ennvo/features/reels/widgets/reel_card.dart';
import 'package:ennvo/shared/icons/ion_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(1080, 2340);

Future<AppPrefs> _buildPrefs({bool dark = false}) async {
  SharedPreferences.setMockInitialValues(
    dark ? {'ennvo_theme_mode': 'dark'} : {'ennvo_theme_mode': 'light'},
  );
  final instance = await SharedPreferences.getInstance();
  return AppPrefs(instance);
}

ProviderContainer _inboxContainer(AppPrefs prefs) {
  final now = DateTime.now();
  return ProviderContainer(
    overrides: [
      prefsProvider.overrideWith((ref) => prefs),
      deviceProfileProvider.overrideWithValue(
        profileForTesting(ramBytes: 2 * 1024 * 1024 * 1024, cores: 4),
      ),
      storiesProvider.overrideWith(
        (ref) => Stream.value(<Story>[
          Story(
            id: 'story-1',
            authorId: 'u-tania',
            authorName: 'Tania Akter',
            authorAvatar: '',
            mediaUrl: 'https://cdn.ennvo.app/stories/demo.jpg',
            type: 'image',
            createdAt: now.subtract(const Duration(hours: 1)),
            expiresAt: now.add(const Duration(hours: 23)),
          ),
        ]),
      ),
      followingProvider.overrideWith((ref) => Stream.value(const <AppUser>[])),
      followersProvider.overrideWith((ref) => Stream.value(const <AppUser>[])),
      notificationsProvider.overrideWith(
        (ref) => Stream.value(<AppNotification>[
          AppNotification(
            id: 'n1',
            type: NotificationType.like,
            actorId: 'u-arif',
            actorName: 'Arif Hasan',
            actorAvatar: '',
            targetId: 'me',
            createdAt: now.subtract(const Duration(minutes: 4)),
            isRead: false,
          ),
        ]),
      ),
      conversationsProvider.overrideWith(
        (ref) => Stream.value(<Conversation>[
          Conversation(
            id: 'dm-arif',
            participantIds: const ['me', 'u-arif'],
            participantNames: const {'me': 'Me', 'u-arif': 'Arif Hasan'},
            participantAvatars: const {'me': '', 'u-arif': ''},
            lastMessage: 'Assalamu alaikum bhai!',
            unreadCount: const {'me': 2},
            updatedAt: now.subtract(const Duration(minutes: 2)),
          ),
        ]),
      ),
    ],
  );
}

void main() {
  test('AppPost.fromMap & PostService.sortFeed filter and order properly', () {
    final base = DateTime.utc(2026, 6, 1, 12, 0, 0);

    final regularOld = AppPost.fromMap({
      'authorId': 'u1',
      'authorUsername': 'rafi',
      'text': 'Older text post',
      'type': 'text',
      'createdAt': base.millisecondsSinceEpoch,
    }, fallbackId: 'p-old');

    final regularNew = AppPost.fromMap({
      'authorId': 'u2',
      'authorName': 'Tania',
      'text': 'Newest post',
      'mediaUrl': 'https://cdn.ennvo.app/photos/one.jpg',
      'createdAt': base.add(const Duration(hours: 2)).toIso8601String(),
    }, fallbackId: 'p-new');

    final promoted = AppPost.fromMap({
      'authorId': 'u3',
      'authorName': 'Ennvo',
      'text': 'Promoted announcement',
      'isPromoted': true,
      'createdAt': Timestamp.fromDate(base.subtract(const Duration(days: 1))),
    }, fallbackId: 'p-promo');

    final reelPost = AppPost.fromMap({
      'authorId': 'u4',
      'authorName': 'Creator',
      'type': 'reel',
      'media': ['https://cdn.ennvo.app/reels/vid.mp4'],
      'createdAt': base.add(const Duration(hours: 5)).millisecondsSinceEpoch,
    }, fallbackId: 'p-reel');

    final deletedPost = AppPost.fromMap({
      'authorId': 'u5',
      'authorName': 'Hidden',
      'status': 'deleted',
      'text': 'Deleted',
      'createdAt': base.add(const Duration(hours: 6)).millisecondsSinceEpoch,
    }, fallbackId: 'p-del');

    expect(regularOld.authorName, 'rafi');
    expect(regularOld.type, PostType.text);
    expect(regularNew.media, ['https://cdn.ennvo.app/photos/one.jpg']);
    expect(promoted.createdAt, isNotNull);

    final sorted = PostService.sortFeed([
      regularOld,
      reelPost,
      deletedPost,
      regularNew,
      promoted,
    ]);

    expect(sorted.map((p) => p.id).toList(), ['p-promo', 'p-new', 'p-old']);
  });

  test('Story.fromMap handles web media array and omitted status', () {
    final now = DateTime.now();

    final freshNoStatus = Story.fromMap({
      'authorId': 'u1',
      'authorName': 'Arif',
      'media': ['https://cdn.ennvo.app/stories/s1.jpg'],
      'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
    }, id: 's1');

    final expiredNoExpiryField = Story.fromMap({
      'authorId': 'u2',
      'authorName': 'Nadia',
      'mediaUrl': 'https://cdn.ennvo.app/stories/s2.jpg',
      'createdAt': now.subtract(const Duration(hours: 30)).millisecondsSinceEpoch,
    }, id: 's2');

    final deletedStory = Story.fromMap({
      'authorId': 'u3',
      'authorName': 'Kamal',
      'mediaUrl': 'https://cdn.ennvo.app/stories/s3.jpg',
      'status': 'deleted',
      'createdAt': now.millisecondsSinceEpoch,
    }, id: 's3');

    expect(freshNoStatus.mediaUrl, 'https://cdn.ennvo.app/stories/s1.jpg');
    expect(freshNoStatus.isActive, isTrue);
    expect(expiredNoExpiryField.isActive, isFalse);
    expect(deletedStory.isActive, isFalse);
  });

  test('Conversation.fromMap extracts nested web participants map', () {
    final conv = Conversation.fromMap({
      'participants': {
        'me': {'name': 'Me', 'avatar': ''},
        'friend-1': {
          'displayName': 'Sadia Rahman',
          'photoURL': 'https://cdn.ennvo.app/avatars/sadia.jpg',
        },
      },
      'lastMessage': 'Ki obosta?',
      'unreadCount': {'me': '3'},
      'updatedAt': DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
    }, id: 'friend-1_me');

    expect(conv.participantIds, containsAll(['me', 'friend-1']));
    expect(conv.displayName('me'), 'Sadia Rahman');
    expect(
      conv.displayAvatar('me'),
      'https://cdn.ennvo.app/avatars/sadia.jpg',
    );
    expect(conv.unreadFor('me'), 3);
  });

  test('ChatService.deduplicateConversations merges duplicate DMs for same peer', () {
    final now = DateTime.utc(2026, 6, 1, 12, 0);
    final older = Conversation(
      id: 'me_u-arif',
      participantIds: const ['me', 'u-arif'],
      participantNames: const {'me': 'Me', 'u-arif': 'Arif Hasan'},
      participantAvatars: const {'me': '', 'u-arif': 'https://cdn.ennvo.app/arif.jpg'},
      lastMessage: 'First ping',
      unreadCount: const {'me': 1},
      updatedAt: now.subtract(const Duration(minutes: 10)),
    );
    final newerIncomplete = Conversation(
      id: 'u-arif_me',
      participantIds: const ['u-arif', 'me'],
      participantNames: const {'me': 'Me', 'u-arif': 'Unknown'},
      participantAvatars: const {'me': '', 'u-arif': ''},
      lastMessage: 'Latest ping',
      unreadCount: const {'me': 3},
      updatedAt: now,
    );

    final merged = ChatService.deduplicateConversations(
      [older, newerIncomplete],
      'me',
    );
    expect(merged.length, 1);
    expect(merged.first.lastMessage, 'Latest ping');
    expect(merged.first.displayName('me'), 'Arif Hasan');
    expect(merged.first.displayAvatar('me'), 'https://cdn.ennvo.app/arif.jpg');
    expect(merged.first.unreadFor('me'), 3);
  });

  testWidgets('PostCard renders big text card, location/tags, and 5 actions including Save',
      (tester) async {
    var savedTapped = false;
    final post = AppPost.fromMap({
      'authorId': 'u-1',
      'authorName': 'Erfan',
      'text': 'Ennvo mobile experience looks clean!',
      'type': 'text',
      'background': '#0EA5E9',
      'location': 'Dhaka, Bangladesh',
      'taggedUsers': ['Tania', 'Arif'],
      'likesCount': 12,
      'commentsCount': 4,
      'favoritesCount': 3,
      'repostsCount': 2,
    }, fallbackId: 'p-big-text');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: EnnvoTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCard(
                post: post,
                isLiked: false,
                isReposted: false,
                likesCount: 12,
                isSaved: false,
                favoritesCount: 3,
                onToggleSave: () => savedTapped = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dhaka, Bangladesh'), findsOneWidget);
    expect(find.textContaining('with Tania, Arif'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);

    // Like, Comment, Save sit on the left side while Share sits on the right side
    final likeX = tester.getCenter(find.byTooltip('Like')).dx;
    final commentX = tester.getCenter(find.byTooltip('Comment')).dx;
    final saveX = tester.getCenter(find.byTooltip('Save')).dx;
    final shareX = tester.getCenter(find.byTooltip('Share')).dx;
    expect(likeX, lessThan(commentX));
    expect(commentX, lessThan(saveX));
    expect(saveX, lessThan(shareX));
    expect(shareX - saveX, greaterThan(60));

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    expect(savedTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ReelCommentsSheet turns liked comment heart and count blue', (
    tester,
  ) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final comment = ReelComment(
      id: 'c-blue-1',
      authorId: 'u-2',
      authorName: 'Tania Akter',
      authorAvatar: '',
      kind: CommentKind.text,
      text: 'Khub sundor hoyeche!',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      likesCount: 4,
      isLiked: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: EnnvoTheme.light(),
        home: Scaffold(
          body: ReelCommentsSheet(
            comments: [comment],
            onSubmit: (_, _) async {},
            onToggleLike: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final likeFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Like the comment',
    );
    await tester.tap(likeFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('5'), findsOneWidget);
    final countWidget = tester.widget<Text>(find.text('5'));
    expect(countWidget.style?.color, const Color(0xFF0095F6));

    final heartWidget = tester.widget<IonIcon>(
      find.descendant(
        of: likeFinder,
        matching: find.byType(IonIcon),
      ),
    );
    expect(heartWidget.color, const Color(0xFF0095F6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfilePage renders TikTok-style vertical reel boxes in Reels tab',
      (tester) async {
    final prefs = await _buildPrefs(dark: false);
    final reelPost = AppPost.fromMap({
      'id': 'reel-profile-1',
      'authorId': 'me',
      'authorName': 'Erfan',
      'text': 'Sunset reel',
      'type': 'reel',
      'media': ['https://cdn.ennvo.app/reels/sunset.mp4'],
      'likesCount': 1200,
      'viewsCount': 8500,
    }, fallbackId: 'reel-profile-1');

    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWith((ref) => prefs),
        deviceProfileProvider.overrideWithValue(
          profileForTesting(ramBytes: 4 * 1024 * 1024 * 1024, cores: 4),
        ),
        userPostsProvider.overrideWith((ref) => Stream.value([reelPost])),
        savedPostsProvider.overrideWith((ref) async => const <AppPost>[]),
      ],
    );

    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: EnnvoTheme.light(),
          home: const ProfilePage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Reels'));
    await tester.pumpAndSettle();

    expect(find.text('8.5K'), findsOneWidget);
    final gridItemSize = tester.getSize(
      find.ancestor(
        of: find.text('8.5K'),
        matching: find.byType(GestureDetector),
      ).first,
    );
    expect(
      gridItemSize.height,
      greaterThan(gridItemSize.width * 1.3),
      reason: 'TikTok-style reel boxes must be tall vertical cards',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ReelCard right-side hold enables clean mode and shows 2x badge',
      (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final cleanEvents = <bool>[];
    final post = AppPost.fromMap({
      'authorId': 'u-1',
      'authorName': 'Creator',
      'text': 'Fast forward test reel',
      'type': 'reel',
      'media': const <String>[],
    }, fallbackId: 'r-test');

    await tester.pumpWidget(
      MaterialApp(
        theme: EnnvoTheme.dark(),
        home: Scaffold(
          body: ReelCard(
            post: post,
            isActive: false,
            isNear: false,
            isLiked: false,
            isSaved: false,
            isReposted: false,
            isFollowing: false,
            likesCount: 10,
            commentsCount: 2,
            favouritesCount: 1,
            sharesCount: 0,
            muted: true,
            onToggleLike: () {},
            onToggleSave: () {},
            onToggleRepost: () {},
            onToggleFollow: () {},
            onToggleMute: () {},
            onOpenComments: () {},
            onOpenShare: () {},
            onCleanModeChanged: cleanEvents.add,
          ),
        ),
      ),
    );
    await tester.pump();

    // Press down on the open right-side video canvas (width 360 -> 250 > 360*0.52)
    final gesture = await tester.startGesture(const Offset(250, 260));
    await tester.pump(const Duration(milliseconds: 250));
    expect(cleanEvents, contains(true));
    expect(find.text('2x'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(cleanEvents.last, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'MessagesPage renders Stories at top and Activity directly below (${dark ? "dark" : "light"})',
      (tester) async {
        final prefs = await _buildPrefs(dark: dark);
        final container = _inboxContainer(prefs);

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
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const MessagesPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('Create'), findsOneWidget);
        expect(find.text('Tania Akter'), findsOneWidget);
        expect(find.text('Activity'), findsOneWidget);
        expect(find.text('Arif Hasan liked your post'), findsOneWidget);
        expect(find.text('Arif Hasan'), findsOneWidget);

        final createDy = tester.getTopLeft(find.text('Create')).dy;
        final activityDy = tester.getTopLeft(find.text('Activity')).dy;
        final messagesDy = tester.getTopLeft(find.text('Arif Hasan')).dy;

        expect(
          createDy,
          lessThan(activityDy),
          reason: 'Stories section must stay above the Activity row',
        );
        expect(
          activityDy,
          lessThan(messagesDy),
          reason: 'Activity row must sit above the conversations list',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'NotificationsPage renders Activity & Followers cleanly (${dark ? "dark" : "light"})',
      (tester) async {
        final prefs = await _buildPrefs(dark: dark);
        final container = _inboxContainer(prefs);

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
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const NotificationsPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('Activity'), findsWidgets);
        expect(find.text('Followers'), findsOneWidget);
        expect(
          find.textContaining('liked your post', findRichText: true),
          findsOneWidget,
        );

        await tester.tap(find.text('Followers').last);
        await tester.pumpAndSettle();
        expect(find.text('No new followers yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
