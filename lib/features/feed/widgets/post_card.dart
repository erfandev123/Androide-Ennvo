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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/post.dart';
import '../../../shared/icons/ion_icons.dart';
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
  Timer? _heartTimer;

  static const int _captionCollapseThreshold = 70;

  @override
  void dispose() {
    _heartTimer?.cancel();
    super.dispose();
  }

  void _handleDoubleTap() {
    final now = DateTime.now();
    final delta = now.difference(_lastTap).inMilliseconds;
    _lastTap = now;

    if (delta < 300) {
      if (!widget.isLiked) widget.onToggleLike?.call();
      setState(() => _showHeart = true);
      HapticFeedback.lightImpact();

      // The heart pops and goes, the way the web app does it. The timer is
      // restarted on every double tap, so rapid taps always show it again.
      _heartTimer?.cancel();
      _heartTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showHeart = false);
      });
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
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: t.border),
        boxShadow: t.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
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

          // --- media, or the big text of a text-only post ---------------
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 2),
              child: GestureDetector(
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
                                    ? Curves.easeOut.transform(value / 0.4) *
                                          1.25
                                    : 1.25 -
                                          (Curves.easeIn.transform(
                                                (value - 0.4) / 0.6,
                                              ) *
                                              0.25);
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
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleDoubleTap,
                child: Stack(
                  children: [
                    _BigTextCard(post: post),
                    if (_showHeart)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: EnnvoDurations.doubleTapHeart,
                              curve: Curves.easeOut,
                              builder: (context, value, child) =>
                                  Transform.scale(
                                    scale: 0.6 + value.clamp(0.0, 1.0) * 0.65,
                                    child: Opacity(
                                      opacity: value.clamp(0.0, 1.0),
                                      child: child,
                                    ),
                                  ),
                              child: const Icon(
                                Icons.favorite,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // --- action row -----------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _ActionButton(
                  icon: IonIcon(
                    widget.isLiked
                        ? IonIcons.heartFilled
                        : IonIcons.heartOutline,
                    size: 21,
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
                  icon: IonIcon(
                    IonIcons.chatOutline,
                    size: 21,
                    color: t.textPrimary,
                  ),
                  count: post.commentsCount,
                  onTap: widget.onComment,
                  semanticLabel: 'Comment',
                ),
                const SizedBox(width: 22),
                _ActionButton(
                  icon: IonIcon(
                    IonIcons.repeatOutline,
                    size: 21,
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
                  icon: IonIcon(IonIcons.share, size: 21, color: t.textPrimary),
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
          // A text-only post writes its words inside the big text card.
          if (post.media.isNotEmpty && post.text.isNotEmpty)
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

    if (media.length == 1) {
      final height = MediaQuery.sizeOf(context).width < 640 ? 360.0 : 420.0;
      final videoUrl = post.videoUrl;

      return SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.postMedia),
          child: videoUrl == null
              ? _MediaImage(
                  url: media.first,
                  thumbnailUrl: post.thumbnailUrl,
                )
              : _PostVideo(url: videoUrl, post: post),
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
                  child: _MediaImage(
                    url: media[0],
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
                    url: media[1],
                    thumbnailUrl: post.thumbnailUrl,
                  ),
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
                  child: _MediaImage(
                    url: media[0],
                    thumbnailUrl: post.thumbnailUrl,
                  ),
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
                      padding: const EdgeInsets.only(
                        left: 2,
                        right: 2,
                        bottom: 1,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppRadius.postMedia,
                        ),
                        child: _MediaImage(
                          url: media[1],
                          thumbnailUrl: post.thumbnailUrl,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 2,
                        right: 2,
                        bottom: 2,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppRadius.postMedia,
                        ),
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
            child: _MediaImage(
              url: media.first,
              thumbnailUrl: post.thumbnailUrl,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

/// The card of a text-only post.
///
/// The words are the picture: the card takes the full width, never less than
/// 220 logical pixels tall, and the text sits in the middle in white over one
/// of the gradients of the web app. The gradient of a post never changes, so
/// the same post always looks the same.
class _BigTextCard extends StatelessWidget {
  const _BigTextCard({required this.post});

  final AppPost post;

  static const List<List<Color>> _gradients = [
    [Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF0EA5E9)],
    [Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFFF97316)],
    [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF22C55E)],
    [Color(0xFFF43F5E), Color(0xFF9333EA), Color(0xFF4F46E5)],
    [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[post.id.hashCode.abs() % _gradients.length];

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(AppRadius.postMedia),
      ),
      alignment: Alignment.center,
      child: Text(
        post.text,
        textAlign: TextAlign.center,
        style: EnnvoText.bodySemi.copyWith(
          color: Colors.white,
          fontSize: 21,
          height: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The video of a post, played inside the feed.
///
/// The player is lazy: the poster is a picture until the first tap, so a feed
/// with ten videos still starts with a single decoder. Once it is built it
/// plays muted in a loop, the way the feed of the web app behaves, and the
/// speaker button switches the sound on.
class _PostVideo extends StatefulWidget {
  const _PostVideo({required this.url, required this.post});

  final String url;
  final AppPost post;

  @override
  State<_PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<_PostVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _loading = false;
  bool _playing = false;
  bool _muted = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Nothing is decoded until the user asks for it: the feed keeps a plain
    // picture in place of the clip, so scrolling stays light on a weak phone.
  }

  Future<void> _prepare({required bool play}) async {
    if (_controller != null) {
      if (play && !_playing) {
        await _controller!.play();
        if (mounted) setState(() => _playing = true);
      }
      return;
    }
    if (_loading) return;

    setState(() => _loading = true);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );
    _controller = controller;
    controller.addListener(_syncState);

    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _ready = true;
        _loading = false;
      });
      if (play) {
        await controller.play();
        if (mounted) setState(() => _playing = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
        _controller = null;
      });
      await controller.dispose();
    }
  }

  void _syncState() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final playing = controller.value.isPlaying;
    if (playing != _playing) setState(() => _playing = playing);
  }

  void _togglePlay() {
    if (_playing) {
      _controller?.pause();
      setState(() => _playing = false);
    } else {
      _prepare(play: true);
    }
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    final muted = !_muted;
    controller.setVolume(muted ? 0 : 1);
    setState(() => _muted = muted);
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncState);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.post.thumbnailUrl?.trim() ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Container(
        color: const Color(0xFF0B1220),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- the poster, until the video is ready --------------------
            if (!_ready)
              poster.isEmpty
                  ? const _VideoFallback()
                  : Image.network(
                      poster,
                      fit: BoxFit.cover,
                      cacheWidth: 1080,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => const _VideoFallback(),
                    ),

            // --- the video itself ----------------------------------------
            if (_ready && _controller != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width == 0
                      ? 1
                      : _controller!.value.size.width,
                  height: _controller!.value.size.height == 0
                      ? 1
                      : _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),

            // --- the dark veil that keeps the icons readable -------------
            if (!_ready)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0x66000000)],
                  ),
                ),
              ),

            // --- the play / pause button ---------------------------------
            if (!_playing && !_failed)
              Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.42),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

            // --- the sound -------------------------------------------------
            if (_ready)
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleMute,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.48),
                    ),
                    alignment: Alignment.center,
                    child: LucideIcon(
                      _muted ? LucideIcons.volumeX : LucideIcons.volume2,
                      size: 18,
                      strokeWidth: 2.1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            if (_failed)
              const Center(
                child: Text(
                  'This video cannot be played.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF0B1220)],
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
///
/// It does not move when it is pressed: the web app hard-disables the
/// `:active` scale, and the native port follows it.
class _ActionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!.call();
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatCount(count!),
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
