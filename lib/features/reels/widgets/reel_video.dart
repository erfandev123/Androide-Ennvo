// ============================================================================
//  ENNVO — REEL VIDEO PLAYER
//
//  A small, self-contained video surface used by the reels feed.
//
//  Performance notes:
//    • the controller is created lazily and disposed as soon as the reel
//      leaves the render window
//    • only one reel plays at a time — the feed tells this widget whether
//      it is the active one
//    • the thumbnail is shown until the first frame is ready, so a slow
//      network never shows a black rectangle
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelVideo extends StatefulWidget {
  const ReelVideo({
    super.key,
    required this.url,
    required this.isActive,
    this.thumbnailUrl,
    this.muted = true,
    this.onReady,
  });

  final String url;
  final bool isActive;
  final String? thumbnailUrl;
  final bool muted;
  final VoidCallback? onReady;

  @override
  State<ReelVideo> createState() => _ReelVideoState();
}

class _ReelVideoState extends State<ReelVideo> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _failed = false;
  Timer? _playDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) _prepare();
  }

  @override
  void didUpdateWidget(covariant ReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _prepare();
      return;
    }
    if (oldWidget.isActive != widget.isActive) {
      _syncPlayback();
    }
    if (oldWidget.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
  }

  @override
  void dispose() {
    _playDebounce?.cancel();
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onTick);
      controller.dispose();
    }
  }

  Future<void> _prepare() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      controller.addListener(_onTick);
      if (!mounted) return;
      setState(() => _isReady = true);
      widget.onReady?.call();
      _syncPlayback();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    // Repaint only when something visible actually changed.
    if (controller.value.isPlaying != _wasPlaying) {
      _wasPlaying = controller.value.isPlaying;
      setState(() {});
    }
  }

  bool _wasPlaying = false;

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !_isReady) return;

    // A short debounce stops a burst of page changes from thrashing the
    // decoder — that is what causes stutter on low end devices.
    _playDebounce?.cancel();
    _playDebounce = Timer(const Duration(milliseconds: 120), () async {
      if (!mounted) return;
      final current = _controller;
      if (current == null) return;
      if (widget.isActive) {
        await current.play();
      } else {
        await current.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_failed) {
      return _Fallback(thumbnailUrl: widget.thumbnailUrl);
    }

    if (controller == null || !_isReady) {
      return _Fallback(thumbnailUrl: widget.thumbnailUrl);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        // A paused reel shows the play glyph, like every other video app.
        if (!controller.value.isPlaying && widget.isActive)
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return Image.network(
        thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF111111)),
      );
    }
    return const ColoredBox(color: Color(0xFF111111));
  }
}
