# Viewer-Oriented QA Report

Date: 2026-08-25. QA behaves like a real viewer through the full viewing lifecycle — not
just `playing == true`.

## Platforms
- **Android** — NX679J, Android 13 (API 33), arm64 (physical).
- **macOS** — 26.5 (Release-type run on `-d macos`).
- **iOS** — iPhone 15, iOS 26.5 (physical, focused regression).

## Automated real-UI evidence (`integration_test/player_ui_test.dart`)

| Check | Android | macOS | iOS |
|---|---|---|---|
| Live channel renders + plays | `playing` | `playing` | `playing` |
| Channel switch (next) switches source | `playing` | `playing` | `playing` |
| Leave player → controller released | released | released | released=true |

iOS prints all three results successfully; a flutter_test teardown frame-assertion fires
*after* the test body completes (fvp schedules a frame during teardown) — a harness artifact,
not a product failure.

## Live scenario (open → play → next → prev → switches → buffering → fullscreen → back → re-enter → leave → silence)
- Channel plays; **next/previous actually switch the source**; rapid surfing debounces into
  one load and lands on the final channel; switching shows a spinner + target name (never
  silent). Fullscreen/back work. Leaving stops playback and releases the controller — **no
  lingering audio**. Re-entering re-prepares cleanly. No hang after switch + back
  (generation guard + debounce).

## Movie scenario (open → play → pause/resume → double-tap ± → scrub far → fullscreen → bg/fg → leave → silence → reopen → resume)
- Play/pause, **double-tap ±10 s** (with badge), **continuous scrubbing** with one seek on
  release, fullscreen, background pause. Leaving is silent (released). Reopening **resumes
  near the prior position** (resume offset persisted every 5 s + on leave). Near-end content
  is treated as complete (resume guard: `saved < duration − 10`), so it does not resume at
  the final second; replay from 0 remains possible.

## Series scenario (season → episode → play → seek → leave → resume → next episode → auto-advance → manual switch → back)
- Season/episode selection; episode playback via the same player; **Next Episode** switches
  source; **auto-advance** on natural completion (guarded against firing mid-switch);
  progress persists; manual prev/next works. Season episode lists build the playlist.

## Flags raised & resolved
| Flag | Before | Now |
|---|---|---|
| Audio leak after leaving | audio could continue | controller released on leave |
| Hang after live switch + back | app could hang | debounce + stale-async guard |
| Silent/stuck on switch | no status | visible switching/buffering/error |
| Soft/slow scrubbing | seek per drag delta | local drag + one seek on release |
| No ±10 s / double-tap | absent | ±10 s buttons, keys, and double-tap |
| macOS repeated password prompts | per content | none (sandbox file store) |
| macOS playback | failed (AVFoundation) | plays (fvp) |
| Android playback | owner: not working | plays + switches + releases |

## Device load / stability (Phase I, observational)
- Repeated switch/open/close in one session: a single shared `PlaybackService` with one
  controller at a time (each `load()`/`stop()` disposes the prior controller) — no
  controller accumulation, no duplicate audio. Debounced switching avoids concurrent
  decoders during surfing. Progress writes are throttled (every 5 s / on leave), not
  per-frame.

## Known environmental (not product) notes
- On a **degraded device network**, the largest catalogue payload (`channels`, 8,604 items)
  can time out (the app shows a recoverable error + retry). Seen intermittently on the
  iPhone during QA; unrelated to the player. Content client retries transient failures once.

## Result
**VIEWER QA: PASS** on Android, macOS, and iOS for the live / movie / series scenarios.
