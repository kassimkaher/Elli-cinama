# ABK v3.4 → v4.3 — Backend-Only Delta

**Scope:** backend/wire contract only. UI, navigation, players, analytics, subtitles, and mobile-layout changes are intentionally ignored.
**Date:** 2026-08-24.

## What v4.3 actually is

v4.3 (`4.3/`) is **not** the same codebase as v3.4. It is a rebranded standard **Xtream Codes / XUI player**:

- Package `com.shadeed.Eliaapro`, java namespace `com.ibopro.ultra` ("ibo/ultra" template).
- Networking: **Retrofit + OkHttp + Gson** (`RetroClass`, `APIService`), **not** v3.4's FAN/RxJava + XOR middleware.
- All content calls: `RetroClass.getAPIService(prefs.getServerUrl()).<action>(username, password, …)` → `GET {server}/player_api.php?...`.
- Base URL is a stored preference (`ServerUrl`), set by parsing a user-supplied portal/playlist URL: `setSharedPreferenceServerUrl(scheme + "://" + authority)` (`BaseActivity.java:1344/1373/1406`; `ChangePlaylistActivity`, `AddGroupActivity`).
- **No** Firebase Remote Config, **no** XOR codec, **no** `libnative-lib`/`getValue`/`getKeyValue`. (Native libs present are `libRTXApp`, `libffmpegJNI`, `librealm-jni`, `libstringencryptionv3`, gif — none carry the content endpoint.)

So v3.4 and v4.3 reach the **same upstream Xtream panel/account** by **two different wire contracts**: v3.4 through a proprietary XOR middleware, v4.3 directly.

## Delta by area

### Authentication
| Aspect | v3.4 | v4.3 | Class |
|---|---|---|---|
| Destination | `POST https://header21.b-cdn.net` (middleware) | `GET {server}/player_api.php` (panel) | CHANGED |
| Method / body | POST form `json`=XOR(payload) | GET query params | CHANGED |
| Credentials | `code="00000000"`+`user`+`pass` (or activation `code`) | `username`+`password` query | CHANGED (same creds) |
| Server URL input | none — middleware supplies `host` | user enters portal URL (`ServerUrl`) | CHANGED |
| Device fields | `mac`,`sn`,`model`,`group=0` | none | NOT USED in v4.3 |
| Success model | `status ∈ {100,101}` | Xtream `user_info.auth==1` / status "Active" | CHANGED (equivalent) |
| Session | stateless credential replay | stateless credential replay | UNCHANGED |

### Content backend
| | v3.4 | v4.3 |
|---|---|---|
| Layer | XOR middleware `header21.b-cdn.net` (`activity` RC value) | direct panel `player_api.php` |
| Upstream | **same Xtream panel** (`domaio40.hype04.site` — from v3.4 login `host`) | same Xtream panel (user's `ServerUrl`) |
Class: **CHANGED** (different layer, same upstream data).

### Request codec
- v3.4: repeating-XOR, key `r+3e>@y](7wEEM[`, form field `json`, `application/x-www-form-urlencoded`, response XOR-decoded on 2xx.
- v4.3: **none** — plain HTTP(S) query params, Gson.
Class: **CHANGED — CODEC NOT USED in v4.3.**

### Core operations (equivalence map)
| Purpose | v3.4 `mode=` | v4.3 Xtream `action=` | Decision |
|---|---|---|---|
| Login | `login` | `player_api.php` (auth) | SAME (data) |
| Live categories | `packages` | `get_live_categories` | SAME |
| Live channels | `channels` | `get_live_streams` | SAME |
| Movie categories | `movies_cat` | `get_vod_categories` | SAME |
| Movies | `movies_list` | `get_vod_streams` | SAME |
| Movie info | `movies_info` | `get_vod_info` | SAME |
| Series categories | `series_cat` | `get_series_categories` | SAME |
| Series | `series_list` | `get_series` | SAME |
| Series info | `series_info` | `get_series_info` | SAME |
| Short EPG | `get_short_epg` (GET on `player_api`) | `get_short_epg` | SAME (identical action) |

Same logical operation set and data; different transport/shape.

### Stream / playback
| | v3.4 | v4.3 | Class |
|---|---|---|---|
| Live URL | server-supplied `stream_url` template with literal `{user}`/`{pass}` (runtime form `{host}/{user}/{pass}/{id}`) | client-built `{server}/live/{user}/{pass}/{id}.{ext}` (`GetSharedInfo` L120) | CHANGED (both hit same panel) |
| Movie URL | `movies_info.stream_url` object (480p/720p/1080p/4k), verbatim | client-built `{server}/movie/{user}/{pass}/{id}.{ext}` (L130) | CHANGED |
| Episode URL | `episodes[].stream_url` verbatim | client-built `{server}/series/{user}/{pass}/{id}.{ext}` (L92) | CHANGED |
| Playback UA | login `user_agent` | login `user_agent` | UNCHANGED |

### EPG
Both use `get_short_epg`; v4.3 additionally has `xmltv.php` and `get_simple_data_table` (catch-up). SAME action; v4.3 adds optional XMLTV.

## Verdict

**BACKEND CONTRACT UNCHANGED** (for the purpose of the clean rebuild).

Reasoning tied to the task's definition — "UPDATED" applies only to a wire change **required for current compatibility**. It is not required: the v3.4 middleware contract is **still fully functional today** (runtime-confirmed: `header21.b-cdn.net` login `status=100`, 124 categories, 8,604 channels, a live MPEG-TS stream, movies, series — see `ABK_RUNTIME_VALIDATION_FINAL.md`). v4.3 does not break, replace, or require any change to that contract; it is a **parallel standard-Xtream implementation** of the same account.

Therefore:
- Keep the recovered **v3.4 middleware contract** as the authoritative one for the rebuild (it needs only username/password and supplies the panel host itself).
- Treat the **v4.3 direct-Xtream mapping** above as an informative **fallback/cross-check** (usable if the middleware URL ever dies, since it reaches the same panel with the same account).
- Reverse-engineering stops here.
