// ============================================================================
//  ENNVO — NAVIGATION CONTROLLER TESTS
//
//  These lock in the navigation semantics of the web app's Zustand store:
//  `pushPage`, `backPage` and `popPage`.
// ============================================================================

import 'package:ennvo/core/nav/nav_controller.dart';
import 'package:ennvo/core/nav/page_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavController', () {
    test('starts on home', () {
      final nav = NavController();
      expect(nav.currentPage, AppPage.home);
      expect(nav.stack, [AppPage.home]);
      expect(nav.canGoBack, isFalse);
    });

    test('pushPage adds to the history stack', () {
      final nav = NavController();
      nav.pushPage(AppPage.profile);

      expect(nav.currentPage, AppPage.profile);
      expect(nav.stack, [AppPage.home, AppPage.profile]);
      expect(nav.canGoBack, isTrue);
      expect(nav.visitedPages, contains(AppPage.profile));
    });

    test('pushPage ignores the page that is already open', () {
      final nav = NavController();
      nav.pushPage(AppPage.home);
      expect(nav.stack, [AppPage.home]);
    });

    test('pushing home resets the stack', () {
      final nav = NavController();
      nav.pushPage(AppPage.profile);
      nav.pushPage(AppPage.messages);
      nav.pushPage(AppPage.home);

      expect(nav.currentPage, AppPage.home);
      expect(nav.stack, [AppPage.home]);
    });

    test('backPage pops the stack', () {
      final nav = NavController();
      nav.pushPage(AppPage.profile);
      nav.pushPage(AppPage.messages);
      nav.backPage();

      expect(nav.currentPage, AppPage.profile);
      expect(nav.stack, [AppPage.home, AppPage.profile]);
    });

    test('backPage on the root falls back to home', () {
      final nav = NavController();
      nav.backPage();
      expect(nav.currentPage, AppPage.home);
      expect(nav.stack, [AppPage.home]);
    });

    test('popPage from edit-profile lands on profile', () {
      final nav = NavController();
      nav.pushPage(AppPage.profile);
      nav.pushPage(AppPage.editProfile);
      nav.popPage();

      expect(nav.currentPage, AppPage.profile);
      expect(nav.stack, [AppPage.home, AppPage.profile]);
    });

    test('popPage from anywhere else lands on home', () {
      final nav = NavController();
      nav.pushPage(AppPage.search);
      nav.popPage();

      expect(nav.currentPage, AppPage.home);
      expect(nav.stack, [AppPage.home]);
    });

    test('visited pages stay mounted, transient ones do not', () {
      final nav = NavController();
      expect(nav.isKeptMounted(AppPage.home), isTrue);
      expect(nav.isKeptMounted(AppPage.reels), isTrue);
      expect(nav.isKeptMounted(AppPage.messages), isTrue);
      expect(nav.isKeptMounted(AppPage.create), isFalse);
      expect(nav.isKeptMounted(AppPage.settings), isFalse);
      expect(nav.isKeptMounted(AppPage.editProfile), isFalse);
      expect(nav.isKeptMounted(AppPage.admin), isFalse);
    });

    test('reset clears the stack', () {
      final nav = NavController();
      nav.pushPage(AppPage.search);
      nav.reset();
      expect(nav.currentPage, AppPage.home);
      expect(nav.stack, [AppPage.home]);
    });
  });

  group('AppPage', () {
    test('maps URL segments like the web app', () {
      expect(AppPage.fromUrlSegment('home'), AppPage.home);
      expect(AppPage.fromUrlSegment('feed'), AppPage.reels);
      expect(AppPage.fromUrlSegment('reels'), AppPage.reels);
      expect(AppPage.fromUrlSegment('search'), AppPage.search);
      expect(AppPage.fromUrlSegment('explore'), AppPage.search);
      expect(AppPage.fromUrlSegment('messages'), AppPage.messages);
      expect(AppPage.fromUrlSegment('chat'), AppPage.messages);
      expect(AppPage.fromUrlSegment('massage'), AppPage.messages);
      expect(AppPage.fromUrlSegment('m'), AppPage.messages);
      expect(AppPage.fromUrlSegment('notifications'), AppPage.notifications);
      expect(AppPage.fromUrlSegment('create'), AppPage.create);
      expect(AppPage.fromUrlSegment('profile'), AppPage.profile);
      expect(AppPage.fromUrlSegment('user'), AppPage.profile);
      expect(AppPage.fromUrlSegment('u'), AppPage.profile);
      expect(AppPage.fromUrlSegment('settings'), AppPage.settings);
      expect(AppPage.fromUrlSegment('edit-profile'), AppPage.editProfile);
      expect(AppPage.fromUrlSegment('admin'), AppPage.admin);
      expect(AppPage.fromUrlSegment('nope'), isNull);
    });

    test('keeps the web app home / reels inversion', () {
      // `home` shows the Reels feed, `reels` shows the home feed.
      expect(AppPage.home.navLabel, 'Home');
      expect(AppPage.reels.navLabel, 'Feed');
      expect(AppPage.home.urlPath, '/home');
      expect(AppPage.reels.urlPath, '/feed');
    });
  });
}
