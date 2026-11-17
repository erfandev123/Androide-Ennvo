// ============================================================================
//  ENNVO — USER / FRIEND SERVICE
//
//  The follow graph of the web app:
//
//    users/{uid}/following/{otherUid}  { name, avatar, createdAt }
//    users/{uid}/followers/{otherUid}  { name, avatar, createdAt }
//
//  These collections are what the share sheet, the profile and the
//  "friends" of a reel use. The counters live on the user document.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';
import 'firebase_service.dart';

class UserService {
  const UserService._();

  /// The people [uid] follows, with their profile data.
  static Stream<List<AppUser>> subscribeFollowing(String uid) {
    if (uid.isEmpty || !FirebaseService.isReady) {
      return Stream.value(const <AppUser>[]);
    }
    return FirebaseService.firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap(_loadProfiles);
  }

  /// One-off read of the people [uid] follows.
  static Future<List<AppUser>> following(String uid) async {
    if (uid.isEmpty || !FirebaseService.isReady) return const [];
    try {
      final snapshot = await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      return _profilesOf(snapshot.docs.map((doc) => doc.id).toList());
    } catch (_) {
      return const [];
    }
  }

  /// The people who follow [uid].
  static Stream<List<AppUser>> subscribeFollowers(String uid) {
    if (uid.isEmpty || !FirebaseService.isReady) {
      return Stream.value(const <AppUser>[]);
    }
    return FirebaseService.firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap(_loadProfiles);
  }

  static Future<List<AppUser>> _loadProfiles(QuerySnapshot snapshot) =>
      _profilesOf(snapshot.docs.map((doc) => doc.id).toList());

  static Future<List<AppUser>> _profilesOf(List<String> ids) async {
    final users = <AppUser>[];
    for (final id in ids) {
      try {
        final doc = await FirebaseService.firestore
            .collection('users')
            .doc(id)
            .get();
        if (doc.exists) {
          users.add(AppUser.fromFirestore(doc, fallbackId: id));
        }
      } catch (_) {
        // One missing profile must not hide the rest.
      }
    }
    return users;
  }

  /// Follows [other] as [me].
  static Future<bool> follow({
    required AppUser me,
    required AppUser other,
  }) async {
    if (!FirebaseService.isReady) return false;
    try {
      final batch = FirebaseService.firestore.batch();
      batch.set(
        FirebaseService.firestore
            .collection('users')
            .doc(me.uid)
            .collection('following')
            .doc(other.uid),
        {
          'uid': other.uid,
          'name': other.name,
          'avatar': other.avatar,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        FirebaseService.firestore
            .collection('users')
            .doc(other.uid)
            .collection('followers')
            .doc(me.uid),
        {
          'uid': me.uid,
          'name': me.name,
          'avatar': me.avatar,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      batch.update(FirebaseService.firestore.collection('users').doc(me.uid), {
        'followingCount': FieldValue.increment(1),
      });
      batch.update(
        FirebaseService.firestore.collection('users').doc(other.uid),
        {'followersCount': FieldValue.increment(1)},
      );
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops following [otherId].
  static Future<bool> unfollow({
    required String myId,
    required String otherId,
  }) async {
    if (!FirebaseService.isReady) return false;
    try {
      final batch = FirebaseService.firestore.batch();
      batch.delete(
        FirebaseService.firestore
            .collection('users')
            .doc(myId)
            .collection('following')
            .doc(otherId),
      );
      batch.delete(
        FirebaseService.firestore
            .collection('users')
            .doc(otherId)
            .collection('followers')
            .doc(myId),
      );
      batch.update(FirebaseService.firestore.collection('users').doc(myId), {
        'followingCount': FieldValue.increment(-1),
      });
      batch.update(
        FirebaseService.firestore.collection('users').doc(otherId),
        {'followersCount': FieldValue.increment(-1)},
      );
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether [myId] follows [otherId].
  static Future<bool> isFollowing(String myId, String otherId) async {
    if (myId.isEmpty || !FirebaseService.isReady) return false;
    try {
      final doc = await FirebaseService.firestore
          .collection('users')
          .doc(myId)
          .collection('following')
          .doc(otherId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}
