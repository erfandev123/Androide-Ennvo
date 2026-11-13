// ============================================================================
//  ENNVO — SETTINGS SCREEN
//
//  Ported from `src/pages/Settings.tsx`.
//
//  Layout:
//    • the page background is `#F4F8FF`
//    • on a wide screen the content becomes a twelve column grid: the
//      navigation card takes five columns (four on a large screen) and the
//      panel takes the rest
//    • the navigation card is white with a `#F4F8FF`-tinted border
//    • the active navigation item is a sky → blue gradient pill
//    • each section has an eleven by eleven rounded gradient icon tile
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/icons/lucide_icons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selected = 0;

  static const List<(String, Widget)> _groups = [
    (
      'Account',
      LucideIcon(
        LucideIcons.user,
        size: 22,
        strokeWidth: 2.2,
        color: Colors.white,
      ),
    ),
    (
      'Visibility',
      LucideIcon(
        LucideIcons.lock,
        size: 22,
        strokeWidth: 2.2,
        color: Colors.white,
      ),
    ),
    (
      'Interactions',
      LucideIcon(
        LucideIcons.messageSquare,
        size: 22,
        strokeWidth: 2.2,
        color: Colors.white,
      ),
    ),
    (
      'Content & Display',
      LucideIcon(
        LucideIcons.palette,
        size: 22,
        strokeWidth: 2.2,
        color: Colors.white,
      ),
    ),
    (
      'Support & Admin',
      LucideIcon(
        LucideIcons.shield,
        size: 22,
        strokeWidth: 2.2,
        color: Colors.white,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 768;

            final sidebar = _Sidebar(
              groups: _groups,
              selected: _selected,
              onSelected: (index) => setState(() => _selected = index),
            );

            final panel = _SettingsPanel(
              title: _groups[_selected].$1,
              icon: _groups[_selected].$2,
            );

            if (!isWide) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          'Settings',
                          style: EnnvoText.titleLg.copyWith(
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: panel),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: sidebar),
                      const SizedBox(width: 24),
                      Expanded(child: panel),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
//  The navigation card
// ============================================================================
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, Widget)> groups;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: const Color(0xFFE0F2FE)),
        boxShadow: AppShadows.settingsPanel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(
                groups[groupIndex].$1.toUpperCase(),
                style: EnnvoText.overlineXs.copyWith(
                  color: const Color(0xFF94A3B8),
                  fontSize: 10.5,
                ),
              ),
            ),
            _NavItem(
              label: _itemsFor(groupIndex).first,
              icon: groups[groupIndex].$2,
              isSelected: selected == groupIndex,
              onTap: () => onSelected(groupIndex),
            ),
            for (final extra in _itemsFor(groupIndex).skip(1))
              _NavItem(
                label: extra,
                icon: groups[groupIndex].$2,
                isSelected: false,
                onTap: () {},
              ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  /// The sub items of each group, matching the web app's sidebar.
  static List<String> _itemsFor(int groupIndex) => switch (groupIndex) {
    0 => ['Account information', 'Password & security', 'Manage devices'],
    1 => ['Private account', 'Blocked accounts'],
    2 => ['Notifications', 'Comments', 'Mentions', 'Direct messages'],
    3 => ['Display & theme', 'UI customisation', 'Free up space'],
    _ => ['Help & support', 'Company admin panel'],
  };
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: EnnvoDurations.dropdown,
        curve: EnnvoCurves.press,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppGradients.settingsActive : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: isSelected ? AppShadows.settingsActive : null,
        ),
        child: Row(
          children: [
            Opacity(
              opacity: isSelected ? 1 : 0.55,
              child: SizedBox(width: 22, height: 22, child: icon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: EnnvoText.bodySemi.copyWith(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (!isSelected)
              const LucideIcon(
                LucideIcons.chevronRight,
                size: 16,
                strokeWidth: 2.2,
                color: Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  The panel
// ============================================================================
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.icon});

  final String title;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: const Color(0xFFE0F2FE)),
        boxShadow: AppShadows.settingsPanel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppGradients.settingsTile,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.settingsActive,
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: EnnvoText.titleLg.copyWith(
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SettingsPlaceholder(),
        ],
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This section is being ported from the web app.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13.5,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: const Color(0xFFEFF6FF)),
              ),
            ),
          ),
      ],
    );
  }
}
