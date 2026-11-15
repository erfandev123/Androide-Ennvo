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
| `flutter test` | 46 tests pass |
| Android release APK | builds, signed, split per ABI |
| `app-arm64-v8a-release.apk` | 20.3 MB |
| `app-armeabi-v7a-release.apk` | 17.9 MB |
| `app-x86_64-release.apk` | 21.5 MB |
| The brand fonts in the APK | Outfit 600–900, Plus Jakarta Sans 600–800 |

### The bugs the tests caught

They were real, and they would have shipped:

1. **The bottom navigation was mis-positioned.** `EnnvoBottomNav` returned a
   `Positioned`, which is a `ParentDataWidget` — it only works as a direct
   child of a `Stack`. The bar was rendering as an ordinary stack child.
   The bar now returns a plain widget and the shell positions it.
2. **The sign-up form had two email fields.** The sign-up branch and the
   shared branch both rendered an email and a password field.
3. **The auth hero overflowed** on a short screen. The showcase column now
   scales down instead of overflowing.
4. **The messages list had no width** on a phone. The row that holds the
   list and the chat gave the list an unbounded width, and the `Spacer`
   inside it had nothing to distribute.
5. **A single tap on a navigation item did nothing.** With both `onTap` and
   `onDoubleTap` on the same gesture detector, Flutter waits for the
   double-tap timeout before reporting the tap.

---

## 10. The reels rebuild

The reels screen was rebuilt from scratch against the reels prototype and
the Ennvo web app.

| File | What it holds |
|---|---|
| `lib/features/reels/reels_page.dart` | the feed, the tabs, the progress bar and the preloading |
| `lib/features/reels/widgets/reel_video.dart` | the playback window and the poster cross fade |
| `lib/features/reels/widgets/reel_card.dart` | the layout, the rail, the springs and the activity avatars |
| `lib/features/reels/widgets/reel_preloader.dart` | the connection warming for the upcoming videos |
| `lib/features/reels/widgets/comments_sheet.dart` | the comments and the composer above the keyboard |
| `lib/features/reels/widgets/share_sheet.dart` | the people grid and the action tiles |

### The playback window

| Distance from the active reel | What happens |
|---|---|
| 0 | plays |
| 1 | the controller is created and prepared, then held paused |
| 2 and beyond | the controller is disposed, the decoder is released |

The pause is exact: the position is rewound, so a reel always starts from
the top when it comes back.

### The preloader

Before the user swipes, the first bytes of the next two videos are fetched
with a range request. That resolves DNS, completes the TLS handshake and
warms the CDN edge for those exact URLs, so the player starts from a warm
path instead of a cold one.

### The comment composer

The sheet carries two composers. A collapsed pill sits at the bottom of the
list. Tapping it focuses the field, the keyboard opens and a **separate
composer appears directly above the keyboard** while the list keeps its
place. The sheet grows upward with the keyboard inset, so the list never
jumps.


### The launch screen, the icon and the brand mark

The app opens on the mark of Ennvo, never on a plain colour.

| Piece | Where it comes from |
|---|---|
| `assets/brand/ennvo_logo.png` | the source of truth, copied from the web build's `public/icon-512.png` |
| `tooling/make_launcher_icons.py` | resamples the mark into every Android density — the launcher icon, the adaptive foreground, the themed icon and the launch screen mark |
| `android/.../values-v31/styles.xml` | the Android 12 splash, on the same black window |
| `lib/shared/widgets/brand_splash.dart` | the mark inside the app, used by the launch screen and by the reels placeholder |

The launch window is black in both light and dark mode, because that is the
colour the app itself opens on — a white window would flash before the
first Flutter frame arrives.

---

## 11. The navigation, the chat and the reels fixes

This round fixed the four complaints that came out of the reels rebuild.

### One navigation bar, everywhere

The reels page used to swap the floating pill for a full width solid bar, so
the navigation changed shape the moment the feed opened. The bar is now the
same widget on every page; on the reels feed it only paints itself with the
dark palette — exactly what the web app's `isDarkNav` does.

The floating pill floats `AppSizes.bottomNavGap` above the system gesture
bar, so `AppSizes.bottomNavTop()` is the one number every page uses to keep
its content clear of it: the reels timeline sits on it, the reels caption
sits above it, and the conversation list and the chat composer scroll behind
it.

The bar steps aside while the keyboard is up, so it never floats on top of
the composer.

### The chat stays inside the messages page

The chat used to be pushed as a route over the whole app, which took the
navigation with it. It is now drawn inside the messages page, the way the
wide layout always did it:

* the conversation list and the chat share the page
* the navigation bar stays exactly where it is
* the system back gesture closes the chat first and leaves the page after it
* tapping the inbox in the navigation goes back to the conversation list

The open conversation lives in `openConversationProvider`, so the app shell
and the messages page always agree on what is open.

### The black reels

Two causes, both fixed:

* the player was told that **every** video was an HLS stream. An MP4 handed
  to the HLS extractor never starts, so the reel stayed a black rectangle.
  `ReelVideo.formatHintFor()` only says HLS for an actual `.m3u8`
* the placeholder was a flat black box. It is now the brand mark, so the
  reel page is never an empty screen while the first video is on the wire

### The scroll

The video reported its position on every frame, and every frame rebuilt the
whole feed. The progress now lives in a `ValueNotifier` that only the
timeline listens to, and the spinning disc and the scrolling song title got
their own repaint boundaries — they run forever, and without a boundary they
repainted the whole reel with them.

## 12. The reels, the comment box and the chat

This round rebuilt the reels screen around the reels prototype and fixed
the two sheets and the chat.

### The reel

* the picture of the author sits on the **left**, in a ring with the follow
  badge on it, next to the handle and the follow button
* the action rail sits on the **right**: like, comment, repost, favourite,
  share and the spinning disc of the song at the bottom
* the disc carries the cover of the song when the song was found
* the name of the song travels in a pill under the caption, in the same
  marquee the feed uses
* the page opens with the local reels, and the feed of the last visit is
  kept in `reelsCacheProvider` — the second visit to the page shows the
  *real* reels right away

A reel that is a photo is drawn as a photo: `AppPost.mediaIsImage` and
`AppPost.videoUrl` tell the card what it is holding.

### The comment box

The sheet is the one from the prototype: a night surface, a grab handle, a
centred header with the count, the list of the comments with their replies,
and the composer at the bottom.

The composer is the part that used to disappear. The sheet lifts its lower
edge by the height of the keyboard, so the input is always on screen — and
the sheet never grows past the room that is left.

The comments are live: `CommentService` reads `posts/{postId}/comments`,
folds the replies into their comment, writes new ones, toggles the likes
(`comments/{id}/likes/{userId}`) and removes them. The local comments keep
the sheet from being empty while the network is still thinking.

### The share box

Same surface, same handle, same header. The row of the people on top, the
way to share below it: add to story, copy the link, messenger, repost,
save. Writing a message swaps the options for an input and a send button.

### The chat

The chat is a page of its own again — a full screen route over the app, so
the navigation bar is *not* on top of the conversation. The back gesture
closes the chat first and returns to the list.

`openConversationProvider` is gone with it: the shell does not have to know
what is open, because the route stack does.

### The song in the feed

The feed lost the name of the song: the pill carried an equalizer and
nothing else. The name and the artist now travel in the same marquee the
reel uses, and a post that only knows the id of its song gets the name from
the `songs` collection — the same lookup the web app does.

### Sending a reel to somebody

The share sheet lists the conversations of the user, and a picked reel is
written into every conversation as a `reel` message with the media of the
post and its id — the same message the web app writes from
`SharePortal`. Without a network the sheet falls back to the local list of
people, the way the rest of the app falls back to its local data.

### A reel that could not be loaded

A video that fails to load shows its poster with a small button in the
middle: one tap loads it again. The reel is never a black rectangle that
stays black.
