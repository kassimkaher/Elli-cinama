# ABK Flutter — UI Handoff (for the Cloud Design phase)

Everything below the presentation layer is complete, tested, and live-verified.
The UI phase builds screens on top of these use cases, states, and repositories —
**no backend rework needed**. Wire UI to the Riverpod providers in
`lib/core/di/providers.dart`.

## What you can rely on

### Session / auth
- `sessionControllerProvider` → `AuthState`: `AuthLoggedOut`,
  `AuthAuthenticating`, `AuthAuthenticated(account)`,
  `AuthError(failure, kind: auth|config|network|unknown)`.
- Actions: `.notifier.login(user, pass)`, `.logout()`, `.restore()` (restore
  runs at bootstrap). `account.roles`, `account.expire`, `account.message`
  available for display.

### Use cases (all return `Result<T>` = `Ok`/`Err(Failure)`)
| Feature | Providers |
|---|---|
| Live | `getLiveCategoriesProvider`, `getLiveChannelsProvider`, `resolveLiveStreamUrlProvider` |
| Movies | `getMovieCategoriesProvider`, `getMoviesProvider`, `getMovieInfoProvider`, `selectMovieQualityProvider` |
| Series | `getSeriesCategoriesProvider`, `getSeriesProvider`, `getSeriesInfoProvider`, `resolveEpisodeUrlProvider` |
| EPG | `getShortEpgProvider` |
| Local | `favoritesRepositoryProvider`, `resumeRepositoryProvider`, `parentalLockRepositoryProvider`, `settingsRepositoryProvider`, `catalogueCacheMetaProvider` |
| Player | `playbackServiceProvider`, `playbackSourceFactoryProvider` |

### Playback
- `playbackSourceFactoryProvider.fromUrl(url, title:)` → `PlaybackSource`
  (headers with User-Agent + container hint).
- `playbackServiceProvider` (`PlaybackService`): `load/play/pause/stop/dispose`,
  `stateStream` (`PlaybackState`: idle/buffering/playing/paused/ended/error),
  `state`. The `video_player` impl exposes a `controller` to attach a
  `VideoPlayer` widget.
- Build live URLs with `resolveLiveStreamUrl`; movie URLs with
  `selectMovieQuality`; episode URLs from `episode.streamUrl` — then
  `fromUrl(...)` → `playbackService.load(...)`.

## Screens the product needs (features already backed)
Intro/Login · Home (with recents/favourites rails) · Live (categories → channel
list → player + now/next EPG) · Movies (categories → grid → detail → play) ·
Series (categories → grid → detail → seasons/episodes → play) · Search (local) ·
Settings (player prefs, parental PIN, account info, logout). All data/actions
exist; only visuals + navigation remain.

## Loading / error / empty contract
- **Loading**: awaited `Result`; show progress while pending.
- **Error**: `Err(failure)` — branch on `Failure` type for messaging
  (`ConnectivityFailure`, `TimeoutFailure`, `HttpFailure`, `BackendLogicalFailure`
  (has `message`/`status`), `ConfigFailure`, `ParseFailure`, …). Offer retry.
- **Empty**: `Ok([])` is valid — especially **EPG** (`has_epg=0` is normal) and
  filtered category lists. Design an explicit empty state; do not treat as error.

## Large-catalogue guidance
- Live 8,604 / Movies 20,484 / Series 7,455, **no pagination** — load once, then
  page/virtualize in the UI (lazy grids/lists, deferred image loading). Decoding
  is already off-isolate.
- Filter by category client-side; use `LocalSearch.filter(list, query, nameOf)`
  (run via `compute` for very large lists). Freshness via `catalogueCacheMeta`
  (live 24h, movies/series 15m) to decide when to refetch.

## Adaptive layout seams
- App shell is a bare Material 3 `MaterialApp`; introduce responsive
  navigation (phone bottom-nav / tablet rail / TV focus grid) at the widget
  layer — the domain/use cases are layout-agnostic.
- Support portrait + landscape and touch + D-pad focus. Player screens are
  typically landscape/fullscreen. Nothing in the foundation assumes phone size.
- The temporary `DevHomeScreen` is engineering-only — replace it entirely.

## Constraints to honor
- Send the account **User-Agent** on stream/EPG requests (already wired via the
  source factory / EPG datasource) — the panel 403s unknown UAs.
- Never log resolved stream URLs; use `Redactor.redactUrl` for diagnostics.
- Keep favourites/search/parental-lock/resume **local** (no backend).
- CONTENT_API can rotate via Remote Config — never hardcode it in UI.
