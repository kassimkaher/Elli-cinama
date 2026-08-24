# ABK Rebuild Handoff — Phase 2 Requirements

**Purpose:** everything a clean-room reimplementation needs, derived entirely from the Phase 1 static analysis. **No implementation is performed in this phase.**

Read alongside:
- `ABK_STATIC_RECOVERY_REPORT.md` — evidence and architecture
- `ABK_API_CONTRACT.md` — the wire contract

---

## 1. The three facts that shape the whole rebuild

1. **There is exactly one content endpoint.** Every content operation is `POST {BASE_URL}` with a single form field `json`, discriminated by a `mode` value inside the obfuscated payload. There is no REST surface, no path routing, no status-code semantics — the HTTP layer is a dumb envelope. Design the network layer around *one* call with a `mode` parameter, not around twelve endpoints.

2. **The server hands you playback URLs.** The client never assembles a live or VOD stream URL from a stream id. It performs two literal string replacements (`{user}`, `{pass}`) on live URLs and uses VOD/episode URLs verbatim. The only URL the client actually builds is the catchup/timeshift path. Do not port Xtream URL-building logic — it does not exist here and would be wrong.

3. **Authentication is stateless credential replay.** No token, no session, no cookie, no expiry check. Every request re-sends the credentials inside the obfuscated body. Your "session" is nothing more than a set of persisted strings.

---

## 2. Required screens and features

### 2.1 Must-have (core flow)

| # | Screen | Responsibilities |
|---|---|---|
| 1 | **Intro / Activation** | Mode toggle (activation code ⟷ username+password); code or username field with switching hint; password field with show/hide; read-only device-MAC display; submit; inline server-message area; loading state. **No host/server field.** Prefill from stored credentials and auto-submit when present. |
| 2 | **Home** | Entry points to Live, Movies, Series, Settings. "Latest movies" and "latest series" rails. |
| 3 | **Live TV** | Split view: category list ⟷ channel list ⟷ embedded player. Synthetic "FAVORITE" category pinned first. Channel info overlay (number, name, category, logo). Now/Next EPG strip. Long-press menu: favourite, lock, archive. Local search. Number-key direct channel entry. |
| 4 | **Movies** | Category list + poster grid + local search. |
| 5 | **Movie detail** | Poster, backdrop, plot, cast, genre, year, rating, MPAA, duration; Play; Trailer; Favourite. |
| 6 | **Series** | Category list + poster grid + local search. |
| 7 | **Series detail** | Info block; seasons list → episodes list; Play episode; Trailer; Favourite. |
| 8 | **VOD player** | Full-screen player with transport controls, title, track selection. |
| 9 | **Settings** | Three sections: user info (username, expire, message, server notice), player selection (4 spinners), user settings (parental PIN set/clear, autostart toggle). |

### 2.2 Should-have (present in the original)

- Trailer playback screen (YouTube).
- Parental lock with a local PIN, applied to both categories and individual channels.
- Track-selection dialog (audio / subtitle) for ExoPlayer.
- Catchup / timeshift playback for channels where `tv_archive != 0`.
- Update gate on the intro screen (optional dialog + forced download path).

### 2.3 Explicitly out of scope (do not build a backend for these)

Search, favourites, watch history and parental locks are **local-only** in the original. There are no server endpoints for them. Keep them local.

### 2.4 Deliberately drop

| Item | Why |
|---|---|
| `BootUpReceiver` | Dead code — reads prefs file `user_info`/`runOnStartUp` while the app writes `snap_pref`/`PREF_KEY_RUN_ON_STARTUP`. Either wire it correctly or remove the settings toggle. |
| `AppDownloadService` | ExoPlayer download service with no reachable UI entry point. |
| `PREF_KEY_EPG_API`, `PREF_KEY_SERIAL_NUMBER` | Write-only prefs. |
| `movie_table.streamUrl` | Persisted, never read. |
| Both anti-tamper traps (§8) | Reimplement only if you deliberately want them; see the constraint in §8.3. |

---

## 3. Client architecture requirements

### 3.1 Non-negotiable behaviours to reproduce

| Requirement | Detail |
|---|---|
| Single API endpoint | `POST {BASE_URL}`, form field `json` |
| Base URL resolution | Remote-config value first, compile-time fallback second. **Must be configurable at runtime.** |
| XOR codec | Repeating-key XOR, key `r+3e>@y](7wEEM[`, applied to request payload and to response bodies **only on 2xx**, followed by `trim()` |
| Credential replay | Full envelope (`code` \| `code="00000000"`+`user`+`pass`, plus `mac`, `sn`, `model`, `group`) on every content call |
| Device id | `wlan0` MAC → `eth0` MAC → `02:00:00:00:00:00`; same value for `mac` and `sn` |
| Success test | `status ∈ {100, 101}` |
| Playback UA | `user_agent` from the login response, wrapped ExoPlayer-style |
| Live URL substitution | `{user}` / `{pass}` — **literal** replacement |
| Catchup URL | `{host}/timeshift/{user}/{pass}/1200/{yyyy-MM-dd:kk-mm}/{id}.m3u8`, start = now − 20 h in the account timezone |
| Category filtering | Hide categories with zero items; always keep the synthetic `-1` favourites row |
| Sort order | `CAST(view_order AS INTEGER) ASC` in every list |
| Cache TTLs | Live 24 h; movies 15 min; series 15 min — on expiry **truncate then refetch** |

### 3.2 Suggested modern stack

The original stack (Dagger 2 + RxJava 2 + FAN + ButterKnife + Data Binding) is dated. A clean rebuild should keep the *shape* and modernise the parts:

| Concern | Original | Suggested |
|---|---|---|
| Language | Java | Kotlin |
| DI | Dagger 2 + `dagger.android` | Hilt |
| Async | RxJava 2 `Flowable`/`Single` | Coroutines + `Flow` |
| HTTP | Fast Android Networking over OkHttp | Retrofit + OkHttp (keep the interceptor pattern) |
| JSON | Gson | kotlinx.serialization or Moshi |
| DB | Room (`allowMainThreadQueries()`) | Room with suspend DAOs — **remove main-thread queries** |
| UI | XML + Data Binding + ButterKnife | Compose (with TV focus support) or XML + ViewBinding |
| Player | ExoPlayer 2 + libVLC | Media3 (ExoPlayer) + libVLC if VLC parity is required |
| Images | Glide 4 | Coil |
| Prefs | `SharedPreferences` | DataStore + EncryptedSharedPreferences for credentials |

### 3.3 Networking layer shape

```
ApiClient
 ├─ baseUrl: StateFlow<String>              # remote-config override applied at startup
 ├─ suspend fun <T> call(mode, extra, deserializer): T
 │     payload = envelope(mode) + extra
 │     body    = FormBody("json" -> xor(json(payload)))
 │     POST baseUrl
 │     if (!response.isSuccessful) throw HttpError(code)   # body NOT decoded
 │     decoded = xor(response.body.string()).trim()
 │     return deserialize(decoded)
 └─ suspend fun shortEpg(streamId): EpgResponse
       GET playerApiUrl?username=..&password=..&action=get_short_epg&stream_id=..
       # plain JSON — must NOT pass through the XOR interceptor
```

Two OkHttp clients are required, exactly as in the original: one with the XOR response interceptor for the content API, one plain for EPG. Do not share.

### 3.4 Repository / caching shape

```
Repository
 ├─ live:   networkIfExpired(24h)  → truncate + insert → observe Room
 ├─ movies: networkIfExpired(15m)  → truncate + insert → observe Room
 ├─ series: networkIfExpired(15m)  → truncate + insert → observe Room
 ├─ detail calls (movies_info / series_info): network only, never cached
 └─ epg: network only, never cached
```
The original checks a `nextUpdateEpochMs` pref, truncates the tables when expired, then triggers a fetch only if the table is empty. Preserve the emptiness check so a failed refresh does not leave a blank catalogue.

---

## 4. API integration order

Build and verify in this sequence — each step is independently testable and each unblocks the next.

| Step | Work | Unblocks | Done when |
|---|---|---|---|
| **0** | XOR codec + unit tests (round-trip, empty, non-ASCII, key wraparound) | everything | round-trip is exact for arbitrary ASCII input |
| **1** | Base-URL provider: remote-config override with compile-time fallback | everything | override is observable and takes effect before the first call |
| **2** | Envelope builder (`code`/`user`/`pass`/`mac`/`sn`/`model`/`group`) + MAC resolver | all calls | envelope matches §2.2 of the contract byte-for-byte |
| **3** | `mode=login` and `mode=active` + `C3164a` model + persistence of the 9 fields | all content calls | `status ∈ {100,101}` gates entry; all 9 prefs written |
| **4** | `mode=packages` + `mode=channels` (concurrent, zipped) + Room persistence | Live TV | categories and channels render from cache |
| **5** | Live playback: `{user}`/`{pass}` substitution + player | core flow complete | a channel plays |
| **6** | `get_short_epg` (plain client, Base64 titles) | EPG strip | Now/Next render in the account timezone |
| **7** | `mode=movies_cat` + `movies_list` + `movies_info` + quality selection | Movies | a movie plays |
| **8** | `mode=series_cat` + `series_list` + `series_info` (seasons/episodes) | Series | an episode plays |
| **9** | `mode=movies_latest` + `series_latest` | Home rails | rails populate |
| **10** | Catchup URL builder + archive entry point | Catchup | a timeshift stream plays |
| **11** | Local favourites / locks / search (Room) | Settings + UX | parity with original |
| **12** | Update gate (`apk_ver_code`, `force_update`, `update_url`) | parity | optional/forced dialogs behave |

**Step 0 is genuinely blocking.** If the XOR codec is off by even one byte the server sees garbage and every subsequent step fails with an indistinguishable error, because the original client swallows content-mode errors silently. Build a logging/debug mode from the start.

---

## 5. Authentication and session behaviour

### 5.1 State machine

```
                 ┌─────────────┐
                 │   Launch    │
                 └──────┬──────┘
                        ▼
             resolve BASE_URL (remote config → fallback)
                        ▼
             ensure MAC persisted (wlan0 → eth0 → 02:00:…)
                        ▼
        ┌───────────────┴────────────────┐
   activationType == true          activationType == false
        ▼                                 ▼
   code stored?                      user AND pass stored?
     yes → POST mode=active            yes → POST mode=login
     no  → show form                   no  → show form
        └───────────────┬────────────────┘
                        ▼
                status ∈ {100,101} ?
              ┌─────────┴──────────┐
             no                   yes
              ▼                    ▼
     show `message`,        persist 9 fields
     stay on Intro                 ▼
                            apk_ver_code > local ?
                        ┌──────────┴───────────┐
                       no                     yes
                        ▼            ┌─────────┴─────────┐
                      Home     force_update==1      otherwise
                                     ▼                   ▼
                              download + block     optional dialog
                                                   (Cancel → Home)
```

### 5.2 Persisted session (rebuild equivalent of `snap_pref`)

| Key | Type | Default | Notes |
|---|---|---|---|
| `activationType` | bool | `true` | true = activation-code mode |
| `activeCode` | string | null | |
| `username` | string | null | **server may rewrite** |
| `password` | string | null | **server may rewrite** |
| `macAddress` | string | null | also sent as `sn` |
| `host` | string | null | catchup base |
| `playerApi` | string | null | EPG URL |
| `userAgent` | string | null | playback UA |
| `expire` | string | null | display only |
| `message` | string | null | server notice |
| `timezone` | string | null | Java TimeZone id |
| `parentalPin` | string | `"12345"` | **local PIN, unrelated to the account password** |
| `playerLive` / `playerMovies` / `playerSeries` / `playerArchive` | int | `1` | 0=VLC, 1=ExoPlayer, 2=MX, 3=VLC external |
| `liveUpdateAt` / `moviesUpdateAt` / `seriesUpdateAt` | long | `0` | next-refresh epoch ms |
| `runOnStartup` | bool | `false` | wire it correctly or drop it |

**Improvements over the original (recommended):**
- Store `username` / `password` / `activeCode` / `parentalPin` in `EncryptedSharedPreferences`.
- Set `android:allowBackup="false"` — the original backs up plaintext credentials.
- Add a **Logout** action that clears credentials and returns to Intro. The original has none.
- Evaluate `expire` client-side and warn before it lapses. The original never reads it.

### 5.3 Error handling — fix what the original gets wrong

The original discards content-mode failures with empty `Throwable` consumers, so a broken deploy looks identical to an empty catalogue. A rebuild must:
- Surface network and parse errors to the UI with a retry affordance.
- Distinguish HTTP failure / XOR-decode failure / JSON-parse failure / empty-result in logs.
- Null-guard `status`, `force_update`, and all four `C3096l` quality fields — the original NPEs on any of them and swallows the exception.

---

## 6. Category and channel models

Minimum domain models for the rebuild. JSON names are fixed by the contract and must not be changed.

```kotlin
data class Account(                      // mode=login | mode=active
    val status: Int?,                    // 100 | 101 == success
    val message: String?,
    val expire: String?,
    val userAgent: String?,              // "user_agent"
    val username: String?,               // may rewrite local
    val password: String?,               // may rewrite local
    val host: String?,                   // catchup base
    val playerApi: String?,              // "player_api" — EPG URL
    val epgApi: String?,                 // "epg_api"    — unused
    val timezone: String?,
    val apkVerCode: String?,             // "apk_ver_code"
    val forceUpdate: Int?,               // "force_update"
    val updateUrl: String?               // "update_url"
)

data class LiveCategory(                 // mode=packages
    val id: String,                      // "-1" reserved for synthetic FAVORITE
    val categoryName: String?,           // "category_name"
    val categoryIcon: String?,           // "category_icon"
    val viewOrder: String?,              // "view_order" — sort CAST(.. AS INTEGER) ASC
    val chCount: Int?,                   // "ch_count"
    val categoryType: Int?,              // "category_type"
    val parent: Int?,
    val isLocked: Boolean?               // superseded by local lock state
)

data class LiveChannel(                  // mode=channels
    val id: Int,                         // THE STREAM ID — EPG, catchup, fav/lock key
    val name: String?,                   // "stream_display_name"
    val categoryId: Int?,                // "category_id"
    val icon: String?,                   // "stream_icon"
    val viewOrder: Int?,                 // "view_order"
    val tvArchive: Int,                  // != 0 ⇒ catchup available
    val hasEpg: Int,                     // "has_epg"
    val streamUrl: String?               // TEMPLATE with {user} / {pass}
)
```

Movie / series models mirror `ABK_API_CONTRACT.md` §4.4–§4.10. Two shape traps to encode explicitly:
- `movies_info` → `stream_url` is an **object** (`480p`/`720p`/`1080p`/`4k`), not a string.
- `series_info` → `info.backdrop` is an **array of strings**, while `series_list` → `backdrop` is a **single string**.

### 6.1 Local-only tables

Keep the original's `item_settings_table` design — it is clean and needs no backend:

| Column | Purpose |
|---|---|
| `entityId` | the content item's server id, as text |
| `origin` | **1 = live channel, 2 = live category, 3 = movie, 4 = series** |
| `isFavorite` | bool |
| `isLocked` | bool |
| `itemOrder` | reserved |

Favourite/lock state is joined into list queries with `EXISTS` sub-selects rather than stored on the content rows — preserve that, so a catalogue refresh never wipes user state.

---

## 7. Playback flow and player requirements

### 7.1 URL derivation (four distinct paths — do not unify them)

| Content | Derivation |
|---|---|
| **Live** | `stream_url` with literal `{user}` / `{pass}` replaced |
| **Catchup** | `{host}/timeshift/{user}/{pass}/1200/{yyyy-MM-dd:kk-mm}/{id}.m3u8`, start = now − 20 h in the account timezone |
| **Movie** | `movies_info` → `stream_url` object, first non-empty of `4k` → `1080p` → `720p` → `480p`, **verbatim** |
| **Episode** | `series_info` → `seasons[].episodes[].stream_url`, **verbatim** |

Use literal string replacement (`String.replace`), **not** `replaceAll` — the original's regex-aware replacement corrupts URLs when credentials contain `$` or `\`.

### 7.2 Player capabilities the rebuild must reproduce

| Capability | Requirement |
|---|---|
| Containers | HLS (`.m3u8`), DASH (`.mpd`), SmoothStreaming (`.ism`), progressive/MPEG-TS (extension-less) |
| Source selection | By URI inference (`Util.inferContentType`), **not** by `Content-Type` header |
| User-Agent | From the account `user_agent`, applied to both engines; fall back to an app-derived UA when null |
| Extra headers | **None.** No Referer, no Cookie, no auth header on media requests |
| Extension renderers | FFmpeg/extension renderers enabled and **preferred** (`EXTENSION_RENDERER_MODE_PREFER`) — needed for non-standard audio codecs common in IPTV |
| Track selection | Audio + subtitle track picker (adaptive selection enabled, multiple overrides disabled) |
| Resize | `RESIZE_MODE_FILL` default; VLC path cycles `ScaleType` on user input, starting at `SURFACE_FILL` |
| Screen | `keepScreenOn`, `WAKE_LOCK` permission |
| Live UI | Controller hidden for live; visible for VOD |
| Buffering | Default `LoadControl` — the original tunes nothing. **Opportunity:** IPTV benefits from a larger buffer; consider tuning, but validate against live latency |
| Retry | Original has none beyond ExoPlayer defaults + `BehindLiveWindowException` re-prepare. **Opportunity:** add a bounded reconnect for live streams |
| Orientation | `sensorLandscape` pinned, `configChanges="screenSize\|orientation\|keyboardHidden"` — no recreate on rotation |
| Cleartext | `usesCleartextTraffic="true"` required — streams and the control API are `http://` |

### 7.3 Player-selection matrix

| Content | Pref | 0 | 1 | 2 | 3 |
|---|---|---|---|---|---|
| Live | `playerLive` | libVLC | ExoPlayer | ExoPlayer* | ExoPlayer* |
| Movies | `playerMovies` | libVLC | ExoPlayer | MX Player (intent) | VLC (intent) |
| Series | `playerSeries` | libVLC | ExoPlayer | MX Player (intent) | VLC (intent) |
| Archive | `playerArchive` | — | — | — | — |

\* The original collapses live indices 1/2/3 to ExoPlayer — external players are not honoured for live TV. `playerArchive` is written by settings but **never read**; catchup always uses ExoPlayer. Decide deliberately whether to fix or preserve these.

External-player intents (`p189q7.C3098b`): `com.mxtech.videoplayer.ad` and `org.videolan.vlc`; when absent, open `https://play.google.com/store/apps/details?id=<pkg>`.

### 7.4 TV / leanback requirements

- `LEANBACK_LAUNCHER` category on the entry activity; `android:banner`.
- `uses-feature` `android.software.leanback` and `android.hardware.touchscreen` both `required="false"`.
- D-pad focus handling throughout — the original ships custom `FocusFixFrameLayout` and `GridLayoutManager` helpers for exactly this.
- Number-key direct channel entry in Live TV.
- Design baseline 1280×720 dp landscape.

---

## 8. Anti-tamper considerations

The original ships **two** independent tripwires. Both must be understood before reusing any original artefact.

### 8.1 Native package check

`LiveActivity.setTimeZone(Context)` is a misleadingly-named JNI stub that tail-calls `checkPackage()`. That function reads `context.getPackageName()` and searches for the literal substring `com.mbm_soft.eliaapro`; on failure it calls `std::terminate()` → immediate `SIGABRT` when Live TV opens.

### 8.2 Java package check

`C2606a.mo11198f0()` returns `"com.mbm_soft.eliaapro".contains("iaap")` from a **hard-coded literal**, not from `getPackageName()`. The base view-model calls `onCleared()` in its own constructor when this returns `false`, disposing every subscription bag immediately — the app then shows empty screens with no error. Easy to miss, hard to diagnose.

### 8.3 Consequences for the rebuild

| Choice | Consequence |
|---|---|
| **Clean-room reimplementation** (recommended) | Neither trap applies. The XOR key and base URL are recovered as plain constants — `libnative-lib.so` is not needed. Do not copy the §8.2 idiom. |
| **Reuse `libnative-lib.so`** | The new `applicationId` **must contain `com.mbm_soft.eliaapro` as a substring**. This is a hard constraint that effectively forces you to keep the original package name. Strongly discouraged. |

If you want equivalent hardening in the rebuild, implement it deliberately (integrity check, signature pinning) rather than porting these two.

---

## 9. Unresolved blockers for Phase 2

Ordered by how likely each is to stop a rebuild from working.

| # | Blocker | Impact | How to resolve |
|---|---|---|---|
| 1 | **Live-testing gate** | Nothing below can be settled without contacting the backend, which Phase 1 forbade. | Phase 2 must begin with an authorised connectivity test using a valid account. |
| 2 | **Middleware client validation** | If the server allow-lists `model`, `mac`, `group`, or checks a control-plane User-Agent, a rebuilt client may be rejected despite a correct payload. | Compare a rebuilt request against a captured original request, field by field. |
| 3 | **Error envelope for content modes** | The client parses list modes as bare JSON arrays. If errors return an object, parsing throws — and the original swallows it. A rebuild needs a real error path. | Observe one deliberate failure (e.g. an invalid `movie_id`). |
| 4 | **Activation quota** (`act_limit` / `act_cnt`) | On Android 10+ the MAC is always `02:00:00:00:00:00`, so device identity is non-unique. A quota keyed on it may behave unexpectedly. | Test on ≥2 devices with the same account. |
| 5 | **`status` 100 vs 101** | Both authorise today. If they encode trial vs. paid, feature gating may be needed. | Observe both from the server. |
| 6 | **Live `stream_url` shape** | The client never inspects it, so its scheme/format is unknown. Player-capability assumptions rest on inference. | Observe one `channels` response. |
| 7 | **Remote-config `activity` value** | If Remote Config currently publishes a non-empty value, the native constant is not the live endpoint. | Read the current Remote Config for project `eliaapro`. |
| 8 | **Version gating** | `apk_ver_code` / `force_update` may gate API access server-side, not just prompt for an update. | Test with a version string below and above the server value. |
| 9 | **ABK ↔ Eliaa Pro relationship** | No ABK branding exists in this APK. If ABK is a different build, endpoint/key/branding may all differ. | Confirm with the product owner which artefact is authoritative. |

### 9.1 Non-blocking but worth deciding early

- Keep libVLC, or ship Media3/ExoPlayer only? Dropping VLC removes ~8 native libraries per ABI and a large share of APK size, at the cost of codec coverage for unusual streams.
- Keep the 4-way player-selection UX, or simplify to internal/external?
- Keep the 24 h live cache, or shorten it? A 24 h TTL means channel-lineup changes take up to a day to appear.
- Move the control-plane API to HTTPS? That is a server-side change, but it should be raised now.

---

## 10. Definition of done for Phase 2

The rebuild is functionally complete when this chain works end to end against the live backend:

```
resolve base URL → login/activate → status ∈ {100,101} → persist session
   → packages + channels → cache to DB → render categories → render channels
   → select channel → substitute {user}/{pass} → play
   → EPG Now/Next renders in the account timezone
   → movies: categories → list → info → quality select → play
   → series: categories → list → info → season → episode → play
   → catchup: archive entry → timeshift URL → play
   → favourites, locks and search work locally and survive a catalogue refresh
```

Plus, as improvements over the original:
- Every failure in that chain produces a visible, actionable error rather than a blank screen.
- Credentials are stored encrypted and excluded from backup.
- A Logout action exists.
- No main-thread database access.

---

*Companion documents: `ABK_STATIC_RECOVERY_REPORT.md`, `ABK_API_CONTRACT.md`.*
