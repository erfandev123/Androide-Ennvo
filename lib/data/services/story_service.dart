// ============================================================================
//  ENNVO — STORY SERVICE + MODEL
//
//  Ports `src/services/storyService.ts`. A story expires 24 hours after it
//  was created.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_service.dart';

class Story {
  const Story({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.mediaUrl,
    required this.type,
    required this.createdAt,
    required this.expiresAt,
    this.viewers = const [],
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String mediaUrl;

  /// `'image'` or `'video'`.
  final String type;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final List<String> viewers;

  bool get isVideo => type == 'video';

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  bool get isSeen => viewers.isNotEmpty;

  factory Story.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Story(
      id: doc.id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorAvatar: (data['authorAvatar'] as String?) ?? '',
      mediaUrl: (data['mediaUrl'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'image',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      viewers: (data['viewers'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

class StoryService {
  const StoryService._();

  /// Subscribes to the active stories of everybody the user follows,
  /// plus their own.
  static Stream<List<Story>> subscribeStories({
    List<String> followingIds = const [],
    int limit = 40,
  }) {
    if (!FirebaseService.isReady) return Stream.value(const <Story>[]);

    return FirebaseService.firestore
        .collection('stories')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(Story.fromFirestore)
                  .where((story) => !story.isExpired)
                  .toList(growable: false),
        );
  }

  /// Marks a story as seen by the current user.
  static Future<void> markSeen({
    required String storyId,
    required String userId,
  }) async {
    if (!FirebaseService.isReady) return;
    try {
      await FirebaseService.firestore
          .collection('stories')
          .doc(storyId)
          .update({
            'viewers': FieldValue.arrayUnion([userId]),
          });
    } catch (_) {
      // A failed view must never break the story viewer.
    }
  }
}
