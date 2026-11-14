# Ennvo — Native Flutter App

The native Android and iOS build of **Ennvo**, the fast social app for
reels, stories, chat and HD calls.

This is a **native Flutter rewrite** of the Ennvo web app
(`https://ennvo.vercel.app`). The visual design is a pixel-faithful port of
the web build; the application logic is written natively rather than wrapped
in a WebView, which is what makes the scrolling, the animations and the
video feed feel right on a low-end phone.

---

## Why Flutter

| | Kotlin | React Native | **Flutter** |
|---|---|---|---|
| Android + iOS from one codebase | needs a second Swift codebase | yes | yes |
| Animation runs on the engine thread | yes | often on the JS thread | **yes** |
| 60/120 fps on a weak GPU | yes | depends on the JS bridge | **yes (Impeller)** |
| Pixel-identical on both platforms | no | no | **yes** |
| Build iOS from Windows | no | yes (EAS) | **yes (macOS runner)** |

Flutter 3.50 runs on the **Impeller** renderer, which pre-compiles its
shaders, so there is no first-frame stutter and no shader compilation jank
while an animation plays.

---

## Design parity

The design system was extracted from the web app's `src/index.css` and its
Tailwind usage, then re-expressed as a Flutter `ThemeExtension`.

| Token | Value | Source |
|---|---|---|
| Brand red | `#FE2C55` | like button, unread badge, send button |
| Accent | `#0EA5E9` | `theme-color` meta, settings CTA |
| Royal blue | `#2563EB` | auth CTA, big-text default |
| Light background | `#FFFFFF` | `body` |
| Dark background | `#000000` | `html.dark` |
| Light body text | `#111827` | `body` |
| Dark body text | `#FFFFFF` | `html.dark` |
| `--ios-spring` | `cubic-bezier(.16, 1, .3, 1)` | activity stacks, sheets |
| `--ios-bounce` | `cubic-bezier(.34, 1.45, .64, 1)` | the activity capsule slider |
| Brand face | **Outfit** 600–900 | `index.html` Google Fonts |
| UI face | **Plus Jakarta Sans** 600–800 | `index.html` Google Fonts |

Two deliberate exceptions from the web app are reproduced exactly:

* the **chat view stays light** in dark mode (`.chat-view-container`)
* the **profile page stays light** (`.profile-page-root`)

The fonts are bundled as assets, so the app renders with the brand faces on
the very first frame and never waits on a network fetch.

### Icons

* The eight **bottom-navigation icons** are hand-drawn SVGs in
  `src/components/NavIcons.tsx`. They are ported verbatim and rendered by a
  `CustomPainter` over cached paths.
* The **145 Lucide icons** the app uses are generated straight out of the
  `lucide-react@0.546.0` package the web app depends on:
  `node tools/generate_lucide_icons.js` regenerates
  `lib/shared/icons/lucide_icons.dart`. The path data, the 24×24 viewBox,
  the round caps and joins and the default stroke width of 2 are identical
  to the web build.

---

## Performance

The web app already had a "lite mode" (`deviceMemory <= 2 ||
hardwareConcurrency <= 4`). The native port keeps that rule and extends it.

| Tier | Trigger | Reel window | Image cache | Blurs |
|---|---|---|---|---|
| `high` | ≥ 4 GB, > 4 cores | 3 | 96 MB | yes |
| `medium` | ≤ 4 GB | 2 | 48 MB | yes |
| `low` | ≤ 2 GB or ≤ 4 cores | 1 | 24 MB | **no** |

Other measures:

* only a small window of reels is mounted, so the number of live video
  decoders stays bounded
* playback is debounced by 120 ms, which stops a burst of page changes from
  thrashing the decoder
* animations run inside `RepaintBoundary` so one reel never repaints the
  screen
* `Material`'s ripple and hover feedback are disabled, matching the web
  app's deliberate `:active { scale: 1 !important }` rule
* `withOpacity` is avoided in favour of `withValues(alpha: …)`
* release builds use `--split-per-abi`, `--obfuscate` and split debug info

---

## Architecture

```
lib/
  main.dart                 bootstrap: theme → device tier → caches → run
  app.dart                  MaterialApp, theme wiring, text-scale clamp
  core/
    auth/                   AuthController (sign in / sign up / reset)
    nav/                    page types + the navigation stack
    perf/                   device tier, lite mode, sustained performance
    providers.dart          Riverpod providers
    storage/                SharedPreferences wrapper (web app key names)
    theme/                  tokens, typography, motion, app theme
  data/
    firebase/               Firebase options (reuses the Ennvo project)
    models/                 AppUser, AppPost
    services/               Firebase, reels
  features/
    auth/  feed/  reels/  messages/  notifications/
    create/  profile/  search/  settings/  edit_profile/
  shared/
    icons/                  brand marks, custom nav icons, generated Lucide
    widgets/                bottom nav, buttons, inputs, placeholders
```

### Navigation

The web app has no router — it keeps a `currentPage` plus a
`navigationStack` in a Zustand store and toggles page visibility. The
native port mirrors that exactly:

* `pushPage` — `home` resets the stack; pushing the open page is a no-op
* `backPage` — pops one entry, never lands on the same page twice
* `popPage` — `edit-profile` → `profile`, anything else → `home`
* visited pages stay mounted (`Offstage`) so their state survives a tab
  switch; `create`, `edit-profile`, `settings` and `admin` unmount

---

## Firebase

The app reuses the **existing Ennvo Firebase project**, so authentication,
Firestore, Realtime Database, Storage and FCM work with no new console
setup. The Android client configuration comes from the Capacitor project's
`android/app/google-services.json`.

Push notifications go through the same Vercel gateway the web app uses
(`https://ennvo.vercel.app/api/push`) with a data-only FCM payload.

---

## Building

Nothing is compiled on the developer's machine. GitHub Actions does it.

| Workflow | Trigger | Output |
|---|---|---|
| `.github/workflows/ci.yml` | every push and pull request | analysis + widget tests |
| `.github/workflows/android-apk.yml` | push to `main`, a tag, or manual | signed, split-per-ABI APKs as a run artifact |
| `.github/workflows/ios-build.yml` | push to `main`, a tag, or manual | unsigned `.app` bundle for later signing |

Signing the APK needs four repository secrets:

| Secret | Meaning |
|---|---|
| `KEYSTORE_BASE64` | the upload keystore, base64 encoded |
| `KEYSTORE_PASSWORD` | keystore password |
| `KEY_ALIAS` | key alias |
| `KEY_PASSWORD` | key password |

Without them the workflow still runs and produces a debug-key APK, which
installs on any device.

To sign a local build with your own key:

```bash
# 1. put the keystore at android/app/upload-keystore.jks
# 2. create android/key.properties
#      storeFile=upload-keystore.jks
#      storePassword=...
#      keyAlias=...
#      keyPassword=...
# 3. switch the release build over to it
node tooling/enable_release_signing.js
```

A tagged build (`git push origin v1.0.0`) also publishes a GitHub release
with the three ABI APKs.

---

## Local development

```bash
flutter pub get
flutter run                 # on a connected device or emulator
flutter analyze
flutter test
```

The project targets **Flutter 3.50.0 / Dart 3.14**, `minSdk 24`,
`compileSdk 36`, AGP 9.1.0, Gradle 9.3.1 and Java 17.

---

## Visual verification

The native screens are rendered by a golden test, so the build can be
compared against the production web build pixel by pixel.

```bash
flutter test --update-goldens
```

The renders land in `test/goldens/`. The comparison is skipped on CI — the
goldens are rasterised on Windows and the runners rasterise differently —
but the rendering still runs there, so a layout regression is still caught.

The font assets are loaded into the test, so the goldens show the real
Outfit and Plus Jakarta Sans typography rather than the test placeholder
font.

---

## The reels screen

The home screen is a full screen vertical video feed. It follows the reels
prototype and the Ennvo web app:

| Behaviour | Detail |
|---|---|
| Playback window | the active reel plays, the neighbour is prepared and paused, everything else is released — at most two live decoders |
| Double tap | a heart bursts out of the tap point, rises 64px, scales 0.4 → 1.1 and fades over 900ms; the reel is liked |
| Single tap | plays or pauses, after a 280ms window so the two gestures never fight |
| Progress bar | tracks the active reel along the bottom edge |
| Tabs | "Following" and "For you" with a sliding underline |
| Action rail | like, comment, favourite, share and the spinning vinyl record |
| Author block | the avatar with a gradient ring, the morphing follow button, the name, the verified mark, the role, the caption with a "See more" toggle, the tags and the scrolling song title |
| Comments | a bottom sheet with nested replies, expandable reply threads, a two tap delete, an emoji tray and a composer |
| Share | a bottom sheet with a multi-select people grid, the quick actions and the privacy switch |
| Seen tracking | a reel counts as seen after 2500ms; the list is capped at 250 and feeds the ranking |

## The messages screen

| Behaviour | Detail |
|---|---|
| Conversation list | the stories row, the conversations with their unread badge, the pinned and muted marks |
| Grouping | two messages belong to the same group when the sender matches and they are less than 60 seconds apart |
| Tail corners | the last bubble of a group squares its tail to 6px, the base radius is 24px |
| Bubble types | text, emoji only, image, video, album, reel, sticker, voice note, call and system |
| Reply preview | inside the bubble with a 2px accent border |
| Swipe to reply | 0.44 damping, 56px of travel, commits at 24px |
| Read receipt | a fixed 15px slot below the list so the chat never shifts |
| Composer | a floating pill that lifts with the keyboard, an attach menu that rotates 45°, a growing text field, and a mic that swaps into the send button |
| Wallpaper | the chat stays light even in dark mode, exactly like the web app |

## Porting status

| Screen | Web source | State |
|---|---|---|
| Design system, theme, motion, icons | `src/index.css` | **done** |
| Navigation shell and bottom navigation | `App.tsx`, `BottomNav.tsx` | **done** |
| Auth — sign in, sign up, password reset | `pages/Auth.tsx` | **done** |
| Reels — the vertical video feed | `pages/Reels.tsx`, `components/ReelItem.tsx` | **done** |
| Feed — stories strip and posts | `pages/Home.tsx`, `components/PostItem.tsx` | **done** |
| Messages — conversations and chat bubbles | `pages/Messages.tsx` | **done** |
| Activity — the card stack accordion | `pages/Notifications.tsx` | **done** |
| Profile — banner, stats, highlights, tabs | `pages/Profile.tsx` | **done** |
| Create — the composer and the big text backgrounds | `pages/Create.tsx` | **done** |
| Settings — the two column layout | `pages/Settings.tsx` | **done** |
| Edit profile | `pages/EditProfile.tsx` | **done** |
| Search | `pages/SearchPage.tsx` | **done** |

Every screen is ported from the corresponding file in the web app's
`src/pages/` directory, with the same tokens, the same copy and the same
interaction rules. `docs/PORTING.md` records the file by file mapping and
lists what is still to come — the story viewer, the media cropper, the
sticker studio, the reel camera and the call UI.

---

## Tooling

| Tool | What it does |
|---|---|
| `tools/generate_lucide_icons.js` | regenerates the 145 Lucide icons from the `lucide-react` package the web app uses |
| `tooling/setup_android.sh` | generates the platform projects and applies the Android customisations — used by the CI |
| `tooling/patch_gradle.js` | the application id, the Google Services plugin and the release lint task |
| `tooling/enable_release_signing.js` | switches the release build over to an upload key |
| `tooling/MainActivity.kt` | the native shell: the device tier channel and edge to edge drawing |
| `tooling/google-services.json` | the public Firebase client configuration |

