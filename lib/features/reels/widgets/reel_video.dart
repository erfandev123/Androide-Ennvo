// ============================================================================
//  ENNVO — REEL VIDEO
//
//  The video surface of a reel.
//
//  Playback strategy — this is what makes the feed feel like TikTok:
//
//    • the controller is created as soon as the reel enters the preload
//      window, not when it becomes active, so the network round trip and
//      the first frame decode happen while the user is still watching
//    • the active reel plays, the prepared neighbour stays paused
//    • a reel that leaves the window is released completely, decoder and all
//    • the poster is shown until the first frame is ready, then the video
//      cross fades in over it
//    • pausing resets the position, so a reel always starts from the top
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
    this.imageUrl,
    required this.isActive,
    required this.isNear,
    this.muted = true,
    this.isSuspended = false,
    this.onProgress,
    this.onReady,
    this.onFailed,
  });

  /// A remote video.
  final String? url;

  /// A bundled video.
  final String? assetPath;

  /// A bundled poster image.
  final String? posterAsset;

  /// A remote poster image.
  final String? posterUrl;

  /// A picture instead of a video.
  ///
  /// A post in the reels feed may carry a photo — handing it to the video
  /// player is what left the feed with a black rectangle.
  final String? imageUrl;

  final bool isActive;
  final bool isNear;
  final bool muted;

  /// The video is held still without losing its position.
  ///
  /// It is used while the app is in the background and while a sheet is
  /// open over the feed: the sound must stop, but the reel must not start
  /// over when it comes back.
  final bool isSuspended;

  final ValueChanged<double>? onProgress;
  final VoidCallback? onReady;
  final VoidCallback? onFailed;

  /// The format of a video URL.
  ///
  /// Only a real HLS playlist is played as HLS. Telling the player that a
  /// plain MP4 is an HLS stream makes it pick the HLS extractor, and the
  /// video never starts — which is what the black rectangle on the reels
  /// page was.
  static VideoFormat? formatHintFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return VideoFormat.hls;
    if (path.endsWith('.mpd')) return VideoFormat.dash;
    return null;
  }

  @override
  State<ReelVideo> createState() => _ReelVideoState();
}

class _ReelVideoState extends State<ReelVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _firstFramePainted = false;
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
        // Outside the window the decoder is released completely.
        _release();
      }
      return;
    }

    if (oldWidget.isActive != widget.isActive) {
      _syncPlayback();
    }

    if (oldWidget.isSuspended != widget.isSuspended) {
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
    _firstFramePainted = false;
    if (controller != null) {
      controller.removeListener(_onTick);
      controller.dispose();
    }
  }

  Future<void> _prepare() async {
    // A picture needs no decoder — it is on screen as soon as it is
    // downloaded.
    if (widget.imageUrl != null) {
      if (mounted) setState(() => _ready = true);
      widget.onReady?.call();
      return;
    }

    final url = widget.url;
    final asset = widget.assetPath;
    if (url == null && asset == null) {
      if (mounted) setState(() => _failed = true);
      widget.onFailed?.call();
      return;
    }

    try {
      final controller = asset != null
          ? VideoPlayerController.asset(asset)
          : VideoPlayerController.networkUrl(
              Uri.parse(url ?? ''),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
              formatHint: ReelVideo.formatHintFor(url ?? ''),
            );

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
      widget.onFailed?.call();
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    if (!_firstFramePainted &&
        controller.value.isInitialized &&
        controller.value.position > Duration.zero) {
      _firstFramePainted = true;
      if (mounted) setState(() {});
    }

    final duration = controller.value.duration;
    if (duration.inMilliseconds > 0) {
      widget.onProgress?.call(
        (controller.value.position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0),
      );
    }
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !_ready) return;

    // A short debounce stops a burst of page changes from thrashing the
    // decoder — that is what causes the stutter on a low end phone.
    _playDebounce?.cancel();
    _playDebounce = Timer(const Duration(milliseconds: 90), () async {
      if (!mounted) return;
      final current = _controller;
      if (current == null) return;

      // Suspended means "hold the frame": the video is paused where it is,
      // and it picks up from the same second when it is released.
      if (widget.isSuspended) {
        await current.pause();
        return;
      }

      if (widget.isActive) {
        await current.play();
      } else {
        // Stopping is exact: the position is rewound so the reel always
        // starts from the top when it comes back.
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

    // --- a picture post --------------------------------------------
    final imageUrl = widget.imageUrl;
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _poster(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _poster();
        },
      );
    }

    if (_failed || controller == null || !_ready) {
      return _poster();
    }

    // The video fills the screen edge to edge, the way TikTok does.
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
        // The poster cross fades out once the first frame is on screen.
        AnimatedOpacity(
          opacity: _firstFramePainted ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: _poster(),
        ),
      ],
    );
  }

  Widget _poster() {
    // A soft gradient underneath, so the reel never shows a flat black
    // rectangle while the video is being prepared.
    final placeholder = const DecoratedBox(
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
