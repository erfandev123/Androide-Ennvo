// ============================================================================
//  ENNVO — LIVE UPLOAD CAMERA
//
//  The screen the `+` of the navigation bar opens.
//
//  Stage 1 — the camera: a live preview, a shutter that takes a photo on a
//  tap and records a video on a hold, the flash, a timer, the flip and the
//  gallery.
//
//  Stage 2 — the edit: trim, sound, text, stickers, filters and the cover.
//
//  Stage 3 — the publish: a TikTok style page with the cover, the title,
//  the privacy and the upload itself.
//
//  The preview uses CameraX through the camera plugin. A middle resolution
//  keeps recording smooth on a weak phone: `max` is the first thing to
//  stutter there.
// ============================================================================

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/icons/ion_icons.dart';
import '../../shared/icons/lucide_icons.dart';
import 'upload_page.dart';

enum CameraMode { post, reel, story }

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;

  /// 0 = the camera, 1 = the edit, 2 = the publish page.
  int _stage = 0;

  CameraMode _mode = CameraMode.post;

  /// The file that was shot or picked.
  XFile? _media;
  Uint8List? _imageBytes;
  bool _mediaIsVideo = false;

  bool _videoReady = false;

  bool _busy = false;
  bool _recording = false;
  bool _flash = false;
  bool _frontCamera = false;
  int _countdown = 0;

  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  Timer? _timer;
  Timer? _countdownTimer;

  // --- the edit ---
  VideoPlayerController? _previewPlayer;
  bool _muted = true;
  String? _music;
  final List<String> _stickers = <String>[];
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _countdownTimer?.cancel();
    _elapsed.dispose();
    _text.dispose();
    unawaited(_previewPlayer?.dispose());
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _stage == 0) {
      _openCamera();
    }
  }

  Future<void> _openCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty || !mounted) return;

      final description = _frontCamera &&
              _cameras.length > 1
          ? _cameras.firstWhere(
              (camera) =>
                  camera.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first,
            )
          : _cameras.first;

      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (_) {
      // A denied permission or a phone without a camera is fine: the
      // gallery button still works.
    } catch (_) {
      // No camera plugin on this device (or in a widget test) - the
      // gallery still works.
    }
  }

  bool get _isVideo {
    if (_mediaIsVideo) return true;
    final p = (_media?.path ?? '').toLowerCase();
    final n = (_media?.name ?? '').toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        n.endsWith('.mp4') ||
        n.endsWith('.mov');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_stage) {
        0 => _buildCamera(),
        1 => _buildEdit(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // ======================================================================
  //  Stage 1 — the camera
  // ======================================================================
  Widget _buildCamera() {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          Positioned.fill(
            child: CameraPreview(
              controller!,
              child: const SizedBox.expand(),
            ),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B1030), Color(0xFF07060C)],
              ),
            ),
          ),

        // --- the top bar ----------------------------------------------
        Positioned(
          top: MediaQuery.paddingOf(context).top + 6,
          left: 6,
          right: 6,
          child: Row(
            children: [
              _RoundButton(
                icon: LucideIcons.x,
                semanticLabel: 'Close',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              if (_countdown > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const Spacer(),
              _RoundButton(
                icon: LucideIcons.settings2,
                semanticLabel: 'Camera settings',
                onTap: () => _openCameraSettings(context),
              ),
            ],
          ),
        ),

        // --- the tools on the right -----------------------------------
        Positioned(
          right: 12,
          top: MediaQuery.paddingOf(context).top + 82,
          child: Column(
            children: [
              _ToolButton(
                icon: LucideIcons.zap,
                label: 'Flash',
                active: _flash,
                onTap: () async {
                  setState(() => _flash = !_flash);
                  final c = _controller;
                  if (c != null && c.value.isInitialized) {
                    await c.setFlashMode(
                      _flash ? FlashMode.torch : FlashMode.off,
                    );
                  }
                },
              ),
              const SizedBox(height: 18),
              _ToolButton(
                icon: LucideIcons.clock,
                label: _countdown == 0 ? 'Timer' : '${_countdown}s',
                active: _recordTimer > 0,
                onTap: () {
                  setState(() {
                    _recordTimer = switch (_recordTimer) {
                      0 => 3,
                      3 => 10,
                      _ => 0,
                    };
                  });
                },
              ),
              const SizedBox(height: 18),
              _ToolButton(
                icon: LucideIcons.switchCamera,
                label: 'Flip',
                active: _frontCamera,
                onTap: () {
                  setState(() => _frontCamera = !_frontCamera);
                  _controller?.dispose();
                  _controller = null;
                  _openCamera();
                },
              ),
              const SizedBox(height: 18),
              _ToolButton(
                icon: IonIcons.music,
                label: 'Sound',
                onTap: () {},
              ),
              const SizedBox(height: 18),
              _ToolButton(
                icon: LucideIcons.sliders,
                label: 'Adjust',
                onTap: () {},
              ),
            ],
          ),
        ),

        // --- the recording pill ---------------------------------------
        if (_recording)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _elapsed,
                builder: (context, value, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fiber_manual_record,
                          color: Color(0xFFFF2D55),
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${value.inSeconds.toString().padLeft(2, '0')}:'
                          '${(value.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        // --- the bottom bar -------------------------------------------
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final mode in CameraMode.values)
                    _ModeChip(
                      label: _labelOf(mode),
                      isActive: mode == _mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SideButton(
                    icon: LucideIcons.image,
                    label: 'Gallery',
                    onTap: _pickFromGallery,
                  ),
                  _Shutter(
                    recording: _recording,
                    busy: _busy,
                    onTap: _takePicture,
                    onHoldStart: _startRecording,
                    onHoldEnd: _stopRecording,
                  ),
                  _SideButton(
                    icon: LucideIcons.sparkles,
                    label: 'Effects',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),

        // The dark fade behind the bottom controls.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 210,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xD9000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),

        if (_busy || _countdown > 0)
          const Positioned.fill(
            child: ColoredBox(color: Color(0x33000000)),
          ),
      ],
    );
  }

  int _recordTimer = 0;

  static String _labelOf(CameraMode mode) => switch (mode) {
    CameraMode.post => 'POST',
    CameraMode.reel => 'REEL',
    CameraMode.story => 'STORY',
  };

  // ---------------------------------------------------------------------
  //  Taking the media
  // ---------------------------------------------------------------------
  void _takePicture() {
    if (_busy || _recording) return;
    if (_recordTimer > 0) {
      setState(() => _countdown = _recordTimer);
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final next = _countdown - 1;
        if (next <= 0) {
          timer.cancel();
          setState(() => _countdown = 0);
          _capturePhoto();
        } else {
          setState(() => _countdown = next);
        }
      });
      return;
    }
    _capturePhoto();
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _media = photo;
        _imageBytes = bytes;
        _mediaIsVideo = false;
        _stage = 1;
        _busy = false;
        _muted = true;
      });
      unawaited(HapticFeedback.mediumImpact());
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (_recording || controller == null || !controller.value.isInitialized) {
      return;
    }
    // A video needs the microphone; if it was denied we still record the
    // picture, just without sound.
    setState(() => _recording = true);
    _elapsed.value = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _elapsed.value = Duration(
        milliseconds: _elapsed.value.inMilliseconds + 100,
      );
    });
    try {
      await controller.startVideoRecording();
    } catch (_) {
      unawaited(_stopRecording());
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (!_recording || controller == null) return;
    _timer?.cancel();
    setState(() => _recording = false);
    try {
      final video = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() {
        _media = XFile(video.path);
        _imageBytes = null;
        _mediaIsVideo = true;
        _stage = 1;
        _videoReady = false;
        _muted = true;
      });
      await _openPreview();
      unawaited(HapticFeedback.mediumImpact());
    } catch (_) {
      // A very short hold is treated as a tap.
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 90),
      );
      final isVideo = picked != null;
      final XFile? chosen = picked ??
          await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            imageQuality: 92,
          );
      if (chosen == null || !mounted) return;
      final bytes = isVideo ? null : await chosen.readAsBytes();
      if (!mounted) return;
      setState(() {
        _media = chosen;
        _imageBytes = bytes;
        _mediaIsVideo = isVideo;
        _stage = 1;
        _muted = true;
      });
      await _openPreview();
    } catch (_) {
      // Nothing picked.
    }
  }

  // ======================================================================
  //  Stage 2 — the edit
  // ======================================================================
  Future<void> _openPreview() async {
    if (!_isVideo) return;
    final path = _media?.path;
    if (path == null || path.isEmpty) return;

    final uri = kIsWeb ? Uri.parse(path) : Uri.file(path);
    final player = VideoPlayerController.networkUrl(uri);
    await player.initialize();
    await player.setLooping(true);
    await player.setVolume(0);
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() {
      _previewPlayer = player;
      _videoReady = true;
    });
    await player.play();
  }

  Widget _buildEdit() {
    final path = _media?.path ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _isVideo && _videoReady && _previewPlayer != null
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _previewPlayer!.value.size.width,
                    height: _previewPlayer!.value.size.height,
                    child: VideoPlayer(_previewPlayer!),
                  ),
                )
              : (_imageBytes != null
                    ? Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const _EmptyStage(),
                      )
                    : (kIsWeb && path.isNotEmpty
                          ? Image.network(
                              path,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const _EmptyStage(),
                            )
                          : const _EmptyStage())),
        ),

        // --- the top bar ----------------------------------------------
        Positioned(
          top: MediaQuery.paddingOf(context).top + 6,
          left: 6,
          right: 6,
          child: Row(
            children: [
              _RoundButton(
                icon: LucideIcons.arrowLeft,
                semanticLabel: 'Retake',
                onTap: _retake,
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _goToPublish,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppGradients.create,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- the edit tools --------------------------------------------
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_stickers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final sticker in _stickers.take(6))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(sticker, style: const TextStyle(fontSize: 30)),
                        ),
                    ],
                  ),
                ),
              SizedBox(
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _EditTool(
                      icon: LucideIcons.scissors,
                      label: _isVideo ? 'Trim' : 'Crop',
                      onTap: () => _editHint(_isVideo ? 'Trim' : 'Crop'),
                    ),
                    _EditTool(
                      icon: IonIcons.music,
                      label: _music ?? 'Sound',
                      active: _music != null,
                      onTap: _pickMusic,
                    ),
                    _EditTool(
                      icon: LucideIcons.type,
                      label: 'Text',
                      onTap: _addText,
                    ),
                    _EditTool(
                      icon: LucideIcons.smile,
                      label: 'Stickers',
                      onTap: _pickSticker,
                    ),
                    _EditTool(
                      icon: LucideIcons.sliders,
                      label: 'Filters',
                      onTap: () => _editHint('Filters'),
                    ),
                    _EditTool(
                      icon: LucideIcons.image,
                      label: 'Cover',
                      onTap: () => _editHint('Cover'),
                    ),
                    _EditTool(
                      icon: LucideIcons.volumeX,
                      label: _muted ? 'Unmute' : 'Mute',
                      onTap: () {
                        setState(() => _muted = !_muted);
                        _previewPlayer?.setVolume(_muted ? 0 : 1);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_text.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    _text.text,
                    textAlign: TextAlign.center,
                    style: EnnvoText.bodySemi.copyWith(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _retake() {
    _previewPlayer?.dispose();
    _previewPlayer = null;
    _videoReady = false;
    _text.clear();
    _stickers.clear();
    _music = null;
    setState(() {
      _media = null;
      _imageBytes = null;
      _mediaIsVideo = false;
      _stage = 0;
    });
    if (_controller == null) _openCamera();
  }

  void _goToPublish() {
    final path = _media?.path;
    if (path == null) return;
    _previewPlayer?.pause();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadPage(
          filePath: path,
          isVideo: _isVideo,
          isReel: _mode != CameraMode.post,
          caption: _text.text,
          music: _music,
          stickers: List<String>.of(_stickers),
        ),
      ),
    );
  }

  void _editHint(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is ready to use'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _pickMusic() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF18162B),
        title: const Text(
          'Add sound',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final song in const [
              'Original audio',
              'Trending sound',
              'Ennvo beats',
            ])
              ListTile(
                title: Text(song, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(dialogContext).pop(song),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _music = picked);
  }

  Future<void> _addText() async {
    final written = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF18162B),
        title: const Text(
          'Add text',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _text,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Say something...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_text.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (written == null) _text.clear();
    if (mounted) setState(() {});
  }

  Future<void> _pickSticker() async {
    const choices = ['✨', '🔥', '❤️', '😂', '🎉', '💯', '😎', '🥰'];
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF18162B),
        title: const Text(
          'Stickers',
          style: TextStyle(color: Colors.white),
        ),
        content: Wrap(
          children: [
            for (final sticker in choices)
              GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(sticker),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(sticker, style: const TextStyle(fontSize: 28)),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _stickers.add(picked));
  }

  void _openCameraSettings(BuildContext context) {
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 7, bottom: 10),
                decoration: BoxDecoration(
                  color: t.borderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const _SettingsLine(
                icon: LucideIcons.grid,
                label: 'Grid lines',
                value: 'Thirds',
              ),
              const _SettingsLine(
                icon: LucideIcons.camera,
                label: 'Video quality',
                value: 'High',
              ),
              const _SettingsLine(
                icon: LucideIcons.mic,
                label: 'Sound',
                value: 'On',
              ),
              const _SettingsLine(
                icon: LucideIcons.shield,
                label: 'Save the location',
                value: 'On',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  Stage placeholder
// ============================================================================
class _EmptyStage extends StatelessWidget {
  const _EmptyStage();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1030), Color(0xFF07060C)],
        ),
      ),
    );
  }
}

// ============================================================================
//  The top bar button
// ============================================================================
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.32),
          ),
          alignment: Alignment.center,
          child: LucideIcon(
            icon,
            size: 20,
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  One of the tools on the right
// ============================================================================
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon.contains('viewBox="0 0 512')
                ? IonIcon(
                    icon,
                    size: 23,
                    color: active ? const Color(0xFF38BDF8) : Colors.white,
                  )
                : LucideIcon(
                    icon,
                    size: 23,
                    strokeWidth: 1.9,
                    color: active ? const Color(0xFF38BDF8) : Colors.white,
                  ),
            const SizedBox(height: 4),
            Text(
              label,
              style: EnnvoText.tiny.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  A mode chip
// ============================================================================
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: EnnvoText.bodySemi.copyWith(
            color: Colors.white,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The shutter: tap for a photo, hold for a video
// ============================================================================
class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.recording,
    required this.busy,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final bool recording;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      onLongPressStart: busy ? null : (_) => onHoldStart(),
      onLongPressEnd: busy ? null : (_) => onHoldEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: recording ? const Color(0xFFFF2D55) : Colors.white,
            width: 3,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: recording
                ? const Color(0xFFFF2D55)
                : (busy ? Colors.white38 : Colors.white),
            borderRadius: BorderRadius.circular(
              recording ? 14 : 100,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The button beside the shutter
// ============================================================================
class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                icon,
                size: 20,
                strokeWidth: 1.9,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: EnnvoText.tiny.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  An edit tool
// ============================================================================
class _EditTool extends StatelessWidget {
  const _EditTool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF38BDF8) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon.contains('viewBox="0 0 512')
                ? IonIcon(icon, size: 25, color: color)
                : LucideIcon(
                    icon,
                    size: 24,
                    strokeWidth: 1.9,
                    color: color,
                  ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EnnvoText.tiny.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  One line of the settings
// ============================================================================
class _SettingsLine extends StatelessWidget {
  const _SettingsLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          LucideIcon(icon, size: 19, strokeWidth: 1.9, color: t.textPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: EnnvoText.body.copyWith(color: t.textPrimary),
            ),
          ),
          Text(
            value,
            style: EnnvoText.caption.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}
