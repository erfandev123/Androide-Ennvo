// ============================================================================
//  ENNVO — REEL COMMENT MODEL + SERVICE
//
//  Ports the comment model of `src/types/index.ts` and the comment parts of
//  `src/services/postService.ts`.
//
//  A comment can be a text, a sticker, a photo or a voice note, and it can
//  carry replies — which is what the comments sheet renders.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/firestore_parse.dart';

enum CommentKind { text, sticker, photo, voice, video, reel }

class ReelComment {
  const ReelComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.mediaUrl,
    this.audioDuration,
    this.likesCount = 0,
    this.isLiked = false,
    this.replyToId,
    this.replyToName,
    this.replies = const [],
    this.isOwn = false,
    this.isPending = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final CommentKind kind;
  final String text;
  final DateTime? createdAt;
  final String? mediaUrl;
  final int? audioDuration;
  final int likesCount;
  final bool isLiked;
  final String? replyToId;
  final String? replyToName;
  final List<ReelComment> replies;
  final bool isOwn;
  final bool isPending;

  ReelComment copyWith({
    int? likesCount,
    bool? isLiked,
    List<ReelComment>? replies,
    String? text,
  }) {
    return ReelComment(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      kind: kind,
      text: text ?? this.text,
      createdAt: createdAt,
      mediaUrl: mediaUrl,
      audioDuration: audioDuration,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      replyToId: replyToId,
      replyToName: replyToName,
      replies: replies ?? this.replies,
      isOwn: isOwn,
      isPending: isPending,
    );
  }

  /// The relative time shown next to the comment.
  String get relativeTime => formatRelativeTime(createdAt);

  /// `Just now`, `5m`, `2h`, `3d`, then a date.
  static String formatRelativeTime(DateTime? time) {
    if (time == null) return '';
    final delta = DateTime.now().difference(time);
    if (delta.inSeconds < 30) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    if (delta.inDays < 7) return '${delta.inDays}d';
    return '${delta.inDays ~/ 7}w';
  }

  factory ReelComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool isOwn = false,
    bool isLiked = false,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ReelComment(
      id: doc.id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorAvatar: (data['authorAvatar'] as String?) ?? '',
      kind: switch (data['kind'] as String?) {
        'sticker' => CommentKind.sticker,
        'photo' => CommentKind.photo,
        'voice' => CommentKind.voice,
        'video' => CommentKind.video,
        'reel' => CommentKind.reel,
        _ => CommentKind.text,
      },
      text: (data['text'] as String?) ?? '',
      createdAt: parseDateTime(data['createdAt']),
      mediaUrl: data['mediaUrl'] as String?,
      audioDuration: (data['audioDuration'] as num?)?.toInt(),
      likesCount: parseInt(data['likesCount']),
      isLiked: isLiked,
      replyToId: (data['replyToId'] ?? data['parentId']) as String?,
      replyToName: data['replyToName'] as String?,
      isOwn: isOwn,
    );
  }
}

/// Formats a count the way the app does: `1.2K`, `3.4M`.
String formatCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
  }
  return '$count';
}

/// The demo comments used by the comments sheet when a reel has none.
List<ReelComment> demoComments(String reelId) {
  final now = DateTime.now();
  return [
    ReelComment(
      id: '$reelId-c1',
      authorId: 'demo-1',
      authorName: 'Arif Hasan',
      authorAvatar: '',
      kind: CommentKind.text,
      text: 'ওয়াও, আলোটা কী সুন্দর! 😍',
      createdAt: now.subtract(const Duration(hours: 2)),
      likesCount: 128,
      replies: [
        ReelComment(
          id: '$reelId-c1-r1',
          authorId: 'demo-2',
          authorName: 'Nila Rahman',
          authorAvatar: '',
          kind: CommentKind.text,
          text: 'ধন্যবাদ ভাই 💖',
          createdAt: now.subtract(const Duration(hours: 1)),
          likesCount: 12,
          replyToId: '$reelId-c1',
          replyToName: 'Arif Hasan',
        ),
      ],
    ),
    ReelComment(
      id: '$reelId-c2',
      authorId: 'demo-3',
      authorName: 'Tania Akter',
      authorAvatar: '',
      kind: CommentKind.sticker,
      text: '🔥',
      createdAt: now.subtract(const Duration(hours: 3)),
      likesCount: 54,
    ),
    ReelComment(
      id: '$reelId-c3',
      authorId: 'demo-4',
      authorName: 'Rafi Ahmed',
      authorAvatar: '',
      kind: CommentKind.text,
      text: 'Location ta kothay bhai?',
      createdAt: now.subtract(const Duration(hours: 5)),
      likesCount: 9,
    ),
    ReelComment(
      id: '$reelId-c4',
      authorId: 'demo-5',
      authorName: 'Mim',
      authorAvatar: '',
      kind: CommentKind.text,
      text: 'Mood ✨',
      createdAt: now.subtract(const Duration(hours: 6)),
      likesCount: 3,
    ),
  ];
}
