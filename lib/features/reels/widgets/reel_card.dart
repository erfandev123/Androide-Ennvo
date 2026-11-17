// ============================================================================
//  ENNVO �?" REEL CARD
//
//  A single reel in the vertical feed.
//
//  The layout follows TikTok and Instagram:
//
//    �?� the video keeps its own shape: a 9:16 reel, a 16:9 reel and a
//      square reel are shown at their own size, centred on the black of the
//      feed. Nothing is stretched and nothing is cropped away.
//    �?� the action rail runs down the right edge: the author avatar with a
//      follow badge, then like, comment, repost, favourite and share, then
//      the spinning music disc
//    �?� the author block sits on the left: one name, the caption, the tags
//      and the scrolling song title
//    �?� a like or a repost sends a friend's avatar above the name, the way
//      Instagram shows an activity
//
//  The controls of a running reel stay out of the way: the timeline and the
//  sound button only show while the reel is stopped, so a playing reel is
//  nothing but the picture.
//
//  No button animates when it is pressed - the icon changes its colour and
//  that is all. The web app hard-disables the `:active` scale, and the
//  native port follows it.
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/post.dart';
import '../../../data/models/song.dart';
import '../../../shared/icons/ion_icons.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../../../shared/widgets/song_marquee.dart';
import '../demo_reels.dart';
import 'reel_video.dart';

/// A friend whose avatar floats above the name.
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
    this.isSuspended = false,
    this.song,
    this.playback,
    this.onPauseChanged,
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

  /// The video is held still �?" the sheet is open, or the app is in the
  /// background.
  final bool isSuspended;

  /// The song of the reel, looked up in the `songs` collection.
  final AppSong? song;

  /// The shared playback handle: the speed and the seek.
  final ReelPlayback? playback;

  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onToggleRepost;
  final VoidCallback onToggleFollow;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenComments;
  final VoidCallback onOpenShare;
  final ValueChanged<double>? onProgress;

  /// The reel was stopped or started.
  ///
  /// The page uses it to show the controls of a stopped reel - the timeline
  /// and the sound button.
  final ValueChanged<bool>? onPauseChanged;

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard>
    with SingleTickerProviderStateMixin {
  final List<ReelActivity> _activities = <ReelActivity>[];

  bool _paused = false;
  bool _expandedCaption = false;

  /// The reel runs at 2x while the right side of the picture is held down.
  bool _fastForward = false;

  /// The heart that bursts out of a double tap.
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _tapTimer;

  static const int _captionThreshold = 60;

  /// The share of the width on the right that runs the reel at 2x.
  static const double _fastZone = 0.62;

  @override
  void dispose() {
    _tapTimer?.cancel();
    _heart.dispose();
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
      // The heart comes out at once - it is the reward of the double tap.
      _heart.forward(from: 0);
      HapticFeedback.lightImpact();
      return;
    }

    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _paused = !_paused);
      widget.onPauseChanged?.call(_paused);
    });
  }

  /// The picture is held down on the right: the reel runs at 2x.
  void _handlePress(Offset position, double width) {
    if (width <= 0) return;
    if (position.dx < width * _fastZone) return;
    if (_fastForward) return;
    setState(() => _fastForward = true);
    widget.playback?.setSpeed(2.0);
  }

  /// The picture is released: the reel runs at its normal speed again.
  void _handleRelease() {
    if (!_fastForward) return;
    setState(() => _fastForward = false);
    widget.playback?.setSpeed(1.0);
  }

  /// Sends a friend's avatar floating above the name.
  void _spawnActivity(String kind) {
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

  @override
  Widget build(BuildContext context) {
    final demo = demoReelFor(widget.post.id);
    final caption = demo?.caption ?? widget.post.text;
    final tags = demo?.tags ?? '';
    final songTitle =
        widget.song?.title ??
        demo?.songTitle ??
        (widget.post.songTitle ?? '');
    final songArtist =
        widget.song?.artist ??
        demo?.songArtist ??
        (widget.post.songArtist ?? '');
    final authorName = widget.post.authorName.isEmpty
        ? (widget.post.authorUsername ?? 'ennvo')
        : widget.post.authorName;

    return Stack(
      fit: StackFit.expand,
      children: [
        // --- media ----------------------------------------------------
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handlePress(
                details.localPosition,
                constraints.maxWidth,
              ),
              onTapUp: (details) {
                _handleRelease();
                _handleTap(details.localPosition);
              },
              onTapCancel: _handleRelease,
              child: ReelVideo(
                url: demo == null ? widget.post.videoUrl : null,
                assetPath: demo?.videoAsset,
                posterAsset: demo?.posterAsset,
                posterUrl: widget.post.thumbnailUrl,
                imageUrl: demo == null && widget.post.mediaIsImage
                    ? widget.post.media.first
                    : null,
                isActive: widget.isActive && !_paused,
                isNear: widget.isNear,
                muted: widget.muted,
                isSuspended: widget.isSuspended || _paused,
                onProgress: widget.onProgress,
                playback: widget.playback,
              ),
            );
          },
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

        // --- the stopped icon ----------------------------------------
        // It appears the moment the reel stops: there is no fade, because a
        // fade is what made the icon feel late.
        if (_paused)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const IonIcon(
                    IonIcons.play,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

        // --- the heart of the double tap ------------------------------
        // It pops out of the middle of the picture and fades away.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _heart,
              builder: (context, _) {
                if (_heart.value == 0) return const SizedBox.shrink();
                final t = _heart.value;
                // It grows fast and fades out.
                final scale = 0.4 + (1.1 * (1 - (1 - t) * (1 - t)));
                final opacity = t < 0.25
                    ? t / 0.25
                    : (t > 0.6 ? 1 - ((t - 0.6) / 0.4) : 1.0);

                return Center(
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: scale,
                      child: const IonIcon(
                        IonIcons.heartFilled,
                        size: 120,
                        color: Color(0xE6FF2D55),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // --- the 2x badge ---------------------------------------------
        if (_fastForward)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 96),
                child: _SpeedBadge(speed: '2x'),
              ),
            ),
          ),

        // --- the author block -----------------------------------------
        Positioned(
          left: 14,
          right: 86,
          // It sits above the floating navigation bar and its timeline, so
          // the caption and the handle read as part of the reel rather than
          // of the chrome.
          bottom:
              AppSizes.bottomNavTop(MediaQuery.paddingOf(context).bottom) +
              16,
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- the friend avatars, above the name ----------------
                if (_activities.isNotEmpty) _ActivityRow(activities: _activities),

                // --- the picture, the follow badge and the name ---------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _AuthorBadge(
                      avatarUrl: widget.post.authorAvatar,
                      name: authorName,
                      isFollowing: widget.isFollowing,
                      onToggleFollow: widget.onToggleFollow,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EnnvoText.titleSm.copyWith(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (!widget.isFollowing) ...[
                            const SizedBox(width: 9),
                            _FollowChip(onTap: widget.onToggleFollow),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
                  // Its own repaint boundary: the marquee runs forever, and
                  // without the boundary it would repaint the whole reel with
                  // it.
                  RepaintBoundary(
                    child: EnnvoSongMarquee(
                      title: songTitle,
                      artist: songArtist,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // --- the action rail -----------------------------------------
        Positioned(
          right: 8,
          bottom:
              AppSizes.bottomNavTop(MediaQuery.paddingOf(context).bottom) +
              16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailButton(
                icon: IonIcons.heartOutline,
                filledIcon: IonIcons.heartFilled,
                filled: widget.isLiked,
                activeColor: const Color(0xFFFF2D55),
                label: _format(widget.likesCount),
                onTap: () {
                  widget.onToggleLike();
                  if (!widget.isLiked) _spawnActivity('like');
                },
                semanticLabel: 'Like',
              ),
              const SizedBox(height: 16),
              _RailButton(
                icon: IonIcons.chatOutline,
                label: _format(widget.commentsCount),
                onTap: widget.onOpenComments,
                semanticLabel: 'Comments',
              ),
              const SizedBox(height: 16),
              _RailButton(
                icon: IonIcons.repeatOutline,
                filledIcon: IonIcons.repeatOutline,
                filled: widget.isReposted,
                activeColor: const Color(0xFF22C55E),
                label: _format(widget.sharesCount),
                onTap: () {
                  widget.onToggleRepost();
                  if (!widget.isReposted) _spawnActivity('repost');
                },
                semanticLabel: 'Repost',
              ),
              const SizedBox(height: 16),
              _RailButton(
                icon: IonIcons.bookmarkOutline,
                filledIcon: IonIcons.bookmarkFilled,
                filled: widget.isSaved,
                activeColor: const Color(0xFFFFD700),
                label: _format(widget.favouritesCount),
                onTap: widget.onToggleSave,
                semanticLabel: 'Save',
              ),
              const SizedBox(height: 16),
              _RailButton(
                icon: IonIcons.share,
                label: _format(widget.sharesCount),
                onTap: widget.onOpenShare,
                semanticLabel: 'Share',
              ),
              const SizedBox(height: 18),
              // The disc spins forever too, so it gets its own boundary.
              RepaintBoundary(
                child: _VinylDisc(
                  avatarUrl:
                      widget.song?.thumbnail ?? widget.post.authorAvatar,
                  playing: widget.isActive && !_paused,
                  onTap: widget.onToggleMute,
                ),
              ),
            ],
          ),
        ),

        // --- the sound toggle -----------------------------------------
        // It only shows while the reel is stopped: a running reel keeps its
        // chrome out of the way.
        if (_paused)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onToggleMute,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  shape: BoxShape.circle,
                ),
                child: IonIcon(
                  widget.muted ? IonIcons.volumeOff : IonIcons.volumeHigh,
                  size: 21,
                  color: Colors.white,
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
//  The friend avatars above the name
//
//  They drift in, sit above the name of the author and fade away. A light
//  blur keeps them behind the name, the way Instagram shows an activity.
// ============================================================================
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activities});

  final List<ReelActivity> activities;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            for (final activity in activities.take(3))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _ActivityAvatar(activity: activity),
              ),
          ],
        ),
      ),
    );
  }
}

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
        // It pops in and then fades away.
        final pop = t < 0.22
            ? (t / 0.22)
            : 1 - ((t - 0.22) / 0.78) * 0.1;
        final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: (0.5 + 0.6 * pop).clamp(0.0, 1.1),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
                color: const Color(0xFF1F2937),
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
                  child: activity.avatarUrl.isEmpty
                      ? Center(
                          child: Text(
                            activity.name.isEmpty
                                ? '?'
                                : activity.name.characters.first.toUpperCase(),
                            style: EnnvoText.tiny.copyWith(color: Colors.white),
                          ),
                        )
                      : Image.network(
                          activity.avatarUrl,
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
//  The 2x badge
// ============================================================================
class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge({required this.speed});

  final String speed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        speed,
        style: EnnvoText.bodySemi.copyWith(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================================================================
//  The picture of the author, with the follow badge on it
// ============================================================================
class _AuthorBadge extends StatelessWidget {
  const _AuthorBadge({
    required this.avatarUrl,
    required this.name,
    required this.isFollowing,
    required this.onToggleFollow,
  });

  final String avatarUrl;
  final String name;
  final bool isFollowing;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2),
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
        // --- the follow badge ----------------------------------------
        Positioned(
          bottom: -3,
          right: -3,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleFollow,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFollowing ? Colors.white : const Color(0xFFFE2C55),
                border: Border.all(color: Colors.black, width: 1.8),
                boxShadow: const [
                  BoxShadow(color: Color(0x73000000), blurRadius: 8),
                ],
              ),
              alignment: Alignment.center,
              child: isFollowing
                  ? const LucideIcon(
                      LucideIcons.check,
                      size: 12,
                      strokeWidth: 3.4,
                      color: Color(0xFF111111),
                    )
                  : const LucideIcon(
                      LucideIcons.plus,
                      size: 13,
                      strokeWidth: 3.2,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  The small "Follow" chip next to the name
//
//  It is the one control of the reel that moves when it is pressed: the
//  follow of the web app springs, and it has to feel soft.
// ============================================================================
class _FollowChip extends StatefulWidget {
  const _FollowChip({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_FollowChip> createState() => _FollowChipState();
}

class _FollowChipState extends State<_FollowChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _pop = Tween<double>(
    begin: 1,
    end: 0.88,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // A soft spring: the chip dips and comes back.
    _controller.forward(from: 0).then((_) {
      if (mounted) _controller.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _pop,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFE2C55),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59FE2C55),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'Follow',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  One action in the rail
//
//  It does not move when it is pressed. The web app hard-disables the
//  `:active` scale, and the native port follows it: only the colour of the
//  icon changes.
// ============================================================================
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
    this.filledIcon,
    this.filled = false,
    this.activeColor,
  });

  /// The outline glyph.
  final String icon;

  /// The solid glyph, used when the action is on.
  final String? filledIcon;

  final String label;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool filled;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = filled ? (activeColor ?? Colors.white) : Colors.white;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A real Ionicons vector, 32-on-512 stroke, from the web build.
            IonIcon(
              filled && filledIcon != null ? filledIcon! : icon,
              size: 34,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
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
