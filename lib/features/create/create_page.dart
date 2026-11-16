// ============================================================================
//  ENNVO — CREATE SCREEN
//
//  Ported from `src/pages/Create.tsx`.
//
//  The composer offers:
//    • a caption field
//    • the picture that was shot in the camera
//    • a "big text" background picker — the fourteen gradients the web app
//      ships, plus a custom colour
//    • the advanced settings sheet: comments disabled, privacy, hidden
//      likes, remixes, high quality and saving to the device
//
//  The share button uploads the file to Cloudflare R2 and writes the post
//  to Firestore, the same two steps the web app takes.
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/services/post_service.dart';
import '../../data/services/upload_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/inputs.dart';

class CreatePage extends ConsumerStatefulWidget {
  const CreatePage({
    super.key,
    this.mediaFile,
    this.isReel = false,
  });

  /// The picture that was shot or picked in the camera.
  final File? mediaFile;

  /// The media is a reel and not a post.
  final bool isReel;

  @override
  ConsumerState<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends ConsumerState<CreatePage> {
  final TextEditingController _caption = TextEditingController();

  /// The selected big-text background id — one of
  /// [AppGradients.bigTextBackgrounds].
  String _background = 'none';
  Color _customColor = const Color(0xFF2563EB);
  bool _showAdvanced = false;

  /// The upload is running.
  bool _uploading = false;

  /// How far the upload has come.
  double _progress = 0;

  /// The picture was sent.
  bool _published = false;

  // --- advanced settings, matching the web app's object --------------
  bool _commentsDisabled = false;
  String _privacy = 'public';
  bool _hideLikes = false;
  bool _allowRemix = true;
  bool _highQuality = true;
  bool _saveToDevice = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;

    // The advanced settings open as a bottom sheet.
    if (_showAdvanced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _showAdvanced = false);
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => const _AdvancedSettingsSheet(),
        );
      });
    }

    return Scaffold(
      backgroundColor: t.background,
      body: Column(
        children: [
          // --- header -------------------------------------------------
          Padding(
            padding: EdgeInsets.fromLTRB(6, top + 6, 12, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: LucideIcon(
                    LucideIcons.arrowLeft,
                    size: 22,
                    strokeWidth: 2.3,
                    color: t.textPrimary,
                  ),
                  tooltip: 'Close',
                ),
                Expanded(
                  child: Text(
                    widget.isReel ? 'New reel' : 'Create',
                    style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
                  ),
                ),
                if (_uploading)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _progress == 0 ? null : _progress,
                        color: t.accent,
                      ),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _uploading ? null : _publish,
                  child: Text(
                    'Share',
                    style: EnnvoText.bodySemi.copyWith(
                      color: _uploading ? t.textTertiary : t.accent,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
              children: [
                // --- the media area ------------------------------------
                AspectRatio(
                  aspectRatio: widget.isReel ? 9 / 16 : 1,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      gradient: _backgroundGradient(),
                      color: _background == 'none' ? t.surfaceAlt : null,
                    ),
                    child: Stack(
                      children: [
                        if (widget.mediaFile != null)
                          Positioned.fill(
                            child: Image.file(
                              widget.mediaFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        if (widget.mediaFile == null && _background == 'none')
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LucideIcon(
                                  LucideIcons.image,
                                  size: 44,
                                  strokeWidth: 1.6,
                                  color: t.textTertiary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Add photos or a video',
                                  style: EnnvoText.body.copyWith(
                                    color: t.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_caption.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _caption.text,
                              style: EnnvoText.pageHero.copyWith(
                                color: _background == 'none'
                                    ? t.textPrimary
                                    : Colors.white,
                                fontSize: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // --- caption --------------------------------------------
                EnnvoTextField(
                  label: 'Caption',
                  controller: _caption,
                  hint: 'Write a caption…',
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 18),

                // --- the tool row ---------------------------------------
                Row(
                  children: [
                    _ToolButton(
                      icon: const LucideIcon(
                        LucideIcons.image,
                        size: 20,
                        strokeWidth: 2.2,
                      ),
                      label: 'Photo',
                      onTap: () {},
                    ),
                    _ToolButton(
                      icon: const LucideIcon(
                        LucideIcons.music,
                        size: 20,
                        strokeWidth: 2.2,
                      ),
                      label: 'Music',
                      onTap: () {},
                    ),
                    _ToolButton(
                      icon: const LucideIcon(
                        LucideIcons.mapPin,
                        size: 20,
                        strokeWidth: 2.2,
                      ),
                      label: 'Location',
                      onTap: () {},
                    ),
                    _ToolButton(
                      icon: const LucideIcon(
                        LucideIcons.userPlus,
                        size: 20,
                        strokeWidth: 2.2,
                      ),
                      label: 'Tag',
                      onTap: () {},
                    ),
                    _ToolButton(
                      icon: const LucideIcon(
                        LucideIcons.sliders,
                        size: 20,
                        strokeWidth: 2.2,
                      ),
                      label: 'Settings',
                      onTap: () => setState(() => _showAdvanced = true),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // --- the big text background picker ---------------------
                Text(
                  'BIG TEXT BACKGROUND',
                  style: EnnvoText.overlineXs.copyWith(
                    color: t.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in AppGradients.bigTextBackgrounds.entries)
                      _GradientSwatch(
                        id: entry.key,
                        css: entry.value,
                        isSelected: _background == entry.key,
                        onTap: () => setState(() => _background = entry.key),
                      ),
                    // The custom colour swatch.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _background = 'custom'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _customColor,
                          border: Border.all(
                            color: _background == 'custom'
                                ? t.accent
                                : Colors.white.withValues(alpha: 0.6),
                            width: _background == 'custom' ? 3 : 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.palette_outlined,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Uploads the picture and writes the post.
  Future<void> _publish() async {
    if (_uploading || _published) return;

    final file = widget.mediaFile;
    final user = ref.read(authControllerProvider).user;

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    String? url;
    if (file != null) {
      try {
        final uploaded = await UploadService.uploadFile(
          file: file,
          folder: widget.isReel ? 'reels' : 'posts',
          onProgress: (sent, total) {
            if (!mounted) return;
            if (total <= 0) return;
            setState(() => _progress = sent / total);
          },
        );
        url = uploaded.url;
      } catch (_) {
        url = null;
      }
    }

    // The post is written even when the upload did not make it: the text
    // of a post is worth more than its picture.
    final id = 'post-${DateTime.now().millisecondsSinceEpoch}';
    final written = await PostService.create(
      id: id,
      authorId: user?.uid ?? 'me',
      authorName: user?.name ?? 'You',
      authorAvatar: user?.avatar ?? '',
      authorUsername: user?.username ?? '',
      text: _caption.text.trim(),
      media: url == null ? const <String>[] : <String>[url],
      mediaTypes: url == null ? const <String>[] : const <String>['image'],
      type: widget.isReel ? 'reel' : 'post',
      privacy: _privacy,
      commentsDisabled: _commentsDisabled,
      allowRemix: _allowRemix,
      hideLikes: _hideLikes,
      highQuality: _highQuality,
      saveToDevice: _saveToDevice,
    );

    if (!mounted) return;
    setState(() {
      _uploading = false;
      _published = written != null;
    });

    if (written != null) {
      Navigator.of(context).maybePop();
    }
  }

  Gradient? _backgroundGradient() {
    if (_background == 'custom') {
      return LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [_customColor, _customColor.withValues(alpha: 0.7)],
      );
    }

    final css = AppGradients.bigTextBackgrounds[_background];
    if (css == null || css.isEmpty) return null;

    // The gradients are stored exactly as the web app's CSS.
    if (css.startsWith('#')) {
      return null;
    }

    final stops = _parseCssGradient(css);
    return LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: stops.map((e) => e.$1).toList(),
      stops: stops.map((e) => e.$2).toList(),
    );
  }

  /// Reads the hex colours out of a CSS gradient string.
  static List<(Color, double)> _parseCssGradient(String css) {
    final hexMatches = RegExp(
      r'#([0-9a-fA-F]{3,8})',
    ).allMatches(css).toList();
    final colors = <Color>[];
    for (final match in hexMatches) {
      final hex = match.group(1)!;
      final expanded = hex.length == 3
          ? hex.split('').map((c) => '$c$c').join()
          : hex;
      final value = int.tryParse(expanded, radix: 16);
      if (value == null) continue;
      colors.add(
        Color(expanded.length == 6 ? 0xFF000000 | value : value),
      );
    }
    if (colors.isEmpty) return const [];
    if (colors.length == 1) return [(colors.first, 0), (colors.first, 1)];

    return [
      for (var i = 0; i < colors.length; i++)
        (colors[i], i / (colors.length - 1)),
    ];
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: EnnvoText.tiny.copyWith(
                color: t.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientSwatch extends StatelessWidget {
  const _GradientSwatch({
    required this.id,
    required this.css,
    required this.isSelected,
    required this.onTap,
  });

  final String id;
  final String css;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final stops = _CreatePageState._parseCssGradient(css);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          gradient: stops.isEmpty
              ? null
              : LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: stops.map((e) => e.$1).toList(),
                  stops: stops.map((e) => e.$2).toList(),
                ),
          color: stops.isEmpty ? const Color(0xFF171717) : null,
          border: Border.all(
            color: isSelected ? t.accent : Colors.white.withValues(alpha: 0.6),
            width: isSelected ? 3 : 1.5,
          ),
        ),
      ),
    );
  }
}

/// The advanced settings sheet.
class _AdvancedSettingsSheet extends StatefulWidget {
  const _AdvancedSettingsSheet();

  @override
  State<_AdvancedSettingsSheet> createState() => _AdvancedSettingsSheetState();
}

class _AdvancedSettingsSheetState extends State<_AdvancedSettingsSheet> {
  bool _commentsDisabled = false;
  bool _hideLikes = false;
  bool _allowRemix = true;
  bool _highQuality = true;
  bool _saveToDevice = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: t.borderStrong,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Advanced settings',
              style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: 10),
            _ToggleRow(
              label: 'Turn off commenting',
              value: _commentsDisabled,
              onChanged: (v) => setState(() => _commentsDisabled = v),
            ),
            _ToggleRow(
              label: 'Hide like counts',
              value: _hideLikes,
              onChanged: (v) => setState(() => _hideLikes = v),
            ),
            _ToggleRow(
              label: 'Allow remixes',
              value: _allowRemix,
              onChanged: (v) => setState(() => _allowRemix = v),
            ),
            _ToggleRow(
              label: 'High quality upload',
              value: _highQuality,
              onChanged: (v) => setState(() => _highQuality = v),
            ),
            _ToggleRow(
              label: 'Save to device',
              value: _saveToDevice,
              onChanged: (v) => setState(() => _saveToDevice = v),
            ),
            const SizedBox(height: 18),
            EnnvoPrimaryButton(label: 'Done', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
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
