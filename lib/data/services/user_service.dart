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

import '../models/firestore_parse.dart';
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
        .snapshots()
        .asyncMap(_loadProfilesFromSubcollection);
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
      return _loadProfilesFromSubcollection(snapshot);
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
        .snapshots()
        .asyncMap(_loadProfilesFromSubcollection);
  }

  /// Searches users by name or username.
  static Future<List<AppUser>> searchUsers(
    String query, {
    int limit = 25,
  }) async {
    if (!FirebaseService.isReady) return const [];
    final q = query.trim().toLowerCase();
    try {
      final snapshot = await FirebaseService.firestore
          .collection('users')
          .limit(80)
          .get();
      final users = snapshot.docs
          .map((doc) => AppUser.fromFirestore(doc, fallbackId: doc.id))
          .where((u) {
            if (q.isEmpty) return true;
            return u.name.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.bio.toLowerCase().contains(q);
          })
          .toList(growable: false);
      return users.take(limit).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// The profiles of a list of uids, in the same order. Missing documents
  /// are skipped.
  static Future<List<AppUser>> profiles(List<String> ids) => _profilesOf(ids);

  static Future<List<AppUser>> _loadProfilesFromSubcollection(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
      snapshot.docs,
    );
    sortedDocs.sort((a, b) {
      final aMs =
          parseDateTime(a.data()['createdAt'])?.millisecondsSinceEpoch ?? 0;
      final bMs =
          parseDateTime(b.data()['createdAt'])?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });

    final results = await Future.wait(
      sortedDocs.map((edgeDoc) async {
        final edge = edgeDoc.data();
        final id = (edge['uid'] as String?) ?? edgeDoc.id;
        try {
          final doc = await FirebaseService.firestore
              .collection('users')
              .doc(id)
              .get();
          if (doc.exists) {
            return AppUser.fromFirestore(doc, fallbackId: id);
          }
        } catch (_) {}
        final edgeName = (edge['name'] as String?) ?? '';
        final edgeAvatar = (edge['avatar'] as String?) ?? '';
        if (edgeName.isEmpty && edgeAvatar.isEmpty) return null;
        return AppUser(
          uid: id,
          name: edgeName.isEmpty ? 'User' : edgeName,
          username: (edge['username'] as String?) ?? '',
          email: '',
          avatar: edgeAvatar,
          bio: '',
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
        );
      }),
    );

    return results.whereType<AppUser>().toList(growable: false);
  }

  static Future<List<AppUser>> _profilesOf(List<String> ids) async {
    final results = await Future.wait(
      ids.map((id) async {
        try {
          final doc = await FirebaseService.firestore
              .collection('users')
              .doc(id)
              .get();
          if (doc.exists) {
            return AppUser.fromFirestore(doc, fallbackId: id);
          }
        } catch (_) {}
        return null;
      }),
    );
    return results.whereType<AppUser>().toList(growable: false);
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
