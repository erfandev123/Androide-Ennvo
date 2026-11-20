// ============================================================================
//  ENNVO — STORY VIEWER
//
//  Full-screen story viewer shared between FeedPage and MessagesPage.
//  Supports image and video stories, tap left/right navigation, hold to
//  pause, progress bars, author header, bottom caption, and seen tracking.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/typography.dart';
import '../../data/services/story_service.dart';
import '../icons/lucide_icons.dart';

class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.currentUserId,
  });

  final List<Story> stories;
  final int initialIndex;
  final String currentUserId;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  static const int _imageDurationMs = 6000;
  static const int _tickMs = 40;

  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex.clamp(0, widget.stories.length - 1),
  );
  late int _index = widget.initialIndex.clamp(0, widget.stories.length - 1);

  Timer? _timer;
  double _progress = 0;
  bool _paused = false;

  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentStory();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposeVideo();
    _pageController.dispose();
    super.dispose();
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
  }

  Future<void> _loadCurrentStory() async {
    _timer?.cancel();
    _disposeVideo();
    if (!mounted || widget.stories.isEmpty) return;

    setState(() => _progress = 0);
    _markSeen();

    final story = widget.stories[_index];
    if (story.isVideo && story.mediaUrl.isNotEmpty) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(story.mediaUrl),
      );
      _videoController = controller;
      try {
        await controller.initialize();
        await controller.setLooping(false);
        await controller.play();
        if (!mounted || _videoController != controller) {
          await controller.dispose();
          return;
        }
        setState(() => _videoReady = true);
        final durationMs = controller.value.duration.inMilliseconds;
        _startProgressTimer(durationMs > 800 ? durationMs : _imageDurationMs);
      } catch (_) {
        if (!mounted) return;
        _startProgressTimer(_imageDurationMs);
      }
    } else {
      _startProgressTimer(_imageDurationMs);
    }
  }

  void _startProgressTimer(int totalMs) {
    _timer?.cancel();
    final step = _tickMs / totalMs;
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted || _paused) return;
      final next = _progress + step;
      if (next >= 1.0) {
        _timer?.cancel();
        _next();
      } else {
        setState(() => _progress = next);
      }
    });
  }

  void _markSeen() {
    if (widget.currentUserId.isEmpty || widget.currentUserId == 'me') return;
    final story = widget.stories[_index];
    if (story.id.isEmpty) return;
    if (!story.viewers.contains(widget.currentUserId)) {
      StoryService.markSeen(storyId: story.id, userId: widget.currentUserId);
    }
  }

  void _setPaused(bool paused) {
    if (_paused == paused) return;
    setState(() => _paused = paused);
    if (paused) {
      _videoController?.pause();
    } else {
      _videoController?.play();
    }
  }

  void _next() {
    if (_index + 1 < widget.stories.length) {
      _pageController.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _previous() {
    if (_index > 0) {
      _pageController.animateToPage(
        _index - 1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      setState(() => _progress = 0);
      _loadCurrentStory();
    }
  }

  static String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final delta = DateTime.now().difference(time);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final current = widget.stories[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              _loadCurrentStory();
            },
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              final isCurrentVideo =
                  index == _index && story.isVideo && _videoController != null;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => _setPaused(true),
                onLongPressEnd: (_) => _setPaused(false),
                onTapUp: (details) {
                  if (_paused) {
                    _setPaused(false);
                    return;
                  }
                  final width = MediaQuery.sizeOf(context).width;
                  if (details.globalPosition.dx < width * 0.32) {
                    _previous();
                  } else {
                    _next();
                  }
                },
                child: Center(
                  child: isCurrentVideo
                      ? (_videoReady
                          ? AspectRatio(
                              aspectRatio:
                                  _videoController!.value.aspectRatio == 0
                                      ? 9 / 16
                                      : _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : const CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ))
                      : (story.mediaUrl.isEmpty
                          ? const SizedBox.shrink()
                          : Image.network(
                              story.mediaUrl,
                              fit: BoxFit.contain,
                              cacheWidth: 1080,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white54,
                                size: 42,
                              ),
                            )),
                ),
              );
            },
          ),

          // Top gradient scrim
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 110,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),

          // Progress bars
          Positioned(
            top: topPadding + 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                for (var i = 0; i < widget.stories.length; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: i < _index
                              ? 1.0
                              : (i == _index ? _progress.clamp(0.0, 1.0) : 0.0),
                          child: const ColoredBox(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Author header + close button
          Positioned(
            top: topPadding + 22,
            left: 12,
            right: 8,
            child: Row(
              children: [
                _ViewerAvatar(
                  name: current.authorName,
                  url: current.authorAvatar,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        current.authorName.isEmpty ? 'Story' : current.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EnnvoText.bodySemi.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      if (current.createdAt != null)
                        Text(
                          _relativeTime(current.createdAt),
                          style: EnnvoText.tiny.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const LucideIcon(
                    LucideIcons.x,
                    size: 22,
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Caption overlay
          if (current.text.trim().isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: bottomPadding + 28,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    current.text.trim(),
                    textAlign: TextAlign.center,
                    style: EnnvoText.body.copyWith(
                      color: Colors.white,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewerAvatar extends StatelessWidget {
  const _ViewerAvatar({required this.name, required this.url});

  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: EnnvoText.bodySemi.copyWith(
        color: Colors.white,
        fontSize: 13,
      ),
    );
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E293B),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: url.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                url,
                width: 33,
                height: 33,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}
