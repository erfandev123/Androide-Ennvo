// ============================================================================
//  ENNVO — CREATE SCREEN
//
//  Facebook-inspired post composer adapted for mobile & web:
//    • Author header with interactive Audience/Privacy selector pill
//    • Spacious auto-growing "What's on your mind?" composer
//    • Rounded (22px) Big Text gradient card + swatch selector strip
//    • Rounded media preview (Photo or Video, Web-safe via XFile bytes)
//    • Quick sheets for Music/Song, Location, Tag Friends, and Settings
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/user.dart';
import '../../data/services/post_service.dart';
import '../../data/services/upload_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../../shared/widgets/buttons.dart';

class CreatePage extends ConsumerStatefulWidget {
  const CreatePage({
    super.key,
    this.mediaFile,
    this.isVideo = false,
    this.isReel = false,
  });

  final XFile? mediaFile;
  final bool isVideo;
  final bool isReel;

  @override
  ConsumerState<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends ConsumerState<CreatePage> {
  final TextEditingController _caption = TextEditingController();

  XFile? _mediaFile;
  Uint8List? _mediaBytes;
  bool _isVideo = false;
  String _background = 'none';
  Color _customColor = const Color(0xFF2563EB);
  String? _musicTitle;
  String? _locationLabel;
  final List<String> _taggedFriends = <String>[];

  bool _uploading = false;
  double _progress = 0;
  bool _published = false;

  bool _commentsDisabled = false;
  String _privacy = 'public';
  bool _hideLikes = false;
  bool _allowRemix = true;
  bool _highQuality = true;
  bool _saveToDevice = false;

  static const List<Color> _customPalette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFFE11D48),
    Color(0xFFF97316),
    Color(0xFF0D9488),
    Color(0xFF171717),
  ];

  static const List<String> _presetSongs = [
    'Lofi Chill Beats - Ennvo Studio',
    'Midnight City Lights - Synthwave',
    'Dhaka Sunset - Acoustic Mix',
    'Summer Breeze - Lo-Fi Vibes',
    'Ocean Horizon - Ambient',
    'Original audio',
  ];

  static const List<String> _presetLocations = [
    'Dhaka, Bangladesh',
    'Chattogram, Bangladesh',
    'Sylhet, Bangladesh',
    'Cox\'s Bazar Beach',
    'London, UK',
    'New York, USA',
  ];

  @override
  void initState() {
    super.initState();
    _mediaFile = widget.mediaFile;
    _isVideo = widget.isVideo;
    if (_mediaFile != null && !_isVideo) {
      _loadMediaBytes(_mediaFile!);
    }
    _caption.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadMediaBytes(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (!mounted || _mediaFile?.path != file.path) return;
      setState(() => _mediaBytes = bytes);
    } catch (_) {}
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _mediaFile = photo;
        _mediaBytes = bytes;
        _isVideo = false;
        _background = 'none';
      });
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    try {
      final video = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 90),
      );
      if (video == null || !mounted) return;
      setState(() {
        _mediaFile = video;
        _mediaBytes = null;
        _isVideo = true;
        _background = 'none';
      });
    } catch (_) {}
  }

  void _clearMedia() {
    setState(() {
      _mediaFile = null;
      _mediaBytes = null;
      _isVideo = false;
    });
  }

  Future<void> _openPrivacyPicker() async {
    final t = context.tokens;
    final picked = await showModalBottomSheet<String>(
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
              _SheetHandle(color: t.borderStrong),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Who can see your post?',
                    style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
                  ),
                ),
              ),
              _PrivacyOption(
                icon: LucideIcons.globe,
                title: 'Public',
                subtitle: 'Anyone on Ennvo can see this post',
                selected: _privacy == 'public',
                onTap: () => Navigator.of(sheetContext).pop('public'),
              ),
              _PrivacyOption(
                icon: LucideIcons.users,
                title: 'Followers',
                subtitle: 'People who follow you',
                selected: _privacy == 'followers',
                onTap: () => Navigator.of(sheetContext).pop('followers'),
              ),
              _PrivacyOption(
                icon: LucideIcons.shield,
                title: 'Only me',
                subtitle: 'Visible only on your profile',
                selected: _privacy == 'private',
                onTap: () => Navigator.of(sheetContext).pop('private'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _privacy = picked);
    }
  }

  Future<void> _openSongPicker() async {
    final controller = TextEditingController(text: _musicTitle ?? '');
    final t = context.tokens;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Container(
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
                _SheetHandle(color: t.borderStrong),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add Song',
                          style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
                        ),
                      ),
                      if (_musicTitle != null)
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(''),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      children: [
                        LucideIcon(
                          LucideIcons.music,
                          size: 16,
                          color: t.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: EnnvoText.body.copyWith(color: t.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Song title - Artist',
                              hintStyle: EnnvoText.body.copyWith(
                                color: t.textTertiary,
                              ),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (v) =>
                                Navigator.of(sheetContext).pop(v.trim()),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext)
                              .pop(controller.text.trim()),
                          child: const Text('Use'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final track in _presetSongs)
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppGradients.create,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const LucideIcon(
                        LucideIcons.music,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      track,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EnnvoText.bodySemi.copyWith(
                        color: t.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(track),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (picked != null && mounted) {
      setState(() => _musicTitle = picked.isEmpty ? null : picked);
    }
  }

  Future<void> _openLocationPicker() async {
    final controller = TextEditingController(text: _locationLabel ?? '');
    final t = context.tokens;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Container(
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
                _SheetHandle(color: t.borderStrong),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add Location',
                          style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
                        ),
                      ),
                      if (_locationLabel != null)
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(''),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      children: [
                        LucideIcon(
                          LucideIcons.mapPin,
                          size: 16,
                          color: t.brand,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: EnnvoText.body.copyWith(color: t.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search city or place...',
                              hintStyle: EnnvoText.body.copyWith(
                                color: t.textTertiary,
                              ),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (v) =>
                                Navigator.of(sheetContext).pop(v.trim()),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext)
                              .pop(controller.text.trim()),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final place in _presetLocations)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: t.surfaceAlt,
                      child: LucideIcon(
                        LucideIcons.mapPin,
                        size: 15,
                        color: t.brand,
                      ),
                    ),
                    title: Text(
                      place,
                      style: EnnvoText.bodySemi.copyWith(
                        color: t.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(place),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (picked != null && mounted) {
      setState(() => _locationLabel = picked.isEmpty ? null : picked);
    }
  }

  Future<void> _openTagFriends() async {
    final following = ref.read(followingProvider).value ?? const <AppUser>[];
    final followers = ref.read(followersProvider).value ?? const <AppUser>[];
    final byUid = <String, AppUser>{};
    for (final u in [...following, ...followers]) {
      if (u.uid.isNotEmpty) byUid.putIfAbsent(u.uid, () => u);
    }
    final friends = byUid.values.toList(growable: false);
    final selected = Set<String>.from(_taggedFriends);
    final customController = TextEditingController();
    final t = context.tokens;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
            ),
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
                  _SheetHandle(color: t.borderStrong),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tag Friends',
                            style: EnnvoText.titleMd.copyWith(
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _taggedFriends
                                ..clear()
                                ..addAll(selected);
                            });
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        children: [
                          LucideIcon(
                            LucideIcons.users,
                            size: 16,
                            color: t.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: customController,
                              style:
                                  EnnvoText.body.copyWith(color: t.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Type friend name to tag...',
                                hintStyle: EnnvoText.body.copyWith(
                                  color: t.textTertiary,
                                ),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (val) {
                                final clean = val.trim();
                                if (clean.isEmpty) return;
                                setSheetState(() {
                                  selected.add(clean);
                                  customController.clear();
                                });
                              },
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final clean = customController.text.trim();
                              if (clean.isEmpty) return;
                              setSheetState(() {
                                selected.add(clean);
                                customController.clear();
                              });
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (friends.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: friends.length,
                        itemBuilder: (_, index) {
                          final f = friends[index];
                          final label = f.name.isNotEmpty
                              ? f.name
                              : (f.username.isNotEmpty
                                    ? '@${f.username}'
                                    : f.uid);
                          final isSelected = selected.contains(label);
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: t.accent,
                            secondary: _ComposerAvatar(
                              url: f.avatar,
                              name: label,
                              size: 36,
                            ),
                            title: Text(
                              label,
                              style: EnnvoText.bodySemi.copyWith(
                                color: t.textPrimary,
                              ),
                            ),
                            onChanged: (checked) {
                              setSheetState(() {
                                if (checked == true) {
                                  selected.add(label);
                                } else {
                                  selected.remove(label);
                                }
                              });
                            },
                          );
                        },
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Text(
                        'Type a friend name above to tag them in this post.',
                        style: EnnvoText.caption.copyWith(
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    customController.dispose();
  }

  Future<void> _pickCustomColor() async {
    final t = context.tokens;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(color: t.borderStrong),
              const SizedBox(height: 8),
              Text(
                'Custom Card Color',
                style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in _customPalette)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _customColor = color;
                          _background = 'custom';
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _customColor == color
                                ? t.accent
                                : Colors.white.withValues(alpha: 0.7),
                            width: _customColor == color ? 3 : 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAdvancedSettings() async {
    final updated = await showModalBottomSheet<
        ({
          bool commentsDisabled,
          bool hideLikes,
          bool allowRemix,
          bool highQuality,
          bool saveToDevice,
        })>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AdvancedSettingsSheet(
        commentsDisabled: _commentsDisabled,
        hideLikes: _hideLikes,
        allowRemix: _allowRemix,
        highQuality: _highQuality,
        saveToDevice: _saveToDevice,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _commentsDisabled = updated.commentsDisabled;
      _hideLikes = updated.hideLikes;
      _allowRemix = updated.allowRemix;
      _highQuality = updated.highQuality;
      _saveToDevice = updated.saveToDevice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;
    final user = ref.watch(authControllerProvider).user;
    final userName = (user?.name ?? '').isEmpty ? 'You' : user!.name;
    final hasBigTextBg = _mediaFile == null && _background != 'none';
    final canPost =
        !_uploading && (_mediaFile != null || _caption.text.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: t.background,
      body: Column(
        children: [
          // --- header ---------------------------------------------------
          Container(
            padding: EdgeInsets.fromLTRB(6, top + 6, 14, 8),
            decoration: BoxDecoration(
              color: t.background,
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).maybePop();
                    } else {
                      ref.read(navControllerProvider).popPage();
                    }
                  },
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
                    widget.isReel ? 'New reel' : 'Create post',
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
                  onTap: canPost ? _publish : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: canPost ? t.accent : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      widget.isReel ? 'Share' : 'Post',
                      style: EnnvoText.bodySemi.copyWith(
                        color: canPost ? Colors.white : t.textTertiary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                // --- author + audience pill ---------------------------
                Row(
                  children: [
                    _ComposerAvatar(
                      url: user?.avatar ?? '',
                      name: userName,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EnnvoText.bodySemi.copyWith(
                              color: t.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openPrivacyPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: t.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: t.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LucideIcon(
                                    _privacy == 'followers'
                                        ? LucideIcons.users
                                        : (_privacy == 'private'
                                              ? LucideIcons.shield
                                              : LucideIcons.globe),
                                    size: 12,
                                    color: t.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _privacy == 'followers'
                                        ? 'Followers'
                                        : (_privacy == 'private'
                                              ? 'Only me'
                                              : 'Public'),
                                    style: EnnvoText.tiny.copyWith(
                                      color: t.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  LucideIcon(
                                    LucideIcons.chevronDown,
                                    size: 12,
                                    color: t.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // --- caption / big-text rounded card --------------------
                if (hasBigTextBg)
                  Container(
                    constraints: const BoxConstraints(minHeight: 240),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: _backgroundGradient(),
                      color: _solidBackgroundColor(),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _caption,
                      maxLines: 7,
                      minLines: 2,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.sentences,
                      style: EnnvoText.pageHero.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.35,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: "What's on your mind?",
                        hintStyle: EnnvoText.pageHero.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 22,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: _caption,
                    maxLines: 8,
                    minLines: _mediaFile == null ? 4 : 2,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    style: EnnvoText.body.copyWith(
                      color: t.textPrimary,
                      fontSize: _mediaFile == null ? 18 : 15.5,
                      height: 1.45,
                    ),
                    cursorColor: t.accent,
                    decoration: InputDecoration(
                      hintText: _mediaFile != null
                          ? 'Say something about this...'
                          : "What's on your mind?",
                      hintStyle: EnnvoText.body.copyWith(
                        color: t.textTertiary,
                        fontSize: _mediaFile == null ? 18 : 15.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                // --- big-text background swatch strip -------------------
                if (_mediaFile == null && !widget.isReel) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final entry
                            in AppGradients.bigTextBackgrounds.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _GradientSwatch(
                              id: entry.key,
                              css: entry.value,
                              isSelected: _background == entry.key,
                              onTap: () =>
                                  setState(() => _background = entry.key),
                            ),
                          ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _pickCustomColor,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _customColor,
                              border: Border.all(
                                color: _background == 'custom'
                                    ? t.accent
                                    : Colors.white.withValues(alpha: 0.7),
                                width: _background == 'custom' ? 3 : 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.palette_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // --- selected media preview (rounded 22px) --------------
                if (_mediaFile != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        if (_isVideo)
                          Container(
                            height: 240,
                            width: double.infinity,
                            color: const Color(0xFF0F172A),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const LucideIcon(
                                    LucideIcons.video,
                                    size: 26,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _mediaFile!.name.isEmpty
                                      ? 'Video attached'
                                      : _mediaFile!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: EnnvoText.caption.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_mediaBytes != null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 380),
                            child: Image.memory(
                              _mediaBytes!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 220,
                            width: double.infinity,
                            color: t.surfaceAlt,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _clearMedia,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xAA000000),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const LucideIcon(
                                LucideIcons.x,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // --- metadata pills (music, location, tags) -------------
                if (_musicTitle != null ||
                    _locationLabel != null ||
                    _taggedFriends.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (_musicTitle != null)
                        Chip(
                          avatar: LucideIcon(
                            LucideIcons.music,
                            size: 14,
                            color: t.accent,
                          ),
                          label: Text(_musicTitle!),
                          onDeleted: () => setState(() => _musicTitle = null),
                        ),
                      if (_locationLabel != null)
                        Chip(
                          avatar: LucideIcon(
                            LucideIcons.mapPin,
                            size: 14,
                            color: t.brand,
                          ),
                          label: Text(_locationLabel!),
                          onDeleted: () =>
                              setState(() => _locationLabel = null),
                        ),
                      for (final friend in _taggedFriends)
                        Chip(
                          avatar: LucideIcon(
                            LucideIcons.users,
                            size: 14,
                            color: t.accent,
                          ),
                          label: Text(friend),
                          onDeleted: () => setState(
                            () => _taggedFriends.remove(friend),
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // --- Facebook-style "Add to your post" action card ------
                Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: t.border),
                  ),
                  child: Column(
                    children: [
                      _AddRow(
                        icon: LucideIcons.image,
                        iconColor: const Color(0xFF10B981),
                        label: 'Photo',
                        trailing: _mediaFile != null && !_isVideo
                            ? 'Attached'
                            : null,
                        onTap: _pickPhoto,
                      ),
                      Divider(height: 1, color: t.border),
                      _AddRow(
                        icon: LucideIcons.video,
                        iconColor: const Color(0xFFF43F5E),
                        label: 'Video',
                        trailing: _mediaFile != null && _isVideo
                            ? 'Attached'
                            : null,
                        onTap: _pickVideo,
                      ),
                      Divider(height: 1, color: t.border),
                      _AddRow(
                        icon: LucideIcons.music,
                        iconColor: const Color(0xFF8B5CF6),
                        label: 'Song / Music',
                        trailing: _musicTitle,
                        onTap: _openSongPicker,
                      ),
                      Divider(height: 1, color: t.border),
                      _AddRow(
                        icon: LucideIcons.mapPin,
                        iconColor: const Color(0xFFEF4444),
                        label: 'Location',
                        trailing: _locationLabel,
                        onTap: _openLocationPicker,
                      ),
                      Divider(height: 1, color: t.border),
                      _AddRow(
                        icon: LucideIcons.users,
                        iconColor: const Color(0xFF0EA5E9),
                        label: 'Tag friends',
                        trailing: _taggedFriends.isEmpty
                            ? null
                            : '${_taggedFriends.length} tagged',
                        onTap: _openTagFriends,
                      ),
                      Divider(height: 1, color: t.border),
                      _AddRow(
                        icon: LucideIcons.sliders,
                        iconColor: t.textSecondary,
                        label: 'Advanced settings',
                        onTap: _openAdvancedSettings,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publish() async {
    if (_uploading || _published) return;
    if (_mediaFile == null && _caption.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a photo, video, or write something first.'),
        ),
      );
      return;
    }

    final file = _mediaFile;
    final user = ref.read(authControllerProvider).user;

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    String? url;
    if (file != null) {
      try {
        final uploaded = await UploadService.uploadXFile(
          file: file,
          folder: widget.isReel ? 'reels' : 'posts',
          contentType: _isVideo ? 'video/mp4' : null,
          onProgress: (sent, total) {
            if (!mounted || total <= 0) return;
            setState(() => _progress = sent / total);
          },
        );
        url = uploaded.url;
      } catch (_) {
        url = null;
      }
    }

    final id = 'post-${DateTime.now().millisecondsSinceEpoch}';
    final caption = _caption.text.trim();
    final isBigText = _mediaFile == null && _background != 'none';
    String? backgroundValue;
    if (isBigText) {
      backgroundValue = _background == 'custom'
          ? _hexOf(_customColor)
          : AppGradients.bigTextBackgrounds[_background];
    }

    final written = await PostService.create(
      id: id,
      authorId: user?.uid ?? 'me',
      authorName: user?.name ?? 'You',
      authorAvatar: user?.avatar ?? '',
      authorUsername: user?.username ?? '',
      text: caption,
      media: url == null ? const <String>[] : <String>[url],
      mediaTypes: url == null
          ? const <String>[]
          : <String>[_isVideo ? 'video' : 'image'],
      type: widget.isReel ? 'reel' : (isBigText ? 'text' : 'post'),
      songTitle: _musicTitle,
      privacy: _privacy,
      location: _locationLabel,
      taggedUsers: List<String>.of(_taggedFriends),
      background: backgroundValue,
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
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).maybePop();
      } else {
        ref.read(navControllerProvider).popPage();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not publish post. Try again.')),
      );
    }
  }

  static String _hexOf(Color c) {
    final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  Color? _solidBackgroundColor() {
    if (_background == 'custom') return _customColor;
    final css = AppGradients.bigTextBackgrounds[_background];
    if (css != null && css.startsWith('#')) {
      final parsed = _parseCssGradient(css);
      if (parsed.isNotEmpty) return parsed.first.$1;
    }
    return null;
  }

  Gradient? _backgroundGradient() {
    if (_background == 'custom') return null;
    final css = AppGradients.bigTextBackgrounds[_background];
    if (css == null || css.isEmpty || css.startsWith('#')) return null;

    final stops = _parseCssGradient(css);
    if (stops.length < 2) return null;
    return LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: stops.map((e) => e.$1).toList(),
      stops: stops.map((e) => e.$2).toList(),
    );
  }

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

class _ComposerAvatar extends StatelessWidget {
  const _ComposerAvatar({
    required this.url,
    required this.name,
    required this.size,
  });

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fallback = Container(
      width: size,
      height: size,
      color: t.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: EnnvoText.bodySemi.copyWith(color: t.textSecondary),
      ),
    );
    if (url.isEmpty) return ClipOval(child: fallback);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: selected ? t.accentSoft : t.surfaceAlt,
        child: LucideIcon(
          icon,
          size: 18,
          color: selected ? t.accent : t.textSecondary,
        ),
      ),
      title: Text(
        title,
        style: EnnvoText.bodySemi.copyWith(color: t.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: EnnvoText.caption.copyWith(color: t.textSecondary),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: t.accent)
          : null,
      onTap: onTap,
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final String icon;
  final Color iconColor;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                icon,
                size: 18,
                strokeWidth: 2.1,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: EnnvoText.bodySemi.copyWith(
                  color: t.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            if (trailing != null && trailing!.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EnnvoText.caption.copyWith(color: t.accent),
                ),
              ),
              const SizedBox(width: 6),
            ],
            LucideIcon(
              LucideIcons.chevronRight,
              size: 16,
              color: t.textTertiary,
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: stops.length < 2
              ? null
              : LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: stops.map((e) => e.$1).toList(),
                  stops: stops.map((e) => e.$2).toList(),
                ),
          color: id == 'none'
              ? t.surfaceAlt
              : (stops.length == 1 ? stops.first.$1 : null),
          border: Border.all(
            color: isSelected ? t.accent : t.borderStrong,
            width: isSelected ? 2.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: id == 'none'
            ? LucideIcon(
                LucideIcons.x,
                size: 16,
                color: t.textSecondary,
              )
            : null,
      ),
    );
  }
}

class _AdvancedSettingsSheet extends StatefulWidget {
  const _AdvancedSettingsSheet({
    required this.commentsDisabled,
    required this.hideLikes,
    required this.allowRemix,
    required this.highQuality,
    required this.saveToDevice,
  });

  final bool commentsDisabled;
  final bool hideLikes;
  final bool allowRemix;
  final bool highQuality;
  final bool saveToDevice;

  @override
  State<_AdvancedSettingsSheet> createState() => _AdvancedSettingsSheetState();
}

class _AdvancedSettingsSheetState extends State<_AdvancedSettingsSheet> {
  late bool _commentsDisabled = widget.commentsDisabled;
  late bool _hideLikes = widget.hideLikes;
  late bool _allowRemix = widget.allowRemix;
  late bool _highQuality = widget.highQuality;
  late bool _saveToDevice = widget.saveToDevice;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
              EnnvoPrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(context).pop((
                    commentsDisabled: _commentsDisabled,
                    hideLikes: _hideLikes,
                    allowRemix: _allowRemix,
                    highQuality: _highQuality,
                    saveToDevice: _saveToDevice,
                  ));
                },
              ),
            ],
          ),
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
