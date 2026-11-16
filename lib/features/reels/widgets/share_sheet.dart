// ============================================================================
//  ENNVO �?" REEL SHARE SHEET
//
//  Sending a reel to somebody.
//
//  The sheet follows the theme of the app: it is white in the light mode and
//  near black in the dark one.
//
//    �?� the people sit in a row on top, and a tap picks them
//    ���� the send button appears at the bottom as soon as somebody is picked
//    �?� below them are the ways to share, and the settings of the reel
//    �?� the sheet only takes the room it needs
// ============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/icons/lucide_icons.dart';

class ShareTarget {
  const ShareTarget({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final bool isOnline;
}

/// The settings of a reel, the ones the share sheet carries.
class ShareSettings {
  const ShareSettings({
    this.privacy = 'public',
    this.commentsDisabled = false,
    this.allowRemix = true,
    this.hideLikes = false,
    this.saveToDevice = false,
  });

  final String privacy;
  final bool commentsDisabled;
  final bool allowRemix;
  final bool hideLikes;
  final bool saveToDevice;

  ShareSettings copyWith({
    String? privacy,
    bool? commentsDisabled,
    bool? allowRemix,
    bool? hideLikes,
    bool? saveToDevice,
  }) {
    return ShareSettings(
      privacy: privacy ?? this.privacy,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      allowRemix: allowRemix ?? this.allowRemix,
      hideLikes: hideLikes ?? this.hideLikes,
      saveToDevice: saveToDevice ?? this.saveToDevice,
    );
  }
}

class ReelShareSheet extends StatefulWidget {
  const ReelShareSheet({
    super.key,
    required this.targets,
    required this.onSend,
    required this.onRepost,
    required this.onSave,
    required this.onCopyLink,
    required this.onAddStory,
    this.onReport,
    this.onDelete,
    this.onDownload,
    this.isOwner = false,
    this.settings = const ShareSettings(),
    this.onSettingsChanged,
  });

  final List<ShareTarget> targets;
  final Future<void> Function(List<ShareTarget> selected) onSend;
  final VoidCallback onRepost;
  final VoidCallback onSave;
  final VoidCallback onCopyLink;
  final VoidCallback onAddStory;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;
  final bool isOwner;

  /// The settings of the reel.
  final ShareSettings settings;

  /// A setting was changed.
  final ValueChanged<ShareSettings>? onSettingsChanged;

  @override
  State<ReelShareSheet> createState() => _ReelShareSheetState();
}

class _ReelShareSheetState extends State<ReelShareSheet> {
  final TextEditingController _message = TextEditingController();

  /// The people that are picked.
  final Set<String> _selected = <String>{};

  ShareSettings _settings = const ShareSettings();

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _toggle(ShareTarget target) {
    setState(() {
      if (!_selected.remove(target.id)) _selected.add(target.id);
    });
  }

  void _updateSettings(ShareSettings settings) {
    setState(() => _settings = settings);
    widget.onSettingsChanged?.call(settings);
  }

  Future<void> _send() async {
    final picked = widget.targets
        .where((target) => _selected.contains(target.id))
        .toList();
    if (picked.isEmpty) return;
    await widget.onSend(picked);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final hasSelection = _selected.isNotEmpty;

    // The sheet never grows past the room it needs, and it lifts its lower
    // edge when the keyboard is up.
    final available = media.size.height - media.padding.top;
    final maxHeight = (available * 0.82).clamp(320.0, available);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- the grab handle -----------------------------------------
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: t.borderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // --- the header ----------------------------------------------
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'Send to',
                    style: EnnvoText.bodySemi.copyWith(
                      color: t.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: LucideIcon(
                            LucideIcons.x,
                            size: 20,
                            strokeWidth: 2.2,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: hasSelection ? 0 : 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- the people ----------------------------------------
                    SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        itemCount: widget.targets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final target = widget.targets[index];
                          final isSelected = _selected.contains(target.id);

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _toggle(target),
                            child: SizedBox(
                              width: 64,
                              child: Column(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFFE2C55)
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: t.surfaceAlt,
                                            image: target.avatarUrl.isEmpty
                                                ? null
                                                : DecorationImage(
                                                    image: NetworkImage(
                                                      target.avatarUrl,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                          alignment: Alignment.center,
                                          child: target.avatarUrl.isEmpty
                                              ? Text(
                                                  target.name.isEmpty
                                                      ? '?'
                                                      : target.name
                                                            .characters
                                                            .first
                                                            .toUpperCase(),
                                                  style: EnnvoText.bodySemi
                                                      .copyWith(
                                                        color: t.textSecondary,
                                                      ),
                                                )
                                              : null,
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFFFE2C55),
                                                border: Border.all(
                                                  color: t.surface,
                                                  width: 2,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: const LucideIcon(
                                                LucideIcons.check,
                                                size: 10,
                                                strokeWidth: 3.4,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    target.name.split(' ').first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: EnnvoText.tiny.copyWith(
                                      color: t.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    Divider(height: 1, color: t.border),

                    // --- the message ------------------------------------
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: t.borderStrong, width: 1.25),
                        ),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _message,
                          onChanged: (_) => setState(() {}),
                          style: EnnvoText.body.copyWith(
                            color: t.textPrimary,
                            fontSize: 14.5,
                          ),
                          cursorColor: t.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Write a message…',
                            hintStyle: EnnvoText.body.copyWith(
                              color: t.textTertiary,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- the ways to share -------------------------------
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Wrap(
                        alignment: WrapAlignment.spaceAround,
                        runSpacing: 12,
                        children: [
                          _ShareOption(
                            icon: LucideIcons.plusCircle,
                            label: 'Add story',
                            onTap: widget.onAddStory,
                          ),
                          _ShareOption(
                            icon: LucideIcons.link,
                            label: 'Copy link',
                            onTap: widget.onCopyLink,
                          ),
                          _ShareOption(
                            icon: LucideIcons.messageCircle,
                            label: 'Messenger',
                            onTap: _send,
                          ),
                          _ShareOption(
                            icon: LucideIcons.repeat2,
                            label: 'Repost',
                            onTap: widget.onRepost,
                          ),
                          _ShareOption(
                            icon: LucideIcons.bookmark,
                            label: 'Save',
                            onTap: widget.onSave,
                          ),
                          _ShareOption(
                            icon: LucideIcons.download,
                            label: 'Download',
                            onTap: widget.onDownload ?? () {},
                          ),
                          _ShareOption(
                            icon: LucideIcons.moreHorizontal,
                            label: 'More',
                            onTap: () => _openMore(context),
                          ),
                          if (widget.isOwner)
                            _ShareOption(
                              icon: LucideIcons.trash2,
                              label: 'Delete',
                              onTap: widget.onDelete ?? () {},
                              color: t.danger,
                            )
                          else
                            _ShareOption(
                              icon: LucideIcons.shieldAlert,
                              label: 'Report',
                              onTap: widget.onReport ?? () {},
                              color: t.danger,
                            ),
                        ],
                      ),
                    ),

                    // --- the settings of the reel ------------------------
                    Divider(height: 1, color: t.border),
                    _SettingsBlock(
                      settings: _settings,
                      onChanged: _updateSettings,
                    ),
                  ],
                ),
              ),
            ),

            // --- the send button ----------------------------------------
            // It appears as soon as somebody is picked.
            if (hasSelection)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      onTap: _send,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: AppGradients.create,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: AppShadows.ctaSky,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          onTap: _send,
                          child: Container(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const LucideIcon(
                                  LucideIcons.send,
                                  size: 17,
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selected.length == 1
                                      ? 'Send to ${_nameOf(widget.targets)}'
                                      : 'Send to ${_selected.length} people',
                                  style: EnnvoText.bodySemi.copyWith(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _nameOf(List<ShareTarget> targets) {
    for (final target in targets) {
      if (target.name.isNotEmpty) return target.name.split(' ').first;
    }
    return 'them';
  }

  /// The "More" menu: the things that do not fit in the row.
  void _openMore(BuildContext context) {
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
          border: Border(top: BorderSide(color: t.border)),
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
              _MoreRow(
                icon: LucideIcons.share2,
                label: 'Share to another app',
                onTap: () {
                  Navigator.of(sheetContext).maybePop();
                  widget.onCopyLink();
                },
              ),
              _MoreRow(
                icon: LucideIcons.userPlus,
                label: 'Add to a close friends list',
                onTap: () {
                  Navigator.of(sheetContext).maybePop();
                  widget.onAddStory();
                },
              ),
              _MoreRow(
                icon: LucideIcons.download,
                label: 'Download the reel',
                onTap: () {
                  Navigator.of(sheetContext).maybePop();
                  widget.onDownload?.call();
                },
              ),
              _MoreRow(
                icon: LucideIcons.flag,
                label: 'Report the reel',
                onTap: () {
                  Navigator.of(sheetContext).maybePop();
                  widget.onReport?.call();
                },
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
//  One of the ways to share
// ============================================================================
class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(
                icon,
                size: 26,
                strokeWidth: 1.8,
                color: color ?? t.textPrimary,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: EnnvoText.tiny.copyWith(
                  color: color ?? t.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  One row of the "More" menu
// ============================================================================
class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            LucideIcon(icon, size: 19, strokeWidth: 1.9, color: t.textPrimary),
            const SizedBox(width: 14),
            Text(
              label,
              style: EnnvoText.body.copyWith(color: t.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  The settings of the reel
//
//  They are the settings the web app offers on a post: who may see it, who
//  may comment, who may remix it and whether the likes are hidden.
// ============================================================================
class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({required this.settings, required this.onChanged});

  final ShareSettings settings;
  final ValueChanged<ShareSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETTINGS',
            style: EnnvoText.overlineXs.copyWith(
              color: t.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          _SettingsRow(
            icon: LucideIcons.lock,
            label: 'Who can see this',
            value: switch (settings.privacy) {
              'followers' => 'Followers',
              'private' => 'Only me',
              _ => 'Everyone',
            },
            onTap: () {
              final next = switch (settings.privacy) {
                'public' => 'followers',
                'followers' => 'private',
                _ => 'public',
              };
              onChanged(settings.copyWith(privacy: next));
            },
          ),
          _SettingsToggle(
            icon: LucideIcons.messageCircle,
            label: 'Turn off commenting',
            value: settings.commentsDisabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(commentsDisabled: value)),
          ),
          _SettingsToggle(
            icon: LucideIcons.repeat2,
            label: 'Allow remixes',
            value: settings.allowRemix,
            onChanged: (value) =>
                onChanged(settings.copyWith(allowRemix: value)),
          ),
          _SettingsToggle(
            icon: LucideIcons.heart,
            label: 'Hide like counts',
            value: settings.hideLikes,
            onChanged: (value) =>
                onChanged(settings.copyWith(hideLikes: value)),
          ),
          _SettingsToggle(
            icon: LucideIcons.download,
            label: 'Save to device',
            value: settings.saveToDevice,
            onChanged: (value) =>
                onChanged(settings.copyWith(saveToDevice: value)),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
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
            LucideIcon(icon, size: 17, strokeWidth: 1.9, color: t.textSecondary),
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
            const SizedBox(width: 6),
            LucideIcon(
              LucideIcons.chevronRight,
              size: 15,
              strokeWidth: 2.2,
              color: t.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
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
          LucideIcon(icon, size: 17, strokeWidth: 1.9, color: t.textSecondary),
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
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: t.borderStrong,
          ),
        ],
      ),
    );
  }
}
