// ============================================================================
//  ENNVO — POST SERVICE
//
//  Ports the feed parts of `src/services/postService.ts`.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import 'firebase_service.dart';

class PostService {
  const PostService._();

  static const int defaultPageSize = 10;

  /// Subscribes to the main home feed, newest first.
  static Stream<List<AppPost>> subscribeFeed({int pageSize = 30}) {
    if (!FirebaseService.isReady) return Stream.value(const <AppPost>[]);

    return FirebaseService.firestore
        .collection('posts')
        .where('type', isEqualTo: 'post')
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
                  .toList(growable: false),
        );
  }

  /// Subscribes to the posts of one user.
  static Stream<List<AppPost>> subscribeUserPosts(
    String userId, {
    int pageSize = 30,
  }) {
    if (!FirebaseService.isReady) return Stream.value(const <AppPost>[]);

    return FirebaseService.firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
                  .toList(growable: false),
        );
  }

  /// Toggles the like on a post.
  static Future<int> toggleLike({
    required String postId,
    required String userId,
    required bool currentlyLiked,
    required int currentCount,
  }) async {
    if (!FirebaseService.isReady) return currentCount;
    try {
      final ref = FirebaseService.firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId);
      if (currentlyLiked) {
        await ref.delete();
      } else {
        await ref.set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return currentlyLiked ? currentCount - 1 : currentCount + 1;
    } catch (_) {
      return currentCount;
    }
  }

  /// Toggles the repost on a post.
  static Future<int> toggleRepost({
    required String postId,
    required String userId,
    required bool currentlyReposted,
    required int currentCount,
  }) async {
    if (!FirebaseService.isReady) return currentCount;
    try {
      final ref = FirebaseService.firestore
          .collection('posts')
          .doc(postId)
          .collection('reposts')
          .doc(userId);
      if (currentlyReposted) {
        await ref.delete();
      } else {
        await ref.set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return currentlyReposted ? currentCount - 1 : currentCount + 1;
    } catch (_) {
      return currentCount;
    }
  }
}
