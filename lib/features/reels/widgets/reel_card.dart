// ============================================================================
//  ENNVO — REEL CARD
//
//  A single reel in the vertical feed.
//
//  The layout and the motion come from the reels prototype, the typography
//  and the colours from the Ennvo design system:
//
//    • the author block sits on the left with the avatar, the follow badge,
//      the name, the verified mark, the role, the caption and the song
//    • the action rail sits on the right: like, comment, favourite, share and
//      the spinning vinyl record
//    • a double tap spawns a heart at the tap point that rises and fades
//    • a single tap plays or pauses, after a 280 ms window so the two
//      gestures never fight each other
//    • the song title scrolls in a marquee with a soft mask
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/post.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../demo_reels.dart';
import 'reel_video.dart';

class ReelCard extends StatefulWidget {
  const ReelCard({
    super.key,
    required this.post,
    required this.isActive,
    required this.isNear,
    required this.isLiked,
    required this.isSaved,
    required this.isFollowing,
    required this.likesCount,
    required this.commentsCount,
    required this.favouritesCount,
    required this.sharesCount,
    required this.muted,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onToggleFollow,
    required this.onToggleMute,
    required this.onOpenComments,
    required this.onOpenShare,
    this.onProgress,
  });

  final AppPost post;
  final bool isActive;
  final bool isNear;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowing;
  final int likesCount;
  final int commentsCount;
  final int favouritesCount;
  final int sharesCount;
  final bool muted;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onToggleFollow;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenComments;
  final VoidCallback onOpenShare;
  final ValueChanged<double>? onProgress;

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {
  /// The heart that bursts out of a double tap.
  final List<_FloatingHeart> _hearts = [];

  bool _paused = false;
  bool _expandedCaption = false;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _tapTimer;

  static const int _captionThreshold = 60;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  /// A double tap likes the reel and bursts a heart; a single tap pauses.
  void _handleTap(Offset position) {
    final now = DateTime.now();
    final delta = now.difference(_lastTap).inMilliseconds;
    _lastTap = now;

    if (delta < 300) {
      _tapTimer?.cancel();
      _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
      _spawnHeart(position);
      if (!widget.isLiked) widget.onToggleLike();
      HapticFeedback.lightImpact();
      return;
    }

    // Wait for the double-tap window before deciding this was a single tap.
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _paused = !_paused);
    });
  }

  void _spawnHeart(Offset position) {
    final heart = _FloatingHeart(
      id: DateTime.now().microsecondsSinceEpoch,
      position: position,
      rotation: (DateTime.now().microsecond % 40) - 20,
    );
    setState(() => _hearts.add(heart));
    Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => _hearts.removeWhere((h) => h.id == heart.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final demo = demoReelFor(widget.post.id);
    final caption = demo?.caption ?? (widget.post.text);
    final tags = demo?.tags ?? '';
    final songTitle = demo?.songTitle ?? (widget.post.songTitle ?? '');
    final songArtist =
        demo?.songArtist ?? (widget.post.songArtist ?? '');
    final authorName = widget.post.authorName as String? ?? '';
    final authorHandle =
        widget.post.authorUsername as String? ?? authorName.toLowerCase();
    final authorRole = demo?.authorRole ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // --- media ----------------------------------------------------
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details.localPosition),
          child: ReelVideo(
            url: demo == null ? (widget.post.media.isNotEmpty ? widget.post.media.first : null) : null,
            assetPath: demo?.videoAsset,
            posterAsset: demo?.posterAsset,
            posterUrl: widget.post.thumbnailUrl,
            isActive: widget.isActive && !_paused,
            isNear: widget.isNear,
            muted: widget.muted,
            onProgress: widget.onProgress,
          ),
        ),

        // --- gradients ------------------------------------------------
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 180,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66080710), Color(0x00080710)],
              ),
            ),
          ),
        ),
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
                colors: [Color(0xB8080710), Color(0x00080710)],
              ),
            ),
          ),
        ),

        // --- play overlay --------------------------------------------
        AnimatedOpacity(
          opacity: _paused ? 0.9 : 0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const LucideIcon(
                LucideIcons.play,
                size: 56,
                strokeWidth: 1.8,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // --- the burst hearts -----------------------------------------
        for (final heart in _hearts)
          Positioned(
            left: heart.position.dx - 44,
            top: heart.position.dy - 44,
            child: IgnorePointer(
              child: _HeartBurst(rotation: heart.rotation),
            ),
          ),

        // --- the author block ----------------------------------------
        Positioned(
          left: 16,
          right: 92,
          bottom: MediaQuery.paddingOf(context).bottom + 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- who ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthorBadge(
                    name: authorName,
                    avatarUrl: widget.post.authorAvatar as String? ?? '',
                    isFollowing: widget.isFollowing,
                    onTapFollow: widget.onToggleFollow,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: EnnvoText.bodySemi.copyWith(
                                  color: Colors.white,
                                  fontSize: 15,
                                  shadows: const [
                                    Shadow(color: Color(0x99000000), blurRadius: 6),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const LucideIcon(
                              LucideIcons.badgeCheck,
                              size: 15,
                              strokeWidth: 2.4,
                              color: Color(0xFF1D9BF0),
                            ),
                          ],
                        ),
                        if (authorRole.isNotEmpty)
                          Text(
                            authorRole,
                            style: EnnvoText.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- caption ---
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    setState(() => _expandedCaption = !_expandedCaption),
                child: Text(
                  caption,
                  maxLines: _expandedCaption ? null : 2,
                  overflow: _expandedCaption
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: EnnvoText.body.copyWith(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.55,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 6),
                    ],
                  ),
                ),
              ),
              if (caption.length > _captionThreshold)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _expandedCaption = !_expandedCaption),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _expandedCaption ? 'See less' : 'See more',
                      style: EnnvoText.seeMore.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tags,
                    style: EnnvoText.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                ),

              // --- song ---
              if (songTitle.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SongMarquee(title: songTitle, artist: songArtist),
              ],
            ],
          ),
        ),

        // --- the action rail -------------------------------------------
        Positioned(
          right: 10,
          bottom: MediaQuery.paddingOf(context).bottom + 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailButton(
                icon: LucideIcons.heart,
                filled: widget.isLiked,
                iconSize: 34,
                label: _format(widget.likesCount),
                activeColor: const Color(0xFFFF3B5C),
                onTap: widget.onToggleLike,
                semanticLabel: 'Like',
              ),
              const SizedBox(height: 14),
              _RailButton(
                icon: LucideIcons.messageCircle,
                iconSize: 34,
                label: _format(widget.commentsCount),
                onTap: widget.onOpenComments,
                semanticLabel: 'Comments',
              ),
              const SizedBox(height: 14),
              _RailButton(
                icon: LucideIcons.bookmark,
                filled: widget.isSaved,
                iconSize: 30,
                label: _format(widget.favouritesCount),
                activeColor: const Color(0xFFFFD700),
                onTap: widget.onToggleSave,
                semanticLabel: 'Save',
              ),
              const SizedBox(height: 14),
              _RailButton(
                icon: LucideIcons.share2,
                iconSize: 30,
                label: _format(widget.sharesCount),
                onTap: widget.onOpenShare,
                semanticLabel: 'Share',
              ),
              const SizedBox(height: 16),
              _VinylDisc(
                avatarUrl: widget.post.authorAvatar as String? ?? '',
                playing: widget.isActive,
                onTap: widget.onToggleMute,
              ),
            ],
          ),
        ),

        // --- the mute toggle -------------------------------------------
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 6,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggleMute,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: LucideIcon(
                widget.muted ? LucideIcons.volumeX : LucideIcons.volume2,
                size: 22,
                strokeWidth: 1.8,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _format(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
    }
    return '$value';
  }
}

// ============================================================================
//  The author badge with the morphing follow button
// ============================================================================
class _AuthorBadge extends StatelessWidget {
  const _AuthorBadge({
    required this.name,
    required this.avatarUrl,
    required this.isFollowing,
    required this.onTapFollow,
  });

  final String name;
  final String avatarUrl;
  final bool isFollowing;
  final VoidCallback onTapFollow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0x66FFFFFF)],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1D1B36),
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
                        style: EnnvoText.titleMd.copyWith(color: Colors.white),
                      ),
                    )
                  : null,
            ),
          ),
          // The follow badge overlaps the bottom of the avatar.
          Positioned(
            left: 0,
            right: 0,
            bottom: -10,
            child: Center(
              child: _FollowButton(
                isFollowing: isFollowing,
                onTap: onTapFollow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The follow button: a plus morphs into a check.
class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // The web app springs the button with `stiffness 500, damping 26`.
    _controller.forward(from: 0);
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1, end: 1.18).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: widget.isFollowing
                ? const LucideIcon(
                    LucideIcons.check,
                    key: ValueKey('following'),
                    size: 13,
                    strokeWidth: 2.8,
                    color: Color(0xFF2C2B4D),
                  )
                : const LucideIcon(
                    LucideIcons.plus,
                    key: ValueKey('follow'),
                    size: 13,
                    strokeWidth: 2.8,
                    color: Color(0xFF2C2B4D),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The action rail button
// ============================================================================
class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
    this.filled = false,
    this.activeColor,
  });

  final String icon;
  final double iconSize;
  final String label;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool filled;
  final Color? activeColor;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _popped = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.filled
        ? (widget.activeColor ?? Colors.white)
        : Colors.white;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _popped = true);
          HapticFeedback.lightImpact();
          widget.onTap();
          Future.delayed(const Duration(milliseconds: 220), () {
            if (mounted) setState(() => _popped = false);
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _popped ? 1.3 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: EnnvoCurves.iosSpring,
              child: LucideIcon(
                widget.icon,
                size: widget.iconSize,
                strokeWidth: 1.4,
                filled: widget.filled,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.label,
              style: EnnvoText.tiny.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12.5,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  The spinning vinyl record
// ============================================================================
class _VinylDisc extends StatefulWidget {
  const _VinylDisc({
    required this.avatarUrl,
    required this.playing,
    required this.onTap,
  });

  final String avatarUrl;
  final bool playing;
  final VoidCallback onTap;

  @override
  State<_VinylDisc> createState() => _VinylDiscState();
}

class _VinylDiscState extends State<_VinylDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _VinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        ),
        padding: const EdgeInsets.all(3),
        child: RotationTransition(
          turns: _controller,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF111111),
              image: widget.avatarUrl.isEmpty
                  ? null
                  : DecorationImage(
                      image: NetworkImage(widget.avatarUrl),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The scrolling song title
// ============================================================================
class _SongMarquee extends StatefulWidget {
  const _SongMarquee({required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  State<_SongMarquee> createState() => _SongMarqueeState();
}

class _SongMarqueeState extends State<_SongMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.artist.isEmpty
        ? widget.title
        : '${widget.title} • ${widget.artist}';

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 16, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LucideIcon(
            LucideIcons.music,
            size: 16,
            strokeWidth: 1.6,
            color: Colors.white,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 150,
            height: 18,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, 0.1, 0.9, 1],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      children: [
                        for (var i = 0; i < 2; i++)
                          Text(
                            '$label      ',
                            style: EnnvoText.caption.copyWith(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The heart that bursts out of a double tap
// ============================================================================
class _FloatingHeart {
  const _FloatingHeart({
    required this.id,
    required this.position,
    required this.rotation,
  });

  final int id;
  final Offset position;
  final double rotation;
}

class _HeartBurst extends StatelessWidget {
  const _HeartBurst({required this.rotation});

  final double rotation;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        final scale = 0.4 + (value < 0.25
                ? (value / 0.25) * 0.7
                : 1.1 - ((value - 0.25) / 0.75) * 0.1);
        return Opacity(
          opacity: (1 - value).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -64 * value),
            child: Transform.rotate(
              angle: rotation * (value * 3.14159 / 180),
              child: Transform.scale(
                scale: scale,
                child: const LucideIcon(
                  LucideIcons.heart,
                  size: 88,
                  strokeWidth: 1.6,
                  filled: true,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
