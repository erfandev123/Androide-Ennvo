// ============================================================================
//  ENNVO — NAVIGATION CONTROLLER
//
//  A faithful port of the web app's navigation model. The web app has no
//  router: it keeps a `currentPage` plus a `navigationStack` array in the
//  Zustand store and toggles page visibility.
//
//  Stack rules ported from `src/store.ts`:
//    • `pushPage` — `home` resets the stack to `['home']`; pushing the page
//      that is already open is a no-op.
//    • `backPage`  — pops one entry; never lands on the same page twice;
//      falls back to `['home']`.
//    • `popPage`   — `edit-profile` → `profile` (stack `['home','profile']`);
//      anything else → `home` (stack `['home']`).
// ============================================================================

import 'package:flutter/foundation.dart';

import 'page_type.dart';

class NavController extends ChangeNotifier {
  NavController({AppPage initial = AppPage.home}) : _current = initial {
    _stack.add(initial);
    _visited.add(initial);
  }

  AppPage _current;
  final List<AppPage> _stack = <AppPage>[];
  final Set<AppPage> _visited = <AppPage>{};

  AppPage get currentPage => _current;

  List<AppPage> get stack => List<AppPage>.unmodifiable(_stack);

  /// Pages that have been opened at least once. The web app keeps every
  /// visited page mounted so returning to a tab restores its scroll
  /// position and state.
  Set<AppPage> get visitedPages => Set<AppPage>.unmodifiable(_visited);

  bool get canGoBack => _stack.length > 1;

  /// Pushes a page onto the history stack.
  void pushPage(AppPage page) {
    if (page == _current) return;
    if (page == AppPage.home) {
      _stack
        ..clear()
        ..add(AppPage.home);
    } else {
      _stack.add(page);
    }
    _current = page;
    _visited.add(page);
    notifyListeners();
  }

  /// Pops the history stack. Never lands on the same page twice in a row.
  void backPage() {
    if (_stack.length <= 1) {
      if (_current != AppPage.home) {
        _current = AppPage.home;
        _stack
          ..clear()
          ..add(AppPage.home);
        notifyListeners();
      }
      return;
    }

    _stack.removeLast();
    // Never show the same page twice in a row.
    if (_stack.isNotEmpty && _stack.last == _current) {
      _stack.removeLast();
    }
    _current = _stack.isNotEmpty ? _stack.last : AppPage.home;
    notifyListeners();
  }

  /// The web app's `popPage()` — a special-cased "dismiss this modal-ish
  /// screen" action rather than a plain history pop.
  void popPage() {
    if (_current == AppPage.editProfile) {
      _stack
        ..clear()
        ..add(AppPage.home)
        ..add(AppPage.profile);
      _current = AppPage.profile;
    } else {
      _stack
        ..clear()
        ..add(AppPage.home);
      _current = AppPage.home;
    }
    notifyListeners();
  }

  /// Switches page without touching the history stack — used by the bottom
  /// navigation, which behaves like a tab switcher.
  void setCurrentPage(AppPage page) {
    if (page == _current) return;
    _current = page;
    _visited.add(page);
    if (page == AppPage.home) {
      _stack
        ..clear()
        ..add(AppPage.home);
    } else if (!_stack.contains(page)) {
      _stack.add(page);
    }
    notifyListeners();
  }

  /// Whether a page should stay mounted while another page is on top.
  ///
  /// The web app unmounts `create`, `edit-profile`, `settings` and `admin`
  /// when they are not active; everything else stays alive.
  bool isKeptMounted(AppPage page) => !const {
    AppPage.create,
    AppPage.editProfile,
    AppPage.settings,
    AppPage.admin,
  }.contains(page);

  /// Resets to the initial state — used when the user signs out.
  void reset({AppPage initial = AppPage.home}) {
    _current = initial;
    _stack
      ..clear()
      ..add(initial);
    _visited
      ..clear()
      ..add(initial);
    notifyListeners();
  }
}
