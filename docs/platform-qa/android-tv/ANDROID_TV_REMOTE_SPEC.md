# Android TV / Google TV — Remote Interaction Contract

Standard TV remote keys map to Flutter logical keys: D-pad → arrow keys, D-pad centre →
`select`, BACK → system back, plus media keys.

## Global navigation (outside the player)
| Remote | Action |
|---|---|
| UP / DOWN / LEFT / RIGHT | move focus (directional traversal) — sidebar, rows, grids, dialogs |
| SELECT / OK (D-pad centre) | activate the focused item (card, nav item, button) |
| BACK | close overlay/dialog → go back one screen; from Home, system exits |
| Focus visual | ring + scale on the focused element (always visible) |

Focus is retained across traversal and restored on back navigation (`IndexedStack` keeps
each section's state).

## Player — VOD (movie / episode)
| Remote | Action |
|---|---|
| OK / SELECT | reveal controls; when shown, **play/pause** |
| MEDIA PLAY/PAUSE | play/pause |
| LEFT | seek **−10 s** |
| RIGHT | seek **+10 s** |
| UP / DOWN (playlist) | previous / next episode |
| MEDIA PREV / NEXT | previous / next episode |
| BACK | exit fullscreen → hide controls → leave player |

## Player — Live (channel)
| Remote | Action |
|---|---|
| OK / SELECT | reveal controls / info (EPG Now-Next when available) |
| UP | previous channel |
| DOWN | next channel |
| MEDIA PREV / NEXT | previous / next channel |
| LEFT / RIGHT | (no seek — live is not seekable) |
| BACK | hide controls → leave; playback stops (no lingering audio) |

Channel switching is **unambiguous** (dedicated UP/DOWN + on-screen prev/next buttons) and
debounced so rapid presses surf to the final channel with one load. Loading / buffering /
switching / error states stay visible even when controls auto-hide.

## Preserved on other inputs (additive, non-destructive)
- **Touch (mobile):** tap toggles controls; double-tap left/right = ∓10 s; drag = scrub.
- **Mouse (desktop):** hover reveals controls; click; drag the seek thumb.
- **Keyboard (desktop):** Space (play/pause), F (fullscreen), Esc (exit), ←/→ (∓10 s),
  ↑/↓ (prev/next).

## Verified
`test/widget/tv_navigation_test.dart` — `AbkFocusable` activates on SELECT and ENTER and
shows a focus ring; the TV shell uses the sidebar (not the bottom bar) and retains focus
during D-pad traversal.
