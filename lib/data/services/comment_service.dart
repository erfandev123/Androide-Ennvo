// ============================================================================
//  ENNVO — COMMENT SERVICE
//
//  The comments of a post live in `posts/{postId}/comments`, exactly like
//  the web app writes them in `src/services/postService.ts`.
//
//    • a comment is a document with the author, the text and the time
//    • a reply carries the id of the comment it answers in `parentId`
//    • a like is a document in `comments/{commentId}/likes/{userId}`
//
//  Every method is quiet about failures: a comment that cannot be written
//  must never take the sheet down with it.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/reels/models/reel_comment.dart';
import 'firebase_service.dart';

class CommentService {
  const CommentService._();

  /// The collection that holds the comments of a post.
  static CollectionReference<Map<String, dynamic>> _collection(String postId) {
    return FirebaseService.firestore
        .collection('posts')
        .doc(postId)
        .collection('comments');
  }

  /// Subscribes to the comments of a post, oldest first.
  ///
  /// The replies are folded into their comment, the way the sheet draws
  /// them.
  static Stream<List<ReelComment>> subscribe(String postId) {
    if (!FirebaseService.isReady) return Stream.value(const <ReelComment>[]);

    return _collection(postId)
        .limit(120)
        .snapshots()
        .map((snapshot) => group(snapshot.docs, postId: postId));
  }

  /// Folds the replies into the comment they answer.
  static List<ReelComment> group(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String postId,
  }) {
    final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(docs);
    sortedDocs.sort((a, b) {
      final aComment = ReelComment.fromFirestore(a);
      final bComment = ReelComment.fromFirestore(b);
      final aMs = aComment.createdAt?.millisecondsSinceEpoch ?? 0;
      final bMs = bComment.createdAt?.millisecondsSinceEpoch ?? 0;
      return aMs.compareTo(bMs);
    });

    final byId = <String, ReelComment>{};
    final replies = <String, List<ReelComment>>{};

    for (final doc in sortedDocs) {
      final comment = ReelComment.fromFirestore(doc);
      byId[comment.id] = comment;
    }

    for (final doc in sortedDocs) {
      final data = doc.data();
      final parentId = (data['parentId'] ?? data['replyToId']) as String?;
      if (parentId == null || parentId.isEmpty) continue;
      final child = byId[doc.id];
      if (child == null) continue;
      replies.putIfAbsent(parentId, () => <ReelComment>[]).add(child);
    }

    final roots = <ReelComment>[];
    for (final doc in sortedDocs) {
      final comment = byId[doc.id];
      if (comment == null) continue;
      final data = doc.data();
      final parentId = (data['parentId'] ?? data['replyToId']) as String?;
      if (parentId != null && parentId.isNotEmpty) continue;
      final own = replies[comment.id] ?? const <ReelComment>[];
      roots.add(comment.copyWith(replies: own));
    }
    return roots;
  }

  /// Writes a comment — or a reply to a comment.
  ///
  /// A comment can be a text, a sticker, a photo or a voice note: the kind
  /// and the file it carries travel with it.
  static Future<bool> add({
    required String postId,
    required String text,
    required String authorId,
    required String authorName,
    required String authorAvatar,
    String? parentId,
    String kind = 'text',
    String? mediaUrl,
    int? audioDuration,
  }) async {
    if (!FirebaseService.isReady) return false;
    if (text.trim().isEmpty && (mediaUrl == null || mediaUrl.isEmpty)) {
      return false;
    }
    try {
      await _collection(postId).add({
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'text': text.trim(),
        'kind': kind,
        'mediaUrl': mediaUrl,
        'audioDuration': audioDuration,
        'createdAt': FieldValue.serverTimestamp(),
        'parentId': parentId,
        'likesCount': 0,
      });

      // The counter on the post follows along.
      await FirebaseService.firestore
          .collection('posts')
          .doc(postId)
          .update({'commentsCount': FieldValue.increment(1)});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggles the like on a comment and returns the new state.
  static Future<bool?> toggleLike({
    required String postId,
    required String commentId,
    required String userId,
    required bool currentlyLiked,
  }) async {
    if (!FirebaseService.isReady) return null;
    try {
      final like = _collection(postId).doc(commentId).collection('likes').doc(userId);
      if (currentlyLiked) {
        await like.delete();
      } else {
        await like.set({'userId': userId, 'createdAt': FieldValue.serverTimestamp()});
      }
      await _collection(postId).doc(commentId).update({
        'likesCount': FieldValue.increment(currentlyLiked ? -1 : 1),
      });
      return !currentlyLiked;
    } catch (_) {
      return null;
    }
  }

  /// Removes a comment.
  static Future<bool> delete({
    required String postId,
    required String commentId,
  }) async {
    if (!FirebaseService.isReady) return false;
    try {
      await _collection(postId).doc(commentId).delete();
      await FirebaseService.firestore
          .collection('posts')
          .doc(postId)
          .update({'commentsCount': FieldValue.increment(-1)});
      return true;
    } catch (_) {
      return false;
    }
  }
}
