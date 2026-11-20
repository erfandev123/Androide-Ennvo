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
  ///
  /// Sorted client-side by `updatedAt` descending and deduplicated per direct
  /// peer so an id never appears multiple times in the inbox list.
  static Stream<List<Conversation>> subscribeConversations(String userId) {
    if (!FirebaseService.isReady || userId.isEmpty) {
      return Stream.value(const <Conversation>[]);
    }

    return FirebaseService.firestore
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .limit(80)
        .snapshots()
        .map(
          (snapshot) => deduplicateConversations(
            snapshot.docs
                .map(Conversation.fromFirestore)
                .toList(growable: false),
            userId,
          ),
        );
  }

  /// Deduplicates 1:1 direct conversations by peer user id, merging metadata
  /// and keeping the richest/newest record first.
  static List<Conversation> deduplicateConversations(
    List<Conversation> raw,
    String currentUserId,
  ) {
    final sorted = List<Conversation>.of(raw)
      ..sort((a, b) {
        final aMs = a.updatedAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.updatedAt?.millisecondsSinceEpoch ?? 0;
        if (aMs != bMs) return bMs.compareTo(aMs);
        final aHasMsg = a.lastMessage.trim().isNotEmpty ? 1 : 0;
        final bHasMsg = b.lastMessage.trim().isNotEmpty ? 1 : 0;
        return bHasMsg.compareTo(aHasMsg);
      });

    final byKey = <String, Conversation>{};
    for (final conv in sorted) {
      final peer = conv.isGroup ? null : conv.otherParticipantId(currentUserId);
      final key = (peer != null && peer.isNotEmpty)
          ? 'dm:$peer'
          : 'conv:${conv.id}';
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = conv;
        continue;
      }

      // Merge participant names & avatars and take best non-empty lastMessage
      // while preserving unread counts.
      final mergedNames = <String, String>{...conv.participantNames};
      existing.participantNames.forEach((k, v) {
        if (v.trim().isNotEmpty && v != 'Unknown') {
          mergedNames[k] = v;
        }
      });

      final mergedAvatars = <String, String>{...conv.participantAvatars};
      existing.participantAvatars.forEach((k, v) {
        if (v.trim().isNotEmpty) {
          mergedAvatars[k] = v;
        }
      });

      final mergedUnread = <String, int>{...conv.unreadCount};
      existing.unreadCount.forEach((k, v) {
        final cur = mergedUnread[k] ?? 0;
        if (v > cur) mergedUnread[k] = v;
      });

      final pickExistingPrimary = existing.lastMessage.trim().isNotEmpty ||
          conv.lastMessage.trim().isEmpty;

      final primary = pickExistingPrimary ? existing : conv;
      byKey[key] = Conversation(
        id: primary.id,
        participantIds: primary.participantIds,
        participantNames: mergedNames,
        participantAvatars: mergedAvatars,
        lastMessage: existing.lastMessage.trim().isNotEmpty
            ? existing.lastMessage
            : conv.lastMessage,
        unreadCount: mergedUnread,
        updatedAt: existing.updatedAt ?? conv.updatedAt,
        typing: existing.typing.isNotEmpty ? existing.typing : conv.typing,
        theme: existing.theme ?? conv.theme,
        isGroup: existing.isGroup,
        groupName: existing.groupName ?? conv.groupName,
        groupAvatar: existing.groupAvatar ?? conv.groupAvatar,
        isRequest: existing.isRequest && conv.isRequest,
        requestTo: existing.requestTo ?? conv.requestTo,
        requestFrom: existing.requestFrom ?? conv.requestFrom,
        requestStatus: existing.requestStatus ?? conv.requestStatus,
        requestMessageCount:
            existing.requestMessageCount ?? conv.requestMessageCount,
      );
    }

    final result = byKey.values.toList(growable: false);
    result.sort((a, b) {
      final aMs = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final bMs = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });
    return result;
  }

  /// Creates a direct conversation, or returns the existing one.
  static Future<String> createConversation({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    required String otherUserAvatar,
    String currentUserName = 'You',
    String currentUserAvatar = '',
  }) async {
    final canonicalId = Conversation.directId(currentUserId, otherUserId);

    if (FirebaseService.isReady) {
      // First look for any pre-existing direct thread with this peer so we
      // never create a duplicate conversation document (e.g., auto-ID vs sorted ID).
      try {
        final existingQuery = await FirebaseService.firestore
            .collection('conversations')
            .where('participantIds', arrayContains: currentUserId)
            .limit(80)
            .get();
        for (final doc in existingQuery.docs) {
          final conv = Conversation.fromFirestore(doc);
          if (!conv.isGroup && conv.participantIds.contains(otherUserId)) {
            return doc.id;
          }
        }
      } catch (_) {
        // Fall through to canonical id check.
      }

      final ref = FirebaseService.firestore
          .collection('conversations')
          .doc(canonicalId);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        await ref.set({
          'participantIds': [currentUserId, otherUserId],
          'participantNames': {
            currentUserId: currentUserName,
            otherUserId: otherUserName,
          },
          'participantAvatars': {
            currentUserId: currentUserAvatar,
            otherUserId: otherUserAvatar,
          },
          'lastMessage': '',
          'unreadCount': {currentUserId: 0, otherUserId: 0},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return canonicalId;
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
      return Stream.value(const <AppMessage>[]);
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

  /// Sends a message. Returns `true` when committed, `false` otherwise.
  ///
  /// The document id is a client generated id, so an optimistic local
  /// message and the server copy share the same id and the message does
  /// not flicker when the snapshot arrives.
  static Future<bool> sendMessage({
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
    String? recipientId,
  }) async {
    if (!FirebaseService.isReady) return false;
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

      final summaryText = switch (type) {
        MessageType.image => content.isNotEmpty ? content : 'Sent a photo',
        MessageType.video => content.isNotEmpty ? content : 'Sent a video',
        MessageType.voice => 'Voice message',
        MessageType.sticker => 'Sent a sticker',
        MessageType.reel => 'Shared a reel',
        _ => content.isEmpty ? 'Sent a message' : content,
      };

      final convUpdate = <String, dynamic>{
        'lastMessage': summaryText,
        'lastMessageType': type.name,
        'lastSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (recipientId != null &&
          recipientId.isNotEmpty &&
          recipientId != senderId) {
        convUpdate['unreadCount.$recipientId'] = FieldValue.increment(1);
      }

      batch.update(
        FirebaseService.firestore
            .collection('conversations')
            .doc(conversationId),
        convUpdate,
      );

      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggles or sets an emoji reaction on a message.
  static Future<bool> reactToMessage({
    required String conversationId,
    required String messageId,
    required String? reaction,
  }) async {
    if (!FirebaseService.isReady) return false;
    try {
      await FirebaseService.firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'reaction': reaction});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes one message from a conversation.
  static Future<bool> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    if (!FirebaseService.isReady) return false;
    try {
      await FirebaseService.firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (_) {
      return false;
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
