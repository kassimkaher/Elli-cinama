# Player UX — Interaction Contract

The shared player (`features/player/player_screen.dart`) behaves as a modern cinema /
streaming player across touch, mouse, and keyboard. All controls sit above a gesture layer
so buttons respond instantly (no double-tap delay).

## VOD (movie / episode)

| Control | Behaviour |
|---|---|
| Play / Pause | centre button + bottom bar; Space (keyboard) |
| Current time / duration | shown in the bottom bar; updates live |
| Progress bar | draggable thumb; **continuous scrubbing** — dragging updates a local target only (no decoder work); a **single real seek fires on release** |
| Scrub time preview | while dragging, the time readout shows the **target** position |
| −10 s / +10 s | on-screen buttons (centre transport) + `←` / `→` keys |
| Double-tap seek | **double-tap left → −10 s, double-tap right → +10 s**, with a brief `∓10s` badge; **disabled for non-seekable live** |
| Fullscreen | button + `F`; `Esc` exits fullscreen then the player |
| Next / Previous episode | bottom bar (when a playlist); debounced source switch |
| Back / Close | top-left + `Esc` |
| Auto-hide controls | hide after 4 s of no interaction; **tap to reveal**; stay visible while scrubbing |
| Loading / buffering | spinner with "Loading…/Preparing…" |
| Error / retry | error card with **Retry** and **Back** |
| Resume | VOD resumes from the saved offset; progress persisted every 5 s and on leave |

## Live (channel)

| Control | Behaviour |
|---|---|
| Channel identity | channel name in the top bar; LIVE badge |
| EPG Now / Next | shown when data exists (`Now: …`, `› Next`) — hidden when empty |
| Previous / Next channel | up / down buttons; `↑` / `↓` keys; **each actually switches the media source** |
| Switching state | immediate `switchingSource` — spinner + target channel name; then playing or error/retry |
| Channel surfing | rapid up/down **debounces** into one load (lands on the final channel) |
| Buffering / retry | visible; never a silent/stuck screen |
| Fullscreen / Back | as VOD |
| Double-tap seek | **disabled** (live is not seekable) |

## Input support
- **Touch:** tap = toggle controls; double-tap = ±10 s (VOD); drag = scrub.
- **Mouse:** hover reveals controls; click buttons; drag the seek thumb.
- **Keyboard:** Space (play/pause), `F` (fullscreen), `Esc` (exit), `←`/`→` (∓10 s),
  `↑`/`↓` (prev/next channel or episode).

## State model (always one visible state)
`preparing → buffering → playing ⇄ paused`, `switchingSource`, `error` (with retry),
and `released` on leave. No silent or stuck state is possible.

## Lifecycle guarantees
- Leaving the player releases the controller → **no lingering audio, no orphan decoder**.
- Source switch = release current → prepare next → visible loading → playing or error.
- Background/foreground pauses/keeps state; disposed controllers are never reused.
