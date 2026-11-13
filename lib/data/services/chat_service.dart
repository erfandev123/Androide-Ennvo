// ============================================================================
//  ENNVO — CHAT SERVICE
//
//  Ports the parts of `src/services/chatService.ts` the native app needs
//  so far, plus the Realtime Database presence and typing channels from
//  `src/services/presenceService.ts`.
//
//  Firestore layout:
//    conversations/{conversationId}
//    conversations/{conversationId}/messages/{messageId}
//  Realtime Database layout:
//    presence/{userId}          → { isOnline, lastSeen }
//    typing/{conversationId}/{userId} → bool
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/message.dart';
import 'firebase_service.dart';

class ChatService {
  const ChatService._();

  // -------------------------------------------------------------------
  //  Conversations
  // -------------------------------------------------------------------

  /// Subscribes to every conversation the user takes part in.
  static Stream<List<Conversation>> subscribeConversations(String userId) {
    if (!FirebaseService.isReady || userId.isEmpty) {
      return const Stream.empty();
    }

    return FirebaseService.firestore
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .limit(60)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Conversation.fromFirestore).toList(
                growable: false,
              ),
        );
  }

  /// Creates a direct conversation, or returns the existing one.
  static Future<String> createConversation({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    required String otherUserAvatar,
  }) async {
    final id = Conversation.directId(currentUserId, otherUserId);

    if (FirebaseService.isReady) {
      final ref = FirebaseService.firestore
          .collection('conversations')
          .doc(id);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        await ref.set({
          'participantIds': [currentUserId, otherUserId],
          'participantNames': {
            currentUserId: 'You',
            otherUserId: otherUserName,
          },
          'participantAvatars': {
            currentUserId: '',
            otherUserId: otherUserAvatar,
          },
          'lastMessage': '',
          'unreadCount': {currentUserId: 0, otherUserId: 0},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return id;
  }

  // -------------------------------------------------------------------
  //  Messages
  // -------------------------------------------------------------------

  /// Subscribes to the newest messages of a conversation.
  static Stream<List<AppMessage>> subscribeMessages(
    String conversationId, {
    int limit = 40,
  }) {
    if (!FirebaseService.isReady || conversationId.isEmpty) {
      return const Stream.empty();
    }

    return FirebaseService.firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AppMessage.fromFirestore).toList().reversed
                  .toList(growable: false),
        );
  }

  /// Loads an older page of messages.
  static Future<List<AppMessage>> loadOlderMessages({
    required String conversationId,
    required DateTime before,
    int limit = 30,
  }) async {
    if (!FirebaseService.isReady) return const [];
    try {
      final snapshot = await FirebaseService.firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('createdAt', isLessThan: Timestamp.fromDate(before))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map(AppMessage.fromFirestore)
          .toList()
          .reversed
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Sends a message.
  ///
  /// The document id is a client generated id, so an optimistic local
  /// message and the server copy share the same id and the message does
  /// not flicker when the snapshot arrives.
  static Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required MessageType type,
    required String content,
    String? mediaUrl,
    List<String> mediaUrls = const [],
    String? stickerUrl,
    String? postId,
    int? voiceDuration,
    ReplyPreview? replyTo,
  }) async {
    if (!FirebaseService.isReady) return;
    try {
      final batch = FirebaseService.firestore.batch();

      batch.set(
        FirebaseService.firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(messageId),
        {
          'id': messageId,
          'senderId': senderId,
          'type': type.name,
          'content': content,
          'status': 'sent',
          'createdAt': FieldValue.serverTimestamp(),
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
          if (stickerUrl != null) 'stickerUrl': stickerUrl,
          if (postId != null) 'postId': postId,
          if (voiceDuration != null) 'voiceDuration': voiceDuration,
          if (replyTo != null)
            'replyTo': {
              'id': replyTo.id,
              'text': replyTo.text,
              'authorName': replyTo.authorName,
            },
        },
      );

      batch.update(
        FirebaseService.firestore
            .collection('conversations')
            .doc(conversationId),
        {
          'lastMessage': content.isEmpty ? 'Sent a message' : content,
          'lastMessageType': type.name,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (_) {
      // The optimistic message stays on screen with a "sending" status.
    }
  }

  /// Marks every message of a conversation as delivered for one user.
  static Future<void> markDelivered({
    required String conversationId,
    required String userId,
  }) async {
    if (!FirebaseService.isReady) return;
    try {
      final snapshot = await FirebaseService.firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .where('status', isEqualTo: 'sent')
          .limit(50)
          .get();
      final batch = FirebaseService.firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'status': 'delivered'});
      }
      await batch.commit();
    } catch (_) {
      // Best effort.
    }
  }

  /// Marks a conversation as read and clears the unread badge.
  static Future<void> markRead({
    required String conversationId,
    required String userId,
  }) async {
    if (!FirebaseService.isReady) return;
    try {
      await FirebaseService.firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
            'unreadCount.$userId': 0,
            'lastReadAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      // Best effort.
    }
  }

  // -------------------------------------------------------------------
  //  Presence and typing (Realtime Database)
  // -------------------------------------------------------------------

  /// Marks the user as online and releases the flag when the app closes.
  static void setOnline(String userId) {
    if (!FirebaseService.isReady) return;
    try {
      final ref = FirebaseService.database.ref('presence/$userId');
      ref.set({'isOnline': true, 'lastSeen': ServerValue.timestamp});
      ref.onDisconnect().set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (_) {
      // Presence is a nice to have, never a blocker.
    }
  }

  static void setOffline(String userId) {
    if (!FirebaseService.isReady) return;
    try {
      FirebaseService.database.ref('presence/$userId').set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (_) {
      // Ignore.
    }
  }

  /// Watches whether a user is online.
  static Stream<bool> subscribePresence(String userId) {
    if (!FirebaseService.isReady) return const Stream.empty();
    try {
      return FirebaseService.database
          .ref('presence/$userId')
          .onValue
          .map((event) {
            final value = event.snapshot.value;
            return value is Map && value['isOnline'] == true;
          });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Publishes the typing state of a user in a conversation.
  static void setTyping({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) {
    if (!FirebaseService.isReady) return;
    try {
      final ref = FirebaseService.database.ref('typing/$conversationId/$userId');
      if (isTyping) {
        ref.set(true);
        ref.onDisconnect().set(false);
      } else {
        ref.set(false);
      }
    } catch (_) {
      // Ignore.
    }
  }

  /// Watches whether the other participant is typing.
  static Stream<bool> subscribeTyping({
    required String conversationId,
    required String otherUserId,
  }) {
    if (!FirebaseService.isReady) return const Stream.empty();
    try {
      return FirebaseService.database
          .ref('typing/$conversationId/$otherUserId')
          .onValue
          .map((event) => event.snapshot.value == true);
    } catch (_) {
      return const Stream.empty();
    }
  }
}
