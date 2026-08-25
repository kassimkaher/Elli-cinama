# Real Google TV / Projector — Owner QA Checklist

Short checklist to validate the Release APK on a physical Google TV / Android TV /
Google TV projector. (Emulator QA is already CLOSED.)

## Install
1. Enable **Developer options** on the TV (Settings → System → About → click Build 7×) and
   **USB/ADB debugging** (or use a sideload app like "Downloader" / "Send files to TV").
2. Install the Release APK:
   - `adb connect <tv-ip>:5555` then `adb install -r ABK-Player.apk`, **or**
   - copy the APK to the TV and open it with a file manager, **or**
   - `make apk` → `build/app/outputs/flutter-apk/app-release.apk`.

## Launcher & banner
- [ ] App appears on the TV **home/launcher** row (Leanback).
- [ ] The **banner** shows the ABK logo + wordmark (not a stretched icon).
- [ ] App launches from the launcher with the **remote** (no touch).

## Remote-only navigation (no touch, no mouse)
- [ ] D-pad moves focus everywhere; the **focused item is obvious** (ring + scale).
- [ ] SELECT/OK activates; BACK goes back; focus never disappears or gets stuck.
- [ ] Sidebar: Home · Live · Movies · Series · Favorites · Settings · Search.

## Content
- [ ] **Home** rails browse smoothly; artwork readable from the couch.
- [ ] **Live**: pick category → channel → plays; **UP/DOWN switch channel**; EPG Now/Next if present; BACK returns.
- [ ] **Movies**: browse grid → detail → **Play**; seek with LEFT/RIGHT; pause/resume; BACK.
- [ ] **Series**: season → episode → play → **next episode**; Continue Watching resumes.
- [ ] **Search**: field focuses, on-screen keyboard opens, results are focusable (AR + EN).
- [ ] **Settings/dialogs**: parental PIN, logout, theme/language — all remote-operable; BACK dismisses.

## Player (remote)
- [ ] OK reveals controls; OK again play/pause; MEDIA play/pause works.
- [ ] LEFT/RIGHT seek ∓10 s (VOD); UP/DOWN switch channel (Live) / episode.
- [ ] BACK exits fullscreen → hides controls → leaves; **audio stops on leave** (no leak).
- [ ] Loading / buffering / switching / error states are visible.

## Quality
- [ ] Text/cards comfortable from ~3 m; nothing hidden by TV **overscan**.
- [ ] Smooth on the box's hardware (no stutter scrolling long rows).
- [ ] Arabic RTL and English LTR both navigate logically.

## Report back
Note the **TV model + Android/Google TV version + resolution** and any focus/scroll/playback
issue so it can be reproduced.
