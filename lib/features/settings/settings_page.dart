// ============================================================================
//  ENNVO — SETTINGS SCREEN
//
//  Ported from `src/pages/Settings.tsx`.
//
//  Every switch on this page is real:
//
//    • account information      — the signed-in user document
//    • password & security      — the Firebase reset mail
//    • private account          — `users/{uid}.isPrivate`
//    • blocked accounts         — `users/{uid}.blockedUserIds`
//    • display & theme          — `ennvo_theme_mode`
//    • navigation bar           — `ennvo_nav_style`
//    • lite mode                — `ennvo_lite`
//    • free up space            — the watched reels and the image cache
//
//  Layout:
//    • the page background is `#F4F8FF`
//    • on a wide screen the content is a sidebar card plus a panel
//    • on a phone the groups are a list, and an item opens its own screen
//    • the active item is a sky → blue gradient pill
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/page_type.dart';
import '../../core/perf/device_tier.dart';
import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/user.dart';
import '../../data/services/user_service.dart';
import '../../shared/icons/lucide_icons.dart';

const Color _kPageBg = Color(0xFFF4F8FF);
const Color _kCardBorder = Color(0xFFE0F2FE);
const Color _kInk = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF64748B);
const Color _kSubtle = Color(0xFF94A3B8);
const Color _kSky = Color(0xFF0284C7);
const Color _kDanger = Color(0xFFDC2626);

/// The ids of the screens, matching the web app's `effectiveScreen` values.
class _Ids {
  static const String account = 'account_info';
  static const String password = 'password';
  static const String privateAccount = 'private_account';
  static const String blocked = 'blocked_accounts';
  static const String theme = 'display_theme';
  static const String navigation = 'ui_customize';
  static const String lite = 'lite_mode';
  static const String space = 'free_up_space';
  static const String help = 'help_center';
  static const String about = 'about';
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// The screen that is open on a phone. `null` is the list.
  String? _screen;

  /// The item that is open in the panel on a wide screen.
  String _selected = _Ids.navigation;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final prefs = ref.watch(prefsProvider);

    final groups = <_Group>[
      _Group('Account', [
        _Item(
          id: _Ids.account,
          label: 'Account information',
          subtitle: 'Name, username and email',
          icon: LucideIcons.user,
          onTap: () => _open(_Ids.account),
        ),
        _Item(
          id: _Ids.password,
          label: 'Password & security',
          subtitle: 'Reset your password by email',
          icon: LucideIcons.keyRound,
          onTap: () => _open(_Ids.password),
        ),
      ]),
      _Group('Privacy & Safety', [
        _Item(
          id: _Ids.privateAccount,
          label: 'Private account',
          icon: LucideIcons.lock,
          badge: user?.isPrivate ?? false ? 'On' : 'Off',
          onTap: () => _open(_Ids.privateAccount),
        ),
        _Item(
          id: _Ids.blocked,
          label: 'Blocked accounts',
          icon: LucideIcons.userX,
          badge: '${user?.blockedUserIds.length ?? 0}',
          onTap: () => _open(_Ids.blocked),
        ),
      ]),
      _Group('Preferences', [
        _Item(
          id: _Ids.theme,
          label: 'Display & theme',
          icon: prefs.isDarkTheme ? LucideIcons.moon : LucideIcons.sun,
          badge: prefs.isDarkTheme ? 'Dark' : 'Light',
          onTap: () => _open(_Ids.theme),
        ),
        _Item(
          id: _Ids.navigation,
          label: 'Navigation bar',
          subtitle: 'Glass or classic',
          icon: LucideIcons.smartphone,
          badge: prefs.navStyle == 'classic' ? 'Classic' : 'Glass',
          onTap: () => _open(_Ids.navigation),
        ),
        _Item(
          id: _Ids.lite,
          label: 'Lite mode',
          subtitle: 'Fewer effects on a weak phone',
          icon: LucideIcons.zap,
          badge: switch (prefs.liteOverride) {
            'on' => 'On',
            'off' => 'Off',
            _ => 'Auto',
          },
          onTap: () => _open(_Ids.lite),
        ),
        _Item(
          id: _Ids.space,
          label: 'Free up space',
          subtitle: 'Cache and watched reels',
          icon: LucideIcons.trash2,
          onTap: () => _open(_Ids.space),
        ),
      ]),
      _Group('Support', [
        _Item(
          id: _Ids.help,
          label: 'Customer care & help',
          icon: LucideIcons.headphones,
          badge: '24/7',
          onTap: () => _open(_Ids.help),
        ),
        _Item(
          id: _Ids.about,
          label: 'About Ennvo',
          icon: LucideIcons.info,
          onTap: () => _open(_Ids.about),
        ),
      ]),
    ];

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 768;

            if (isWide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 340,
                          child: _Sidebar(
                            groups: groups,
                            selected: _selected,
                            onSelected: (id) =>
                                setState(() => _selected = id),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: _panel(_selected, user)),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (_screen != null) {
              final item = _find(groups, _screen!);
              return Column(
                children: [
                  _MobileHeader(
                    title: item?.label ?? 'Settings',
                    onBack: () => setState(() => _screen = null),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      child: _detail(_screen!, user),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _MobileHeader(
                  title: 'Settings',
                  onBack: () => ref.read(navControllerProvider).popPage(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                    children: [
                      for (final group in groups) ...[
                        _GroupLabel(group.title),
                        _ListCard(
                          children: [
                            for (var i = 0; i < group.items.length; i++) ...[
                              if (i > 0) const _Divider(),
                              _SettingRow(item: group.items[i]),
                            ],
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      _SignOutTile(
                        onTap: () => _confirmSignOut(context, ref),
                      ),
                      const SizedBox(height: 22),
                      const Center(
                        child: Text(
                          'Ennvo 1.0.0  ·  made with care',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            color: _kSubtle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _open(String id) {
    if (MediaQuery.sizeOf(context).width >= 768) {
      setState(() => _selected = id);
    } else {
      setState(() => _screen = id);
    }
  }

  static _Item? _find(List<_Group> groups, String id) {
    for (final group in groups) {
      for (final item in group.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  // ======================================================================
  //  The panel of the wide screen
  // ======================================================================
  Widget _panel(String id, AppUser? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: _kCardBorder),
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
                child: LucideIcon(
                  _iconFor(id),
                  size: 22,
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _titleFor(id),
                  style: EnnvoText.titleLg.copyWith(color: _kInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _detail(id, user),
        ],
      ),
    );
  }

  static String _titleFor(String id) => switch (id) {
    _Ids.account => 'Account information',
    _Ids.password => 'Password & security',
    _Ids.privateAccount => 'Private account',
    _Ids.blocked => 'Blocked accounts',
    _Ids.theme => 'Display & theme',
    _Ids.navigation => 'Navigation bar',
    _Ids.lite => 'Lite mode',
    _Ids.space => 'Free up space',
    _Ids.help => 'Customer care & help',
    _Ids.about => 'About Ennvo',
    _ => 'Settings',
  };


  static String _iconFor(String id) => switch (id) {
    _Ids.account => LucideIcons.user,
    _Ids.password => LucideIcons.keyRound,
    _Ids.privateAccount => LucideIcons.lock,
    _Ids.blocked => LucideIcons.userX,
    _Ids.theme => LucideIcons.moon,
    _Ids.navigation => LucideIcons.smartphone,
    _Ids.lite => LucideIcons.zap,
    _Ids.space => LucideIcons.trash2,
    _Ids.help => LucideIcons.headphones,
    _ => LucideIcons.info,
  };

  // ======================================================================
  //  The screens
  // ======================================================================
  Widget _detail(String id, AppUser? user) => switch (id) {
    _Ids.account => _AccountDetail(user: user),
    _Ids.password => _PasswordDetail(email: user?.email ?? ''),
    _Ids.privateAccount => _PrivateDetail(user: user),
    _Ids.blocked => _BlockedDetail(user: user),
    _Ids.theme => const _ThemeDetail(),
    _Ids.navigation => const _NavigationDetail(),
    _Ids.lite => const _LiteDetail(),
    _Ids.space => const _FreeSpaceDetail(),
    _Ids.help => const _HelpDetail(),
    _Ids.about => const _AboutDetail(),
    _ => const SizedBox.shrink(),
  };
}

// ============================================================================
//  The data of a row
// ============================================================================
class _Item {
  const _Item({
    required this.id,
    required this.label,
    required this.icon,
    this.subtitle,
    this.badge,
    this.onTap,
  });

  final String id;
  final String label;
  final String icon;
  final String? subtitle;
  final String? badge;
  final VoidCallback? onTap;
}

class _Group {
  const _Group(this.title, this.items);

  final String title;
  final List<_Item> items;
}

// ============================================================================
//  The mobile header
// ============================================================================
class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xF2FFFFFF),
        border: Border(bottom: BorderSide(color: _kCardBorder)),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: LucideIcon(
                LucideIcons.arrowLeft,
                size: 23,
                strokeWidth: 2.3,
                color: _kInk,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EnnvoText.titleMd.copyWith(color: _kInk, fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The sidebar of the wide screen
// ============================================================================
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<_Group> groups;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: _kCardBorder),
        boxShadow: AppShadows.settingsPanel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(
                group.title.toUpperCase(),
                style: EnnvoText.overlineXs.copyWith(
                  color: _kSubtle,
                  fontSize: 10.5,
                ),
              ),
            ),
            for (final item in group.items)
              _SidebarItem(
                item: item,
                isSelected: item.id == selected,
                onTap: () => onSelected(item.id),
              ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _Item item;
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
              child: LucideIcon(
                item.icon,
                size: 19,
                strokeWidth: 2.2,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EnnvoText.bodySemi.copyWith(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const LucideIcon(
                LucideIcons.chevronRight,
                size: 16,
                strokeWidth: 2.2,
                color: Colors.white70,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  The list of the phone
// ============================================================================
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
      child: Text(
        text.toUpperCase(),
        style: EnnvoText.overlineXs.copyWith(
          color: const Color(0xFF0369A1),
          fontSize: 10.5,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: _kCardBorder),
        boxShadow: AppShadows.settingsPanel,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 62),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppGradients.settingsTile,
                borderRadius: BorderRadius.circular(11),
                boxShadow: AppShadows.settingsActive,
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                item.icon,
                size: 18,
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: EnnvoText.bodySemi.copyWith(
                      color: _kInk,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: _kMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.badge != null) _Badge(item.badge!),
            const SizedBox(width: 6),
            const LucideIcon(
              LucideIcons.chevronRight,
              size: 17,
              strokeWidth: 2.2,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: EnnvoText.tiny.copyWith(
          color: const Color(0xFF0369A1),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SignOutTile extends StatelessWidget {
  const _SignOutTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Row(
          children: [
            const LucideIcon(
              LucideIcons.logOut,
              size: 19,
              strokeWidth: 2.2,
              color: _kDanger,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sign out',
                style: EnnvoText.bodySemi.copyWith(
                  color: _kDanger,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  The shared pieces of the details
// ============================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: EnnvoText.overlineXs.copyWith(
          color: const Color(0xFF0369A1).withValues(alpha: 0.75),
          fontSize: 10.5,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12.5,
        height: 1.55,
        color: _kMuted,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = true,
    this.busy = false,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : const Color(0xFF0369A1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: filled ? AppGradients.settingsActive : null,
          color: filled ? null : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: filled ? null : Border.all(color: const Color(0xFFBAE6FD)),
          boxShadow: filled ? AppShadows.settingsActive : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(foreground),
                ),
              )
            else
              LucideIcon(
                icon,
                size: 17,
                strokeWidth: 2.3,
                color: foreground,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: EnnvoText.bodySemi.copyWith(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the big choice cards of the web app (glass / classic, light / dark).
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: EnnvoDurations.dropdown,
        curve: EnnvoCurves.press,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xB3E0F2FE) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? const Color(0xFF7DD3FC) : const Color(0xFFF1F5F9),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                icon,
                size: 19,
                strokeWidth: 2.2,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: EnnvoText.bodySemi.copyWith(
                      color: _kInk,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      height: 1.25,
                      color: _kMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected)
              const LucideIcon(
                LucideIcons.check,
                size: 19,
                strokeWidth: 2.6,
                color: _kSky,
              )
            else
              Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: _kMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: EnnvoText.bodySemi.copyWith(
                color: _kInk,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: _kCardBorder),
        boxShadow: AppShadows.settingsPanel,
      ),
      child: child,
    );
  }
}

/// The avatar of the signed-in user, with the initial as the fallback.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, this.size = 64});

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: const Color(0xFFE0F2FE),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: EnnvoText.titleLg.copyWith(
          color: const Color(0xFF0369A1),
          fontSize: size * 0.4,
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

// ============================================================================
//  Account information
// ============================================================================
class _AccountDetail extends ConsumerWidget {
  const _AccountDetail({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Avatar(
              url: current?.avatar ?? '',
              name: current?.name ?? '',
              size: 60,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current?.name.isNotEmpty == true
                        ? current!.name
                        : 'Your account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EnnvoText.titleMd.copyWith(color: _kInk),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    current?.username.isNotEmpty == true
                        ? '@${current!.username}'
                        : 'not signed in',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      color: _kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Card(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            children: [
              _InfoRow(label: 'Name', value: current?.name ?? ''),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _InfoRow(label: 'Username', value: current?.username ?? ''),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _InfoRow(label: 'Email', value: current?.email ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          label: 'Edit profile',
          icon: LucideIcons.user,
          onTap: () =>
              ref.read(navControllerProvider).pushPage(AppPage.editProfile),
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: 'Sign out',
          icon: LucideIcons.logOut,
          filled: false,
          onTap: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }
}

/// The sign-out confirmation, shared by the list and the account screen.
Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      title: const Text(
        'Sign out of Ennvo?',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _kInk,
        ),
      ),
      content: const Text(
        'Your drafts and your watched reels stay on this phone.',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          height: 1.45,
          color: _kMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Stay',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              color: _kMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'Sign out',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              color: _kDanger,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    ref.read(navControllerProvider).reset();
    await ref.read(authControllerProvider).signOut();
  }
}

// ============================================================================
//  Password & security
// ============================================================================
class _PasswordDetail extends ConsumerStatefulWidget {
  const _PasswordDetail({required this.email});

  final String email;

  @override
  ConsumerState<_PasswordDetail> createState() => _PasswordDetailState();
}

class _PasswordDetailState extends ConsumerState<_PasswordDetail> {
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    final ok = await ref
        .read(authControllerProvider)
        .sendPasswordReset(widget.email);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? const Color(0xFF0F172A) : _kDanger,
        content: Text(
          ok
              ? 'The reset link is on its way to ${widget.email}.'
              : 'Could not send the link. Check the address and try again.',
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const LucideIcon(
                      LucideIcons.keyRound,
                      size: 19,
                      strokeWidth: 2.2,
                      color: _kSky,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.email.isEmpty ? 'No email' : widget.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EnnvoText.bodySemi.copyWith(
                        color: _kInk,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _Hint(
                'We send a secure link to the email of the account. Open it '
                'on this phone and pick a new password.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          label: _busy ? 'Sending…' : 'Send reset link',
          icon: LucideIcons.send,
          busy: _busy,
          onTap: widget.email.isEmpty ? () {} : _send,
        ),
      ],
    );
  }
}

// ============================================================================
//  Private account
// ============================================================================
class _PrivateDetail extends ConsumerWidget {
  const _PrivateDetail({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = user?.isPrivate ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value ? 'Your account is private' : 'Your account is public',
                      style: EnnvoText.bodySemi.copyWith(
                        color: _kInk,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const _Hint(
                      'A private account only shows its posts and reels to '
                      'the people you follow back.',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                onChanged: user == null
                    ? null
                    : (next) =>
                          ref.read(authControllerProvider).setPrivate(next),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  Blocked accounts
// ============================================================================
class _BlockedDetail extends StatefulWidget {
  const _BlockedDetail({required this.user});

  final AppUser? user;

  @override
  State<_BlockedDetail> createState() => _BlockedDetailState();
}

class _BlockedDetailState extends State<_BlockedDetail> {
  late Future<List<AppUser>> _blocked = _load();

  Future<List<AppUser>> _load() {
    final ids = widget.user?.blockedUserIds ?? const <String>[];
    if (ids.isEmpty) return Future.value(const <AppUser>[]);
    return UserService.profiles(ids);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
      future: _blocked,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final people = snapshot.data ?? const <AppUser>[];
        if (people.isEmpty) {
          return const _Card(
            child: Column(
              children: [
                LucideIcon(
                  LucideIcons.userX,
                  size: 40,
                  strokeWidth: 1.8,
                  color: Color(0xFFBAE6FD),
                ),
                SizedBox(height: 10),
                Text(
                  'Nobody is blocked',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'The people you block cannot find your profile, message '
                  'you or see your reels.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    height: 1.5,
                    color: _kMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final person in people) ...[
              _Card(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _Avatar(
                      url: person.avatar,
                      name: person.name,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EnnvoText.bodySemi.copyWith(
                              color: _kInk,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '@${person.username}',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              color: _kMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================================
//  Display & theme
// ============================================================================
class _ThemeDetail extends ConsumerWidget {
  const _ThemeDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final dark = prefs.isDarkTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Appearance'),
        _ChoiceCard(
          title: 'Light',
          subtitle: 'The white pages of the web app',
          icon: LucideIcons.sun,
          selected: !dark,
          onTap: () => prefs.setDarkTheme(false),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'Dark',
          subtitle: 'The black pages, easy on the eyes',
          icon: LucideIcons.moon,
          selected: dark,
          onTap: () => prefs.setDarkTheme(true),
        ),
        const SizedBox(height: 14),
        const _Hint(
          'The reels and the chat keep their own colours — the reels are '
          'black in both themes, the chat is light in both.',
        ),
      ],
    );
  }
}

// ============================================================================
//  Navigation bar
// ============================================================================
class _NavigationDetail extends ConsumerWidget {
  const _NavigationDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(prefsProvider).navStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Navigation bar (2 designs)'),
        _ChoiceCard(
          title: 'Glass navigation',
          subtitle: 'Floating glass capsule, the reels timeline above it',
          icon: LucideIcons.sparkles,
          selected: style != 'classic',
          onTap: () => ref.read(prefsProvider).setNavStyle('glass'),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'Classic navigation',
          subtitle: 'Full width bar, the timeline flush on top of it',
          icon: LucideIcons.smartphone,
          selected: style == 'classic',
          onTap: () => ref.read(prefsProvider).setNavStyle('classic'),
        ),
        const SizedBox(height: 14),
        const _Hint(
          'The bar changes as soon as you pick one — every page keeps its '
          'scroll position.',
        ),
      ],
    );
  }
}

// ============================================================================
//  Lite mode
// ============================================================================
class _LiteDetail extends ConsumerWidget {
  const _LiteDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(prefsProvider).liteOverride;
    final device = ref.watch(deviceProfileProvider);
    final tier = switch (device.tier) {
      DeviceTier.low => 'a low end phone',
      DeviceTier.medium => 'a mid range phone',
      DeviceTier.high => 'a fast phone',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Row(
            children: [
              const LucideIcon(
                LucideIcons.zap,
                size: 20,
                strokeWidth: 2.2,
                color: _kSky,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Hint('This phone was detected as $tier.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionTitle('Effects'),
        _ChoiceCard(
          title: 'Automatic',
          subtitle: 'Lite only on a weak phone',
          icon: LucideIcons.sparkles,
          selected: override == null,
          onTap: () => ref.read(prefsProvider).setLiteOverride(null),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'On',
          subtitle: 'No blur, no big shadows — the fastest',
          icon: LucideIcons.zap,
          selected: override == 'on',
          onTap: () => ref.read(prefsProvider).setLiteOverride('on'),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'Off',
          subtitle: 'Every effect, even on a weak phone',
          icon: LucideIcons.eye,
          selected: override == 'off',
          onTap: () => ref.read(prefsProvider).setLiteOverride('off'),
        ),
        const SizedBox(height: 14),
        const _Hint(
          'The choice is applied the next time the app opens, so the very '
          'first frame is already drawn the right way.',
        ),
      ],
    );
  }
}

// ============================================================================
//  Free up space
// ============================================================================
class _FreeSpaceDetail extends ConsumerStatefulWidget {
  const _FreeSpaceDetail();

  @override
  ConsumerState<_FreeSpaceDetail> createState() => _FreeSpaceDetailState();
}

class _FreeSpaceDetailState extends ConsumerState<_FreeSpaceDetail> {
  bool _clean = false;

  Future<void> _clear() async {
    await ref.read(prefsProvider).clearSeenReels();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    if (!mounted) return;
    setState(() => _clean = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF0F172A),
        content: Text(
          'Cache cleared. The feed starts fresh.',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seen = ref.watch(prefsProvider).seenReels.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LucideIcon(
                    LucideIcons.hardDrive,
                    size: 20,
                    strokeWidth: 2.2,
                    color: _kSky,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _clean ? '0 watched reels' : '$seen watched reels',
                      style: EnnvoText.bodySemi.copyWith(
                        color: _kInk,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _Hint(
                'The ranking remembers what you watched so it can show you '
                'something new. Clearing it also empties the image cache.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          label: 'Clear cache',
          icon: LucideIcons.trash2,
          filled: false,
          onTap: _clear,
        ),
      ],
    );
  }
}

// ============================================================================
//  Customer care
// ============================================================================
class _HelpDetail extends StatelessWidget {
  const _HelpDetail();

  Future<void> _copy(BuildContext context, String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        content: Text(
          '$what copied',
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ennvo official customer care',
                style: EnnvoText.bodySemi.copyWith(
                  color: _kInk,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _ContactLine(
                icon: LucideIcons.phone,
                label: '+880 1700-000000',
                onTap: () =>
                    _copy(context, '+880 1700-000000', 'The hotline'),
              ),
              const SizedBox(height: 10),
              _ContactLine(
                icon: LucideIcons.send,
                label: 'ennvoapp@gmail.com',
                onTap: () =>
                    _copy(context, 'ennvoapp@gmail.com', 'The email'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _Hint(
          'The desk answers around the clock. A verified badge request is '
          'reviewed within 24 hours.',
        ),
      ],
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
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
      child: Row(
        children: [
          LucideIcon(icon, size: 17, strokeWidth: 2.2, color: _kSky),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: EnnvoText.bodySemi.copyWith(
                color: const Color(0xFF0369A1),
                fontSize: 13.5,
              ),
            ),
          ),
          const LucideIcon(
            LucideIcons.chevronRight,
            size: 16,
            strokeWidth: 2.2,
            color: Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  About
// ============================================================================
class _AboutDetail extends StatelessWidget {
  const _AboutDetail();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/brand/ennvo_logo.png',
                  width: 84,
                  height: 84,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const SizedBox.square(
                    dimension: 84,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ennvo',
                style: EnnvoText.titleLg.copyWith(
                  color: _kInk,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Version 1.0.0 (1)',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  color: _kMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _Card(
          child: _Hint(
            'Ennvo is a fast, small social app: a short-video feed, a home '
            'feed, stories, messages and HD calls, in one place.\n\n'
            'The native build is written in Flutter and talks to the same '
            'Ennvo backend as the web app, so an account works on both.\n\n'
            'Built with care by Erfan Sarker.',
          ),
        ),
      ],
    );
  }
}
