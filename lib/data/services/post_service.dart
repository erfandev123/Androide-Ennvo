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

  /// Subscribes to the main home feed, promoted & newest first.
  ///
  /// Matches the web app (`src/services/postService.ts`): single-field
  /// `orderBy('createdAt')` with NO `.where('type', ...)` filter (which
  /// previously required a composite index and dropped `'text'`/untyped posts).
  static Stream<List<AppPost>> subscribeFeed({int pageSize = 30}) {
    if (!FirebaseService.isReady) return Stream.value(const <AppPost>[]);

    return FirebaseService.firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(pageSize * 2)
        .snapshots()
        .map(
          (snapshot) => sortFeed(
            snapshot.docs
                .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
                .toList(growable: false),
            limit: pageSize,
          ),
        );
  }

  /// Filters out reels/archived posts and orders promoted + newest posts first.
  static List<AppPost> sortFeed(List<AppPost> raw, {int? limit}) {
    final visible = raw
        .where(
          (post) =>
              !post.isReel &&
              post.status != 'deleted' &&
              post.status != 'archived',
        )
        .toList(growable: false);

    visible.sort((a, b) {
      if (a.isPromoted != b.isPromoted) return a.isPromoted ? -1 : 1;
      final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });

    if (limit != null && visible.length > limit) {
      return visible.take(limit).toList(growable: false);
    }
    return visible;
  }

  /// Subscribes to the posts of one user (sorted client-side so no composite
  /// index on `authorId + createdAt` is needed).
  static Stream<List<AppPost>> subscribeUserPosts(
    String userId, {
    int pageSize = 30,
  }) {
    if (!FirebaseService.isReady || userId.isEmpty) {
      return Stream.value(const <AppPost>[]);
    }

    return FirebaseService.firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .limit(pageSize * 2)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
              .where((post) => post.status != 'deleted')
              .toList(growable: false);
          posts.sort((a, b) {
            final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bMs.compareTo(aMs);
          });
          return posts.take(pageSize).toList(growable: false);
        });
  }

  /// Client-side filtered search over recent posts/reels.
  static Future<List<AppPost>> searchPosts(
    String query, {
    int limit = 25,
  }) async {
    if (!FirebaseService.isReady) return const [];
    final q = query.trim().toLowerCase();
    try {
      final snapshot = await FirebaseService.firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(80)
          .get();
      final posts = snapshot.docs
          .map((doc) => AppPost.fromFirestore(doc, fallbackId: doc.id))
          .where((post) {
            if (post.status == 'deleted') return false;
            if (q.isEmpty) return true;
            return post.text.toLowerCase().contains(q) ||
                post.authorName.toLowerCase().contains(q) ||
                (post.authorUsername?.toLowerCase().contains(q) ?? false) ||
                (post.songTitle?.toLowerCase().contains(q) ?? false) ||
                (post.songArtist?.toLowerCase().contains(q) ?? false) ||
                (post.category?.toLowerCase().contains(q) ?? false);
          })
          .toList(growable: false);
      return posts.take(limit).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// The posts the user saved, read from `users/{uid}/favorites`.
  static Future<List<AppPost>> savedPosts(String uid) async {
    if (uid.isEmpty || !FirebaseService.isReady) return const [];
    try {
      final snapshot = await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .get();
      final posts = <AppPost>[];
      for (final doc in snapshot.docs) {
        try {
          final post = await FirebaseService.firestore
              .collection('posts')
              .doc(doc.id)
              .get();
          if (post.exists) {
            posts.add(
              AppPost.fromFirestore(post, fallbackId: doc.id),
            );
          }
        } catch (_) {
          // One missing post must not hide the rest.
        }
      }
      return posts;
    } catch (_) {
      return const [];
    }
  }

  /// Saves a post for later, or takes the save back.
  ///
  /// The saved posts live in `users/{uid}/favorites`, the collection the
  /// saved screen already reads.
  static Future<bool> toggleSave({
    required String postId,
    required String userId,
  }) async {
    if (!FirebaseService.isReady || userId.isEmpty) return false;
    try {
      final ref = FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(postId);
      final snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.delete();
        return false;
      }
      await ref.set({'createdAt': FieldValue.serverTimestamp()});
      return true;
    } catch (_) {
      return false;
    }
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

  /// Writes a new post.
  ///
  /// It is the document the web app writes in `src/services/postService.ts`:
  /// the author, the text, the media and the counters.
  ///
  /// The id is made on the phone, so the post is known before it is on the
  /// server - that is what lets the feed show it at once.
  static Future<String?> create({
    required String id,
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String authorUsername,
    required String text,
    required List<String> media,
    required List<String> mediaTypes,
    required String type,
    String? thumbnailUrl,
    String? songId,
    String? songTitle,
    String? songArtist,
    String privacy = 'public',
    bool commentsDisabled = false,
    bool allowRemix = true,
    bool hideLikes = false,
    bool highQuality = true,
    bool saveToDevice = false,
  }) async {
    if (!FirebaseService.isReady) return null;
    try {
      await FirebaseService.firestore.collection('posts').doc(id).set({
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'authorUsername': authorUsername,
        'text': text,
        'media': media,
        'mediaDetails': [
          for (var i = 0; i < media.length; i++)
            {
              'type': i < mediaTypes.length ? mediaTypes[i] : 'image',
              'url': media[i],
            },
        ],
        'type': type,
        'thumbnailUrl': thumbnailUrl,
        'songId': songId,
        'songTitle': songTitle,
        'songArtist': songArtist,
        'privacy': privacy,
        'commentsDisabled': commentsDisabled,
        'allowRemix': allowRemix,
        'hideLikes': hideLikes,
        'highQuality': highQuality,
        'saveToDevice': saveToDevice,
        'likesCount': 0,
        'commentsCount': 0,
        'repostsCount': 0,
        'favoritesCount': 0,
        'viewsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return id;
    } catch (_) {
      return null;
    }
  }
}
