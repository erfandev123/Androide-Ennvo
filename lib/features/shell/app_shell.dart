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
import '../create/create_page.dart';
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
    final openConversation = ref.watch(openConversationProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // A chat that is open inside the messages page closes first — the
        // system back gesture never leaves the app with a chat on screen.
        if (nav.currentPage == AppPage.messages && openConversation != null) {
          ref.read(openConversationProvider.notifier).state = null;
          return;
        }
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EnnvoBottomNav(
                  currentPage: nav.currentPage,
                  onSelect: _onSelectTab,
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
  ///
  /// Tapping the inbox while a conversation is open goes back to the
  /// conversation list, the way every messenger does it.
  void _onSelectTab(AppPage page) {
    final nav = ref.read(navControllerProvider);
    if (page == AppPage.messages) {
      ref.read(openConversationProvider.notifier).state = null;
    }
    nav.setCurrentPage(page);
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
