# ABK — Component System & Tokens

Semantic tokens only; no screen hardcodes a hex, size or duration. Access via
`context.c` (colours), `context.type` (text), `context.wc` (width class),
`context.isRtl`, `context.tr(key)`.

## Tokens (`core/design/tokens.dart`, `breakpoints.dart`, `typography.dart`)

- **AbkColors** — ThemeExtension with dark + light designed palettes (background,
  surface{,Elevated,Strong}, card{,Focused}, accentPrimary/secondary,
  success/warning/error/info, text{primary,secondary,muted,disabled},
  borderSubtle, divider, focusRing, scrim, playerOverlay, skeleton, 3 placeholder
  tints, `placeholderFor(key)` stable by hash). Light adds a card border; players/
  launch/login/fullscreen/TV stay dark (`AlwaysDark`).
- **AbkSpace** 2…80 · **AbkRadius** xs4/sm8/poster10/md12/modal16/lg20/sheet24/pill
  · **AbkAspect** poster 2:3, backdrop 16:9, logo 1:1, categoryTile 3:2 · **AbkElevation**
  elev1/elev2/hover/focus · **AbkMotion** fast120…overlayOut320, curves.
- **AbkBreakpoints** — Compact<600, Medium 600–904, Expanded 905–1279, Desktop
  1280–1727, WideDesktop ≥1728, TV override; per-class contentMargin/gridGap/
  sectionGap/posterWidth/posterColumns/minHitTarget; contentMax 1680.
- **AbkTextStyles** — hero/pageTitle/sectionTitle/cardTitle/body/metadata/caption/
  button/playerControl/navLabel, adaptive by class, Arabic +2dp size & +0.35
  line-height, never letter-spaced/uppercased; families Archivo (Latin display),
  IBM Plex Sans Arabic (product), IBM Plex Mono (metadata) with platform fallback.

## Shared components (`shared/widgets/`, `shared/state/`)

One interaction contract: `AbkFocusable` — hover/focus/pressed/selected states,
2dp focus ring at 3dp offset, press scale 0.98, optional artwork focus scale,
secondary activation (long-press/right-click/menu), reduced-motion aware.

- **Content**: `PosterCard` (rest/hover/focus/pressed/selected/disabled/locked/
  compact/light), `LiveChannelRow`, `ContinueWatchingCard`, `CategoryTile`,
  `CategoryRailItem`, `EpisodeCard`, `HeroBanner`.
- **Metadata/badges**: `LiveBadge` (only accent.secondary use), `RatingBadge`
  (hidden when null/0), `QualityBadge`, `LockedBadge`, `ArchiveBadge`,
  `MetadataRow` (separators between present values only; collapses empty),
  `FavoriteButton` (optimistic).
- **Input**: `AbkButton` (primary/secondary/ghost/destructive, loading),
  `AbkTextField`, `PasswordField`, `SearchField`, `FilterChipRow`, `SortSelector`,
  `PinInput`.
- **Feedback/state**: `SkeletonBox` (shimmer→static on reduced motion),
  `EmptyStateBlock`, `ErrorBlock` (sanitized), `OfflineBanner`, `StaleBanner`,
  `SectionAsync` (loading/error/empty/data), `showAbkSnackbar/Sheet/Dialog`.
- **Image**: `AbkImage` (skeleton→fade→fallback), `PosterFallback`,
  `LogoFallback`, `BackdropScrim`.
- **Player chrome**: overlay (auto-hide), progress/seek (VOD), play/pause,
  fullscreen, buffering/error/retry, live identity — in `player_screen.dart`.
- **Layout**: `ContentMax` (cap 1680), `SectionHeader`, `PosterRail`,
  `AdaptivePosterGrid` (virtualised), `PagePadding`.

No component is duplicated per feature; every screen composes these.

## Themes

`AbkTheme.dark()` / `.light()` build Material 3 `ThemeData` carrying the
`AbkColors` extension; theme mode is System/Dark/Light (persisted, live via
`themeModeProvider`); locale ar/en persisted (`localeProvider`), direction from
the app locale.
