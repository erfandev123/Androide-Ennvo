// ============================================================================
//  ENNVO — GLOBAL PROVIDERS
//
//  The web app keeps everything in one flat Zustand store. The native port
//  splits it into focused providers so a rebuild of one slice (say the
//  message list) never touches the navigation bar.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/message.dart';
import '../data/models/notification.dart';
import '../data/models/post.dart';
import '../data/services/chat_service.dart';
import '../data/services/firebase_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/post_service.dart';
import '../data/services/reels_service.dart';
import '../data/services/story_service.dart';
import 'auth/auth_controller.dart';
import 'nav/nav_controller.dart';
import 'perf/device_tier.dart';
import 'storage/app_prefs.dart';

/// Loaded once at startup.
final prefsProvider = ChangeNotifierProvider<AppPrefs>((ref) {
  throw UnimplementedError('prefsProvider must be overridden at startup');
});

/// The signed-in user.
final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController();
});

/// The detected device profile, used to decide lite mode.
final deviceProfileProvider = Provider<DeviceProfile>((ref) {
  return DeviceTierService.unknown;
});

/// The navigation stack.
final navControllerProvider = ChangeNotifierProvider<NavController>((ref) {
  return NavController();
});

/// Light / dark theme, driven by the persisted preference.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final prefs = ref.watch(prefsProvider);
  return prefs.isDarkTheme ? ThemeMode.dark : ThemeMode.light;
});

/// Whether the bottom navigation uses the glass or the classic skin.
final navStyleProvider = Provider<String>((ref) {
  return ref.watch(prefsProvider).navStyle;
});

/// Unread counters shown on the bottom navigation badges.
class NavBadges {
  const NavBadges({this.messages = 0, this.notifications = 0});

  final int messages;
  final int notifications;

  int get inboxTotal => messages + notifications;
}

final navBadgesProvider = Provider<NavBadges>((ref) {
  return const NavBadges();
});

/// The reels for the "For You" tab.
final reelsProvider = StreamProvider<List<AppPost>>((ref) {
  return ReelsService.subscribeReels();
});

/// The reels for the "Following" tab.
final followingReelsProvider = StreamProvider<List<AppPost>>((ref) {
  final auth = ref.watch(authControllerProvider);
  final followingIds = auth.user == null
      ? const <String>[]
      : <String>[auth.user!.uid];
  return ReelsService.subscribeFollowingReels(followingIds: followingIds);
});

/// The main home feed.
final feedProvider = StreamProvider<List<AppPost>>((ref) {
  return PostService.subscribeFeed();
});

/// The stories strip.
final storiesProvider = StreamProvider<List<Story>>((ref) {
  return StoryService.subscribeStories();
});

/// The activity feed of the signed-in user.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(authControllerProvider).user?.uid ?? '';
  return NotificationService.subscribeNotifications(uid);
});

/// Every conversation the signed-in user takes part in.
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final uid = ref.watch(authControllerProvider).user?.uid ?? '';
  return ChatService.subscribeConversations(uid);
});

/// The messages of one conversation.
final messagesProvider =
    StreamProvider.family<List<AppMessage>, String>((ref, conversationId) {
      return ChatService.subscribeMessages(conversationId);
    });

/// The posts of the signed-in user.
final userPostsProvider = StreamProvider<List<AppPost>>((ref) {
  final uid = ref.watch(authControllerProvider).user?.uid ?? '';
  return PostService.subscribeUserPosts(uid);
});

/// The Firestore instance, or null when Firebase could not start.
final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  if (!FirebaseService.isReady) return null;
  return FirebaseService.firestore;
});
