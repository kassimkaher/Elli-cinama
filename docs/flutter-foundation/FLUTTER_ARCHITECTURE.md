# ABK Flutter — Architecture (Phase 1 Foundation)

Clean, feature-first architecture with a strict `presentation → domain → data`
dependency direction. This phase completes everything **below** the UI; final
screens come from Cloud Design later.

Project: `abk_flutter/` · package `abk_player` · Flutter 3.44 / Dart 3.12.

## Layers & dependency direction

```
presentation (Riverpod controllers, dev UI)     depends ↓ only
        │
domain (entities, repository interfaces, usecases)   pure Dart, no Flutter/plugins
        │
data (models/fromJson, datasources, repository impls)
        │
core (config, network, storage, player, device, logging, errors, utils, di)
```

Rule enforced throughout: **domain never imports data or Flutter plugins**;
data implements domain interfaces; presentation depends on domain (+ DI). Core
is shared infrastructure. The **entire content path — codec, HTTP client,
models, resolvers, use cases — is plugin-free**, so it runs on the Dart VM under
`flutter test` (54 unit tests, no device needed). Plugins (secure storage,
device info, player, prefs) sit behind interfaces with in-memory fakes.

## Module structure

```
lib/
  app/                         app shell + bootstrap + temporary dev UI
    bootstrap.dart             composition root (async singletons, RC resolve, session restore)
    app.dart, dev/dev_home_screen.dart
  core/
    config/                    AppConstants, ServerRoles, RemoteConfigService, ContentApiResolver
    network/                   XorCodec, ContentClient, RequestBuilder, RuntimeSession, StreamingHeaders
    storage/                   SecureStore, KeyValueStore (+ in-memory fakes)
    player/                    PlaybackService (abstraction) + VideoPlayer impl + SourceFactory
    device/                    DeviceEnvelope + providers
    errors/                    Failure taxonomy
    logging/                   Redactor + AppLogger
    utils/                     Result<T>, json coercion
    di/providers.dart          Riverpod composition
  features/
    auth/  live/  movies/  series/  epg/     (each: data/ domain/ [presentation/])
    favorites/  search/  settings/           (local-only repositories)
```

## State management & DI

- **Riverpod** (`flutter_riverpod`) for DI and state. All dependencies are
  `Provider`s in `core/di/providers.dart`; two leaf providers
  (`sharedPreferencesProvider`, `deviceModelProvider`) are overridden at
  bootstrap. Everything is injectable and testable (the test suite builds the
  same graph with fakes/`MockClient`).
- Auth state is a `StateNotifier<AuthState>` (`SessionController`) with explicit
  states: `AuthLoggedOut`, `AuthAuthenticating`, `AuthAuthenticated`,
  `AuthError(kind: auth|config|network|unknown)`.
- The DI cycle between auth and the content layer is broken by **`RuntimeSession`**
  — a leaf holder of current credentials + `ServerRoles`, updated by the
  controller and read by the request builder (`CredentialSource`) and the EPG
  datasource.

## Repositories & use cases

Every feature exposes a domain `Repository` interface, a data `…RepositoryImpl`
delegating to a `…RemoteDataSource` (content client) or local store, and thin
use cases returning `Result<T>` (`Ok`/`Err`). Use cases are the presentation's
only entry points (e.g. `GetLiveChannels`, `ResolveLiveStreamUrl`,
`SelectMovieQuality`, `GetShortEpg`).

## Error handling

A sealed `Failure` taxonomy (`Connectivity`, `Timeout`, `Http`, `Decode`,
`Parse`, `BackendLogical`, `EmptyResult`, `Config`, `Auth`, `Unknown`) is
returned via `Result<T>`. **No swallowed errors** — the client maps every
transport/decode/shape problem to a typed failure. This is a deliberate
departure from the legacy app, which discarded content-mode failures silently.

## Storage

- **Secrets** (credentials, server-returned credentials, whole session) →
  `flutter_secure_storage` (`AndroidOptions(encryptedSharedPreferences: true)`).
- **Non-sensitive** prefs + local features → `shared_preferences`.
- Both behind interfaces (`SecureStore`, `KeyValueStore`) with in-memory fakes.

## Player abstraction

`PlaybackService` (load/play/pause/stop/dispose + `stateStream`) with a
`video_player` (ExoPlayer/AVPlayer) implementation. `PlaybackSourceFactory`
builds sources with the streaming **User-Agent** and a container hint
(`detectContainer`). No UI is built; the later phase attaches a widget to the
controller. Handles HLS/DASH/MPEG-TS/progressive.

## Runtime configuration

`ContentApiResolver` resolves `CONTENT_API` from Firebase Remote Config key
`activity` (via `RemoteConfigService`), validates the URL, and falls back to the
confirmed `https://header21.b-cdn.net`. `refresh()` picks up a rotated value
without a new release. Remote Config uses a pure-Dart REST implementation
(`FirebaseRestRemoteConfigService`) so the native build needs no Firebase gradle
plugin; it is swappable behind the interface for the SDK later. The four server
roles — CONTENT_API, streaming host, player_api, epg_api — are modeled
distinctly (`ServerRoles`) and never conflated.

## Adaptive presentation seams (no final design)

- App shell is a plain `MaterialApp` (Material 3) hosting only the dev screen.
- Orientation/layout are unconstrained (no phone-only assumptions); the widget
  layer is intentionally thin so Cloud Design can introduce
  phone/tablet/TV + portrait/landscape + touch/D-pad layouts on top of the
  existing use cases and states. See `UI_HANDOFF.md`.

## Large-catalogue strategy

The backend has no pagination (8,604 live / 20,484 VOD / 7,455 series in single
responses). The `ContentClient` decodes any response over 64 KB — XOR + JSON —
in a **background isolate** (`compute`) so the UI isolate never blocks.
`CatalogueCacheMeta` tracks per-domain freshness (live 24h, movies/series 15m).
`LocalSearch` is a pure function suitable for `compute`. No server-pagination
abstraction is built (the backend doesn't support it).
