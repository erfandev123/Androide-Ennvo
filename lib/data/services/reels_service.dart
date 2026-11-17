// ============================================================================
//  ENNVO — REELS SERVICE
//
//  Ports the reel feed logic of `src/services/postService.ts`
//  (`subscribeReels`, `getFeed`) and the ranking that lives in
//  `src/pages/Reels.tsx`.
//
//  The web app asks Firestore for `where('type','==','reel')` and sorts the
//  result in memory. It does NOT put an `orderBy('createdAt')` on that
//  query: a filter plus an order needs a composite index, and a project
//  without that index returns nothing - which left the feed with no real
//  videos. The native port follows the web app exactly, so the real reels
//  always load.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import 'firebase_service.dart';

class ReelsService {
  const ReelsService._();

  static const int defaultPageSize = 25;

  /// Newest first. The creation time can be a Firestore timestamp or a
  /// string in the documents the web app has already stored.
  static int _timeOf(AppPost post) {
    final created = post.createdAt;
    if (created != null) return created.millisecondsSinceEpoch;
    return 0;
  }

  static void _newestFirst(List<AppPost> posts) {
    posts.sort((a, b) => _timeOf(b).compareTo(_timeOf(a)));
  }

  /// Subscribes to the newest reels.
  static Stream<List<AppPost>> subscribeReels({int pageSize = defaultPageSize}) {
    if (!FirebaseService.isReady) return Stream.value(const <AppPost>[]);

    return FirebaseService.firestore
        .collection('posts')
        .where('type', isEqualTo: 'reel')
        .limit(pageSize * 2)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
          .toList(growable: false);
      _newestFirst(posts);
      return posts;
    });
  }

  /// Subscribes to the reels of the people the user follows.
  ///
  /// The `whereIn` is done on the phone when the list is short: Firestore
  /// caps `whereIn` at 10 values on older SDKs, and a `whereIn` plus an
  /// `orderBy` needs another index.
  static Stream<List<AppPost>> subscribeFollowingReels({
    required List<String> followingIds,
    int pageSize = defaultPageSize,
  }) {
    if (!FirebaseService.isReady || followingIds.isEmpty) {
      return Stream.value(const <AppPost>[]);
    }

    final ids = followingIds.toSet();
    return FirebaseService.firestore
        .collection('posts')
        .where('type', isEqualTo: 'reel')
        .limit(pageSize * 3)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
          .where((post) => ids.contains(post.authorId))
          .toList(growable: false);
      _newestFirst(posts);
      return posts.take(pageSize).toList(growable: false);
    });
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
          .limit(pageSize * 2)
          .get();
      final posts = snapshot.docs
          .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
          .toList();
      _newestFirst(posts);
      return posts;
    } catch (_) {
      return const [];
    }
  }

  /// Loads an older page of reels, so the feed never ends.
  ///
  /// The cursor is applied on the phone after the fetch: a `where` plus a
  /// range plus an `orderBy` needs a composite index that a fresh Firebase
  /// project does not have yet.
  static Future<List<AppPost>> fetchMore({
    required DateTime before,
    int limit = 12,
  }) async {
    if (!FirebaseService.isReady) return const [];
    try {
      final snapshot = await FirebaseService.firestore
          .collection('posts')
          .where('type', isEqualTo: 'reel')
          .limit(limit * 6)
          .get();
      final posts = snapshot.docs
          .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
          .where((post) {
            final created = post.createdAt;
            return created != null && created.isBefore(before);
          })
          .toList();
      _newestFirst(posts);
      return posts.take(limit).toList(growable: false);
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
