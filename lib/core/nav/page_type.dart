// ============================================================================
//  ENNVO — PAGE TYPES
//
//  The web app has no router. Navigation is a Zustand `currentPage` string
//  plus a `navigationStack` array, mirrored to the URL through
//  `URL_PAGE_MAP`. This is the Flutter equivalent.
//
//  NOTE the inversion, inherited from the web app:
//    • `home`  → the TikTok-style Reels feed  (BottomNav label "Home")
//    • `reels` → the Facebook-style home feed   (BottomNav label "Feed")
// ============================================================================

enum AppPage {
  home,
  search,
  reels,
  messages,
  notifications,
  create,
  profile,
  settings,
  editProfile,
  admin;

  /// Bottom navigation label (from `BottomNav.tsx`).
  String get navLabel => switch (this) {
    AppPage.home => 'Home',
    AppPage.reels => 'Feed',
    AppPage.create => 'New',
    AppPage.messages => 'Inbox',
    AppPage.profile => 'Profile',
    _ => '',
  };

  /// The five bottom-navigation destinations, in order.
  static const List<AppPage> navOrder = [
    AppPage.home,
    AppPage.reels,
    AppPage.create,
    AppPage.messages,
    AppPage.profile,
  ];

  /// Maps a URL path segment to a page — the Flutter port of
  /// `URL_PAGE_MAP` in `src/store.ts`.
  ///
  /// `home` → home, `feed`/`reels` → reels, `search`/`explore` → search,
  /// `messages`/`chat`/`massage`/`m` → messages, `notifications` →
  /// notifications, `create` → create, `profile`/`user`/`u` → profile,
  /// `settings` → settings, `edit-profile` → editProfile, `admin` → admin.
  static AppPage? fromUrlSegment(String segment) {
    switch (segment) {
      case 'home':
        return AppPage.home;
      case 'feed':
      case 'reels':
        return AppPage.reels;
      case 'search':
      case 'explore':
        return AppPage.search;
      case 'messages':
      case 'chat':
      case 'massage':
      case 'm':
        return AppPage.messages;
      case 'notifications':
        return AppPage.notifications;
      case 'create':
        return AppPage.create;
      case 'profile':
      case 'user':
      case 'u':
        return AppPage.profile;
      case 'settings':
        return AppPage.settings;
      case 'edit-profile':
        return AppPage.editProfile;
      case 'admin':
        return AppPage.admin;
      default:
        return null;
    }
  }

  /// The canonical URL path for a page.
  String get urlPath => switch (this) {
    AppPage.home => '/home',
    AppPage.search => '/search',
    AppPage.reels => '/feed',
    AppPage.messages => '/messages',
    AppPage.notifications => '/notifications',
    AppPage.create => '/create',
    AppPage.profile => '/profile',
    AppPage.settings => '/settings',
    AppPage.editProfile => '/edit-profile',
    AppPage.admin => '/admin',
  };
}
