// ============================================================================
//  ENNVO — STORY SERVICE + MODEL
//
//  Ports `src/services/storyService.ts`. A story expires 24 hours after it
//  was created.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parse.dart';
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
    this.text = '',
    this.status,
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
  final String text;
  final String? status;

  bool get isVideo => type.toLowerCase() == 'video';

  bool get isActive {
    if (status == 'deleted' || status == 'expired' || status == 'archived') {
      return false;
    }
    return !isExpired;
  }

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry != null) return DateTime.now().isAfter(expiry);
    final created = createdAt;
    if (created != null) {
      return DateTime.now().difference(created) > const Duration(hours: 24);
    }
    return false;
  }

  bool get isSeen => viewers.isNotEmpty;

  factory Story.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Story.fromMap(data, id: doc.id);
  }

  factory Story.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    var mediaUrl = (data['mediaUrl'] as String?) ?? '';
    if (mediaUrl.isEmpty) {
      final rawMedia = data['media'];
      if (rawMedia is String) {
        mediaUrl = rawMedia;
      } else {
        final list = parseStringList(rawMedia);
        if (list.isNotEmpty) mediaUrl = list.first;
      }
    }

    final rawName = (data['authorName'] as String?)?.trim() ?? '';
    final rawUsername = (data['authorUsername'] as String?)?.trim() ?? '';
    final authorName = rawName.isNotEmpty
        ? rawName
        : (rawUsername.isNotEmpty ? rawUsername : 'User');

    return Story(
      id: id.isNotEmpty ? id : ((data['id'] as String?) ?? ''),
      authorId: (data['authorId'] as String?) ?? '',
      authorName: authorName,
      authorAvatar: (data['authorAvatar'] as String?) ?? '',
      mediaUrl: mediaUrl,
      type: (data['type'] ?? data['mediaType'] ?? 'image').toString(),
      createdAt: parseDateTime(data['createdAt']),
      expiresAt: parseDateTime(data['expiresAt']),
      viewers: parseStringList(data['viewers']),
      text: (data['text'] as String?) ?? '',
      status: data['status'] as String?,
    );
  }
}

class StoryService {
  const StoryService._();

  /// Subscribes to active stories without requiring a composite `status+createdAt`
  /// index (web-created stories often omit `status`).
  static Stream<List<Story>> subscribeStories({
    List<String> followingIds = const [],
    int limit = 40,
  }) {
    if (!FirebaseService.isReady) return Stream.value(const <Story>[]);

    final followingSet = followingIds.toSet();
    return FirebaseService.firestore
        .collection('stories')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final stories = snapshot.docs
              .map(Story.fromFirestore)
              .where((story) => story.isActive && story.mediaUrl.isNotEmpty)
              .toList(growable: false);

          if (followingSet.isNotEmpty) {
            stories.sort((a, b) {
              final aFollowed = followingSet.contains(a.authorId);
              final bFollowed = followingSet.contains(b.authorId);
              if (aFollowed != bFollowed) return aFollowed ? -1 : 1;
              final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
              final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
              return bMs.compareTo(aMs);
            });
          }
          return stories;
        });
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

  /// Shares a reel that already lives on the server to the story of [authorId].
  ///
  /// It is the `uploadStory` of the web app with the media of the reel: no
  /// upload happens, the story points at the same file.
  static Future<bool> shareReel({
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String mediaUrl,
    String mediaType = 'video',
    String title = '',
    String storyMode = 'home',
  }) async {
    if (!FirebaseService.isReady || mediaUrl.isEmpty) return false;
    try {
      final now = DateTime.now();
      await FirebaseService.firestore.collection('stories').add({
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'mediaUrl': mediaUrl,
        'type': mediaType == 'video' ? 'video' : 'image',
        'text': title.trim(),
        'storyMode': storyMode,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          now.add(const Duration(hours: 24)),
        ),
        'viewers': <String>[],
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
