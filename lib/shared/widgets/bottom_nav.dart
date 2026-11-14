// ============================================================================
//  ENNVO — BOTTOM NAVIGATION
//
//  A faithful port of `src/components/BottomNav.tsx`.
//
//  Two skins ship:
//    • glass   — a floating rounded pill with a sliding active highlight
//                (`motion.div layoutId="iphoneGlassActivePill"`), used by
//                default.
//    • classic — a full-width bar with a border and a small active dot.
//
//  The active highlight slides on a spring (`stiffness 520, damping 38`)
//  which is the web app's `layoutId` animation, reimplemented with a
//  [SpringCurve].
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../icons/ennvo_nav_icons.dart';
import '../icons/lucide_icons.dart';

class EnnvoBottomNav extends ConsumerStatefulWidget {
  const EnnvoBottomNav({
    super.key,
    required this.currentPage,
    required this.onSelect,
    this.avatarUrl,
    this.messageCount = 0,
    this.notificationCount = 0,
    this.isHidden = false,
    this.solidDark = false,
  });

  final AppPage currentPage;
  final ValueChanged<AppPage> onSelect;
  final String? avatarUrl;
  final int messageCount;
  final int notificationCount;

  /// The reels page hides the bar for a clean full-screen video feed.
  final bool isHidden;

  /// A full width solid black bar, the way TikTok puts its navigation over
  /// the video so the bar matches the screen.
  final bool solidDark;
  @override
  ConsumerState<EnnvoBottomNav> createState() => _EnnvoBottomNavState();
}

class _EnnvoBottomNavState extends ConsumerState<EnnvoBottomNav> {
  static const List<AppPage> _items = AppPage.navOrder;

  int _indexOf(AppPage page) => _items.indexOf(page);

  void _handleTap(AppPage page, int index) {
    if (page == widget.currentPage) return;
    HapticFeedback.lightImpact();
    widget.onSelect(page);
  }

  /// Double tap on a tab activates it — the web app treats a quick second
  /// tap as a confirm.
  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHidden) return const SizedBox.shrink();

    final style = ref.watch(navStyleProvider);
    final profile = ref.watch(deviceProfileProvider);
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    if (widget.solidDark) return _buildSolid(context, safeBottom);

    return style == 'classic'
        ? _buildClassic(context, safeBottom)
        : _buildGlass(context, safeBottom, profile.allowBlur);
  }

  // ======================================================================
  //  The solid dark bar — TikTok puts a black navigation over the video so
  //  the bar and the screen read as one surface.
  // ======================================================================
  Widget _buildSolid(BuildContext context, double safeBottom) {
    final activeIndex = _indexOf(widget.currentPage);

    return Container(
      height: 54 + safeBottom,
      padding: EdgeInsets.only(bottom: safeBottom),
      color: Colors.black,
      child: Row(
        children: [
          for (final page in _items)
            Expanded(
              child: _SolidItem(
                page: page,
                isActive: page == widget.currentPage,
                avatarUrl: page == AppPage.profile ? widget.avatarUrl : null,
                badgeCount:
                    page == AppPage.messages
                    ? widget.messageCount + widget.notificationCount
                    : 0,
                onTap: () => _handleTap(page, _indexOf(page)),
              ),
            ),
        ],
      ),
    );
  }

  // ======================================================================
  //  Glass skin
  // ======================================================================
  Widget _buildGlass(BuildContext context, double safeBottom, bool allowBlur) {
    final t = context.tokens;
    final isDark = t.isDark;
    final activeIndex = _indexOf(widget.currentPage);

    final pillBackground = isDark ? const Color(0xFF000000) : Colors.white;
    final pillBorder = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0xCCD4D4D8); // neutral-200/80
    final activeBg = isDark
        ? const Color(0x2EFFFFFF) // white/18
        : const Color(0x1F0EA5E9); // sky-500/12
    final activeBorder = isDark
        ? const Color(0x40FFFFFF) // white/25
        : const Color(0x8099D9F6); // sky-300/50
    final idleIcon = isDark ? const Color(0x99FFFFFF) : const Color(0xFF64748B);
    final activeIcon = isDark ? Colors.white : const Color(0xFF0284C7);

    // The bar is positioned by its parent, so this widget must not return a
    // `Positioned` — a `ParentDataWidget` only works as a direct child of a
    // `Stack`.
    return Padding(
      padding: EdgeInsets.only(bottom: safeBottom + 12),
      child: Center(
        child: Container(
          height: AppSizes.bottomNavHeight,
          constraints: const BoxConstraints(
            minWidth: AppSizes.bottomNavPillMinWidth,
            maxWidth: AppSizes.bottomNavPillMaxWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: pillBackground,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: pillBorder),
            boxShadow: isDark
                ? const [BoxShadow(color: Color(0x73000000), blurRadius: 16)]
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: activeIndex.toDouble(),
                  end: activeIndex.toDouble(),
                ),
                duration: const Duration(milliseconds: 520),
                curve: const SpringCurve(EnnvoSprings.navPill),
                builder: (context, animatedIndex, _) {
                  return Stack(
                    children: [
                      // --- sliding active highlight (layoutId) ---
                      Positioned(
                        left: animatedIndex * itemWidth + 4,
                        top: 0,
                        bottom: 0,
                        width: itemWidth - 8,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: activeBg,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(color: activeBorder),
                            ),
                          ),
                        ),
                      ),
                      // --- the five destinations ---
                      Row(
                        children: [
                          for (var i = 0; i < _items.length; i++)
                            Expanded(
                              child: _NavItem(
                                page: _items[i],
                                isActive: _items[i] == widget.currentPage,
                                iconSize: AppSizes.navIconSize,
                                activeIconColor: activeIcon,
                                idleIconColor: idleIcon,
                                avatarUrl: _items[i] == AppPage.profile
                                    ? widget.avatarUrl
                                    : null,
                                badgeCount:
                                    _items[i] == AppPage.messages
                                    ? widget.messageCount +
                                          widget.notificationCount
                                    : 0,
                                onTap: () => _handleTap(_items[i], i),
                                onDoubleTap: _handleDoubleTap,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ======================================================================
  //  Classic skin
  // ======================================================================
  Widget _buildClassic(BuildContext context, double safeBottom) {
    final t = context.tokens;
    final isDark = t.isDark;
    final isReels = widget.currentPage == AppPage.home;

    final background = isReels
        ? Colors.black
        : (isDark ? const Color(0xFF0B0B0E) : Colors.white);
    final borderColor = isReels
        ? Colors.transparent
        : (isDark ? const Color(0x1AFFFFFF) : const Color(0xCCE5E7EB));
    final idleIcon = isReels || isDark
        ? const Color(0x99FFFFFF)
        : const Color(0xFF6B7280);
    final activeIcon = isReels || isDark ? Colors.white : const Color(0xFF0EA5E9);
    final dotColor = isDark ? Colors.white : const Color(0xFF0EA5E9);

    // Positioned by the parent — see the note in the glass skin.
    return Container(
      height: 58 + safeBottom,
      padding: EdgeInsets.only(bottom: safeBottom),
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          for (final page in _items)
            Expanded(
              child: _NavItem(
                page: page,
                isActive: page == widget.currentPage,
                iconSize: AppSizes.navIconSizeClassic,
                activeIconColor: activeIcon,
                idleIconColor: idleIcon,
                avatarUrl: page == AppPage.profile ? widget.avatarUrl : null,
                badgeCount:
                    page == AppPage.messages
                    ? widget.messageCount + widget.notificationCount
                    : 0,
                showDot: true,
                dotColor: dotColor,
                onTap: () => _handleTap(page, _indexOf(page)),
                onDoubleTap: _handleDoubleTap,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
//  A single destination
// ============================================================================
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.page,
    required this.isActive,
    required this.iconSize,
    required this.activeIconColor,
    required this.idleIconColor,
    required this.onTap,
    required this.onDoubleTap,
    this.avatarUrl,
    this.badgeCount = 0,
    this.showDot = false,
    this.dotColor = Colors.white,
  });

  final AppPage page;
  final bool isActive;
  final double iconSize;
  final Color activeIconColor;
  final Color idleIconColor;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final String? avatarUrl;
  final int badgeCount;
  final bool showDot;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeIconColor : idleIconColor;

    Widget icon;
    switch (page) {
      case AppPage.home:
        icon = EnnvoNavIconView(EnnvoNavIcon.home, color: color, size: iconSize);
      case AppPage.reels:
        icon = EnnvoNavIconView(EnnvoNavIcon.feed, color: color, size: iconSize);
      case AppPage.create:
        icon = _CreateButton(size: iconSize);
      case AppPage.messages:
        icon = EnnvoNavIconView(
          EnnvoNavIcon.message,
          color: color,
          size: iconSize,
        );
      case AppPage.profile:
        icon = _ProfileAvatar(
          url: avatarUrl,
          size: iconSize - (showDot ? 2 : 3),
          isActive: isActive,
          activeColor: activeIconColor,
        );
      default:
        icon = EnnvoNavIconView(
          EnnvoNavIcon.home,
          color: color,
          size: iconSize,
        );
    }

    final content = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (showDot)
          Positioned(
            bottom: 2,
            child: AnimatedScale(
              scale: isActive ? 1 : 0,
              duration: EnnvoDurations.dropdown,
              curve: EnnvoCurves.press,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        AnimatedScale(
          scale: isActive ? 1.05 : 1.0,
          duration: EnnvoDurations.dropdown,
          curve: EnnvoCurves.press,
          child: icon,
        ),
        if (badgeCount > 0)
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              constraints: BoxConstraints(
                minWidth: showDot ? 16 : 15,
                minHeight: showDot ? 16 : 15,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kBrand,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: Colors.white),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: EnnvoText.tiny.copyWith(
                  color: Colors.white,
                  fontSize: showDot ? 10 : 9,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      key: ValueKey<String>('ennvo-nav-${page.name}'),
      button: true,
      selected: isActive,
      label: page.navLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: SizedBox(height: 48, child: Center(child: content)),
      ),
    );
  }
}

/// The gradient create button — `from-sky-400 via-blue-500 to-indigo-600`.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isClassic = size >= AppSizes.navIconSizeClassic;

    return Container(
      width: isClassic ? 38 : 32,
      height: isClassic ? 30 : 32,
      decoration: BoxDecoration(
        gradient: AppGradients.create,
        borderRadius: BorderRadius.circular(isClassic ? 12 : 999),
        boxShadow: [
          BoxShadow(
            color: const Color(0x5938BDF8),
            blurRadius: isClassic ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: EnnvoNavIconView(
          EnnvoNavIcon.create,
          color: Colors.white,
          size: isClassic ? 18 : 17,
          strokeWidth: 2.3,
        ),
      ),
    );
  }
}

/// The profile avatar in the navigation bar.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.size,
    required this.isActive,
    required this.activeColor,
    this.url,
  });

  final String? url;
  final double size;
  final bool isActive;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: activeColor, width: isActive ? 2 : 0),
        image: url == null || url!.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(url!),
                fit: BoxFit.cover,
              ),
        color: url == null || url!.isEmpty
            ? activeColor.withValues(alpha: 0.25)
            : null,
      ),
      child: url == null || url!.isEmpty
          ? Center(
              child: EnnvoNavIconView(
                EnnvoNavIcon.profile,
                color: activeColor,
                size: size * 0.62,
              ),
            )
          : null,
    );

    return AnimatedScale(
      scale: isActive ? 1.05 : 1.0,
      duration: EnnvoDurations.dropdown,
      curve: EnnvoCurves.press,
      child: avatar,
    );
  }
}

// ============================================================================
//  One destination of the solid dark bar
// ============================================================================
class _SolidItem extends StatelessWidget {
  const _SolidItem({
    required this.page,
    required this.isActive,
    required this.onTap,
    this.avatarUrl,
    this.badgeCount = 0,
  });

  final AppPage page;
  final bool isActive;
  final VoidCallback onTap;
  final String? avatarUrl;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    Widget icon;
    switch (page) {
      case AppPage.home:
        icon = EnnvoNavIconView(
          EnnvoNavIcon.home,
          color: Colors.white,
          size: 25,
          filled: isActive,
        );
      case AppPage.reels:
        icon = EnnvoNavIconView(
          EnnvoNavIcon.feed,
          color: Colors.white,
          size: 25,
          filled: isActive,
        );
      case AppPage.create:
        icon = const _SolidCreateButton();
      case AppPage.messages:
        icon = EnnvoNavIconView(
          EnnvoNavIcon.message,
          color: Colors.white,
          size: 25,
          filled: isActive,
        );
      case AppPage.profile:
        icon = _SolidAvatar(url: avatarUrl, isActive: isActive);
      default:
        icon = EnnvoNavIconView(
          EnnvoNavIcon.home,
          color: Colors.white,
          size: 25,
        );
    }

    return Semantics(
      button: true,
      selected: isActive,
      label: page.navLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                icon,
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -12,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: kBrand,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: EnnvoText.tiny.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The create button of the solid bar.
class _SolidCreateButton extends StatelessWidget {
  const _SolidCreateButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const LucideIcon(
        LucideIcons.plus,
        size: 18,
        strokeWidth: 2.6,
        color: Colors.black,
      ),
    );
  }
}

/// The profile avatar of the solid bar.
class _SolidAvatar extends StatelessWidget {
  const _SolidAvatar({this.url, this.isActive = false});

  final String? url;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = url ?? '';

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        image: avatarUrl.isEmpty
            ? null
            : DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover),
      ),
      child: avatarUrl.isEmpty
          ? Center(
              child: EnnvoNavIconView(
                EnnvoNavIcon.profile,
                color: Colors.white,
                size: 16,
              ),
            )
          : null,
    );
  }
}
