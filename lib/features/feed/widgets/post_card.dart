// ============================================================================
//  ENNVO — POST CARD
//
//  A single post in the home feed. Ported from
//  `src/components/PostItem.tsx`.
//
//  Layout:
//    • author row: avatar, name, handle, time, more button
//    • the media card — a squircle (`rounded-[34px]`) that grows with the
//      number of photos: 1 photo fills it, 2 sit side by side, 3 are one
//      large plus two stacked, 4+ collapse into a "+N" overlay
//    • the action row: like, comment, repost, share
//    • the caption with a "See more..." toggle
//    • the song pill with the name of the song
//
//  Interactions:
//    • double tap likes the post and pops a heart
//    • the like and the repost icons spring on a 450 / 18 spring
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/providers.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/post.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../../../shared/widgets/song_marquee.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isLiked,
    required this.isReposted,
    required this.likesCount,
    this.onToggleLike,
    this.onToggleRepost,
    this.onOpenProfile,
    this.onComment,
    this.onShare,
  });

  final AppPost post;
  final bool isLiked;
  final bool isReposted;
  final int likesCount;
  final VoidCallback? onToggleLike;
  final VoidCallback? onToggleRepost;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showHeart = false;
  bool _expandedCaption = false;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  static const int _captionCollapseThreshold = 70;

  void _handleDoubleTap() {
    final now = DateTime.now();
    final delta = now.difference(_lastTap).inMilliseconds;
    _lastTap = now;

    if (delta < 300) {
      if (!widget.isLiked) widget.onToggleLike?.call();
      setState(() => _showHeart = true);
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final post = widget.post;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- author row ------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpenProfile,
                  child: _Avatar(
                    url: post.authorAvatar,
                    name: post.authorName,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onOpenProfile,
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnnvoText.bodySemi.copyWith(
                            color: t.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (post.authorUsername != null)
                        Text(
                          '@${post.authorUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnnvoText.caption.copyWith(
                            color: t.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (post.isPromoted)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: t.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Promoted',
                      style: EnnvoText.tiny.copyWith(
                        color: t.accent,
                        fontSize: 10,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () {},
                  icon: LucideIcon(
                    LucideIcons.moreHorizontal,
                    size: 20,
                    color: t.textSecondary,
                  ),
                  tooltip: 'More options',
                ),
              ],
            ),
          ),

          // --- media ----------------------------------------------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleDoubleTap,
            child: Stack(
              children: [
                _MediaGrid(post: post),
                if (_showHeart)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: EnnvoDurations.doubleTapHeart,
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            final scale = value < 0.4
                                ? Curves.easeOut.transform(value / 0.4) * 1.25
                                : 1.25 -
                                    (Curves.easeIn.transform((value - 0.4) / 0.6)) *
                                        0.25;
                            return Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: value.clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              boxShadow: AppShadows.heart,
                            ),
                            child: const LucideIcon(
                              LucideIcons.heart,
                              size: 48,
                              strokeWidth: 2,
                              filled: true,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // --- action row -----------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _ActionButton(
                  icon: LucideIcon(
                    LucideIcons.heart,
                    size: 20,
                    strokeWidth: 2,
                    filled: widget.isLiked,
                    color: widget.isLiked
                        ? const Color(0xFFF43F5E)
                        : t.textPrimary,
                  ),
                  count: widget.likesCount,
                  onTap: widget.onToggleLike,
                  semanticLabel: 'Like',
                ),
                const SizedBox(width: 22),
                _ActionButton(
                  icon: LucideIcon(
                    LucideIcons.messageCircle,
                    size: 20,
                    strokeWidth: 2,
                    color: t.textPrimary,
                  ),
                  count: post.commentsCount,
                  onTap: widget.onComment,
                  semanticLabel: 'Comment',
                ),
                const SizedBox(width: 22),
                _ActionButton(
                  icon: LucideIcon(
                    LucideIcons.repeat2,
                    size: 20,
                    strokeWidth: 2.2,
                    color: widget.isReposted
                        ? const Color(0xFF3B82F6)
                        : t.textPrimary,
                  ),
                  count: post.repostsCount,
                  onTap: widget.onToggleRepost,
                  semanticLabel: 'Repost',
                ),
                const SizedBox(width: 22),
                _ActionButton(
                  icon: LucideIcon(
                    LucideIcons.share2,
                    size: 20,
                    strokeWidth: 2,
                    color: t.textPrimary,
                  ),
                  onTap: widget.onShare,
                  semanticLabel: 'Share',
                ),
                const Spacer(),
              ],
            ),
          ),

          // --- song ------------------------------------------------------
          // The name of the song travels in a pill under the post, the way
          // the web app writes it. When the post only carries the id of the
          // song, the name is looked up in the `songs` collection.
          _SongBlock(post: post),

          // --- caption ---------------------------------------------------
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _expandedCaption = !_expandedCaption),
                    child: Text(
                      post.text,
                      maxLines: _expandedCaption ? null : 3,
                      overflow: _expandedCaption
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: EnnvoText.body.copyWith(color: t.textPrimary),
                    ),
                  ),
                  if (post.text.length > _captionCollapseThreshold)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _expandedCaption = !_expandedCaption),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          _expandedCaption ? 'See less' : 'See more...',
                          style: EnnvoText.seeMore.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
//  Media — 1, 2, 3 or 4+ photos
// ============================================================================
class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.post});

  final AppPost post;

  @override
  Widget build(BuildContext context) {
    final media = post.media;

    if (media.isEmpty) {
      // A text-only post uses the big-text gradients.
      return AspectRatio(
        aspectRatio: 1,
        child: _BigTextBackground(
          postId: post.id,
          color: const Color(0xFF2563EB),
        ),
      );
    }

    if (media.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.postMedia),
          child: _MediaImage(url: media.first, thumbnailUrl: post.thumbnailUrl),
        ),
      );
    }

    final height = MediaQuery.sizeOf(context).width < 640 ? 360.0 : 420.0;

    if (media.length == 2) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.postMedia),
                  child: _MediaImage(url: media[0], thumbnailUrl: post.thumbnailUrl),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.postMedia),
                  child: _MediaImage(url: media[1], thumbnailUrl: post.thumbnailUrl),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (media.length == 3) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            // One large photo on the left.
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.postMedia),
                  child: _MediaImage(url: media[0], thumbnailUrl: post.thumbnailUrl),
                ),
              ),
            ),
            // Two stacked on the right.
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.postMedia),
                        child: _MediaImage(
                          url: media[1],
                          thumbnailUrl: post.thumbnailUrl,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.postMedia),
                        child: _MediaImage(
                          url: media[2],
                          thumbnailUrl: post.thumbnailUrl,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4 or more — the first photo with a "+N" overlay.
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.postMedia),
            child: _MediaImage(url: media.first, thumbnailUrl: post.thumbnailUrl),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '+${media.length - 2}',
                style: EnnvoText.titleSm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaImage extends StatelessWidget {
  const _MediaImage({required this.url, this.thumbnailUrl});

  final String url;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      // Decode at roughly the display size — a full resolution photo in a
      // scrolling list is the fastest way to run out of memory.
      cacheWidth: 1080,
      errorBuilder: (_, __, ___) {
        if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
          return Image.network(
            thumbnailUrl!,
            fit: BoxFit.cover,
            cacheWidth: 1080,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF1F2937)),
          );
        }
        return const ColoredBox(color: Color(0xFF1F2937));
      },
    );
  }
}

/// The solid-colour background used by a text-only post.
class _BigTextBackground extends StatelessWidget {
  const _BigTextBackground({required this.postId, required this.color});

  final String postId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [color, color.withValues(alpha: 0.65)],
        ),
      ),
    );
  }
}

// ============================================================================
//  The song of the post
//
//  The pill under the post carries the name of the song and the artist, and
//  the name travels when it does not fit. A post usually keeps the id of
//  its song — the name is then looked up in the `songs` collection, the
//  same collection the web app reads.
// ============================================================================
class _SongBlock extends ConsumerWidget {
  const _SongBlock({required this.post});

  final AppPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    // The lookup is free when the post has no song: the service answers
    // straight away without touching the network.
    final songAsync = ref.watch(songProvider(post.songId ?? ''));
    final song = songAsync.hasValue ? songAsync.value : null;

    final title = _pick(post.songTitle, song?.title);
    final artist = _pick(post.songArtist, song?.artist);
    if (title.isEmpty && artist.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: EnnvoSongMarquee(
          title: title.isEmpty ? 'Track' : title,
          artist: artist,
          width: 156,
          textColor: t.textPrimary,
          iconColor: t.textSecondary,
          background: t.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE9EAEE),
          borderColor: Colors.transparent,
        ),
      ),
    );
  }

  /// The first of the two that has something in it.
  static String _pick(String? first, String? second) {
    final a = first?.trim() ?? '';
    if (a.isNotEmpty) return a;
    return second?.trim() ?? '';
  }
}

// ============================================================================
//  A small helper widget
// ============================================================================
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, this.size = 38});

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surfaceAlt,
        image: url.isEmpty
            ? null
            : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: url.isEmpty
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
              ),
            )
          : null,
    );
  }
}

/// The like / comment / repost / share button in the action row.
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.count,
    this.semanticLabel,
  });

  final Widget icon;
  final VoidCallback? onTap;
  final int? count;
  final String? semanticLabel;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _popped = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null
            ? null
            : () {
                setState(() => _popped = true);
                HapticFeedback.lightImpact();
                widget.onTap!.call();
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              // The web app springs the icon from 0.75 to 1.
              scale: _popped ? 1 : 0.92,
              duration: const Duration(milliseconds: 260),
              curve: const SpringCurve(EnnvoSprings.likePop),
              child: widget.icon,
            ),
            if (widget.count != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatCount(widget.count!),
                style: EnnvoText.count.copyWith(color: t.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }
}
