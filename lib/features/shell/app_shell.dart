// ============================================================================
//  ENNVO — APP SHELL
//
//  The web app keeps every visited page mounted and toggles visibility with
//  `display:none` / `opacity:0` plus a z-index. The native port does the
//  same with [Offstage], which keeps the widget tree (and therefore the
//  scroll position and state) alive while skipping painting entirely.
//
//  Pages that must not stay alive — `create`, `edit-profile`, `settings`,
//  `admin` — are dropped from the tree instead, matching the web app's
//  conditional rendering.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/nav_controller.dart';
import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../create/camera_page.dart';
import '../edit_profile/edit_profile_page.dart';
import '../feed/feed_page.dart';
import '../messages/messages_page.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../reels/reels_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Pages that show the shared bottom navigation.
  ///
  /// The messages page is one of them: the chat is drawn *inside* the page
  /// instead of being pushed as a route over the app, so the navigation stays
  /// exactly where it is — the same way the feed keeps it.
  static const Set<AppPage> _withBottomNav = {
    AppPage.home,
    AppPage.reels,
    AppPage.messages,
    AppPage.profile,
  };

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navControllerProvider);
    final visited = nav.visitedPages;
    // The navigation bar steps aside while the keyboard is up — it would
    // otherwise float on top of the composer.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showNav =
        _withBottomNav.contains(nav.currentPage) && !keyboardOpen;

    // The buttons of the phone — back, home and the square — are painted in
    // the colour of the page that is on screen: black under the reels, the
    // white of the feed under the feed, and so on. There is never a dark
    // strip under a light page.
    final pageColor = _pageColor(nav.currentPage, context);
    _applySystemBars(pageColor);

    final avatarUrl = ref.watch(authControllerProvider).user?.avatar;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (nav.canGoBack) {
          nav.backPage();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // The keyboard must never push the screen up: the composer of a
        // sheet floats above it and the page behind stays where it is.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            for (final page in visited)
              Positioned.fill(
                child: _PageHost(
                  page: page,
                  isActive: page == nav.currentPage,
                  keepMounted: nav.isKeptMounted(page),
                ),
              ),
            if (showNav)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EnnvoBottomNav(
                  currentPage: nav.currentPage,
                  onSelect: _onSelectTab,
                  avatarUrl: avatarUrl,
                  messageCount: ref.watch(navBadgesProvider).messages,
                  notificationCount: ref
                      .watch(navBadgesProvider)
                      .notifications,
                  // The reels feed is a black screen, so the bar paints itself
                  // dark there — exactly like the web app does. It keeps the
                  // same shape and the same place everywhere.
                  forceDark: nav.currentPage == AppPage.home,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Handles a tap on a navigation destination.
  void _onSelectTab(AppPage page) {
    ref.read(navControllerProvider).setCurrentPage(page);
  }

  /// The last style that was sent to the system, so the channel is only
  /// written when something really changed.
  SystemUiOverlayStyle? _systemBars;

  /// The colour of the page behind the system bar.
  Color _pageColor(AppPage page, BuildContext context) {
    final tokens = context.tokens;
    return switch (page) {
      AppPage.home => const Color(0xFF000000),
      AppPage.create => const Color(0xFF000000),
      AppPage.profile => const Color(0xFFFAF5FF),
      AppPage.settings => const Color(0xFFF4F8FF),
      AppPage.messages =>
        tokens.isDark ? const Color(0xFF000000) : Colors.white,
      _ => tokens.background,
    };
  }

  /// Paints the buttons of the phone in the colour of the page.
  void _applySystemBars(Color color) {
    final isDark = color.computeLuminance() < 0.5;

    final style = SystemUiOverlayStyle(
      // The page runs under both bars, so they are transparent; the
      // navigation bar takes the colour of the page so the three buttons
      // sit on the page and not on a black strip.
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: color,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      // Android 10+ otherwise draws its own translucent scrim over the
      // navigation bar, which is exactly the black box we do not want.
      systemNavigationBarContrastEnforced: false,
    );
    if (_systemBars == style) return;
    _systemBars = style;
    SystemChrome.setSystemUIOverlayStyle(style);
  }
}

/// Hosts a single page and keeps it alive while another page is on top.
class _PageHost extends StatelessWidget {
  const _PageHost({
    required this.page,
    required this.isActive,
    required this.keepMounted,
  });

  final AppPage page;
  final bool isActive;
  final bool keepMounted;

  @override
  Widget build(BuildContext context) {
    // Pages that must unmount when they are not active.
    if (!keepMounted && !isActive) return const SizedBox.shrink();

    final child = _buildPage(page);

    return Offstage(offstage: !isActive, child: child);
  }

  Widget _buildPage(AppPage page) => switch (page) {
    AppPage.home => const ReelsPage(),
    AppPage.reels => const FeedPage(),
    AppPage.search => const SearchPage(),
    AppPage.messages => const MessagesPage(),
    AppPage.notifications => const NotificationsPage(),
    // The `+` of the navigation bar opens the camera, the way Instagram
    // does: the composer comes after the picture.
    AppPage.create => const CameraPage(),
    AppPage.profile => const ProfilePage(),
    AppPage.settings => const SettingsPage(),
    AppPage.editProfile => const EditProfilePage(),
    AppPage.admin => const SizedBox.shrink(),
  };
}

/// Convenience access to the navigation controller from any widget.
extension NavContextX on BuildContext {
  NavController get nav => ProviderScope.containerOf(
    this,
    listen: false,
  ).read(navControllerProvider);
}
