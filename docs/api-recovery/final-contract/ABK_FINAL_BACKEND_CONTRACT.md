# ABK — Final Backend Contract (authoritative for the clean rebuild)

This is the single source of truth for the new application's backend. It reflects **runtime-confirmed** behaviour of the live v3.4 content middleware (2026-08-24) plus static evidence from Phase 1. The future app implements **this** — no need to consult the decompiled APKs.

Legend: **[RUNTIME]** verified live · **[STATIC]** from code, not re-verified live.

---

## 0. Server configuration (four distinct roles)

| Role | Value | How obtained |
|---|---|---|
| **CONTENT API** | `https://header21.b-cdn.net` | Firebase Remote Config key `activity` (overrides the dead native fallback). Fetch it at startup; do **not** hardcode — it can rotate. |
| **STREAMING HOST** | login response `host` (runtime: `http://domaio40.hype04.site:80`) | returned by login; base for live/VOD stream URLs |
| **PLAYER API** | login response `player_api` (runtime: `http://domaio40.hype04.site:80/`) | returned by login; EPG. Use canonical `{host}/player_api.php`. |
| **EPG API** | login response `epg_api` | returned by login; optional XMLTV; unused by v3.4 |

Firebase identity (to read the CONTENT API at runtime): project `eliaapro`, number `722642815778`, app id `1:722642815778:android:81593e922af4127dd0737b`, client api key `AIzaSyBZyxL8c2-…`, signing SHA-1 `FB85099F501D54139F6901B6D848D8265575BC1F`. (See `tools/abk-compat/fetch_remote_config.py`.)

**Do NOT treat `nok3.zxmnbv04.xyz:80` as any of these — it is stale/unrelated.**

---

## 1. Transport & codec  [RUNTIME]

- **Content ops:** `POST {CONTENT_API}` (root path), `Content-Type: application/x-www-form-urlencoded`, single field **`json`** = `XOR(payload_json)` then percent-encoded.
- **Codec:** repeating-key XOR, key **`r+3e>@y](7wEEM[`** (15 bytes), symmetric, byte-wise. Response body is XOR-decoded (only on HTTP 2xx) then `trim()`ed, then JSON-parsed.
- **List ops decode to a bare JSON array; login/series_info decode to a JSON object.**
- No auth header, no cookie, no token. Credentials ride inside the encrypted body on every call.

---

## 2. Authentication  [RUNTIME]

**Required inputs:** username + password (activation-code mode also exists but is out of scope for the rebuild unless needed).

**Request** — `mode="login"`, payload before XOR:
```
{ "code":"00000000", "user":<username>, "pass":<password>,
  "mac":<mac>, "sn":<mac>, "model":<device>, "group":0, "mode":"login" }
```
- `mac`=`sn` (same value); representative default `02:00:00:00:00:00`. `model`=device name; `group`=0. Device fields were **accepted as-is** at runtime (no rejection).

**Success criterion:** `status ∈ {100, 101}`. Runtime observed **`status=100`**, `message="Login Success."`.

**Persist these server fields** (all present at runtime):
`status, message, host, player_api, epg_api, username, password, user_agent, timezone, expire, apk_ver_code, force_update, update_url`.
- Server **may** rewrite `username`/`password` [STATIC]; runtime did **not** rewrite. Always use the returned values downstream.
- `user_agent` (runtime `UA.UAGENT`) is the playback/panel User-Agent.

---

## 3. Live  [RUNTIME]

### 3.1 Categories — `mode="packages"`
Response: array of category objects. Fields: `id`, `category_name`, `category_icon`, `view_order`, `ch_count`, `category_type`, `parent`, `isLocked`.
Runtime: **124** categories. Sort by `CAST(view_order AS INT)`. Inject a synthetic favourites category client-side if desired (local only).

### 3.2 Channels — `mode="channels"`
Response: array of channel objects. Fields: **`id`** (the stream id), `stream_display_name`, `category_id`, `stream_icon`, `view_order`, `tv_archive`, `has_epg`, **`stream_url`**.
Runtime: **8,604** channels; every one has a `stream_url` containing literal `{user}`/`{pass}`. Returned in one response (no pagination).

### 3.3 Live stream URL
Take `stream_url`, **literally** replace `{user}`→username, `{pass}`→password (use `String.replace`, not regex). Runtime form: `{host}/{user}/{pass}/{id}` → HTTP 200, `video/mp2t` (MPEG-TS) via redirect. Send the account **User-Agent** (panel 403s unknown UAs). Let the player infer container from the response (MPEG-TS/HLS/DASH).

### 3.4 EPG — `get_short_epg`  [RUNTIME transport / STATIC model]
`GET {host}/player_api.php?username=<u>&password=<p>&action=get_short_epg&stream_id=<id>` with a normal **User-Agent**.
Response model [STATIC]: `{ "epg_listings": [ { "title"(Base64), "start", "end", "start_timestamp", "stop_timestamp", … } ] }`; render items `[0]` (now) / `[1]` (next); parse `start`/`end` as `yyyy-MM-dd HH:mm:ss` in the account `timezone`.
**Runtime: NOT AVAILABLE** — this account returns no listings and all channels report `has_epg=0`. Implement the call defensively (empty is normal).

---

## 4. Movies  [RUNTIME]

- **Categories** — `mode="movies_cat"` → array (`id`,`category_name`,`category_icon`,`stream_count`,`cat_order`,`parent_id`). Runtime: **30**.
- **List** — `mode="movies_list"` → array (`id`,`stream_display_name`,`category_id`,`stream_icon`,`backdrop`,`plot`,`rating`,`genre`,`cast`,`year`,`view_order`). Runtime: **20,484**. (`stream_url` present but unused — use info.)
- **Info** — `mode="movies_info"`, extra field `movie_id` → **array**; read `[0]`. Key field **`stream_url` is an object**: `{ "480p","720p","1080p","4k" }` (runtime keys confirmed). Absent qualities are `""` (never `null`).
- **Movie URL:** first non-empty of `4k → 1080p → 720p → 480p`, used **verbatim** (no substitution).

---

## 5. Series  [RUNTIME]

- **Categories** — `mode="series_cat"` → array (same shape as movie categories). Runtime: **36**.
- **List** — `mode="series_list"` → array (`id`,`title`,`icon`,`catid`,`icon_big`,`backdrop`,`genre`,`plot`,`cast`,`rating`,`director`,`releaseDate`,`view_order`). Runtime: **7,455**.
- **Info** — `mode="series_info"`, extra field `series_id` → **object** `{ "info": {...}, "seasons":[ { "season_num", "episodes":[ { "episode_num","episode_name","stream_url" } ] } ] }`. Runtime confirmed `info` + `seasons[]` + episode fields present.
- **Episode URL:** `episodes[].stream_url` used **verbatim** (no substitution).

---

## 6. Request/response summary

| Purpose | mode / call | extra | request | response root |
|---|---|---|---|---|
| Login | `login` | — | POST json=XOR | object |
| Live categories | `packages` | — | POST json=XOR | array |
| Live channels | `channels` | — | POST json=XOR | array |
| Movie categories | `movies_cat` | — | POST json=XOR | array |
| Movies | `movies_list` | — | POST json=XOR | array |
| Movie info | `movies_info` | `movie_id` | POST json=XOR | array (read `[0]`) |
| Series categories | `series_cat` | — | POST json=XOR | array |
| Series | `series_list` | — | POST json=XOR | array |
| Series info | `series_info` | `series_id` | POST json=XOR | object |
| Short EPG | `get_short_epg` | `stream_id` | GET `{host}/player_api.php` (plain, UA required) | object |

---

## 7. Local-only (keep OUT of the backend contract)

Favourites, recent/resume, parental lock (PIN, default `12345`), local search (`LIKE`), and catalogue caching are **client-local** in v3.4 and remain local features in the rebuild — no backend endpoints. v4.3 does not change this. Implement with the app's own local store.

---

## 8. Do NOT carry over

Original package name, anti-repackaging traps, `libnative-lib.so`, Dagger/RxJava, the old Room schema, old UI, the 4-way player-selection UX, and known v3.4 defects (regex `{user}` substitution, unguarded null derefs, swallowed errors, main-thread DB) are **not** part of this contract. Only backend compatibility matters.

---

## 9. Edge cases the rebuild MUST handle

1. **User-Agent:** send the account `user_agent` (or an `okhttp/*`/browser UA) on all streaming-host requests (stream + EPG); unknown UAs get HTTP 403.
2. **CONTENT_API is dynamic:** read `https://header21.b-cdn.net` from Remote Config `activity` at startup (it can rotate); keep it configurable.
3. **Literal `{user}`/`{pass}`** substitution for live only; movies/episodes are verbatim.
4. **Large catalogues, no pagination** — parse/stream efficiently.
5. **`movies_info.stream_url` is an object**; empty qualities are `""`.
6. **EPG may be empty** for an account (`has_epg=0`); treat as normal.
7. **Errors are silent in v3.4** — the rebuild should surface HTTP / XOR-decode / JSON / empty-result failures distinctly.

---

## 10. Optional fallback — direct Xtream (from v4.3)

The same account is reachable **directly** on the panel via standard Xtream (`{host}/player_api.php?username&password&action=…`; live `{host}/live/{u}/{p}/{id}.{ext}`, movie `/movie/…`, series `/series/…`). This is v4.3's contract and a valid fallback if the middleware ever dies, but it requires the panel host to be known (the middleware otherwise supplies it) and changes login to require a server URL. See `ABK_V43_BACKEND_DELTA.md` for the full mode↔action map. **Primary remains the confirmed v3.4 middleware contract above.**
