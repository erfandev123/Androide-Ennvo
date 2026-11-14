// ============================================================================
//  ENNVO — REEL VIDEO
//
//  The video surface of a reel.
//
//  The playback window follows the prototype:
//    • outside the window the controller does not exist at all and only
//      the poster is painted — the decoder is released completely
//    • one step away the video is prepared but stays paused
//    • the active reel plays
//
//  That keeps the number of live decoders at two on a cheap phone instead
//  of one per item in the feed.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelVideo extends StatefulWidget {
  const ReelVideo({
    super.key,
    this.url,
    this.assetPath,
    this.posterAsset,
    this.posterUrl,
    required this.isActive,
    required this.isNear,
    this.muted = true,
    this.onProgress,
    this.onReady,
    this.onEnded,
  });

  /// A remote video.
  final String? url;

  /// A bundled video.
  final String? assetPath;

  /// A bundled poster image.
  final String? posterAsset;

  /// A remote poster image.
  final String? posterUrl;

  final bool isActive;
  final bool isNear;
  final bool muted;
  final ValueChanged<double>? onProgress;
  final VoidCallback? onReady;
  final VoidCallback? onEnded;

  @override
  State<ReelVideo> createState() => _ReelVideoState();
}

class _ReelVideoState extends State<ReelVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  Timer? _playDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.isNear) _prepare();
  }

  @override
  void didUpdateWidget(covariant ReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isNear != widget.isNear) {
      if (widget.isNear) {
        _prepare();
      } else {
        // Outside the window: release the decoder entirely.
        _release();
      }
      return;
    }

    if (oldWidget.isActive != widget.isActive) {
      _syncPlayback();
    }

    if (oldWidget.muted != widget.muted) {
      unawaited(_controller?.setVolume(widget.muted ? 0 : 1));
    }

    if (oldWidget.url != widget.url ||
        oldWidget.assetPath != widget.assetPath) {
      _release();
      if (widget.isNear) _prepare();
    }
  }

  @override
  void dispose() {
    _playDebounce?.cancel();
    _release();
    super.dispose();
  }

  void _release() {
    _playDebounce?.cancel();
    final controller = _controller;
    _controller = null;
    _ready = false;
    if (controller != null) {
      controller.removeListener(_onTick);
      controller.dispose();
    }
  }

  Future<void> _prepare() async {
    final url = widget.url;
    final asset = widget.assetPath;
    if (url == null && asset == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    try {
      final controller = asset != null
          ? VideoPlayerController.asset(asset)
          : VideoPlayerController.networkUrl(Uri.parse(url!));

      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      controller.addListener(_onTick);

      if (!mounted) {
        controller.removeListener(_onTick);
        unawaited(controller.dispose());
        return;
      }

      setState(() => _ready = true);
      widget.onReady?.call();
      _syncPlayback();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final duration = controller.value.duration;
    if (duration.inMilliseconds > 0) {
      final progress =
          controller.value.position.inMilliseconds / duration.inMilliseconds;
      widget.onProgress?.call(progress.clamp(0.0, 1.0));
    }
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !_ready) return;

    // A short debounce stops a burst of page changes from thrashing the
    // decoder — that is what causes the stutter on a low end phone.
    _playDebounce?.cancel();
    _playDebounce = Timer(const Duration(milliseconds: 120), () async {
      if (!mounted) return;
      final current = _controller;
      if (current == null) return;
      if (widget.isActive) {
        await current.play();
      } else {
        await current.pause();
        await current.seekTo(Duration.zero);
      }
    });
  }

  /// Sets the playback speed — used by the 2x hold gesture.
  Future<void> setSpeed(double speed) async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    await controller.setPlaybackSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_failed || controller == null || !_ready) {
      return _Poster();
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
      ],
    );
  }

  Widget _Poster() {
    // The poster always sits on a soft gradient, so the reel never shows a
    // flat black rectangle while the video is being prepared.
    Widget placeholder = const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14121F), Color(0xFF0B0B12)],
        ),
      ),
    );

    if (widget.posterAsset != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          Image.asset(
            widget.posterAsset!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      );
    }

    if (widget.posterUrl != null && widget.posterUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          Image.network(
            widget.posterUrl!,
            fit: BoxFit.cover,
            cacheWidth: 1080,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      );
    }

    return placeholder;
  }
}
