// ============================================================================
//  ENNVO — REEL ACTIVITIES
//
//  The floating pictures above the name of a reel.
//
//  The web app reads `posts/{id}/likes` and `posts/{id}/reposts` and only
//  shows an activity when the person is somebody the viewer follows (or
//  the viewer themself). A stranger's like never floats over the reel.
//
//  Every repost is shown; a like is shown only for a friend. That is the
//  rule that makes the reel feel personal.
// ============================================================================

import 'dart:async';

import 'package:async/async.dart' show StreamZip;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/reels/widgets/reel_card.dart';
import '../models/user.dart';
import 'firebase_service.dart';

class ReelInteractionService {
  const ReelInteractionService._();

  static Stream<List<ReelActivity>> subscribeFriendActivities({
    required String postId,
    required Set<String> friendIds,
    required String currentUserId,
  }) {
    if (postId.isEmpty || !FirebaseService.isReady) {
      return Stream.value(const <ReelActivity>[]);
    }

    final likes = FirebaseService.firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .limit(6)
        .snapshots();

    final reposts = FirebaseService.firestore
        .collection('posts')
        .doc(postId)
        .collection('reposts')
        .limit(6)
        .snapshots();

    return StreamZip([likes, reposts]).asyncMap((snapshots) async {
      final seen = <String>{};
      final activities = <ReelActivity>[];

      // Reposts first, the way the web app orders them.
      for (final doc in snapshots[1].docs) {
        final uid = _uidOf(doc);
        if (uid.isEmpty || uid == currentUserId) continue;
        if (!friendIds.contains(uid)) continue;
        if (!seen.add(uid)) continue;
        final user = await _user(uid);
        activities.add(
          ReelActivity(
            id: uid.hashCode,
            name: user?.name ?? (doc.get('name') as String? ?? ''),
            avatarUrl: user?.avatar ?? (doc.get('avatar') as String? ?? ''),
            kind: 'repost',
            persistent: true,
          ),
        );
      }

      for (final doc in snapshots[0].docs) {
        final uid = _uidOf(doc);
        if (uid.isEmpty || uid == currentUserId) continue;
        if (!friendIds.contains(uid)) continue;
        if (!seen.add(uid)) continue;
        final user = await _user(uid);
        activities.add(
          ReelActivity(
            id: uid.hashCode,
            name: user?.name ?? (doc.get('name') as String? ?? ''),
            avatarUrl: user?.avatar ?? (doc.get('avatar') as String? ?? ''),
            kind: 'like',
            persistent: true,
          ),
        );
      }

      return activities.take(3).toList(growable: false);
    });
  }

  static String _uidOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return (data['uid'] as String?) ?? doc.id;
  }

  static Future<AppUser?> _user(String uid) async {
    try {
      final doc = await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc, fallbackId: uid);
    } catch (_) {
      return null;
    }
  }
}
