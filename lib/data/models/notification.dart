// ============================================================================
//  ENNVO — NOTIFICATION MODEL
//
//  A direct port of the `Notification` interface in `src/types/index.ts`.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  follow,
  mention,
  reply,
  favorite,
  commentLike,
  repost,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.actorAvatar,
    required this.targetId,
    required this.isRead,
    this.postId,
    this.postMedia,
    this.postAuthorId,
    this.postAuthorName,
    this.postAuthorAvatar,
    this.content,
    this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String actorId;
  final String actorName;
  final String actorAvatar;
  final String targetId;
  final bool isRead;
  final String? postId;
  final String? postMedia;
  final String? postAuthorId;
  final String? postAuthorName;
  final String? postAuthorAvatar;
  final String? content;
  final DateTime? createdAt;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: switch (data['type'] as String?) {
        'like' => NotificationType.like,
        'comment' => NotificationType.comment,
        'follow' => NotificationType.follow,
        'mention' => NotificationType.mention,
        'reply' => NotificationType.reply,
        'favorite' => NotificationType.favorite,
        'comment_like' => NotificationType.commentLike,
        'repost' => NotificationType.repost,
        _ => NotificationType.like,
      },
      actorId: (data['actorId'] as String?) ?? '',
      actorName: (data['actorName'] as String?) ?? '',
      actorAvatar: (data['actorAvatar'] as String?) ?? '',
      targetId: (data['targetId'] as String?) ?? '',
      isRead: data['isRead'] as bool? ?? false,
      postId: data['postId'] as String?,
      postMedia: data['postMedia'] as String?,
      postAuthorId: data['postAuthorId'] as String?,
      postAuthorName: data['postAuthorName'] as String?,
      postAuthorAvatar: data['postAuthorAvatar'] as String?,
      content: data['content'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// The sentence shown under the actor's name, matching the web app's
  /// `activityText.ts` helper.
  String get activityText => switch (type) {
    NotificationType.like => 'liked your post',
    NotificationType.comment => 'commented: $content',
    NotificationType.follow => 'started following you',
    NotificationType.mention => 'mentioned you in a post',
    NotificationType.reply => 'replied to your comment',
    NotificationType.favorite => 'saved your post',
    NotificationType.commentLike => 'liked your comment',
    NotificationType.repost => 'reposted your post',
  };
}
