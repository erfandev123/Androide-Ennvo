// ============================================================================
//  ENNVO — MESSAGE + CONVERSATION MODELS
//
//  A direct port of the `Message` and `Conversation` interfaces in
//  `src/types/index.ts`.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parse.dart';

enum MessageType {
  text,
  image,
  video,
  voice,
  reel,
  sticker,
  system,
  album,
}

enum MessageStatus { sending, sent, delivered, seen }

class ReplyPreview {
  const ReplyPreview({required this.id, required this.text, required this.authorName});

  final String id;
  final String text;
  final String authorName;

  factory ReplyPreview.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ReplyPreview(id: '', text: '', authorName: '');
    return ReplyPreview(
      id: (data['id'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
    );
  }
}

class AppMessage {
  const AppMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.content,
    required this.createdAt,
    this.mediaUrl,
    this.mediaUrls = const [],
    this.mediaItems = const [],
    this.stickerUrl,
    this.stickerType,
    this.postId,
    this.status = MessageStatus.sent,
    this.voiceDuration,
    this.reaction,
    this.replyTo,
  });

  final String id;
  final String senderId;
  final MessageType type;
  final String content;
  final DateTime? createdAt;
  final String? mediaUrl;
  final List<String> mediaUrls;
  final List<({String type, String url})> mediaItems;
  final String? stickerUrl;
  final String? stickerType;
  final String? postId;
  final MessageStatus status;
  final int? voiceDuration;
  final String? reaction;
  final ReplyPreview? replyTo;

  factory AppMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppMessage.fromMap(data, id: doc.id);
  }

  factory AppMessage.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    final rawItems = data['mediaItems'] as List?;

    return AppMessage(
      id: id.isNotEmpty ? id : ((data['id'] as String?) ?? ''),
      senderId: (data['senderId'] as String?) ?? '',
      type: switch (data['type'] as String?) {
        'image' => MessageType.image,
        'video' => MessageType.video,
        'voice' => MessageType.voice,
        'reel' => MessageType.reel,
        'sticker' => MessageType.sticker,
        'system' => MessageType.system,
        'album' => MessageType.album,
        _ => MessageType.text,
      },
      content: (data['content'] as String?) ?? '',
      createdAt: parseDateTime(data['createdAt']),
      mediaUrl: data['mediaUrl'] as String?,
      mediaUrls: parseStringList(data['mediaUrls']),
      mediaItems:
          rawItems
              ?.whereType<Map>()
              .map(
                (item) => (
                  type: (item['type'] as String?) ?? 'image',
                  url: (item['url'] as String?) ?? '',
                ),
              )
              .toList() ??
          const [],
      stickerUrl: data['stickerUrl'] as String?,
      stickerType: data['stickerType'] as String?,
      postId: data['postId'] as String?,
      status: switch (data['status'] as String?) {
        'sending' => MessageStatus.sending,
        'delivered' => MessageStatus.delivered,
        'seen' => MessageStatus.seen,
        _ => MessageStatus.sent,
      },
      voiceDuration: (data['voiceDuration'] as num?)?.toInt(),
      reaction: data['reaction'] as String?,
      replyTo: data['replyTo'] is Map
          ? ReplyPreview.fromMap(
              Map<String, dynamic>.from(data['replyTo'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toFirestore(String clientId) => {
    'id': clientId,
    'senderId': senderId,
    'type': type.name,
    'content': content,
    'status': status.name,
    'createdAt': FieldValue.serverTimestamp(),
    if (mediaUrl != null) 'mediaUrl': mediaUrl,
    if (mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
    if (stickerUrl != null) 'stickerUrl': stickerUrl,
    if (postId != null) 'postId': postId,
    if (voiceDuration != null) 'voiceDuration': voiceDuration,
    if (replyTo != null)
      'replyTo': {
        'id': replyTo!.id,
        'text': replyTo!.text,
        'authorName': replyTo!.authorName,
      },
  };
}

class Conversation {
  const Conversation({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    required this.unreadCount,
    this.participantNames = const {},
    this.participantAvatars = const {},
    this.updatedAt,
    this.typing = const {},
    this.theme,
    this.isGroup = false,
    this.groupName,
    this.groupAvatar,
    this.isRequest = false,
    this.requestTo,
    this.requestFrom,
    this.requestStatus,
    this.requestMessageCount,
  });

  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String> participantAvatars;
  final String lastMessage;
  final Map<String, int> unreadCount;
  final DateTime? updatedAt;
  final Map<String, bool> typing;
  final String? theme;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final bool isRequest;
  final String? requestTo;
  final String? requestFrom;
  final String? requestStatus;
  final int? requestMessageCount;

  /// The direct conversation id for two users is derived from their sorted
  /// ids, so the same pair always maps to the same document.
  static String directId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  factory Conversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Conversation.fromMap(data, id: doc.id);
  }

  factory Conversation.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    Map<String, String> stringMap(String key) {
      final raw = data[key] as Map?;
      if (raw == null) return const {};
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }

    Map<String, int> intMap(String key) {
      final raw = data[key] as Map?;
      if (raw == null) return const {};
      return raw.map((k, v) => MapEntry(k.toString(), parseInt(v)));
    }

    Map<String, bool> boolMap(String key) {
      final raw = data[key] as Map?;
      if (raw == null) return const {};
      return raw.map((k, v) => MapEntry(k.toString(), v == true));
    }

    final names = Map<String, String>.of(stringMap('participantNames'));
    final avatars = Map<String, String>.of(stringMap('participantAvatars'));
    final ids = List<String>.of(parseStringList(data['participantIds']));

    // Web app conversations may store `{ participants: { uid: { name, avatar } } }`
    final participantsRaw = data['participants'] as Map?;
    if (participantsRaw != null) {
      participantsRaw.forEach((rawKey, rawVal) {
        final pid = rawKey.toString();
        if (pid.isEmpty) return;
        if (!ids.contains(pid)) ids.add(pid);
        if (rawVal is Map) {
          final pName = (rawVal['name'] ?? rawVal['displayName'])?.toString();
          final pAvatar = (rawVal['avatar'] ?? rawVal['photoURL'])?.toString();
          if ((names[pid] ?? '').isEmpty && pName != null && pName.isNotEmpty) {
            names[pid] = pName;
          }
          if ((avatars[pid] ?? '').isEmpty &&
              pAvatar != null &&
              pAvatar.isNotEmpty) {
            avatars[pid] = pAvatar;
          }
        }
      });
    }

    return Conversation(
      id: id.isNotEmpty ? id : ((data['id'] as String?) ?? ''),
      participantIds: ids,
      participantNames: names,
      participantAvatars: avatars,
      lastMessage: (data['lastMessage'] as String?) ?? '',
      unreadCount: intMap('unreadCount'),
      updatedAt: parseDateTime(data['updatedAt']),
      typing: boolMap('typing'),
      theme: data['theme'] as String?,
      isGroup: data['isGroup'] == true,
      groupName: data['groupName'] as String?,
      groupAvatar: data['groupAvatar'] as String?,
      isRequest: data['isRequest'] == true,
      requestTo: data['requestTo'] as String?,
      requestFrom: data['requestFrom'] as String?,
      requestStatus: data['requestStatus'] as String?,
      requestMessageCount: (data['requestMessageCount'] as num?)?.toInt(),
    );
  }

  /// The display name of the conversation.
  String displayName(String currentUserId) {
    if (isGroup) return groupName ?? 'Group';
    final other = participantIds
        .where((id) => id != currentUserId)
        .firstOrNull;
    if (other == null) return 'Unknown';
    final name = participantNames[other];
    if (name == null || name.isEmpty) return 'Unknown';
    return name;
  }

  /// The avatar of the conversation.
  String displayAvatar(String currentUserId) {
    if (isGroup) return groupAvatar ?? '';
    final other = participantIds
        .where((id) => id != currentUserId)
        .firstOrNull;
    if (other == null) return '';
    return participantAvatars[other] ?? '';
  }

  int unreadFor(String currentUserId) => unreadCount[currentUserId] ?? 0;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
