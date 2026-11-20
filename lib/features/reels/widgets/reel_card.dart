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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/post.dart';
import '../../../data/models/song.dart';
import '../../../shared/icons/ion_icons.dart';
import '../../../shared/icons/lucide_icons.dart';
import '../../../shared/widgets/song_marquee.dart';
import '../demo_reels.dart';
import 'reel_video.dart';

/// The blue of the brand, used by every active action of a reel: the like,
/// the follow, the repost, the save and the hearts.
const Color kReelBlue = Color(0xFF2AA1FB);

/// A friend whose avatar floats above the name.
class ReelActivity {
  const ReelActivity({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.kind,
    this.persistent = false,
  });

  final int id;
  final String name;
  final String avatarUrl;

  /// `'like'` or `'repost'`.
  final String kind;

  /// A real friend activity stays; a local burst fades away.
  final bool persistent;
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
    this.onCleanModeChanged,
    this.friendActivities = const [],
    this.navStyle = 'glass',
    this.viewerName = '',
    this.viewerAvatar = '',
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

  /// The real friend likes and reposts of this reel, read from Firestore.
  /// Only people the viewer follows appear here.
  final List<ReelActivity> friendActivities;

  /// The skin of the bottom bar, so the caption and the rail keep clear of
  /// it — the glass pill floats, the classic bar is flush.
  final String navStyle;

  /// The picture and the name of the signed-in user, used for the burst
  /// that a like or a repost sends above the name.
  final String viewerName;
  final String viewerAvatar;

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

  /// Fired when right-side hold toggles 2x clean cinema mode.
  final ValueChanged<bool>? onCleanModeChanged;

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
  bool _holdTriggered = false;
  Offset _pressOrigin = Offset.zero;
  Timer? _holdTimer;

  /// The heart that bursts out of a double tap.
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the reel was running before the tap that is still inside the
  /// double-tap window. A double tap puts it back exactly where it was.
  bool? _pausedBeforeTap;

  static const int _captionThreshold = 60;

  /// The share of the width on the right that runs the reel at 2x.
  static const double _fastZone = 0.52;

  @override
  void didUpdateWidget(covariant ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _holdTimer?.cancel();
      _holdTimer = null;
      _holdTriggered = false;
      if (_fastForward) {
        _fastForward = false;
        widget.playback?.setSpeed(1.0);
      }
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _heart.dispose();
    super.dispose();
  }

  /// A double tap likes the reel and sends the viewer's avatar across the
  /// screen; a single tap plays or pauses.
  ///
  /// The pause is **instant**: a tap stops the picture on the same frame,
  /// instead of waiting out the double-tap window. When the second tap of a
  /// double tap arrives, the pause of the first tap is undone, so liking a
  /// reel never leaves it stopped.
  void _handleTap(Offset position) {
    final now = DateTime.now();
    final delta = now.difference(_lastTap).inMilliseconds;
    _lastTap = now;

    if (delta < 260) {
      _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

      final restore = _pausedBeforeTap;
      _pausedBeforeTap = null;
      if (restore != null && restore != _paused) {
        setState(() => _paused = restore);
        widget.onPauseChanged?.call(_paused);
      }

      if (!widget.isLiked) widget.onToggleLike();
      _spawnActivity('like');
      // The heart comes out at once, and a fast second double tap starts it
      // again from zero — the burst is never blocked by the one before it.
      _heart.forward(from: 0);
      HapticFeedback.lightImpact();
      return;
    }

    // The first tap of a possible double tap: stop (or start) the reel now.
    _pausedBeforeTap = _paused;
    setState(() => _paused = !_paused);
    widget.onPauseChanged?.call(_paused);
  }

  /// The picture is pressed: arm a 200ms hold timer on the right side for 2x.
  void _handlePress(Offset position, double width) {
    _holdTimer?.cancel();
    _holdTriggered = false;
    _pressOrigin = position;
    if (width <= 0) return;
    if (position.dx < width * _fastZone) return;

    _holdTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _holdTriggered = true;
      setState(() => _fastForward = true);
      widget.playback?.setSpeed(2.0);
      widget.onCleanModeChanged?.call(true);
      HapticFeedback.selectionClick();
    });
  }

  /// The picture is released: restore 1x speed and all overlays.
  void _handleRelease() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!_fastForward) return;
    setState(() => _fastForward = false);
    widget.playback?.setSpeed(1.0);
    widget.onCleanModeChanged?.call(false);
  }

  /// Sends a viewer's avatar floating above the name.
  void _spawnActivity(String kind) {
    final activity = ReelActivity(
      id: DateTime.now().microsecondsSinceEpoch,
      name: widget.viewerName,
      avatarUrl: widget.viewerAvatar,
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

    // The author block and the action rail sit above the bar of the skin in
    // use: the floating glass pill floats 12 px above the bottom, the
    // classic bar is flush, so the two need different room.
    final barTop =
        AppSizes.navTopFor(
          widget.navStyle,
          MediaQuery.paddingOf(context).bottom,
        ) +
        16;

    return Stack(
      fit: StackFit.expand,
      children: [
        // --- media ----------------------------------------------------
        LayoutBuilder(
          builder: (context, constraints) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (details) => _handlePress(
                details.localPosition,
                constraints.maxWidth,
              ),
              onPointerMove: (details) {
                if (!_holdTriggered &&
                    (details.localPosition - _pressOrigin).distance > 14) {
                  _holdTimer?.cancel();
                  _holdTimer = null;
                }
              },
              onPointerUp: (_) => _handleRelease(),
              onPointerCancel: (_) {
                _holdTriggered = false;
                _handleRelease();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  if (_holdTriggered) {
                    _holdTriggered = false;
                    return;
                  }
                  _holdTimer?.cancel();
                  _holdTimer = null;
                  _handleTap(details.localPosition);
                },
                onTapCancel: () {
                  _holdTimer?.cancel();
                  _holdTimer = null;
                },
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
            ),
            );
          },
        ),

        // --- gradients ------------------------------------------------
        if (!_fastForward) ...[
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
                  colors: [
                    Color(0xC7000000),
                    Color(0x40000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
        ],

        // --- the stopped icon ----------------------------------------
        if (_paused && !_fastForward)
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
                        color: Color(0xE62AA1FB),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // --- the 2x badge (bottom center in clean cinema mode) --------
        if (_fastForward)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: const Center(child: _SpeedBadge(speed: '2x')),
          ),

        // --- the author block -----------------------------------------
        if (!_fastForward)
          Positioned(
          left: 14,
          right: 86,
          // It sits above the bar of the skin in use, so the caption and
          // the handle read as part of the reel rather than of the chrome.
          bottom: barTop,
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- the friend avatars, above the name ----------------
                if (_activities.isNotEmpty || widget.friendActivities.isNotEmpty)
                  _ActivityRow(
                    activities: [
                      ...widget.friendActivities,
                      ..._activities,
                    ].take(3).toList(),
                  ),

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
        if (!_fastForward)
          Positioned(
            right: 8,
            bottom: barTop,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailButton(
                icon: IonIcons.heartOutline,
                filledIcon: IonIcons.heartFilled,
                filled: widget.isLiked,
                activeColor: kReelBlue,
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
                activeColor: kReelBlue,
                label: _format(widget.sharesCount),
                spinOnTap: true,
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
                activeColor: kReelBlue,
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
        if (_paused && !_fastForward)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onToggleMute,
              child: AnimatedContainer(
                duration: EnnvoDurations.dropdown,
                curve: EnnvoCurves.press,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.muted
                      ? const Color(0xCC000000)
                      : Colors.black.withValues(alpha: 0.38),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                alignment: Alignment.center,
                child: LucideIcon(
                  widget.muted ? LucideIcons.volumeX : LucideIcons.volume2,
                  size: 19,
                  strokeWidth: 2.3,
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
    final avatar = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.6),
        color: const Color(0xFF1F2937),
      ),
      alignment: Alignment.center,
      // A sharp picture: the avatar of a friend is not art, it is a face.
      child: ClipOval(
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
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    activity.name.isEmpty
                        ? '?'
                        : activity.name.characters.first.toUpperCase(),
                    style: EnnvoText.tiny.copyWith(color: Colors.white),
                  ),
                ),
              ),
      ),
    );

    // A blue repeat for a repost, a blue heart for a like.
    final badge = Positioned(
      right: -2,
      bottom: -2,
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kReelBlue,
          border: Border.all(color: Colors.black, width: 1.2),
        ),
        alignment: Alignment.center,
        child: activity.kind == 'repost'
            ? const LucideIcon(
                LucideIcons.repeat2,
                size: 9,
                strokeWidth: 3,
                color: Colors.white,
              )
            : const IonIcon(
                IonIcons.heartFilled,
                size: 9,
                color: Colors.white,
              ),
      ),
    );

    // The real activities of friends stay on the reel. Only the local
    // burst of a double tap fades away.
    if (activity.persistent) {
      return Stack(clipBehavior: Clip.none, children: [avatar, badge]);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final pop = t < 0.22 ? (t / 0.22) : 1 - ((t - 0.22) / 0.78) * 0.1;
        final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: (0.5 + 0.6 * pop).clamp(0.0, 1.1),
            child: Stack(clipBehavior: Clip.none, children: [avatar, badge]),
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
              colors: [Color(0xFF71D2FD), Color(0xFF2AA1FB), Color(0xFF2563EB)],
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF111111),
            ),
            padding: const EdgeInsets.all(1.6),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF222222),
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipOval(
                child: avatarUrl.isEmpty
                    ? Center(
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                          style: EnnvoText.bodySemi.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Image.network(
                        avatarUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name.characters.first.toUpperCase(),
                            style: EnnvoText.bodySemi.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),
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
                color: isFollowing ? Colors.white : kReelBlue,
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
            color: kReelBlue,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: const [
              BoxShadow(
                color: Color(0x592AA1FB),
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
class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
    this.filledIcon,
    this.filled = false,
    this.activeColor,
    this.spinOnTap = false,
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

  /// Whether the glyph turns around itself when it is pressed — the repost
  /// arrows do, the rest of the rail stays still.
  final bool spinOnTap;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.spinOnTap) _spin.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.filled
        ? (widget.activeColor ?? Colors.white)
        : Colors.white;

    // A real Ionicons vector, 32-on-512 stroke, from the web build.
    Widget glyph = IonIcon(
      widget.filled && widget.filledIcon != null
          ? widget.filledIcon!
          : widget.icon,
      size: 34,
      color: color,
    );

    if (widget.spinOnTap) {
      glyph = AnimatedBuilder(
        animation: _spin,
        builder: (context, child) {
          // One full turn with a soft landing, so a repost reads as an
          // action and not as a colour change.
          final t = Curves.easeOutCubic.transform(_spin.value);
          return Transform.rotate(angle: t * 2 * math.pi, child: child);
        },
        child: glyph,
      );
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph,
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF111111),
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipOval(
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
                  : Image.network(
                      widget.avatarUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: const Icon(
                            Icons.music_note_rounded,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
