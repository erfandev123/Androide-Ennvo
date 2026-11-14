// ============================================================================
//  ENNVO — SHARE SHEET
//
//  The share portal of a reel, laid out the way TikTok does it:
//
//    • a search field at the top
//    • a grid of the people the reel can be sent to, five across
//    • a row of action tiles: copy the link, download, report and more
//    • a send button that appears once somebody is picked
//
//  Picking somebody does not close the sheet — the count grows and the
//  button becomes active, so several people can be picked at once.
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

  @override
  State<ReelShareSheet> createState() => _ReelShareSheetState();
}

class _ReelShareSheetState extends State<ReelShareSheet> {
  final Set<String> _selected = <String>{};
  String _query = '';
  bool _copied = false;
  bool _saved = false;

  List<ShareTarget> get _filtered {
    if (_query.trim().isEmpty) return widget.targets;
    final term = _query.trim().toLowerCase();
    return widget.targets
        .where((t) => t.name.toLowerCase().contains(term))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);
    final hasSelection = _selected.isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
      child: Container(
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
            // --- the handle ---------------------------------------------
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: t.isDark
                    ? const Color(0x66224982)
                    : const Color(0xFFBAE6FD),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // --- the header ---------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
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

            // --- the search ---------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: t.isDark ? const Color(0xFF131D31) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: t.isDark
                        ? const Color(0x4D0EA5E9)
                        : const Color(0x4DBAE6FD),
                  ),
                ),
                child: Row(
                  children: [
                    LucideIcon(
                      LucideIcons.search,
                      size: 16,
                      strokeWidth: 2.2,
                      color: t.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _query = value),
                        style: EnnvoText.body.copyWith(
                          color: t.textPrimary,
                          fontSize: 13.5,
                        ),
                        cursorColor: t.accent,
                        decoration: InputDecoration(
                          hintText: 'Search people',
                          hintStyle: EnnvoText.body.copyWith(
                            color: t.textTertiary,
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- the people grid ---------------------------------------
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'No friends found',
                        style: EnnvoText.caption.copyWith(color: t.textTertiary),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final target = _filtered[index];
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: EnnvoDurations.dropdown,
                                    curve: EnnvoCurves.iosSpring,
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: t.surfaceAlt,
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFF0EA5E9),
                                              width: 2.5,
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
                                    const Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Color(0xFF0EA5E9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.check,
                                            size: 11,
                                            color: Colors.white,
                                          ),
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

            // --- the action tiles --------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                  _ActionTile(
                    icon: LucideIcons.link,
                    label: _copied ? 'Copied!' : 'Copy link',
                    active: _copied,
                    onTap: () {
                      setState(() => _copied = true);
                      widget.onCopyLink();
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _copied = false);
                      });
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.repeat,
                    label: 'Repost',
                    onTap: widget.onRepost,
                  ),
                  _ActionTile(
                    icon: LucideIcons.download,
                    label: _saved ? 'Saved!' : 'Save',
                    active: _saved,
                    onTap: () {
                      setState(() => _saved = true);
                      widget.onSave();
                    },
                  ),
                  _ActionTile(
                    icon: LucideIcons.plusCircle,
                    label: 'Story',
                    onTap: widget.onAddStory,
                  ),
                  if (widget.onReport != null)
                    _ActionTile(
                      icon: LucideIcons.flag,
                      label: 'Report',
                      danger: true,
                      onTap: widget.onReport!,
                    )
                  else if (widget.onDelete != null)
                    _ActionTile(
                      icon: LucideIcons.trash2,
                      label: 'Delete',
                      danger: true,
                      onTap: widget.onDelete!,
                    ),
                ],
              ),
            ),

            // --- the send button ---------------------------------------
            if (hasSelection)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.paddingOf(context).bottom + 14,
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
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
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
              child: LucideIcon(icon, size: 19, strokeWidth: 2, color: color),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: EnnvoText.tiny.copyWith(
                color: active ? const Color(0xFF059669) : t.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
