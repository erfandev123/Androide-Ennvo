// ============================================================================
//  ENNVO — REELS SERVICE
//
//  Ports the reel feed logic of `src/services/postService.ts`
//  (`subscribeReels`, `getFeed`) and the ranking that lives in
//  `src/pages/Reels.tsx`.
//
//  Ranking rules ported from the web app:
//    1. promoted reels come first
//    2. then by score = (seen ? 0 : 500) + likes*1.5 + comments*3
//                 + views*0.1 + (id[0] % 30)
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import 'firebase_service.dart';

class ReelsService {
  const ReelsService._();

  static const int defaultPageSize = 25;

  /// Subscribes to the newest reels.
  static Stream<List<AppPost>> subscribeReels({int pageSize = defaultPageSize}) {
    if (!FirebaseService.isReady) return Stream.value(const <AppPost>[]);

    return FirebaseService.firestore
        .collection('posts')
        .where('type', isEqualTo: 'reel')
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

  /// Subscribes to the reels of the people the user follows.
  static Stream<List<AppPost>> subscribeFollowingReels({
    required List<String> followingIds,
    int pageSize = defaultPageSize,
  }) {
    if (!FirebaseService.isReady || followingIds.isEmpty) {
      return Stream.value(const <AppPost>[]);
    }

    return FirebaseService.firestore
        .collection('posts')
        .where('type', isEqualTo: 'reel')
        .where('authorId', whereIn: followingIds.take(30).toList())
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

  /// Loads one page of reels — used for the offline cache.
  static Future<List<AppPost>> fetchReels({
    int pageSize = defaultPageSize,
  }) async {
    if (!FirebaseService.isReady) return const [];
    try {
      final snapshot = await FirebaseService.firestore
          .collection('posts')
          .where('type', isEqualTo: 'reel')
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .get();
      return snapshot.docs
          .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Loads an older page of reels, so the feed never ends.
  ///
  /// The cursor is the creation time of the oldest reel on screen, which
  /// is the same cursor the web app uses.
  static Future<List<AppPost>> fetchMore({
    required DateTime before,
    int limit = 12,
  }) async {
    if (!FirebaseService.isReady) return const [];
    try {
      final snapshot = await FirebaseService.firestore
          .collection('posts')
          .where('type', isEqualTo: 'reel')
          .where('createdAt', isLessThan: Timestamp.fromDate(before))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Sorts reels the way the web app does.
  static List<AppPost> rank(List<AppPost> reels, Set<String> seenIds) {
    final copy = List<AppPost>.of(reels);
    copy.sort((a, b) {
      if (a.isPromoted != b.isPromoted) return a.isPromoted ? -1 : 1;
      final scoreA = a.rankScore(seenIds);
      final scoreB = b.rankScore(seenIds);
      if (scoreA == scoreB) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      }
      return scoreB.compareTo(scoreA);
    });
    return copy;
  }

  /// Derives the category label from the caption, exactly like the web app
  /// does (Music / Comedy / Gaming / Tech / Lifestyle / Trending).
  static String categoryFor(String caption) {
    final text = caption.toLowerCase();
    bool has(List<String> words) => words.any(text.contains);

    if (has(['music', 'song', 'beat', 'rap', 'remix', 'dj'])) return 'Music';
    if (has(['comedy', 'funny', 'laugh', 'joke', 'meme'])) return 'Comedy';
    if (has(['game', 'gaming', 'play', 'gamer', 'esport'])) return 'Gaming';
    if (has(['tech', 'code', 'coding', 'app', 'ai', 'phone', 'pc'])) {
      return 'Tech';
    }
    if (has(['life', 'travel', 'food', 'style', 'fitness'])) return 'Lifestyle';
    return 'Trending';
  }

  /// Toggles the like on a reel and returns the new count.
  static Future<int> toggleLike({
    required String reelId,
    required String userId,
    required bool currentlyLiked,
    required int currentCount,
  }) async {
    if (!FirebaseService.isReady) return currentCount;
    try {
      final ref = FirebaseService.firestore
          .collection('posts')
          .doc(reelId)
          .collection('likes')
          .doc(userId);
      if (currentlyLiked) {
        await ref.delete();
      } else {
        await ref.set({'userId': userId, 'createdAt': FieldValue.serverTimestamp()});
      }
      return currentlyLiked ? currentCount - 1 : currentCount + 1;
    } catch (_) {
      return currentCount;
    }
  }

  /// Records a view. The web app de-duplicates views per user.
  static Future<void> incrementView({
    required String reelId,
    required String userId,
  }) async {
    if (!FirebaseService.isReady) return;
    try {
      await FirebaseService.firestore
          .collection('posts')
          .doc(reelId)
          .collection('views')
          .doc(userId)
          .set({'userId': userId, 'createdAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // A failed view must never interrupt playback.
    }
  }
}
