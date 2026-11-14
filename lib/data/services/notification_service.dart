// ============================================================================
//  ENNVO — NOTIFICATION SERVICE
//
//  Ports `src/services/notificationService.ts`.
//
//  Notifications live in a *subcollection* — `notifications/{uid}/items/{id}`
//  — not in a top level collection.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification.dart';
import 'firebase_service.dart';

class NotificationService {
  const NotificationService._();

  /// Subscribes to the activity of one user.
  static Stream<List<AppNotification>> subscribeNotifications(String userId) {
    if (!FirebaseService.isReady || userId.isEmpty) {
      return Stream.value(const <AppNotification>[]);
    }

    return FirebaseService.firestore
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AppNotification.fromFirestore).toList(
                growable: false,
              ),
        );
  }

  /// Marks every notification as read.
  static Future<void> markAllRead(String userId) async {
    if (!FirebaseService.isReady || userId.isEmpty) return;
    try {
      final snapshot = await FirebaseService.firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .get();
      final batch = FirebaseService.firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {
      // A failed "mark as read" must never interrupt the feed.
    }
  }

  /// Creates a notification for a user.
  static Future<void> send({
    required String userId,
    required String actorId,
    required String actorName,
    required String actorAvatar,
    required String type,
    required String targetId,
    String? content,
    String? postId,
    String? postMedia,
  }) async {
    if (!FirebaseService.isReady || userId.isEmpty) return;
    if (userId == actorId) return; // never notify yourself
    try {
      await FirebaseService.firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .add({
            'actorId': actorId,
            'actorName': actorName,
            'actorAvatar': actorAvatar,
            'type': type,
            'targetId': targetId,
            'content': content,
            'postId': postId,
            'postMedia': postMedia,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      // Notifications are best effort.
    }
  }
}
