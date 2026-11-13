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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/nav_controller.dart';
import '../../core/nav/page_type.dart';
import '../../core/providers.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../auth/auth_page.dart';
import '../create/create_page.dart';
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
  static const Set<AppPage> _withBottomNav = {
    AppPage.home,
    AppPage.reels,
    AppPage.profile,
  };

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navControllerProvider);
    final visited = nav.visitedPages;
    final showNav = _withBottomNav.contains(nav.currentPage);

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
              EnnvoBottomNav(
                currentPage: nav.currentPage,
                onSelect: nav.setCurrentPage,
                messageCount: ref.watch(navBadgesProvider).messages,
                notificationCount: ref.watch(navBadgesProvider).notifications,
              ),
          ],
        ),
      ),
    );
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
    AppPage.create => const CreatePage(),
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
