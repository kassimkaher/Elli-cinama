# ABK Flutter — Phase 3 Implementation Plan (executed)

Full product UI built on the existing Phase 1/1B foundation (backend, data,
domain, player abstraction unchanged), driven by the Claude Design master
`ABK_CINEMA_MASTER_DESIGN.dc.html`. macOS-first QA.

## Design import (Phase A)

Imported via the Claude Design MCP (`DesignSync`), project
`fc6ccee1-… "ABK Cinema mobile app design"`. Read the master
`ABK_CINEMA_MASTER_DESIGN.dc.html` (258 KB) in full and extracted the token,
theme, typography, motion, component and shell specs plus the five exemplar
screens it contains: **00–08** (foundation/tokens/theme/type/motion/components/
shell) and screens **10 Launch, 11 Login, 20 Home, 30 Live Browser, 31 Live
Player**.

**Reconciliation — the master file defines the complete design SYSTEM + shell +
component library + 5 exemplar screens; it does not include sections 40+
(Movies/Series/Search/Favorites/Settings/players).** The remaining feature
screens were implemented by faithfully extrapolating the established system and
component library, guided by the design's IA, the reconciliation rules in the
Phase 3 brief, and `docs/flutter-foundation/UI_HANDOFF.md`. See
`DESIGN_MCP_MAPPING.md`.

## Executed sequence

1. **Design system (Phase B)** — `AbkColors` (dark+light, ThemeExtension),
   `AbkSpace`, `AbkRadius`, `AbkAspect`, `AbkElevation`, `AbkMotion`,
   `AbkBreakpoints`, `AbkTextStyles`; `AbkTheme.dark()/light()` + `AlwaysDark`;
   `context.c/type/wc/isRtl` accessors. i18n (`AbkStrings` ar/en + `context.tr`),
   theme/locale controllers (persisted, live switch).
2. **Adaptive shell + components (Phase C/D)** — `AdaptiveShell` (bottom bar /
   labelled sidebar / icon rail) + destinations + More menu + top search;
   `AbkFocusable` interaction contract; content cards, badges, inputs, state/
   feedback widgets, image/fallback system, player chrome.
3. **Screens (Phase E)** — Launch, Login, Home, Live browser, Live/VOD player,
   Movies catalogue + details, Series catalogue + details, Episode player,
   Search, Favorites, Settings, Parental lock — each wired to the existing
   use cases/providers via a thin presentation layer (`catalogue_providers`).
4. **State/error system** — sanitized loading/empty/error/partial rendering
   mapped from the foundation's `Result`/`Failure` and `AuthState`.
5. **QA** — token/theme/component widget tests, design-system tests, deterministic
   macOS UI integration, plus the retained data-layer macOS integration.

## Discipline held

- No backend/repository rebuilt; no API client duplicated; no invented
  endpoint/field; no server pagination; no recommendation API; no legacy UI
  copied. All networking stays in the foundation use cases; widgets read
  Riverpod providers only.

## Reconciliations applied (see DESIGN_MCP_MAPPING §Deviations)

- Movies/Series sort exposes only real fields (name/year/rating/default) — no
  "Newest/added" (contract has no `added`).
- Large catalogues rendered with virtualized lazy grids/rails (local windowing);
  no server pagination.
- Series cards show list-model metadata only; `series_info` fetched on details.
- No recommendation/trending/for-you anywhere; Home featured is a deterministic
  local pick.
- EPG rendered only when data exists; no reserved empty EPG space.
- Feature screens 40+ extrapolated from the design system (documented).
