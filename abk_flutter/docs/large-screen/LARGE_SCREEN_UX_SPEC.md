# Large-Screen UX Spec — TV / Windows / macOS

One adaptive presentation system. Input behaviour is layered on top per platform;
the screen hierarchy, breakpoints, and components are shared.

```
Mobile Android / iOS   -> compact touch UX (bottom bar)
TV / Windows / macOS   -> large-screen UX (sidebar, wider content, desktop/TV nav)
   TV                  -> D-pad / remote focus behaviour
   Windows / macOS     -> mouse + keyboard + window resize
```

`AbkBreakpoints` drives everything: `WidthClass` (compact/medium/expanded/tv),
`isTv` (set at bootstrap from Android leanback/television features or
`--dart-define=ABK_FORCE_TV`), `isDesktopClass`, `usesSidebar`, `minHitTarget`
(64 on TV). Nothing below hard-codes a device; values key off `isTv` /
`WidthClass` / the pane's own `LayoutBuilder` width.

## Shared TV focus treatment (`AbkFocusable`)

The single focus contract for every focusable control. On TV a focused element is
**unmistakable even on top of a same-colour (gold) primary button**:

- **scale 1.06** (motion is the strongest couch-distance cue),
- **3 dp white outline** (contrasts on dark cards AND gold buttons),
- **gold glow halo** (`focusRing` @55%, blur 20) that spills onto the dark
  surround, plus a soft dark shadow,
- fast animation (`AbkMotion.focusMove`).

Off-TV keeps the on-brand 2 dp gold ring. Focused controls inside a scroll view
auto-scroll into view (`Scrollable.ensureVisible`, alignment 0.5) so no focused
control is ever off-screen (scroll-to-focus).

`FocusManager.highlightStrategy` is forced to `alwaysTraditional` at bootstrap on
TV, so focus rings paint on the **first frame** — not only after the first key
press.

## Login (height-aware)

Adapts to BOTH width and height, not width alone.

- `tallEnough = maxHeight >= 620`. The cinematic **branding split is used only
  when large-screen AND tallEnough**. On a wide-but-short viewport (TV 960×540)
  the branding panel is dropped and the form goes single-column, centred, with a
  small inline logo.
- `compact = !tallEnough || isTv`: logo 40, no subtitle, field vertical padding
  10 (from 14), tighter gaps, form max-width 440.
- Username **autofocus** → visible initial focus on frame 1. Focus order:
  Username → Password → Login → QA card. The QA card returns focus to Login after
  filling.
- Fallback: `SingleChildScrollView` + `minHeight` so nothing clips below ~480
  logical height; D-pad focus auto-reveals each control. Scrolling is the
  fallback, never the normal path.

## Home (TV rebalance)

Rail heights were desktop-sized and starved the TV posters; they are now
TV-aware:

| Rail | width (TV) | height (TV) |
|---|---|---|
| Movies / Series posters | 228 (`posterWidth`) | 420 (was 230) |
| Continue watching | 340 (was 260) | 250 (was 180) |
| Favourite channels | 132 (was 92) | 132 (was 92) |
| Live categories | 230 (was 170) | 160 (was 110) |

- **Hero** capped to ~52% of viewport height on TV (was full-width 16:9), so the
  first rail peeks below and invites D-pad-down; backdrop `BoxFit.cover`.
- **PosterCard** on TV: title pinned to 1 line (no reflow), bold + `textPrimary`
  when focused, enlarged play chip; the internal artwork scale is dropped on TV
  so it doesn't stack with the outer 1.06 ring.
- Initial focus on the shell = the **selected sidebar item** (autofocus on TV) →
  visible focus on the first frame of every tab.

## Live (large-screen, embedded real player)

Three-pane, responsive to the pane's own width `W`; the two lists compress, the
preview never does:

```
categories  = W < 1000 ? 184 : 220
channels    = clamp(W*0.30, 256, 360)
preview     = Expanded (always the widest pane, ≥ ~42% of W)
```

**Embedded preview is the REAL player** (not a placeholder):

- Selecting a channel loads its actual stream into the shared
  `playbackServiceProvider` and plays it in the embedded 16:9 surface.
- Channel switching swaps the source **in place** (debounced 320 ms for
  surfing), with a visible loading state — no route push, no black teardown.
- **Fullscreen expands the SAME session**: the preview widget carries a
  `GlobalKey` and is re-parented between the embedded slot and a full-bleed
  overlay, so its State (and decode session) is moved, never rebuilt — no reload,
  no audio gap. Exit returns to the embedded box still playing. BACK/Escape exits
  fullscreen first.
- No background audio: the preview stops when the Live tab is not the visible tab
  and reloads the selected channel on return; it pauses on app background.

**Five distinct channel-row states** (independent layers, so they coexist):

| State | background | leading indicator | left bar / text |
|---|---|---|---|
| focused | surfaceElevated | — | white outline + gold glow + scale |
| selected | surfaceStrong | logo | gold left bar |
| playing | accent @10% | equalizer glyph (accent) | gold bar, name in accent |
| loading | — | spinner (accent) | "· Loading…" |
| error | error @8% | error glyph | "· Unavailable" in error |

## Player (VOD + Live)

Real focusable control surface on TV (not shortcut-only). Three interaction
modes: PLAYER_VIEW_MODE (OK reveals/enters controls; BACK leaves), 
CONTROLS_FOCUSED_MODE (D-pad moves between controls; OK activates the focused
one; BACK hides), TIMELINE_FOCUSED_MODE (LEFT/RIGHT scrub, debounced; UP/DOWN
leave; OK/BACK return to controls). Controls that are unavailable are disabled
and skipped by focus traversal; hidden controls are `ExcludeFocus`-d so the
remote can never focus an invisible button. Deterministic BACK hierarchy:
fullscreen → timeline sub-mode → hide controls → leave. Touch (double-tap ±10 s,
drag scrub) and desktop mouse/keyboard behaviour are unchanged off-TV.

## First frame (no black / no flicker)

`main()` now runs **runApp → bootstrap** (previously it awaited bootstrap before
runApp, leaving a black window for the whole async init — the length varied by
device/network, which is why some TVs, e.g. TCL, showed a long black/flicker
start while the projector did not). A branded splash paints on frame 1 and holds
until the `ProviderContainer` is ready; no arbitrary delay. The native Android
launch window is **dark in both day and night** configs (was `Theme.Light` +
white in day mode → a white flash on devices selecting day resources). Together:
dark native window → branded Flutter splash → shell/login, focus visible, on
every device.

## Windows / macOS

Same large-screen presentation (sidebar, adaptive widths, `LayoutBuilder`-driven
Live/Home), with mouse + keyboard + window resize. All widths use relative/clamp
constraints so the layout survives resizing (small → maximised → low-height
wide). macOS is validated directly; Windows shares the identical
`isDesktopClass` layout path and is covered by parity + code review pending a
Windows host.
