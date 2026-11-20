// ============================================================================
//  ENNVO — THE UPLOAD PAGE
//
//  The last step of the camera. It is the TikTok publish screen:
//
//    • the cover of the reel, with a frame picker
//    • the title, the tags, the sound and the location
//    • who may see it, who may comment, who may remix it
//    • the upload to Cloudflare R2 and the post in Firestore
//
//  The progress is a real one: the file goes up in pieces, and the bar
//  follows the bytes.
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/services/post_service.dart';
import '../../data/services/upload_service.dart';
import '../../shared/icons/ion_icons.dart';
import '../../shared/icons/lucide_icons.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({
    super.key,
    required this.filePath,
    required this.isVideo,
    required this.isReel,
    this.caption = '',
    this.music,
    this.stickers = const [],
  });

  final String filePath;
  final bool isVideo;
  final bool isReel;
  final String caption;
  final String? music;
  final List<String> stickers;

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _tags = TextEditingController();

  VideoPlayerController? _player;
  XFile? _cover;
  Uint8List? _coverBytes;
  Uint8List? _imageBytes;

  bool _uploading = false;
  double _progress = 0;
  String? _error;
  bool _done = false;

  String _privacy = 'public';
  bool _comments = true;
  bool _remix = true;
  final bool _hideLikes = false;
  final bool _saveToDevice = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.caption;
    if (widget.isVideo) {
      _openVideo();
    } else {
      _loadImageBytes();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _loadImageBytes() async {
    try {
      final bytes = await XFile(widget.filePath).readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (_) {}
  }

  Future<void> _openVideo() async {
    final uri = kIsWeb
        ? Uri.parse(widget.filePath)
        : Uri.file(widget.filePath);
    final controller = VideoPlayerController.networkUrl(uri);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _player = controller);
      await controller.play();
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: t.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // --- the cover of the post ----------------------------------
          Positioned(
            top: top + 64,
            left: 0,
            right: 0,
            bottom: bottom + 300,
            child: _CoverPreview(
              path: _cover?.path ?? widget.filePath,
              imageBytes: _coverBytes ?? _imageBytes,
              isVideo: widget.isVideo && _cover == null,
              player: _player,
              onPickCover: _pickCover,
            ),
          ),

          // --- the top bar --------------------------------------------
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: LucideIcon(
                      LucideIcons.arrowLeft,
                      size: 22,
                      color: t.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'New ${widget.isReel ? 'reel' : 'post'}',
                      textAlign: TextAlign.center,
                      style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _uploading ? null : _publish,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        'Post',
                        style: EnnvoText.bodySemi.copyWith(
                          color: t.accent,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- the fields ---------------------------------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: Container(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.sheetSmall),
                ),
                border: Border(top: BorderSide(color: t.border)),
              ),
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // the handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.borderStrong,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // the title
                  TextField(
                    controller: _title,
                    maxLines: 2,
                    style: EnnvoText.body.copyWith(
                      color: t.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.isReel
                          ? 'Say something about your reel...'
                          : 'Write a caption...',
                      hintStyle: EnnvoText.body.copyWith(
                        color: t.textTertiary,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // the tags and the music
                  Row(
                    children: [
                      Icon(Icons.tag, size: 16, color: t.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _tags,
                          style: EnnvoText.caption.copyWith(
                            color: t.textSecondary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add tags',
                            hintStyle: EnnvoText.caption.copyWith(
                              color: t.textTertiary,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.music != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IonIcon(
                          IonIcons.music,
                          size: 15,
                          color: t.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.music!,
                          style: EnnvoText.caption.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  Divider(height: 1, color: t.border),
                  const SizedBox(height: 6),

                  // the options
                  _OptionRow(
                    icon: LucideIcons.globe,
                    label: 'Who can see this',
                    value: switch (_privacy) {
                      'followers' => 'Followers',
                      'private' => 'Only me',
                      _ => 'Everyone',
                    },
                    onTap: () {
                      setState(() {
                        _privacy = switch (_privacy) {
                          'public' => 'followers',
                          'followers' => 'private',
                          _ => 'public',
                        };
                      });
                    },
                  ),
                  _OptionSwitch(
                    icon: LucideIcons.messageCircle,
                    label: 'Allow comments',
                    value: _comments,
                    onChanged: (v) => setState(() => _comments = v),
                  ),
                  _OptionSwitch(
                    icon: LucideIcons.repeat2,
                    label: 'Allow remixes',
                    value: _remix,
                    onChanged: (v) => setState(() => _remix = v),
                  ),
                ],
              ),
            ),
          ),

          // --- the upload progress ------------------------------------
          if (_uploading || _done || _error != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.86),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_done)
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF22C55E),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          )
                        else if (_error != null)
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFFF2D55),
                            size: 64,
                          )
                        else
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              value: _progress == 0 ? null : _progress,
                              strokeWidth: 5,
                              color: const Color(0xFF38BDF8),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                        const SizedBox(height: 22),
                        Text(
                          _done
                              ? 'Your reel is live'
                              : (_error ?? 'Uploading...'),
                          textAlign: TextAlign.center,
                          style: EnnvoText.titleMd.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!_done && _error == null)
                          Text(
                            '${(_progress * 100).round()}%',
                            style: EnnvoText.bodySemi.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 15,
                            ),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => setState(() {
                              _error = null;
                              _uploading = false;
                              _progress = 0;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: const Text(
                                'Try again',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCover() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _cover = picked;
        _coverBytes = bytes;
      });
    } catch (_) {
      // Nothing picked.
    }
  }

  // ---------------------------------------------------------------------
  //  The upload
  // ---------------------------------------------------------------------
  Future<void> _publish() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });

    String? url;
    try {
      final uploaded = await UploadService.uploadXFile(
        file: XFile(widget.filePath),
        folder: widget.isReel ? 'reels' : 'posts',
        contentType: widget.isVideo ? 'video/mp4' : null,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = (sent / total).clamp(0.0, 1.0));
        },
      );
      url = uploaded.url;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Upload failed. Check the connection.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _progress = 1);

    final user = ref.read(authControllerProvider).user;
    final id = 'post-${DateTime.now().millisecondsSinceEpoch}';
    final tags = _tags.text.trim();
    final caption = [
      _title.text.trim(),
      if (tags.isNotEmpty) tags,
      ...widget.stickers,
    ].where((part) => part.isNotEmpty).join(' ');

    final written = await PostService.create(
      id: id,
      authorId: user?.uid ?? 'me',
      authorName: user?.name ?? 'You',
      authorAvatar: user?.avatar ?? '',
      authorUsername: user?.username ?? '',
      text: caption,
      media: <String>[url],
      mediaTypes: <String>[widget.isVideo ? 'video' : 'image'],
      type: widget.isReel ? 'reel' : 'post',
      songTitle: widget.music,
      privacy: _privacy,
      commentsDisabled: !_comments,
      allowRemix: _remix,
      hideLikes: _hideLikes,
      saveToDevice: _saveToDevice,
    );

    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (written != null) {
        _done = true;
      } else {
        _error = 'Could not save the post. Please try again.';
      }
    });

    if (written != null) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

// ============================================================================
//  The cover of the post
// ============================================================================
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.path,
    required this.imageBytes,
    required this.isVideo,
    required this.player,
    required this.onPickCover,
  });

  final String path;
  final Uint8List? imageBytes;
  final bool isVideo;
  final VideoPlayerController? player;
  final VoidCallback onPickCover;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: isVideo && player != null && player!.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: player!.value.size.width,
                    height: player!.value.size.height,
                    child: VideoPlayer(player!),
                  ),
                )
              : (imageBytes != null
                    ? Image.memory(
                        imageBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF0B0B0E),
                        ),
                      )
                    : (kIsWeb && path.isNotEmpty
                          ? Image.network(
                              path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: Color(0xFF0B0B0E),
                              ),
                            )
                          : const ColoredBox(color: Color(0xFF0B0B0E)))),
        ),
        Positioned(
          right: 14,
          bottom: 14,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPickCover,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Edit cover',
                    style: EnnvoText.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  One option row
// ============================================================================
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            LucideIcon(icon, size: 17, color: t.textSecondary),
            const SizedBox(width: 12),
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
            const SizedBox(width: 4),
            LucideIcon(
              LucideIcons.chevronRight,
              size: 15,
              color: t.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          LucideIcon(icon, size: 17, color: t.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: EnnvoText.body.copyWith(color: t.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: t.accent,
          ),
        ],
      ),
    );
  }
}
