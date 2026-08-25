# ABK — Design MCP → Flutter Mapping

Claude Design master `ABK_CINEMA_MASTER_DESIGN.dc.html` (project
`fc6ccee1-…`) → Flutter routes, widgets and state/use-case dependencies.

## Design sections → implementation

| Design § | Flutter |
|---|---|
| 02 Adaptive layout | `core/design/breakpoints.dart` (WidthClass, metrics) |
| 03 Design tokens | `core/design/tokens.dart` (AbkColors dark/light, Space/Radius/Aspect/Elevation/Motion) |
| 04 Theme system | `core/design/theme.dart` (AbkTheme, AlwaysDark) + `core/app_prefs.dart` (mode, live) |
| 05 Typography | `core/design/typography.dart` (AbkTextStyles, Arabic +2dp/+0.35lh) |
| 06 Motion | `AbkMotion` durations/curves; reduced-motion aware in `AbkFocusable`/`SkeletonBox` |
| 07 Component library | `shared/widgets/*` + `shared/state/states.dart` |
| 08 App shell & nav | `features/shell/adaptive_shell.dart` |
| 80/81 RTL/L10n | `core/i18n/strings.dart` + `flutter_localizations`; `context.tr`, direction from locale |

## Screens → route / widget / use cases

| Design screen | Widget | Wired use cases / providers |
|---|---|---|
| 10 Launch | `features/launch/launch_screen.dart` (via `ui/root_gate.dart`) | bootstrap (RC resolve, restore), catalogue prefetch |
| 11 Login | `features/auth/presentation/login_screen.dart` | `sessionControllerProvider` (LoginUseCase) |
| 20 Home | `features/home/home_screen.dart` | `featuredProvider`, `continueWatchingProvider`, `favoriteChannelsProvider`, `moviesProvider`, `seriesListProvider`, `liveCategoriesProvider` |
| 30 Live browser | `features/live/presentation/live_browser_screen.dart` | `liveCategoriesProvider`, `channelsByCategoryProvider`, `favoritesRepositoryProvider`, `resolveLiveStreamUrlProvider`, `parentalLockRepositoryProvider` |
| 31 Live player | `features/player/player_screen.dart` (live) | `playbackServiceProvider`, `playbackSourceFactoryProvider` |
| 40* Movies | `features/movies/presentation/movies_screen.dart` | `moviesProvider`, `movieCategoriesProvider` |
| 41* Movie details | `movie_details_screen.dart` | `movieInfoProvider`, `selectMovieQualityProvider`, favourites |
| 42* Movie player | `player_screen.dart` (VOD) | player abstraction |
| 50* Series | `series/presentation/series_screen.dart` | `seriesListProvider`, `seriesCategoriesProvider` |
| 51* Series details | `series_details_screen.dart` | `seriesInfoProvider` (seasons/episodes) |
| 52* Episode player | `player_screen.dart` (VOD) | player abstraction |
| 60* Search | `features/search/search_screen.dart` | `LocalSearch` over cached lists (no backend/query) |
| 61* Favorites | `features/favorites/favorites_screen.dart` | `favoritesRepositoryProvider`, cached lists |
| 62* Settings | `features/settings/settings_screen.dart` | `themeModeProvider`, `localeProvider`, session, cache invalidation |
| 61* Parental lock | `features/settings/parental_lock.dart` + live browser PIN gate | `parentalLockRepositoryProvider` |
| 70* State/error system | `shared/state/states.dart` (`SectionAsync`, `ErrorBlock`, `EmptyStateBlock`, banners) | maps `Result`/`Failure`/`AuthState` |

`*` = feature screen extrapolated from the design system (not an exemplar in the
master file). Visual language, tokens, components and interaction come from the
master's system + exemplars; the screen composition follows the design's IA and
the Phase 3 brief.

## Navigation IA (Design §08)

Destinations: Home · Live · Movies · Series · Favorites · Settings, with Search
as a pushed route (app-bar/sidebar, `/` shortcut). Phone → bottom bar
(Home/Live/Movies/Series/More; Favorites+Settings+Account under More). Desktop →
labelled sidebar (Settings pinned), collapses to icon rail < 1280, bottom bar
< 905. Keyboard shortcuts (1–6 jump, / search) at the shell.

## Intentional deviations / reconciliations

1. **No "Newest/Added" sort** (Movies/Series) — the contract has no `added`
   field. Sort = Default / Name / Year / Rating only.
2. **No server pagination** — virtualized lazy grids/rails over the full
   retrieved catalogue; "loads while scrolling" = local windowing.
3. **Series cards** show only `series_list` metadata; `series_info`
   (seasons/episodes) is fetched on entering details — no per-card info calls.
4. **No recommendations/trending/for-you** — Home featured is a deterministic
   local pick from titles that have a real backdrop/plot/rating.
5. **EPG** rendered only when data exists (account currently has none); no
   reserved empty EPG space; the `Now:` slot shows the category until EPG exists.
6. **Live embedded preview (desktop ≥1280)** shows channel identity + a
   fullscreen Play rather than an in-pane live decode — AVFoundation on
   macOS/desktop does not decode raw MPEG-TS; full playback uses the player
   route (documented platform-adapter limitation from Phase 1B, unchanged).
7. **Fonts** (Archivo / IBM Plex Sans Arabic / IBM Plex Mono) fall back to the
   platform stack when not bundled; the exact scale/weights/line-heights (which
   drive layout) are implemented precisely.
