// ============================================================================
//  ENNVO — REEL CARD
//
//  A single reel in the vertical feed. Ported from
//  `src/components/ReelItem.tsx`.
//
//  Layout (mobile):
//    • the video fills the screen
//    • bottom left: author row with a follow button, the caption with a
//      "See more..." toggle, and the audio row
//    • right rail: avatar, like, comment, save, share — each with its count
//
//  Interactions:
//    • double tap on the media likes the reel and pops a heart
//    • the heart pop animates scale 0 → 1.25 → 1 over 600ms
//    • the like button springs to 1 with stiffness 450 / damping 18
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/post.dart';
import '../../../shared/icons/lucide_icons.dart';
import 'reel_video.dart';

class ReelCard extends StatefulWidget {
  const ReelCard({
    super.key,
    required this.post,
    required this.isActive,
    required this.isLiked,
    required this.likesCount,
    required this.isFollowing,
    required this.isMuted,
    required this.onToggleLike,
    required this.onToggleFollow,
    required this.onToggleMute,
    this.onComment,
    this.onShare,
    this.onOpenProfile,
  });

  final AppPost post;
  final bool isActive;
  final bool isLiked;
  final int likesCount;
  final bool isFollowing;
  final bool isMuted;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleFollow;
  final VoidCallback onToggleMute;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onOpenProfile;

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {
  bool _showHeart = false;
  bool _expandedCaption = false;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  static const int _captionCollapseThreshold = 70;

  void _handleDoubleTap() {
    final now = DateTime.now();
    final delta = now.difference(_lastTap).inMilliseconds;
    _lastTap = now;

    if (delta < 300) {
      if (!widget.isLiked) widget.onToggleLike();
      setState(() => _showHeart = true);
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // --- media -------------------------------------------------
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleDoubleTap,
              onDoubleTap: () {},
              child: post.media.isEmpty
                  ? const ColoredBox(color: Color(0xFF111111))
                  : ReelVideo(
                      url: post.media.first,
                      thumbnailUrl: post.thumbnailUrl,
                      isActive: widget.isActive,
                      muted: widget.isMuted,
                    ),
            ),
          ),

          // --- double tap heart --------------------------------------
          if (_showHeart)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: EnnvoDurations.doubleTapHeart,
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      // scale: 0 → 1.25 → 1
                      final scale = value < 0.4
                          ? Curves.easeOut.transform(value / 0.4) * 1.25
                          : 1.25 - (Curves.easeIn.transform((value - 0.4) / 0.6)) * 0.25;
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.heart,
                      ),
                      child: const SizedBox(
                        width: 80,
                        height: 80,
                        child: Center(
                          child: LucideIcon(
                            LucideIcons.heart,
                            size: 52,
                            strokeWidth: 2,
                            filled: true,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // --- top gradient so the action rail stays readable ---------
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x00000000)],
                ),
              ),
            ),
          ),

          // --- bottom gradient ----------------------------------------
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
          ),

          // --- right action rail -------------------------------------
          Positioned(
            right: 10,
            bottom: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AuthorAvatar(
                  avatarUrl: post.authorAvatar,
                  name: post.authorName,
                  onTap: widget.onOpenProfile,
                ),
                const SizedBox(height: 20),
                _RailButton(
                  icon: LucideIcon(
                    LucideIcons.heart,
                    size: 26,
                    strokeWidth: 2,
                    filled: widget.isLiked,
                    color: widget.isLiked
                        ? const Color(0xFFF43F5E)
                        : Colors.white,
                  ),
                  count: widget.likesCount,
                  onTap: widget.onToggleLike,
                  semanticLabel: 'Like',
                ),
                const SizedBox(height: 14),
                _RailButton(
                  icon: const LucideIcon(
                    LucideIcons.messageCircle,
                    size: 26,
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                  count: post.commentsCount,
                  onTap: widget.onComment,
                  semanticLabel: 'Comment',
                ),
                const SizedBox(height: 14),
                _RailButton(
                  icon: const LucideIcon(
                    LucideIcons.bookmark,
                    size: 26,
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                  onTap: () {},
                  semanticLabel: 'Save',
                ),
                const SizedBox(height: 14),
                _RailButton(
                  icon: const LucideIcon(
                    LucideIcons.share2,
                    size: 26,
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                  onTap: widget.onShare,
                  semanticLabel: 'Share',
                ),
              ],
            ),
          ),

          // --- mute toggle -------------------------------------------
          Positioned(
            right: 16,
            top: 120,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onToggleMute,
              child: Icon(
                widget.isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          // --- author + caption + audio ------------------------------
          Positioned(
            left: 14,
            right: 84,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onOpenProfile,
                      child: Text(
                        '@${post.authorUsername ?? post.authorName}',
                        style: EnnvoText.bodySemi.copyWith(
                          color: Colors.white,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _FollowButton(
                      isFollowing: widget.isFollowing,
                      onTap: widget.onToggleFollow,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (post.text.isNotEmpty)
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
                      style: EnnvoText.reelCaption.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                if (post.text.length > _captionCollapseThreshold) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _expandedCaption = !_expandedCaption),
                    child: Text(
                      _expandedCaption ? 'See less' : 'See more...',
                      style: EnnvoText.seeMore.copyWith(color: Colors.white),
                    ),
                  ),
                ],
                if (post.songTitle != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.music_note_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.songTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnnvoText.caption.copyWith(
                            color: Colors.white,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular author avatar with the story ring.
class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.avatarUrl, required this.name, this.onTap});

  final String avatarUrl;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.6),
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF222222),
            image: avatarUrl.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  ),
          ),
          child: avatarUrl.isEmpty
              ? Center(
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: EnnvoText.bodySemi.copyWith(color: Colors.white),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// The animated like / comment / save / share button in the right rail.
class _RailButton extends StatefulWidget {
  const _RailButton({
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
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _popped = false;

  void _handleTap() {
    setState(() {
      _popped = !_popped;
    });
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _handleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _popped ? 1.22 : 1.0,
              duration: EnnvoDurations.dropdown,
              curve: EnnvoCurves.press,
              child: widget.icon,
            ),
            if (widget.count != null) ...[
              const SizedBox(height: 3),
              Text(
                _formatCount(widget.count!),
                style: EnnvoText.tiny.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
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

/// The follow button next to the author name.
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: EnnvoDurations.iconSwap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: isFollowing
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF2563EB)],
                ),
          color: isFollowing ? const Color(0x26FFFFFF) : null,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isFollowing
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowing ? Icons.check_rounded : Icons.add_rounded,
              size: 12,
              color: Colors.white,
            ),            const SizedBox(width: 4),
            Text(
              isFollowing ? 'Following' : 'Follow',
              style: EnnvoText.tiny.copyWith(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
