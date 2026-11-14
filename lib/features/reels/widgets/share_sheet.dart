// ============================================================================
//  ENNVO — SHARE SHEET
//
//  The share portal of a reel, ported from the `SharePortal` of
//  `src/components/ReelItem.tsx`.
//
//    • a people grid with multi-select
//    • a quick action row: repost, save, copy link, add to story, report
//    • a privacy section for the owner: public, friends or only me
//    • a send bar that appears once somebody is selected
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/icons/lucide_icons.dart';

/// Somebody the reel can be sent to.
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
    this.isOwner = false,
    this.privacy = 'public',
    this.onPrivacyChanged,
    this.shareCount = 0,
  });

  final List<ShareTarget> targets;
  final Future<void> Function(List<ShareTarget> selected) onSend;
  final VoidCallback onRepost;
  final VoidCallback onSave;
  final VoidCallback onCopyLink;
  final VoidCallback onAddStory;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;
  final bool isOwner;
  final String privacy;
  final ValueChanged<String>? onPrivacyChanged;
  final int shareCount;

  @override
  State<ReelShareSheet> createState() => _ReelShareSheetState();
}

class _ReelShareSheetState extends State<ReelShareSheet> {
  final Set<String> _selected = <String>{};
  bool _copied = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasSelection = _selected.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF0C121E) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            border: Border.all(
              color: t.isDark ? const Color(0x400B4A6A) : const Color(0x40BAE6FD),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- the handle -------------------------------------------
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: t.isDark ? const Color(0x66224982) : const Color(0xFFBAE6FD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // --- the header ------------------------------------------
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: t.isDark
                          ? const Color(0x260B4A6A)
                          : const Color(0x29BAE6FD),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 32),
                    Expanded(
                      child: Text(
                        'Send to',
                        textAlign: TextAlign.center,
                        style: EnnvoText.bodySemi.copyWith(
                          color: t.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: t.isDark
                              ? const Color(0x330EA5E9)
                              : const Color(0xFFF0F9FF),
                          shape: BoxShape.circle,
                        ),
                        child: LucideIcon(
                          LucideIcons.x,
                          size: 16,
                          strokeWidth: 2.2,
                          color: t.isDark
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- the people grid --------------------------------------
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: widget.targets.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No friends found',
                          style: EnnvoText.caption.copyWith(
                            color: t.textTertiary,
                          ),
                        ),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: widget.targets.length,
                        itemBuilder: (context, index) {
                          final target = widget.targets[index];
                          final isSelected = _selected.contains(target.id);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (!_selected.remove(target.id)) {
                                  _selected.add(target.id);
                                }
                              });
                            },
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: t.surfaceAlt,
                                        border: isSelected
                                            ? Border.all(
                                                color: const Color(0xFF0EA5E9),
                                                width: 2,
                                              )
                                            : null,
                                        image: target.avatarUrl.isEmpty
                                            ? null
                                            : DecorationImage(
                                                image: NetworkImage(
                                                  target.avatarUrl,
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      child: target.avatarUrl.isEmpty
                                          ? Center(
                                              child: Text(
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
                                              ),
                                            )
                                          : null,
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF0EA5E9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  target.name.split(' ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: EnnvoText.tiny.copyWith(
                                    color: t.textPrimary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // --- the quick actions ------------------------------------
              if (!hasSelection)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: t.isDark
                            ? const Color(0x260B4A6A)
                            : const Color(0x29BAE6FD),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickAction(
                        icon: LucideIcons.repeat,
                        label: 'Repost',
                        onTap: widget.onRepost,
                      ),
                      _QuickAction(
                        icon: LucideIcons.download,
                        label: _saved ? 'Saved!' : 'Save Reel',
                        active: _saved,
                        onTap: () {
                          setState(() => _saved = true);
                          widget.onSave();
                        },
                      ),
                      _QuickAction(
                        icon: LucideIcons.link,
                        label: _copied ? 'Copied!' : 'Copy Link',
                        active: _copied,
                        onTap: () {
                          setState(() => _copied = true);
                          widget.onCopyLink();
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copied = false);
                          });
                        },
                      ),
                      _QuickAction(
                        icon: LucideIcons.plusCircle,
                        label: 'Add Story',
                        onTap: widget.onAddStory,
                      ),
                      if (widget.onReport != null)
                        _QuickAction(
                          icon: LucideIcons.flag,
                          label: 'Report',
                          danger: true,
                          onTap: widget.onReport!,
                        )
                      else if (widget.onDelete != null)
                        _QuickAction(
                          icon: LucideIcons.trash2,
                          label: 'Delete',
                          danger: true,
                          onTap: widget.onDelete!,
                        ),
                    ],
                  ),
                ),

              // --- the privacy section ----------------------------------
              if (widget.isOwner && !hasSelection)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: t.isDark ? const Color(0xFF131D31) : const Color(0xFFF0F9FF),
                    border: Border(
                      top: BorderSide(
                        color: t.isDark
                            ? const Color(0x260B4A6A)
                            : const Color(0x29BAE6FD),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          LucideIcon(
                            LucideIcons.lock,
                            size: 14,
                            strokeWidth: 2,
                            color: t.isDark
                                ? const Color(0xFF7DD3FC)
                                : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Settings (Privacy)',
                            style: EnnvoText.caption.copyWith(
                              color: t.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: t.isDark
                                  ? const Color(0x330EA5E9)
                                  : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              _privacyLabel(widget.privacy),
                              style: EnnvoText.tiny.copyWith(
                                color: t.isDark
                                    ? const Color(0xFF7DD3FC)
                                    : const Color(0xFF075985),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _PrivacyOption(
                            icon: LucideIcons.globe,
                            label: 'Public',
                            value: 'public',
                            active: widget.privacy == 'public',
                            onTap: () => widget.onPrivacyChanged?.call('public'),
                          ),
                          const SizedBox(width: 8),
                          _PrivacyOption(
                            icon: LucideIcons.users,
                            label: 'Friends',
                            value: 'followers',
                            active: widget.privacy == 'followers',
                            onTap: () =>
                                widget.onPrivacyChanged?.call('followers'),
                          ),
                          const SizedBox(width: 8),
                          _PrivacyOption(
                            icon: LucideIcons.lock,
                            label: 'Only Me',
                            value: 'private',
                            active: widget.privacy == 'private',
                            onTap: () =>
                                widget.onPrivacyChanged?.call('private'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // --- the send bar -----------------------------------------
              if (hasSelection)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    MediaQuery.paddingOf(context).bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: t.isDark
                            ? const Color(0x260B4A6A)
                            : const Color(0x29BAE6FD),
                      ),
                    ),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final selected = widget.targets
                          .where((target) => _selected.contains(target.id))
                          .toList();
                      await widget.onSend(selected);
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x400EA5E9),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        'Send (${_selected.length})',
                        style: EnnvoText.bodySemi.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _privacyLabel(String value) => switch (value) {
    'followers' => 'Friends',
    'private' => 'Only Me',
    _ => 'Public',
  };
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = danger
        ? const Color(0xFFE11D48)
        : (active ? const Color(0xFF059669) : t.textPrimary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: danger
                  ? (t.isDark
                        ? const Color(0x263F1315)
                        : const Color(0xFFFEF2F2))
                  : (active
                        ? (t.isDark
                              ? const Color(0x2606B6D4)
                              : const Color(0xFFECFDF5))
                        : (t.isDark
                              ? const Color(0xFF131D31)
                              : Colors.white)),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: danger
                    ? const Color(0x40FECACA)
                    : (t.isDark
                          ? const Color(0x4D0EA5E9)
                          : const Color(0x4DBAE6FD)),
              ),
            ),
            alignment: Alignment.center,
            child: LucideIcon(icon, size: 20, strokeWidth: 2, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: EnnvoText.tiny.copyWith(
              color: active ? const Color(0xFF059669) : t.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: EnnvoDurations.dropdown,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF0EA5E9)
                : (t.isDark ? const Color(0xFF131D31) : Colors.white),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: active
                  ? const Color(0xFF0EA5E9)
                  : (t.isDark
                        ? const Color(0x4D0EA5E9)
                        : const Color(0x4DBAE6FD)),
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x260EA5E9),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LucideIcon(
                icon,
                size: 14,
                strokeWidth: 2,
                color: active ? Colors.white : t.textPrimary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EnnvoText.tiny.copyWith(
                    color: active ? Colors.white : t.textPrimary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
