// ============================================================================
//  ENNVO — REEL CARD
//
//  A single reel in the vertical feed.
//
//  The layout follows TikTok and Instagram:
//
//    • the video fills the screen edge to edge, there are no black bars
//    • the action rail runs down the right edge: the author avatar with a
//      follow badge, then like, comment, repost, favourite and share, then
//      the spinning music disc
//    • the author block sits on the left: the handle, the caption, the tags
//      and the scrolling song title
//    • a like or a repost sends a friend's avatar floating to the left, the
//      way Instagram shows an activity
//
//  Every animation runs on a spring and is wrapped in a repaint boundary, so
//  a tap never drops a frame.
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/post.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../demo_reels.dart';
import 'reel_video.dart';

/// A friend whose avatar floats across the screen.
class ReelActivity {
  const ReelActivity({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.kind,
  });

  final int id;
  final String name;
  final String avatarUrl;

  /// `'like'` or `'repost'`.
  final String kind;
}

class ReelCard extends StatefulWidget {
  const ReelCard({
    super.key,
    required this.post,
    required this.isActive,
    required this.isNear,
    required this.isLiked,
    required this.isSaved,
    required this.isReposted,
    required this.isFollowing,
    required this.likesCount,
    required this.commentsCount,
    required this.favouritesCount,
    required this.sharesCount,
    required this.muted,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onToggleRepost,
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
  final bool isReposted;
  final bool isFollowing;
  final int likesCount;
  final int commentsCount;
  final int favouritesCount;
  final int sharesCount;
  final bool muted;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onToggleRepost;
  final VoidCallback onToggleFollow;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenComments;
  final VoidCallback onOpenShare;
  final ValueChanged<double>? onProgress;

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {
  final List<ReelActivity> _activities = <ReelActivity>[];

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

  /// A double tap likes the reel and sends a friend's avatar across the
  /// screen; a single tap plays or pauses.
  void _handleTap(Offset position) {
    final now = DateTime.now();
    final delta = now.difference(_lastTap).inMilliseconds;
    _lastTap = now;

    if (delta < 300) {
      _tapTimer?.cancel();
      _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
      if (!widget.isLiked) widget.onToggleLike();
      _spawnActivity('like');
      HapticFeedback.lightImpact();
      return;
    }

    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _paused = !_paused);
    });
  }

  /// Sends a friend's avatar floating to the left.
  void _spawnActivity(String kind) {
    final demo = demoReelFor(widget.post.id);
    final activity = ReelActivity(
      id: DateTime.now().microsecondsSinceEpoch,
      name: widget.post.authorName,
      avatarUrl: widget.post.authorAvatar,
      kind: kind,
    );
    setState(() => _activities.add(activity));
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _activities.removeWhere((a) => a.id == activity.id));
    });
  }

  void _animate(VoidCallback action) {
    // A soft spring, the way the app feels when a control is pressed.
    action();
  }

  @override
  Widget build(BuildContext context) {
    final demo = demoReelFor(widget.post.id);
    final caption = demo?.caption ?? widget.post.text;
    final tags = demo?.tags ?? '';
    final songTitle = demo?.songTitle ?? (widget.post.songTitle ?? '');
    final songArtist = demo?.songArtist ?? (widget.post.songArtist ?? '');
    final authorName = widget.post.authorName;
    final authorHandle =
        widget.post.authorUsername ?? authorName.toLowerCase();
    final authorRole = demo?.authorRole ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // --- media ----------------------------------------------------
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details.localPosition),
          child: ReelVideo(
            url: demo == null
                ? (widget.post.media.isNotEmpty
                      ? widget.post.media.first
                      : null)
                : null,
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
          height: 170,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x73000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 360,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xC7000000), Color(0x40000000), Color(0x00000000)],
              ),
            ),
          ),
        ),

        // --- the paused overlay --------------------------------------
        AnimatedOpacity(
          opacity: _paused ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.play,
                  size: 58,
                  strokeWidth: 1.6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        // --- the floating friend avatars ------------------------------
        for (final activity in _activities)
          Positioned(
            right: 42,
            bottom: 150 + _activities.indexOf(activity) * 46.0,
            child: IgnorePointer(child: _ActivityAvatar(activity: activity)),
          ),

        // --- the author block ----------------------------------------
        Positioned(
          left: 14,
          right: 86,
          // Sits above the black navigation bar, so the title and the
          // timeline read as part of the reel rather than the chrome.
          bottom: MediaQuery.paddingOf(context).bottom + 74,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- the handle and the follow button ---
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '@$authorHandle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EnnvoText.bodySemi.copyWith(
                        color: Colors.white,
                        fontSize: 15.5,
                        shadows: const [
                          Shadow(color: Color(0xB3000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FollowPill(
                    isFollowing: widget.isFollowing,
                    onTap: widget.onToggleFollow,
                  ),
                ],
              ),
              if (authorRole.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  authorRole,
                  style: EnnvoText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 5),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // --- the caption ---
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
                    fontSize: 14,
                    height: 1.45,
                    shadows: const [
                      Shadow(color: Color(0xB3000000), blurRadius: 6),
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
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      _expandedCaption ? 'See less' : 'See more',
                      style: EnnvoText.seeMore.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        decoration: TextDecoration.underline,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 5),
                        ],
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
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      shadows: const [
                        Shadow(color: Color(0x99000000), blurRadius: 5),
                      ],
                    ),
                  ),
                ),

              // --- the song ---
              if (songTitle.isNotEmpty) ...[
                const SizedBox(height: 10),
                _SongMarquee(title: songTitle, artist: songArtist),
              ],
            ],
          ),
        ),

        // --- the action rail -----------------------------------------
        Positioned(
          right: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 74,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailAvatar(
                avatarUrl: widget.post.authorAvatar,
                name: authorName,
                isFollowing: widget.isFollowing,
                onTapFollow: widget.onToggleFollow,
              ),
              const SizedBox(height: 18),
              _RailButton(
                icon: LucideIcons.heart,
                filled: widget.isLiked,
                activeColor: const Color(0xFFFF2D55),
                label: _format(widget.likesCount),
                onTap: () {
                  _animate(widget.onToggleLike);
                  if (!widget.isLiked) _spawnActivity('like');
                },
                semanticLabel: 'Like',
              ),
              const SizedBox(height: 16),
              _RailButton(
                icon: LucideIcons.messageCircle,
                label: _format(widget.commentsCount),
                onTap: widget.onOpenComments,
                semanticLabel: 'Comments',
              ),
              const SizedBox(height: 16),
              _RailButton(
                icon: LucideIcons.repeat2,
                filled: widget.isReposted,
                activeColor: const Color(0xFF22C55E),
                label: _format(widget.sharesCount),
                onTap: () {
                  _animate(widget.onToggleRepost);
                  if (!widget.isReposted) _spawnActivity('repost');
                },
                semanticLabel: 'Repost',
              ),
              const SizedBox(height: 16),
              _RailButton(
                icon: LucideIcons.bookmark,
                filled: widget.isSaved,
                activeColor: const Color(0xFFFFD700),
                label: _format(widget.favouritesCount),
                onTap: () {
                  _animate(widget.onToggleSave);
                },
                semanticLabel: 'Save',
              ),
              const SizedBox(height: 16),
              _RailButton(
                icon: LucideIcons.share2,
                label: _format(widget.sharesCount),
                onTap: widget.onOpenShare,
                semanticLabel: 'Share',
              ),
              const SizedBox(height: 18),
              _VinylDisc(
                avatarUrl: widget.post.authorAvatar,
                playing: widget.isActive && !_paused,
                onTap: widget.onToggleMute,
              ),
            ],
          ),
        ),

        // --- the sound toggle ----------------------------------------
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 8,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggleMute,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: LucideIcon(
                widget.muted ? LucideIcons.volumeX : LucideIcons.volume2,
                size: 22,
                strokeWidth: 1.8,
                color: Colors.white.withValues(alpha: 0.95),
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
//  The floating friend avatar
// ============================================================================
class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({required this.activity});

  final ReelActivity activity;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        // It pops in, drifts to the left and fades away.
        final pop = t < 0.22
            ? (t / 0.22)
            : 1 - ((t - 0.22) / 0.78) * 0.1;
        final drift = ((t - 0.22) / 0.78).clamp(0.0, 1.0);
        final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(-96 * drift, -26 * drift),
            child: Transform.scale(
              scale: (0.4 + 0.7 * pop).clamp(0.0, 1.2),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                  color: const Color(0xFF1F2937),
                  image: activity.avatarUrl.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(activity.avatarUrl),
                          fit: BoxFit.cover,
                        ),
                ),
                child: activity.avatarUrl.isEmpty
                    ? Center(
                        child: Text(
                          activity.name.isEmpty
                              ? '?'
                              : activity.name.characters.first.toUpperCase(),
                          style: EnnvoText.tiny.copyWith(color: Colors.white),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
//  The follow button next to the handle
// ============================================================================
class _FollowPill extends StatefulWidget {
  const _FollowPill({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  State<_FollowPill> createState() => _FollowPillState();
}

class _FollowPillState extends State<_FollowPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // A soft spring, so the button never snaps.
    _controller.forward(from: 0);
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.12).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: EnnvoCurves.iosSpring,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isFollowing
                ? Colors.white.withValues(alpha: 0.22)
                : const Color(0xFFFE2C55),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: widget.isFollowing
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isFollowing)
                const LucideIcon(
                  LucideIcons.check,
                  size: 12,
                  strokeWidth: 3,
                  color: Colors.white,
                )
              else
                const LucideIcon(
                  LucideIcons.plus,
                  size: 12,
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              const SizedBox(width: 4),
              Text(
                widget.isFollowing ? 'Following' : 'Follow',
                style: EnnvoText.tiny.copyWith(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The avatar at the top of the action rail
// ============================================================================
class _RailAvatar extends StatelessWidget {
  const _RailAvatar({
    required this.avatarUrl,
    required this.name,
    required this.isFollowing,
    required this.onTapFollow,
  });

  final String avatarUrl;
  final String name;
  final bool isFollowing;
  final VoidCallback onTapFollow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD700), Color(0xFFFE2C55), Color(0xFF8B5CF6)],
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF111111),
            ),
            padding: const EdgeInsets.all(1.6),
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
        ),
        const SizedBox(height: 8),
        // The follow badge under the avatar.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapFollow,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFollowing ? Colors.white : const Color(0xFFFE2C55),
              border: Border.all(color: Colors.black, width: 1.6),
            ),
            alignment: Alignment.center,
            child: isFollowing
                ? const LucideIcon(
                    LucideIcons.check,
                    size: 10,
                    strokeWidth: 3.4,
                    color: Color(0xFF111111),
                  )
                : const LucideIcon(
                    LucideIcons.plus,
                    size: 10,
                    strokeWidth: 3.4,
                    color: Colors.white,
                  ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  One action in the rail
// ============================================================================
class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
    this.filled = false,
    this.activeColor,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool filled;
  final Color? activeColor;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton>
    with SingleTickerProviderStateMixin {
  // A spring, so a burst of taps stays smooth — restarting the animation
  // never queues up a backlog.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _pop = Tween<double>(
    begin: 1,
    end: 1.28,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0).then((_) {
      if (mounted) _controller.reverse();
    });
    HapticFeedback.lightImpact();
    widget.onTap();
  }

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
        onTap: _handleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The icon springs rather than snapping.
            ScaleTransition(
              scale: _pop,
              child: LucideIcon(
                widget.icon,
                size: 33,
                strokeWidth: 1.9,
                filled: widget.filled,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: EnnvoText.tiny.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 5),
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
//  The spinning music disc
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.4,
          ),
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
            child: widget.avatarUrl.isEmpty
                ? Center(
                    child: Transform.rotate(
                      angle: -math.pi / 4,
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ),
                  )
                : null,
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
    duration: const Duration(seconds: 9),
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
        : '${widget.title} · ${widget.artist}';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LucideIcon(
            LucideIcons.music,
            size: 15,
            strokeWidth: 1.7,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
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
                stops: [0, 0.08, 0.92, 1],
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
                              fontSize: 12.5,
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
