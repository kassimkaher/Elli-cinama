# ABK Flutter — Backend Integration Map

Maps the authoritative contract (`docs/api-recovery/final-contract/ABK_FINAL_BACKEND_CONTRACT.md`)
to the Flutter implementation. All content operations share one transport.

## Transport

- **Content**: `POST {CONTENT_API}` form field `json` = XOR(payload).
  - `CONTENT_API` = Remote Config `activity` → validated → fallback `https://header21.b-cdn.net`
    (`core/config/content_api_resolver.dart`).
  - Codec: `core/network/xor_codec.dart` (key `r+3e>@y](7wEEM[`).
  - Client: `core/network/content_client.dart` — `callObject` / `callList`,
    off-isolate decode for >64 KB, full failure mapping.
  - Envelope: `core/network/request_builder.dart` (+ `RuntimeSession` credentials,
    `DeviceEnvelope`).
- **EPG**: plain `GET {host}/player_api.php` (NON-XOR) with streaming User-Agent
  (`features/epg/data/datasource.dart`).
- **Streaming**: `PlaybackSourceFactory` injects the User-Agent; live URL via
  literal `{user}`/`{pass}` substitution.

## Operation → datasource → model → repository → use case

| Contract op | mode / call | Datasource | Model | Repository | Use case |
|---|---|---|---|---|---|
| Login | `login` | `auth/data/.../auth_remote_datasource.dart` | `AccountModel` → `Account` | `AuthRepositoryImpl` | `LoginUseCase` / `LogoutUseCase` / `RestoreSessionUseCase` |
| Live categories | `packages` | `live/data/datasource.dart` | `LiveModels.categoryFromJson` → `LiveCategory` | `LiveRepositoryImpl` | `GetLiveCategories` |
| Live channels | `channels` | `live/data/datasource.dart` | `LiveModels.channelFromJson` → `LiveChannel` | `LiveRepositoryImpl` | `GetLiveChannels` |
| Live stream URL | — (client) | — | `LiveChannel.streamUrlTemplate` | — | `ResolveLiveStreamUrl` (literal `{user}`/`{pass}`) |
| Movie categories | `movies_cat` | `movies/data/datasource.dart` | `MovieModels.categoryFromJson` → `MovieCategory` | `MovieRepositoryImpl` | `GetMovieCategories` |
| Movies | `movies_list` | `movies/data/datasource.dart` | `MovieModels.listItemFromJson` → `MovieListItem` | `MovieRepositoryImpl` | `GetMovies` |
| Movie info | `movies_info` + `movie_id` | `movies/data/datasource.dart` (array→`[0]`) | `MovieModels.infoFromJson` → `MovieInfo` (`StreamQualities`) | `MovieRepositoryImpl` | `GetMovieInfo`, `SelectMovieQuality` |
| Series categories | `series_cat` | `series/data/datasource.dart` | `SeriesModels.categoryFromJson` → `SeriesCategory` | `SeriesRepositoryImpl` | `GetSeriesCategories` |
| Series | `series_list` | `series/data/datasource.dart` | `SeriesModels.listItemFromJson` → `SeriesListItem` | `SeriesRepositoryImpl` | `GetSeries` |
| Series info | `series_info` + `series_id` | `series/data/datasource.dart` (object) | `SeriesModels.infoFromJson` → `SeriesInfo`/`Season`/`Episode` | `SeriesRepositoryImpl` | `GetSeriesInfo`, `ResolveEpisodeUrl` |
| Short EPG | GET `get_short_epg` + `stream_id` | `epg/data/datasource.dart` | `EpgListing` | `EpgRepositoryImpl` | `GetShortEpg` |

## Authentication envelope (mode=login)

`{ code:"00000000", user, pass, mac, sn(=mac), model, group:0, mode:"login" }`
XOR-obfuscated into `json`. Built by `ContentRequestBuilder.buildLogin`. Success
= `status ∈ {100,101}`. On success, `AuthRepositoryImpl` persists the account
(secure storage) and registers server-returned credentials for redaction; the
`SessionController` updates `RuntimeSession` (credentials + `ServerRoles`) so all
later calls use the (possibly rewritten) server credentials.

## Server roles (kept distinct)

| Role | Source | Consumed by |
|---|---|---|
| CONTENT_API | Remote Config `activity` (fallback header21) | `ContentClient` |
| Streaming host | login `host` | live/VOD stream URLs, `player_api.php` base |
| player_api | login `player_api` | EPG (canonical `{host}/player_api.php`) |
| epg_api | login `epg_api` | reserved (optional XMLTV; unused) |
| user_agent | login `user_agent` | all streaming-host + EPG requests |

## Runtime-confirmed (from Flutter)

Login `status=100`, no credential rewrite, streaming host `domaio40.hype04.site`;
packages 124; channels 8,604 (all `{user}`/`{pass}` templated); one live stream
`video/mp2t`; movies 30/20,484 with `stream_url` object; series 36/7,455 with
seasons/episodes; EPG reachable, empty (account `has_epg=0`). See `QA_REPORT.md`.
