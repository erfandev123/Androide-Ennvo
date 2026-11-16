// ============================================================================
//  ENNVO �?" UPLOAD CAMERA
//
//  The screen the `+` of the navigation bar opens.
//
//  It is the camera of Instagram: a dark stage, the shutter at the bottom,
//  the tools on the right and the modes on top of the shutter.
//
//    �?� the modes: POST, REEL and STORY
//    �?� the shutter takes the picture, the gallery brings one in
//    �?� the flash, the timer and the flip sit on the right
//    ���� the picked media is shown, and `Next` opens the composer
//
//  The camera of the phone is used through the photo picker of the system,
//  so the app asks for no camera permission it does not need.
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/icons/lucide_icons.dart';
import 'create_page.dart';

/// The three modes of the camera.
enum CameraMode { post, reel, story }

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraMode _mode = CameraMode.post;

  /// The file that was shot or picked.
  File? _file;

  /// The flash is on.
  bool _flash = false;

  /// The timer of the shutter.
  int _timer = 0;

  /// The picture is being taken.
  bool _busy = false;

  /// The camera is on the back of the phone.
  bool _frontCamera = false;

  @override
  Widget build(BuildContext context) {
    final file = _file;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- the stage ---------------------------------------------
          if (file != null)
            _Preview(file: file)
          else
            const _EmptyStage(),

          // --- the top bar --------------------------------------------
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
                if (file != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openComposer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppGradients.create,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  _RoundButton(
                    icon: LucideIcons.settings2,
                    semanticLabel: 'Settings',
                    onTap: () => _openCameraSettings(context),
                  ),
              ],
            ),
          ),

          // --- the tools on the right --------------------------------
          if (file == null)
            Positioned(
              right: 12,
              top: MediaQuery.paddingOf(context).top + 90,
              child: Column(
                children: [
                  _ToolButton(
                    icon: LucideIcons.zap,
                    label: 'Flash',
                    active: _flash,
                    onTap: () => setState(() => _flash = !_flash),
                  ),
                  const SizedBox(height: 18),
                  _ToolButton(
                    icon: LucideIcons.clock,
                    label: _timer == 0 ? 'Timer' : '${_timer}s',
                    active: _timer > 0,
                    onTap: _pickTimer,
                  ),
                  const SizedBox(height: 18),
                  _ToolButton(
                    icon: LucideIcons.switchCamera,
                    label: 'Flip',
                    active: _frontCamera,
                    onTap: () => setState(() => _frontCamera = !_frontCamera),
                  ),
                  const SizedBox(height: 18),
                  _ToolButton(
                    icon: LucideIcons.music,
                    label: 'Music',
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

          // --- the bottom bar -----------------------------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- the modes -----------------------------------------
                if (file == null) ...[
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
                ],

                // --- the shutter ---------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SideButton(
                      icon: LucideIcons.image,
                      label: 'Gallery',
                      onTap: _pickFromGallery,
                    ),
                    _Shutter(
                      busy: _busy,
                      onTap: _takePicture,
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

          // The light of the flash.
          if (_flash && _busy)
            const Positioned.fill(
              child: ColoredBox(color: Color(0xCCFFFFFF)),
            ),

          // The bottom of the screen is always dark, so the controls read.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 190,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _labelOf(CameraMode mode) => switch (mode) {
    CameraMode.post => 'POST',
    CameraMode.reel => 'REEL',
    CameraMode.story => 'STORY',
  };

  // ---------------------------------------------------------------------
  //  The camera
  // ---------------------------------------------------------------------
  Future<void> _takePicture() async {
    if (_busy) return;
    setState(() => _busy = true);

    if (_timer > 0) {
      await Future<void>.delayed(Duration(seconds: _timer));
      if (!mounted) return;
    }

    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: _frontCamera
            ? CameraDevice.front
            : CameraDevice.rear,
        maxWidth: 1920,
        imageQuality: 92,
      );
      if (shot == null) return;
      if (!mounted) return;
      setState(() => _file = File(shot.path));
    } catch (_) {
      // A phone without a camera still opens the gallery.
      await _pickFromGallery();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 92,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _file = File(picked.path));
    } catch (_) {
      // Nothing to do.
    }
  }

  void _pickTimer() {
    setState(() {
      _timer = switch (_timer) {
        0 => 3,
        3 => 10,
        _ => 0,
      };
    });
  }

  /// The composer of the post, with the media that was picked.
  void _openComposer() {
    final file = _file;
    if (file == null) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatePage(
          mediaFile: file,
          isReel: _mode == CameraMode.reel,
        ),
      ),
    );
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
                label: 'Grid',
                value: 'Off',
              ),
              const _SettingsLine(
                icon: LucideIcons.camera,
                label: 'Grid lines',
                value: 'Thirds',
              ),
              const _SettingsLine(
                icon: LucideIcons.type,
                label: 'Text size',
                value: 'Medium',
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
//  The stage, before anything was shot
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
//  The picture that was shot
// ============================================================================
class _Preview extends StatelessWidget {
  const _Preview({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    final isVideo = file.path.toLowerCase().endsWith('.mp4');

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _EmptyStage(),
        ),
        if (isVideo)
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 64,
              color: Color(0xCCFFFFFF),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
//  The round button in the top bar
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
            LucideIcon(
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
//  One of the modes
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
//  The shutter
// ============================================================================
class _Shutter extends StatelessWidget {
  const _Shutter({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        width: 74,
        height: 74,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy ? Colors.white38 : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  The button on the side of the shutter
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
//  One line of the settings of the camera
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
          Text(value, style: EnnvoText.caption.copyWith(color: t.textSecondary)),
        ],
      ),
    );
  }
}
