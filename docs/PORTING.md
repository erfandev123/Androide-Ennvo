# Porting guide — Ennvo web app → native Flutter app

This document maps every part of the web app to its native counterpart and
records the decisions that were made along the way.

The source of truth for the design is the web app in
`C:\Users\erfan\3D Objects\Ennvo`.

---

## 1. Screens

| Web app | Route | Native | State |
|---|---|---|---|
| `src/pages/Reels.tsx` | `/home`, `/feed`, `/reels` | `lib/features/reels/reels_page.dart` | **ported** |
| `src/pages/Home.tsx` | `/feed` | `lib/features/feed/feed_page.dart` | **ported** |
| `src/pages/Auth.tsx` | — | `lib/features/auth/auth_page.dart` | **ported** |
| `src/pages/Messages.tsx` | `/messages` | `lib/features/messages/messages_page.dart` | **ported** |
| `src/pages/Notifications.tsx` | `/notifications` | `lib/features/notifications/notifications_page.dart` | **ported** |
| `src/pages/Profile.tsx` | `/profile`, `/user/:handle` | `lib/features/profile/profile_page.dart` | **ported** |
| `src/pages/Create.tsx` | `/create` | `lib/features/create/create_page.dart` | **ported** |
| `src/pages/Settings.tsx` | `/settings` | `lib/features/settings/settings_page.dart` | **ported** |
| `src/pages/EditProfile.tsx` | `/edit-profile` | `lib/features/edit_profile/edit_profile_page.dart` | **ported** |
| `src/pages/SearchPage.tsx` | `/search`, `/explore` | `lib/features/search/search_page.dart` | **ported** |
| `admin-console/` | `/admin` | — | not started |

> The web app's naming is inverted — `home` shows the **Reels** feed and
> `reels` shows the **home** feed. The native port keeps the inversion so
> the deep links keep working.

---

## 2. Components

| Web app | Native |
|---|---|
| `src/components/BottomNav.tsx` | `lib/shared/widgets/bottom_nav.dart` |
| `src/components/NavIcons.tsx` | `lib/shared/icons/ennvo_nav_icons.dart` |
| `src/components/PostItem.tsx` | `lib/features/feed/widgets/post_card.dart` |
| `src/components/ReelItem.tsx` | `lib/features/reels/widgets/reel_card.dart` |
| `src/components/MediaViewerModal.tsx` | `lib/features/reels/widgets/reel_video.dart` |
| `src/components/VerifiedBadge.tsx` | `LucideIcons.badgeCheck` |
| `src/components/Skeletons.tsx` | inline per screen |
| `lucide-react` (145 icons) | `lib/shared/icons/lucide_icons.dart` (generated) |

---

## 3. State

The web app has one flat Zustand store. The native port splits it into
focused Riverpod providers so a rebuild of one slice never touches the
navigation bar.

| Zustand slice | Native provider |
|---|---|
| `currentPage`, `navigationStack` | `navControllerProvider` → `NavController` |
| `currentUser`, `isAuthenticated` | `authControllerProvider` → `AuthController` |
| `appTheme` | `themeModeProvider` (persisted in `AppPrefs`) |
| `navStyle`, `profileStyle`, `reelsStyle` | `navStyleProvider` (persisted) |
| `cachedReels`, `cachedFeed` | `reelsProvider`, `feedProvider` |
| `notificationCount`, `messageCount` | `navBadgesProvider` |

---

## 4. Services

| Web app | Native |
|---|---|
| `src/services/authService.ts` | `lib/core/auth/auth_controller.dart` |
| `src/services/postService.ts` | `lib/data/services/post_service.dart` |
| `src/services/reelsService.ts` | `lib/data/services/reels_service.dart` |
| `src/services/chatService.ts` | `lib/data/services/chat_service.dart` |
| `src/services/storyService.ts` | `lib/data/services/story_service.dart` |
| `src/services/notificationService.ts` | `lib/data/services/notification_service.dart` |
| `src/services/presenceService.ts` | `ChatService` (presence and typing) |
| `src/services/firebase.ts` | `lib/data/services/firebase_service.dart` + `lib/data/firebase/firebase_options.dart` |

---

## 5. Design tokens

`src/index.css` holds the web app's tokens. The native port turns them
into a `ThemeExtension` in `lib/core/theme/tokens.dart`.

| Web app | Native |
|---|---|
| `--app-safe-top` / `--app-safe-bottom` | `MediaQuery.paddingOf(context)` |
| `--ios-spring` | `EnnvoCurves.iosSpring` |
| `--ios-bounce` | `EnnvoCurves.iosBounce` |
| `--act-*` | `ActTokens` |
| `.font-brand` | `EnnvoFonts.brand` (Outfit) |
| `--font-sans` | `EnnvoFonts.ui` (Plus Jakarta Sans) |
| `motion` spring configs | `EnnvoSprings` (same stiffness / damping / mass) |
| `motion` duration configs | `EnnvoDurations` |
| `.bg-white/95` etc. | `EnnvoTokens.surface` |
| `.chat-view-container` (always light) | `EnnvoTokens.chatBackground` |
| `.profile-page-root` (always light) | `EnnvoTokens.profileBackground` |

### Deliberate exceptions

1. The **chat view stays light** in dark mode.
2. The **profile page stays light** in dark mode.
3. The web app disables `:active` press styling — Flutter's ripple is
   switched off in `EnnvoTheme` so the native build matches.
4. The web app has no `prefers-reduced-motion` support; the native port
   adds it.

---

## 6. Performance

The web app's lite mode rule is `deviceMemory <= 2 ||
hardwareConcurrency <= 4`. The native port keeps it and adds the RAM and
core count through the `ennvo/device` method channel.

| Tier | Rule | Reel window | Image cache | Blurs |
|---|---|---|---|---|
| `high` | ≥ 4 GB and > 4 cores | 3 | 96 MB | on |
| `medium` | ≤ 4 GB | 2 | 48 MB | on |
| `low` | ≤ 2 GB or ≤ 4 cores | 1 | 24 MB | off |

---

## 7. Icons

* The eight **bottom navigation** icons are hand-drawn SVGs from
  `NavIcons.tsx`. The markup is copied verbatim.
* The **145 Lucide** icons are generated from the `lucide-react@0.546.0`
  package the web app depends on, keeping the original markup:

  ```bash
  node tools/generate_lucide_icons.js
  ```

  The generator resolves the upstream aliases (`AlertCircle` →
  `circle-alert`, `Grid` → `grid-3x3`, `Edit2` → `pencil`, …) by following
  the re-export chain.

* Both sets render through `flutter_svg`, which keeps every SVG command —
  including the elliptical arcs the Lucide set uses.

---

## 8. Still to port

| Area | Notes |
|---|---|
| Reel comments and share sheets | the portals are opened from the rail buttons |
| Story viewer | the progress bar, the reply sheet and the 24 h expiry |
| Media viewer and cropper | the full screen lightbox and the avatar crop |
| Sticker creator and picker | the sticker studio |
| Reel camera | the in-app camera with the reel filters |
| Calls | WebRTC signalling is written; the UI is not ported yet |
| Push notifications | the FCM service and the gateway are wired; the notification actions are not |
| Offline media | the saved-media index |
| Admin console | the web app keeps it in a separate lazy chunk |

---

## 9. Build

The repository keeps the Dart sources only. The platform folders are
generated by `tooling/setup_android.sh`, which also applies the Ennvo
specific customisations:

* the application id stays `com.erfan.ennvoapp`
* the Google Services configuration is installed
* the native shell with the device-tier channel replaces the template
* the release lint task is disabled — the Kotlin compiler that ships with
  the Flutter template is not compatible with the lint API in AGP 9
* Gradle is tuned so the build fits on a small machine

The three GitHub Actions workflows — CI, the Android APK and the iOS
build — run that script, so a fresh clone builds without any local setup.

### Verified state

| Check | Result |
|---|---|
| `flutter analyze` | no errors |
| `flutter test` | 41 tests pass |
| Android release APK | builds, signed, split per ABI |
| `app-arm64-v8a-release.apk` | 19.7 MB |
| `app-armeabi-v7a-release.apk` | 17.3 MB |
| `app-x86_64-release.apk` | 20.9 MB |
| The brand fonts in the APK | Outfit 600–900, Plus Jakarta Sans 600–800 |

### The bugs the tests caught

They were real, and they would have shipped:

1. **The bottom navigation was mis-positioned.** `EnnvoBottomNav` returned
   a `Positioned`, which is a `ParentDataWidget` — it only works as a direct
   child of a `Stack`. The bar was rendering as an ordinary stack child.
   The bar now returns a plain widget and the shell positions it.
2. **The sign-up form had two email fields.** The sign-up branch and the
   shared branch both rendered an email and a password field.
3. **The auth hero overflowed** on a short screen. The showcase column now
   scales down instead of overflowing.
4. **The sign-in label said "Username or email"** while the web app says
   "Email address".

