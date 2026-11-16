// ============================================================================
//  ENNVO �?" REEL VIDEO
//
//  The video surface of a reel.
//
//  Playback strategy �?" this is what makes the feed feel like TikTok:
//
//    �?� the controller is created as soon as the reel enters the preload
//      window, not when it becomes active, so the network round trip and
//      the first frame decode happen while the user is still watching
//    �?� the active reel plays, the prepared neighbour stays paused
//    �?� a reel that leaves the window is released completely, decoder and all
//    �?� the poster is shown until the first frame is ready, then the video
//      cross fades in over it
//    �?� pausing resets the position, so a reel always starts from the top
//
//  The frame of the video keeps its own shape. A 9:16 reel, a 16:9 reel and
//  a square reel are all shown at their own size, centred on the black of
//  the feed: the picture is never stretched and never cropped away, which is
//  what Instagram does with the frames of its feed.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../shared/icons/lucide_icons.dart';

/// A handle on the playback of the reel on screen.
///
/// The timeline drags it, and the reel follows: the page owns the handle
/// and hands it to the card, so a scrub never rebuilds the feed.
class ReelPlayback extends ChangeNotifier {
  double _speed = 1;
  double? _seekTo;

  /// The playback speed the reel runs at.
  double get speed => _speed;

  /// Runs the reel at [speed]. The 2x hold gesture uses it.
  void setSpeed(double speed) {
    if ((_speed - speed).abs() < 0.01) return;
    _speed = speed;
    notifyListeners();
  }

  /// Moves the reel to [fraction] of its length.
  void seek(double fraction) {
    _seekTo = fraction.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// The position the reel is asked to move to.
  ///
  /// It stays pending until the reel that is on screen takes it, so a
  /// neighbouring reel never swallows the scrub.
  double? get pendingSeek => _seekTo;

  /// Takes the pending seek.
  void consumeSeek() {
    _seekTo = null;
  }
}

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
    this.playback,
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
  /// A post in the reels feed may carry a photo �?" handing it to the video
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

  /// The shared playback handle: the speed and the seek.
  final ReelPlayback? playback;

  /// The format of a video URL.
  ///
  /// Only a real HLS playlist is played as HLS. Telling the player that a
  /// plain MP4 is an HLS stream makes it pick the HLS extractor, and the
  /// video never starts �?" which is what the black rectangle on the reels
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
  ReelPlayback? _playback;

  @override
  void initState() {
    super.initState();
    if (widget.isNear) _prepare();
    _attachPlayback();
  }

  @override
  void didUpdateWidget(covariant ReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.playback != widget.playback) {
      _detachPlayback();
      _attachPlayback();
    }

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
    _detachPlayback();
    _release();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  //  The playback handle
  // ---------------------------------------------------------------------
  void _attachPlayback() {
    final playback = widget.playback;
    if (playback == null) return;
    _playback = playback..addListener(_onPlaybackChanged);
  }

  void _detachPlayback() {
    _playback?.removeListener(_onPlaybackChanged);
    _playback = null;
  }

  /// A scrub or a speed change arrived.
  void _onPlaybackChanged() {
    final playback = _playback;
    if (playback == null) return;

    // The speed first: it is the cheap one.
    final controller = _controller;
    if (controller != null && _ready) {
      unawaited(controller.setPlaybackSpeed(playback.speed));
    }

    final fraction = playback.pendingSeek;
    if (fraction == null) return;

    // Only the reel on screen takes the scrub. The neighbours are paused,
    // and they must not swallow the position the user dragged to.
    if (!widget.isActive) return;
    playback.consumeSeek();

    final current = _controller;
    if (current == null || !_ready) return;
    final duration = current.value.duration;
    if (duration.inMilliseconds <= 0) return;
    unawaited(
      current.seekTo(
        Duration(
          milliseconds: (duration.inMilliseconds * fraction).round(),
        ),
      ),
    );
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
    // A picture needs no decoder �?" it is on screen as soon as it is
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
      await controller.setPlaybackSpeed(_playback?.speed ?? 1);
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

  /// Loads the video again after a failure.
  void _retry() {
    setState(() => _failed = false);
    unawaited(_prepare());
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
    // decoder �?" that is what causes the stutter on a low end phone.
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

  /// Sets the playback speed �?" used by the 2x hold gesture.
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
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _poster(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _poster();
        },
      );
    }

    if (_failed) {
      // The video could not be loaded. The reel says so and offers a second
      // try, instead of showing a black rectangle for ever.
      return Stack(
        fit: StackFit.expand,
        children: [
          _poster(),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _retry,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: const LucideIcon(
                  LucideIcons.rotateCw,
                  size: 20,
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (controller == null || !_ready) {
      return _poster();
    }

    // The video keeps its own shape: it is fitted inside the frame, never
    // stretched and never cropped away.
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.contain,
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
            fit: BoxFit.contain,
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
            fit: BoxFit.contain,
            cacheWidth: 1080,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      );
    }

    return placeholder;
  }
}
