# Ennvo — native app: what is done and what is left

This is the list of everything the native port needs, in the order the work
makes sense. The **Done** sections are shipped; the **Open** sections are
what is left.

Last updated after the "reels, splash, camera, uploads" round.

---

## 1. The app shell and the navigation — done

- [x] The five bottom destinations: Home (reels), Feed, `+`, Inbox, Profile.
- [x] The navigation bar has two skins: the floating glass pill and the
      classic bar. The choice is persisted.
- [x] The bar of the reels feed is black, like the screen behind it.
- [x] The pages stay mounted, so going back restores the scroll position.
- [x] The messages page has **the same** navigation bar as the feed.
- [x] A conversation opens as **its own page** (a route over the app), so
      the bar is never on top of the chat.
- [x] The page change is instant: the pages are already built, and the
      highlight of the bar moves in 280 ms.
- [x] The keyboard never pushes the screen up (`resizeToAvoidBottomInset`
      is off), so a composer floats above it instead.

## 2. The splash and the brand — done

- [x] The app opens on the **Ennvo purple** with the logo.
- [x] The logo is seen **exactly once**: the Android window carries the
      purple and no logo at all, and the Flutter splash draws the mark.
- [x] Android 12+ gets an empty system icon for the same reason.
- [x] The mark is a PNG with a **black background and a white logo**.
- [x] The app icon is generated from the same master: the white mark on the
      Ennvo purple, for the legacy icon, the adaptive icon, the themed
      icon and every iOS size.
- [x] The app name is `Ennvo` on Android and on iOS.
- [x] The **welcome card on the reels feed is gone**. The app opens on the
      feed.

## 3. The reels feed — done

- [x] The vertical snap feed with a small window of live decoders.
- [x] The video keeps **its own shape**: 9:16, 16:9, 1:1 and anything else
      are shown at their own size, centred. Nothing is stretched, nothing is
      cropped away, and the feed is not a full screen video any more.
- [x] The poster is shown until the first frame is ready, then the video
      fades in over it.
- [x] A reel that leaves the window releases its decoder.
- [x] The **timeline can be dragged**: tap or drag it and the reel follows.
- [x] The timeline and the sound button **only show while the reel is
      stopped**. A running reel is nothing but the picture.
- [x] The stopped icon appears **at once** — there is no fade, because a
      fade is what made it feel late.
- [x] The sound button really mutes the video, and the song is the real
      one from the `songs` collection.
- [x] Holding the **right side** of the picture runs the reel at **2x**,
      with a badge, and it goes back to 1x on release.
- [x] The name is shown **once**, bigger, and it renders fast (no shadow
      per letter).
- [x] A friend who likes or reposts sends their picture **above the name**,
      with a light blur, the way Instagram shows an activity.
- [x] The like, comment, repost, favourite and share buttons **do not move
      when they are pressed**. Only the colour of the icon changes.
- [x] The feed pages forward with a cursor, so it never runs out.

## 4. The comments — done

- [x] The sheet follows the theme: white in the light mode, near black in
      the dark one.
- [x] The input row: the **picture of the user on the left**, the sticker,
      the photo and the voice buttons on the right.
- [x] A tap on the input opens the keyboard and a **separate input box
      appears right above it**. The sheet does not move and the screen does
      not go up.
- [x] The send button sits on the right of the box and lights up as soon as
      there is something to send. It is there when the keyboard closes too.
- [x] Every comment has a **heart on its right**.
- [x] A comment can be answered, and a sticker, a photo or a **voice note**
      can be sent.
- [x] The voice note is really recorded (`record`), and it is uploaded.

## 5. The share sheet — done

- [x] The sheet follows the theme: white in the light mode, near black in
      the dark one.
- [x] The people sit in a row on top and a tap picks them.
- [x] The **send button appears** as soon as somebody is picked.
- [x] The ways to share: story, link, messenger, repost, save, download,
      more, report and delete.
- [x] The **settings of the reel**: who can see it, commenting, remixes,
      hidden likes and saving to the device.

## 6. The camera and the uploads — done

- [x] The `+` of the navigation bar opens the **upload camera**: the
      Instagram screen with the modes (POST, REEL, STORY), the shutter, the
      gallery, the flash, the timer, the flip, the music and the settings.
- [x] The picked media goes to the composer.
- [x] The composer takes the caption, the big-text backgrounds, the tools
      and the advanced settings.
- [x] **Cloudflare R2** carries the uploads: a signed `PUT` with the AWS
      Signature Version 4, the region `auto`.
- [x] The credentials are **not** in the source. They are secrets of the
      repository and they are compiled into the build with `--dart-define`.
- [x] The post is written to Firestore with the document the web app
      writes.

## 7. Still open

### 7.1 The account and the screens
- [x] The auth page of the web app: the blue wave header, the rounded
      inputs, all five screens (Log In, Sign Up chooser, Sign Up form,
      Reset Pass, Google setup). The account that signs in is the one the
      chat, the profile, the saved posts and the reels run as.
- [x] The share sheet: all friends from `users/{me}/following`, a search
      box, and a Settings page that only the owner can open. The privacy
      change is written to `posts/{id}`.
- [x] The comment input has no rounded box: plain text on the surface.
- [x] A long press on a comment opens a menu with reply, copy, report and
      delete. Delete is shown for the comment's author or the owner of the
      reel or post.
- [x] Voice notes really play, photos open full screen and GIF stickers
      are live.
- [x] The Messages page has the Activity option, which opens the same
      Activity page the web app mounts from the inbox.
- [x] Floating friend PFPs come from `posts/{id}/likes` and `reposts`, and
      only people the viewer follows are shown, with the red heart or the
      green repost badge.
- [x] The reels feed learns: liked reels and the reels of liked authors
      come forward.
- [x] The profile tabs are real: Posts, Reels, Saved (from
      `users/{uid}/favorites`) and Private.
- [ ] Google and Facebook sign-in buttons are drawn but not wired; the
      Firebase providers need the native OAuth setup.
- [ ] The profile "Edit profile" and the chat read receipts are next.

### 7.2 The camera and the edit
- [x] A **live** camera preview, on CameraX.
- [x] A shutter that takes a photo on a tap and records a video on a hold.
- [x] The flash, the timer, the flip, the gallery, the sound and the modes.
- [x] The edit screen: trim / crop, sound, text, stickers, filters, cover and
      mute.
- [x] The TikTok publish page: the cover, the title, the tags, the privacy,
      the comments, the remix and a real upload bar.
- [ ] The trim and the filters change the preview today; baking them into
      the exported video needs an on-device encoder (FFmpeg), which would
      add about 50 MB to the APK.
- [ ] The music picker offers three demo sounds. A real `songs` picker is
      the next step.

### 7.2 The uploads
- [ ] The progress of an upload is only on the post and the reel, not on
      the voice note or on the picture of a comment.
- [ ] The uploads of a voice note and of a picture of a comment fall back
      to "the file is not there" when the bucket is not configured.
- [ ] No **retry** of a failed upload.
- [ ] The files are not deleted from the cache after they are sent.

### 7.3 The reels
- [x] **Real videos** from the web app's Firebase project and the R2
      bucket. The Firestore query is the same as the web app's: a filter on
      `type` with the sort done in memory, so no composite index is needed.
- [x] The exact Ionicons of the web build on the rail and on the actions.
- [ ] The song of a reel is looked up, not chosen. There is no music
      picker yet.
- [ ] The reel that is playing is not written to the history of the user.

### 7.4 The comments and the chat
- [ ] The **voice notes are not played** yet. They are recorded and sent,
      but there is no player.
- [ ] A picture of a comment is sent, but it is not opened on a tap.
- [ ] The chat of the messages page has no **read receipt** and no typing
      indicator that comes from the server.
- [ ] The stickers of the chat are the demo ones.

### 7.5 The product
- [ ] The **stories** of the web app are not ported yet.
- [ ] The **live calls** are not ported yet.
- [ ] The **admin** page is a placeholder.
- [ ] The notifications page is a port of the web app, but it does not
      read the `notifications` collection of Firestore yet.

### 7.6 The build
- [ ] The APK is signed with the **debug key**. Run
      `node tooling/enable_release_signing.js` and put the keystore in the
      secrets of the repository to sign it for real.
- [ ] The **iOS build** runs on the runners, but there is no TestFlight
      upload and no App Store profile.
- [ ] There is no **Play Store** listing and no bundle of the app.

### 7.7 The quality
- [ ] The goldens are compared on a machine, not on the runners, because
      the rasterising is different there. The CI only renders them.
- [ ] There is no **integration test** that runs the whole app.
- [ ] The bundle is not split into a **dynamic feature** for the camera.
- [ ] The `lite mode` of the web app is on the device tier, but the video
      quality does not follow it yet.

---

## How the build works

Nothing is built on the developer's machine. The three workflows in
`.github/workflows` do it:

| Workflow | What it does |
| --- | --- |
| `ci.yml` | `flutter analyze` and `flutter test` on every push |
| `android-apk.yml` | the release APK, one per ABI, as an artifact |
| `ios-build.yml` | the iOS build, without a signature |

The platform folders are in the repository, and `tooling/setup_android.sh`
makes them match the Flutter SDK that builds them: the application id, the
Google Services file, the native shell and the Gradle tuning.

## The secrets of the repository

| Name | What it is |
| --- | --- |
| `CLOUDFLARE_ACCOUNT_ID` | the Cloudflare account of the bucket |
| `CLOUDFLARE_R2_ACCESS_KEY_ID` | the key of the bucket |
| `CLOUDFLARE_R2_SECRET_ACCESS_KEY` | the secret of the key |
| `CLOUDFLARE_R2_BUCKET_NAME` | the bucket the files go to |
| `CLOUDFLARE_R2_PUBLIC_DOMAIN` | the address the files are served from |
| `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` | the signature of the release build |

Without the Cloudflare secrets the app still builds and runs: the uploads
report that they are not configured.

## The rules of the port

- The **web app is the source of truth**. The tokens, the icons and the
  motion come from `src/index.css`, `lucide-react` and the `motion`
  configuration.
- **Nothing is built locally.** The laptop only writes code.
- The **Dart sources** are the product. The platform folders follow the
  Flutter SDK.
- A screen that is not used yet is **not** a placeholder with a spinner: it
  is the real screen, with the parts that are not ported yet listed in this
  file.
