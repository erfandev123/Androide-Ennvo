// ============================================================================
//  ENNVO — POST MODEL
//
//  A direct port of the `Post` interface in `src/types/index.ts`.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { post, reel, text }

enum PostPrivacy { public, followers, private }

class AppPost {
  const AppPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.text,
    required this.media,
    required this.type,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    this.authorUsername,
    this.repostsCount = 0,
    this.viewsCount = 0,
    this.favoritesCount = 0,
    this.songId,
    this.songTitle,
    this.songArtist,
    this.songUrl,
    this.privacy = PostPrivacy.public,
    this.category,
    this.aspectRatioFit,
    this.thumbnailUrl,
    this.isPromoted = false,
    this.isPinned = false,
    this.isFeatured = false,
    this.status,
    this.location,
    this.taggedUsers = const [],
    this.mediaTypes = const [],
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String? authorUsername;
  final String text;
  final List<String> media;
  final PostType type;
  final int likesCount;
  final int commentsCount;
  final int repostsCount;
  final int viewsCount;
  final int favoritesCount;
  final DateTime? createdAt;

  final String? songId;
  final String? songTitle;
  final String? songArtist;
  final String? songUrl;

  final PostPrivacy privacy;
  final String? category;
  final String? aspectRatioFit;
  final String? thumbnailUrl;
  final bool isPromoted;
  final bool isPinned;
  final bool isFeatured;
  final String? status;
  final String? location;
  final List<String> taggedUsers;

  /// The type of every media item — `video` or `image`.
  ///
  /// The web app stores it in `mediaDetails`, and it is what tells a photo
  /// post from a video post when the file name says nothing.
  final List<String> mediaTypes;

  bool get isReel => type == PostType.reel;

  /// Whether the first media item is a picture rather than a video.
  ///
  /// A reel is always a video — that is the rule the web app uses in
  /// `ReelItem.tsx`. A regular post may carry a photo, and handing a photo
  /// to the video player is what left the feed with a black rectangle.
  bool get mediaIsImage {
    if (type == PostType.reel) return false;
    if (media.isEmpty) return false;
    if (mediaTypes.isNotEmpty &&
        mediaTypes.first.toLowerCase().contains('video')) {
      return false;
    }
    return !_looksLikeVideo(media.first);
  }

  /// The video of the post, if it has one.
  String? get videoUrl {
    if (media.isEmpty) return null;
    if (mediaIsImage) return null;
    return media.first;
  }

  static bool _looksLikeVideo(String url) {
    final lower = url.toLowerCase();

    // The extensions the web app recognises.
    if (RegExp(r'\.(mp4|webm|mov|m4v|ogg|3gp)($|#|\?)').hasMatch(lower)) {
      return true;
    }
    // Reels are always stored under /reels/.
    if (lower.contains('/reels/')) return true;
    // A lot of the media lives behind a path that says "video".
    if (lower.contains('video')) return true;
    return false;
  }

  factory AppPost.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? fallbackId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final type = switch (data['type'] as String?) {
      'reel' => PostType.reel,
      'text' => PostType.text,
      _ => PostType.post,
    };
    final privacy = switch (data['privacy'] as String?) {
      'followers' => PostPrivacy.followers,
      'private' => PostPrivacy.private,
      _ => PostPrivacy.public,
    };

    return AppPost(
      id: (data['id'] as String?) ?? doc.id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorAvatar: (data['authorAvatar'] as String?) ?? '',
      authorUsername: data['authorUsername'] as String?,
      text: (data['text'] as String?) ?? '',
      media: (data['media'] as List?)?.whereType<String>().toList() ?? const [],
      type: type,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      repostsCount: (data['repostsCount'] as num?)?.toInt() ?? 0,
      viewsCount: (data['viewsCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (data['favoritesCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      songId: data['songId'] as String?,
      songTitle: data['songTitle'] as String?,
      songArtist: data['songArtist'] as String?,
      songUrl: data['songUrl'] as String?,
      privacy: privacy,
      category: data['category'] as String?,
      aspectRatioFit: data['aspectRatioFit'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      isPromoted: data['isPromoted'] as bool? ?? false,
      isPinned: data['isPinned'] as bool? ?? false,
      isFeatured: data['isFeatured'] as bool? ?? false,
      status: data['status'] as String?,
      location: data['location'] as String?,
      taggedUsers:
          (data['taggedUsers'] as List?)?.whereType<String>().toList() ?? const [],
      mediaTypes: [
        for (final detail in (data['mediaDetails'] as List?) ?? const [])
          if (detail is Map && detail['type'] is String) detail['type'] as String,
      ],
    );
  }

  /// The ranking score used by the web app's reel feed:
  ///
  ///   score = (seen ? 0 : 500) + likes*1.5 + comments*3 + views*0.1
  ///           + (id.charCodeAt(0) % 30)
  ///
  /// Unseen content is pushed to the front so the user always sees
  /// something new.
  double rankScore(Set<String> seenIds) {
    final base = seenIds.contains(id) ? 0.0 : 500.0;
    final jitter = id.isEmpty ? 0.0 : (id.codeUnitAt(0) % 30).toDouble();
    return base +
        (likesCount * 1.5) +
        (commentsCount * 3) +
        (viewsCount * 0.1) +
        jitter;
  }
}
