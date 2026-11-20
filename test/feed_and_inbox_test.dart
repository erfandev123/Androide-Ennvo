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
import 'package:ennvo/data/services/post_service.dart';
import 'package:ennvo/data/services/story_service.dart';
import 'package:ennvo/features/messages/messages_page.dart';
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
  }
}
