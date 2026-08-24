# ABK API Contract — Recovered from APK

**Source:** static analysis of the JADX-decompiled `com.mbm_soft.eliaapro` v3.4 (`versionCode` 24).
**Scope rule:** every statement below is derived from local source or binary evidence. **No request was ever sent to the backend, and no response sample was observed.** Consequently this document contains **no example request or response payloads** — only the field names, types and structures the client is provably built to emit and parse.

Confidence legend: **C** = Confirmed (direct evidence) · **I** = Strongly inferred · **U** = Unresolved.

---

## 1. Transport

### 1.1 Content API (all `mode` operations)

| Property | Value | Confidence | Evidence |
|---|---|---|---|
| Method | `POST` | **C** | `C1867b.m8505b` → `C2110a.k(String)` sets `f9315b = 1` (`p074g1/C2110a.java:526-530`) |
| URL | `{BASE_URL}` — no path suffix, no query string | **C** | `AppApiHelper.mo65I0`…`mo74w0` all use `C1867b.m8505b(f7849a)` |
| Content-Type | `application/x-www-form-urlencoded` | **C** | `FormBody.Builder.add()` (`C2110a.java:1101-1105`) |
| Body | single field `json` | **C** | `.m9405s("json", …)` in all eight POST helpers |
| Field value | `XOR(payload_json_string)`, then standard form URL-encoding | **C** | `DecInterceptor.m7815a(jSONObject.toString())` |
| Headers added by app | *none* | **C** | no `addHeaders`/`m9384p` call on the POST path |
| Response body | XOR-obfuscated JSON, decoded in-place before parsing | **C** | `C1717a` interceptor on the shared FAN client (`QuickPlayerApp.java:176`) |
| Response decode condition | **only when `response.isSuccessful()`**; non-2xx bodies pass through raw | **C** | `C1717a.java:15-17` |
| Post-decode transform | `.trim()` | **C** | `C1717a.java:23` |
| Parser | Gson (`@SerializedName` + `@Expose`) | **C** | model annotations `p068f6.InterfaceC2027c` / `InterfaceC2025a` |
| List parsing | `$Gson$Types.newParameterizedTypeWithOwner(null, List.class, T.class)` ⇒ decoded body must be a **bare JSON array** | **C** | `C1866a.m8498M` (`p048d8/C1866a.java:44-46`) |
| Threading | `subscribeOn(Schedulers.io())`, `observeOn(AndroidSchedulers.mainThread())` | **C** | every call site |

### 1.2 Base URL resolution

```
BASE_URL := FirebaseRemoteConfig.getString("activity")            if non-empty
            otherwise the native constant
```

| Item | Value | Confidence |
|---|---|---|
| Native constant | `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` | **C** |
| Remote Config key | `activity` | **C** |
| Remote Config min fetch interval | 360 s | **C** |

Evidence: `AppApiHelper.java:16,23` (native `getValue()`); disassembly `Java_..._getValue` @ `0x1ed9c` → `0x15f64`; `IntroActivity.m7860v0()` + `C1723a.onComplete` → `AppApiHelper.m7814a(remoteConfig.getString("activity"))`.

### 1.3 Payload obfuscation

Repeating-key XOR over UTF-16 `char` values, symmetric for request and response.

| Item | Value | Confidence |
|---|---|---|
| Key | `r+3e>@y](7wEEM[` | **C** |
| Key bytes | `72 2b 33 65 3e 40 79 5d 28 37 77 45 45 4d 5b` | **C** |
| Key length | 15 | **C** |

```
out[i] = plain[i] XOR key[i % 15]
```

Evidence: `DecInterceptor.java:6-24`; disassembly `Java_..._getKeyValue` @ `0x1edb0` → `0x15dd0`; hexdump at that offset; identical bytes confirmed on `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`.

Reference implementation (verified locally against the decompiled algorithm; round-trip exact):
```python
KEY = "r+3e>@y](7wEEM["
def xor_codec(s: str) -> str:
    return "".join(chr(ord(c) ^ ord(KEY[i % len(KEY)])) for i, c in enumerate(s))
```
Both operands are ASCII, so ciphertext stays below `0x80` (control characters included) — which is why it travels as a percent-encoded form field rather than Base64.

### 1.4 EPG API (separate channel)

| Property | Value | Confidence | Evidence |
|---|---|---|---|
| Method | `GET` | **C** | `C1867b.m8504a` → `C2110a.j(String)` sets `f9300b = 0` |
| URL | value of `PREF_KEY_PLAYER_API` (the `player_api` field from login), used as a complete URL | **C** | `AppApiHelper.mo68g0(map, str)`; `C1757c.m8025E` passes `mo11225w()` |
| Parameters | query string | **C** | `m9385q(map)` → `HttpUrl.Builder.addQueryParameter` (`C2110a.java:748-757`) |
| OkHttp client | **fresh `new OkHttpClient()`, interceptor-free** | **C** | `AppApiHelper.java:46` — `.m9386r(new OkHttpClient().newBuilder().build())` |
| Obfuscation | **none** — plain JSON in, plain JSON out | **C** | consequence of the interceptor-free client |

---

## 2. Authentication

### 2.1 Model

There is **no token, no session cookie, and no `Authorization` header**. Credentials are re-sent inside the obfuscated body of every content request.

Two mutually exclusive modes, selected by `PREF_KEY_ACTIVATION_TYPE` (boolean, default `true`):

| Mode | Flag | Fields emitted |
|---|---|---|
| Activation code | `true` | `code = <activation code>` |
| Username/password | `false` | `code = "00000000"` (literal), `user = <username>`, `pass = <password>` |

Evidence: `C2606a.m11178P0()` (`p145m6/C2606a.java:225-243`).

### 2.2 Base request envelope

Present on **every** content request:

| Field | Type | Source | Confidence |
|---|---|---|---|
| `code` | string | `PREF_KEY_ACTIVE_CODE`, or literal `"00000000"` in user/pass mode | **C** |
| `user` | string | `PREF_KEY_USERNAME` — **only in user/pass mode** | **C** |
| `pass` | string | `PREF_KEY_PASSWORD` — **only in user/pass mode** | **C** |
| `mac` | string | `PREF_KEY_MAC_ADDRESS` (colon-separated lowercase hex) | **C** |
| `sn` | string | same value as `mac` (`PREF_KEY_SERIAL_NUMBER` has no reader) | **C** |
| `model` | string | `android.os.Build.DEVICE` | **C** |
| `group` | number | integer literal `0`, never varied | **C** |
| `mode` | string | operation discriminator, added by `mo11168K` / `mo11151B` / `mo11208l0` | **C** |
| `movie_id` | string | only for `mode=movies_info` | **C** |
| `series_id` | string | only for `mode=series_info` | **C** |

MAC derivation (`p189q7.C3104h.m13754b`): `wlan0` hardware address → else `eth0` → else `02:00:00:00:00:00`. **C**

### 2.3 Success criterion

```
authorised  ⟺  response.status == 100 || response.status == 101
```
Anything else ⇒ show `response.message` on the intro screen and stop. **C** (`C1730c.m7867s/m7869u`, lines 22-28 and 48-54).

The semantic difference between `100` and `101` is **U** — the client treats them identically.

### 2.4 Session persistence

On success the client writes nine response fields into `SharedPreferences("snap_pref")` via `mo11164H0(...)` (`C2606a.java:187-197`), in this argument order:

| Arg | Response field | Pref key | Later use |
|---|---|---|---|
| 1 | `message` | `PREF_KEY_MESSAGE` | settings display |
| 2 | `expire` | `PREF_KEY_EXPIRE` | settings display only (never compared to clock) |
| 3 | `user_agent` | `PREF_KEY_USER_AGENT` | **playback User-Agent** (ExoPlayer + libVLC) |
| 4 | `player_api` | `PREF_KEY_PLAYER_API` | **EPG endpoint URL** |
| 5 | `host` | `PREF_KEY_HOST` | **catchup/timeshift base** |
| 6 | `username` | `PREF_KEY_USERNAME` | `{user}` substitution + EPG query |
| 7 | `password` | `PREF_KEY_PASSWORD` | `{pass}` substitution + EPG query |
| 8 | `epg_api` | `PREF_KEY_EPG_API` | **written, never read** |
| 9 | `timezone` | `PREF_KEY_TIME_ZONE` | EPG formatting + catchup timestamp |

> The server may **rewrite** the stored username and password. In activation-code mode this is the only way the client obtains a credential pair.

### 2.5 Logout / expiry

**NOT FOUND.** No code path clears credentials. `expire` is never evaluated client-side. Enforcement is entirely server-side via `status` + `message` on the next launch.

---

## 3. Operations

Every operation in §3.1–§3.12 shares the transport of §1.1 and the envelope of §2.2. Only `mode` and any extra field differ.

---

### 3.1 `active` — Activate by code

| | |
|---|---|
| **Name** | Activate |
| **Method / URL** | `POST {BASE_URL}` |
| **`mode`** | `active` |
| **Extra request fields** | none |
| **Auth inputs** | `code` (activation code), `mac`, `sn`, `model`, `group` |
| **Response** | single object → `r6.C3164a` (§4.1) |
| **Key fields** | `status`, `message`, `host`, `player_api`, `epg_api`, `username`, `password`, `user_agent`, `timezone`, `expire`, `apk_ver_code`, `force_update`, `update_url` |
| **Consumer** | `C1730c.m7871A()` → `IntroActivity` |
| **Evidence** | `C1730c.java:90` — `mo66Q(mo11168K("active"))` |
| **Confidence** | **C** |

---

### 3.2 `login` — Log in with username/password

| | |
|---|---|
| **Name** | Login |
| **Method / URL** | `POST {BASE_URL}` |
| **`mode`** | `login` |
| **Extra request fields** | none |
| **Auth inputs** | `code = "00000000"`, `user`, `pass`, `mac`, `sn`, `model`, `group` |
| **Response** | single object → `r6.C3164a` (§4.1) |
| **Key fields** | identical to §3.1 |
| **Consumer** | `C1730c.m7879z()` → `IntroActivity` |
| **Evidence** | `C1730c.java:163` — `mo66Q(mo11168K(FirebaseAnalytics.Event.LOGIN))`; `FirebaseAnalytics.Event.LOGIN == "login"` |
| **Confidence** | **C** |

---

### 3.3 `packages` — Live TV categories

| | |
|---|---|
| **Name** | Get live categories |
| **Method / URL** | `POST {BASE_URL}` |
| **`mode`** | `packages` |
| **Extra request fields** | none |
| **Auth inputs** | base envelope |
| **Response** | **array** → `List<q6.C3087c>` (§4.2) |
| **Key fields** | `id`, `category_name`, `category_icon`, `view_order`, `ch_count`, `isLocked`, `category_type`, `parent` |
| **Consumer** | `C1757c.m8033c0()` — zipped with §3.4, persisted to `liveCat_table` |
| **Evidence** | `C1757c.java:301` — `mo72r0(mo11168K("packages"))` |
| **Confidence** | **C** |

Client post-processing: a synthetic favourites row is inserted at index 0 before persisting —
`C3087c("-1", "FAVORITE", 0, "", "0", 1, false, 0)` (`C1757c.java:130`).

---

### 3.4 `channels` — Live TV channels

| | |
|---|---|
| **Name** | Get live channels |
| **Method / URL** | `POST {BASE_URL}` |
| **`mode`** | `channels` |
| **Extra request fields** | none |
| **Auth inputs** | base envelope |
| **Response** | **array** → `List<q6.C3088d>` (§4.3) |
| **Key fields** | `id` (**the stream id**), `stream_display_name`, `category_id`, `stream_icon`, `view_order`, `tv_archive`, `has_epg`, **`stream_url`** |
| **Consumer** | `C1757c.m8033c0()` — persisted to `live_table` |
| **Evidence** | `C1757c.java:302` — `mo73v0(mo11168K("channels"))` |
| **Confidence** | **C** |

`stream_url` is a **fully-qualified playback URL containing the literal placeholders `{user}` and `{pass}`** — see §5.1. No pagination or category filter parameter exists; the full catalogue is returned in one response. Issued concurrently with §3.3 via `Flowable.zip`.

---

### 3.5 `movies_cat` — Movie categories

| | |
|---|---|
| **Name** | Get movie categories |
| **`mode`** | `movies_cat` |
| **Extra request fields** | none |
| **Response** | **array** → `List<q6.C3091g>` (§4.4) |
| **Key fields** | `id`, `category_name`, `category_icon`, `isLocked`, `stream_count`, `cat_order`, `parent_id` |
| **Consumer** | `C1767d` → `movie_Cat_table` → `MoviesActivity` |
| **Evidence** | `C1767d.java:224` — `mo67W(mo11168K("movies_cat"))` |
| **Confidence** | **C** |

---

### 3.6 `movies_list` — Movie catalogue

| | |
|---|---|
| **Name** | Get movies |
| **`mode`** | `movies_list` |
| **Extra request fields** | none |
| **Response** | **array** → `List<q6.C3090f>` (§4.5) |
| **Key fields** | `id`, `stream_display_name`, `category_id`, `stream_icon`, `backdrop`, `view_order`, `plot`, `rating`, `genre`, `cast`, `year`, `stream_url` |
| **Consumer** | `C1767d` → `movie_table` → `MoviesActivity` |
| **Evidence** | `C1767d.java:157` — `mo74w0(mo11168K("movies_list"))` |
| **Confidence** | **C** |

`stream_url` is persisted but **never read by any UI path** — playback goes through §3.8. **C**

---

### 3.7 `movies_latest` — Latest movies rail

| | |
|---|---|
| **Name** | Get latest movies |
| **`mode`** | `movies_latest` |
| **Extra request fields** | none |
| **Response** | **array** → `List<q6.C3090f>` (§4.5) |
| **Consumer** | `C1722c` → Home "latest movies" rail |
| **Evidence** | `C1722c.java:103` — `mo74w0(mo11168K("movies_latest"))` |
| **Confidence** | **C** |

Result-count limiting is server-side; the client sends no `limit`. **C**

---

### 3.8 `movies_info` — Movie detail

| | |
|---|---|
| **Name** | Get movie info |
| **`mode`** | `movies_info` |
| **Extra request fields** | `movie_id` (string) — the `id` from §3.6 |
| **Response** | **array** → `List<q6.C3092h>` (§4.6); the client reads element `[0]` |
| **Key fields** | `id`, `title`, `trailer`, `catid`, `icon`, **`stream_url` (object, not string)**, `genre`, `MPAA`, `release_date`, `plot`, `cast`, `duration`, `rating`, `year` |
| **Consumer** | `C1760c` → `MovieInfoActivity` |
| **Evidence** | `C1760c.java:133` — `mo65I0(mo11151B("movies_info", str))`; builder `C2606a.java:76-85` |
| **Confidence** | **C** |

> `stream_url` here is a **quality map object** (`q6.C3096l`), not a string — unlike every other model. See §4.7.

---

### 3.9 `series_cat` — Series categories

| | |
|---|---|
| **Name** | Get series categories |
| **`mode`** | `series_cat` |
| **Extra request fields** | none |
| **Response** | **array** → `List<q6.C3095k>` (§4.8) |
| **Key fields** | `id`, `category_name`, `category_icon`, `isLocked`, `stream_count`, `cat_order`, `parent_id` |
| **Consumer** | `C1774d` → `seriesCat_table` → `SeriesActivity` |
| **Evidence** | `C1774d.java:158` — `mo71r(mo11168K("series_cat"))` |
| **Confidence** | **C** |

Field-identical to §3.5 but a distinct model, table and DAO.

---

### 3.10 `series_list` — Series catalogue

| | |
|---|---|
| **Name** | Get series |
| **`mode`** | `series_list` |
| **Extra request fields** | none |
| **Response** | **array** → `List<q6.C3094j>` (§4.9) |
| **Key fields** | `id`, `title`, `icon`, `catid`, `icon_big`, `backdrop`, `genre`, `plot`, `cast`, `rating`, `director`, `releaseDate`, `view_order` |
| **Consumer** | `C1774d` → `series_table` → `SeriesActivity` |
| **Evidence** | `C1774d.java:189` — `mo69j0(mo11168K("series_list"))` |
| **Confidence** | **C** |

---

### 3.11 `series_latest` — Latest series rail

| | |
|---|---|
| **Name** | Get latest series |
| **`mode`** | `series_latest` |
| **Extra request fields** | none |
| **Response** | **array** → `List<q6.C3094j>` (§4.9) |
| **Consumer** | `C1722c` → Home "latest series" rail |
| **Evidence** | `C1722c.java:119` — `mo69j0(mo11168K("series_latest"))` |
| **Confidence** | **C** |

---

### 3.12 `series_info` — Series detail with seasons and episodes

| | |
|---|---|
| **Name** | Get series info |
| **`mode`** | `series_info` |
| **Extra request fields** | `series_id` (string) — the `id` from §3.10 |
| **Response** | **single object** → `t6.C3314b` (§4.10) |
| **Structure** | `{ "info": t6.C3313a, "seasons": [ q6.C3093i ] }` where `C3093i = { "season_num": int, "episodes": [ q6.C3085a ] }` |
| **Key fields** | `info.title`, `info.plot`, `info.trailer`, `info.backdrop` (**array of strings**), `seasons[].season_num`, `seasons[].episodes[].episode_num`, `.episode_name`, **`.stream_url`** |
| **Consumer** | `C1779c` → `SeriesInfoActivity` |
| **Evidence** | `C1779c.java:127` — `mo70q(mo11208l0("series_info", str))`; builder `C2606a.java:344-353` |
| **Confidence** | **C** |

Episode `stream_url` is a directly playable URL used **verbatim** — no `{user}`/`{pass}` substitution. **C**

---

### 3.13 `get_short_epg` — Short EPG (separate Xtream Codes endpoint)

| | |
|---|---|
| **Name** | Get short EPG |
| **Method** | `GET` |
| **URL** | value of `PREF_KEY_PLAYER_API` (login response `player_api`) |
| **Parameters** | query string: `username`, `password`, `action=get_short_epg`, `stream_id` |
| **Auth inputs** | `username` + `password` as **plaintext query parameters** |
| **Obfuscation** | **none** — client uses an interceptor-free OkHttp instance |
| **Response** | plain JSON object → `s6.C3235b` = `{ "epg_listings": [ s6.C3234a ] }` (§4.11) |
| **Key fields** | `epg_listings[].title` (**Base64-encoded**), `.start`, `.end` |
| **Consumer** | `C1757c.m8025E()` → `LiveActivity.m7885C1()` — renders only elements `[0]` (now) and `[1]` (next) |
| **Evidence** | `C2606a.mo11224v` (`C2606a.java:371-379`); `AppApiHelper.mo68g0` (`AppApiHelper.java:44-47`); `C1757c.java:209`; Base64 decode at `LiveActivity.java:854,860` |
| **Confidence** | **C** |

Time parsing (`LiveActivity.m7982m1`): `start` / `end` are parsed with `SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ENGLISH)` in `TimeZone.getTimeZone(PREF_KEY_TIME_ZONE)` and rendered as `HH:mm`. **C**

This is the only **confirmed genuine Xtream Codes / XUI `player_api.php`** interaction in the app.

---

### 3.14 Operations that do **not** exist

| Capability | Status | Note |
|---|---|---|
| Search | **NOT FOUND** | Local Room query: `WHERE <title> LIKE '%'||?||'%'` on `live_table` / `movie_table` / `series_table` |
| Favourites | **NOT FOUND** | Local only — `item_settings_table`, `origin` 1/2/3/4 |
| Watch history / resume | **NOT FOUND** | No table, no field, no call |
| Parental lock sync | **NOT FOUND** | Local only; PIN in `PREF_KEY_USER_PASSWORD` (default `"12345"`) |
| Bootstrap / config endpoint | **NOT FOUND** | Firebase Remote Config fills this role |
| Full EPG / XMLTV | **NOT FOUND** | `epg_api` is stored but never read |
| Xtream `get_live_streams` / `get_vod_streams` / `get_series` | **NOT FOUND** | Content comes exclusively from the `mode` API |
| Pagination | **NOT FOUND** | No `page`/`limit`/`offset` field anywhere |
| Token refresh | **NOT FOUND** | No tokens exist |

---

## 4. Response models

All fields carry Gson `@SerializedName` + `@Expose`. Types are as declared in the decompiled source. "Nullable" indicates the declared Java type permits `null`; **crash risk** flags places where the client dereferences without a guard.

### 4.1 `r6.C3164a` — Account / ServerInfo

Response of §3.1 and §3.2.

| JSON | Java type | Read by client | Persisted | Meaning |
|---|---|---|---|---|
| `status` | `Integer` | ✔ | — | **100 or 101 ⇒ success.** *Crash risk:* `.intValue()` unguarded |
| `message` | `String` | ✔ | `PREF_KEY_MESSAGE` | error text / notice |
| `server_name` | `String` | ✘ | — | |
| `apk_ver_code` | `String` | ✔ | — | parsed as `double`, compared to `"3.4"`; parse failure ⇒ treated as `3.4` |
| `expire` | `String` | ✔ | `PREF_KEY_EXPIRE` | display only |
| `user_agent` | `String` | ✔ | `PREF_KEY_USER_AGENT` | **playback UA** |
| `username` | `String` | ✔ | `PREF_KEY_USERNAME` | **overwrites local**; feeds `{user}` |
| `password` | `String` | ✔ | `PREF_KEY_PASSWORD` | **overwrites local**; feeds `{pass}` |
| `max_connections` | `String` | ✘ | — | Xtream vocabulary |
| `allowed_output_formats` | `List<String>` | ✘ | — | Xtream vocabulary |
| `host` | `String` | ✔ | `PREF_KEY_HOST` | **catchup base URL** |
| `player_api` | `String` | ✔ | `PREF_KEY_PLAYER_API` | **EPG endpoint URL** |
| `epg_api` | `String` | ✔ | `PREF_KEY_EPG_API` | write-only |
| `code_id` | `String` | ✘ | — | |
| `force_update` | `Integer` | ✔ | — | `1` ⇒ mandatory. *Crash risk:* `.intValue()` unguarded |
| `update_url` | `String` | ✔ | — | APK download URL |
| `apk_page` | `String` | ✘ | — | |
| `update_ch` | `String` | ✘ | — | |
| `act_limit` | `Integer` | ✘ | — | activation quota (**I**) |
| `act_cnt` | `Integer` | ✘ | — | activation count (**I**) |
| `adm_act_cnt` | `Integer` | ✘ | — | |
| `rememberVal` | `Integer` | ✘ | — | |
| `timezone` | `String` | ✔ | `PREF_KEY_TIME_ZONE` | Java TimeZone id |

Source: `p198r6/C3164a.java`.

### 4.2 `q6.C3087c` — Live category

| JSON | Java type | Room column | Notes |
|---|---|---|---|
| `id` | `String` | `id` (PK) | joins `C3088d.category_id`; `"-1"` reserved for the client-synthesised FAVORITE row |
| `category_name` | `String` | `categoryName` | |
| `category_type` | `Integer` | `categoryType` | never read in UI |
| `category_icon` | `String` | `categoryIcon` | absolute URL |
| `view_order` | `String` | `viewOrder` | sorted `CAST(... AS integer) ASC` |
| `ch_count` | `Integer` | `chCount` | |
| `isLocked` | `Boolean` | `isLocked` | **superseded locally** by `item_settings_table` (`origin=2`) |
| `parent` | `Integer` | `parent` | never read in UI |

Source: `p188q6/C3087c.java`; DDL `AppDatabase_Impl.java:66`.

### 4.3 `q6.C3088d` — LiveChannel

| JSON | Java type | Room column | Notes |
|---|---|---|---|
| **`id`** | `Integer` | `id` | **THE STREAM ID.** Used for EPG `stream_id`, catchup path, favourite/lock key, current-channel dedup |
| `stream_display_name` | `String` | `streamDisplayName` | title; local search target |
| `category_id` | `Integer` | `categoryId` | joins `C3087c.id` |
| `stream_icon` | `String` | `streamIcon` | absolute URL → Glide |
| `view_order` | `Integer` | `viewOrder` | sort key |
| `tv_archive` | `int` | `tvArchive` NOT NULL | `!= 0` ⇒ catchup offered |
| `has_epg` | `int` | `hasEPG` NOT NULL | |
| **`stream_url`** | `String` | `streamUrl` | **playback URL template with `{user}` / `{pass}`** — see §5.1 |
| *(none)* | `int` | `streamId` PK AUTOINCREMENT | **local row id — not a server id** |
| *(none)* | `int` | `isFavorite` DEFAULT 0 | computed by SQL sub-select |
| *(none)* | `int` | `isLocked` DEFAULT 0 | computed by SQL sub-select |

Source: `p188q6/C3088d.java`; DDL `AppDatabase_Impl.java:65`.

### 4.4 `q6.C3091g` — Movie category

| JSON | Java type | Room column |
|---|---|---|
| `id` | `String` | `catId` (PK) |
| `category_name` | `String` | `catName` |
| `category_icon` | `String` | `catIcon` |
| `isLocked` | `Boolean` | `isLocked` |
| `stream_count` | `Integer` | `streamCount` |
| `cat_order` | `String` | `catOrder` |
| `parent_id` | `String` | `parentId` |

Source: `p188q6/C3091g.java`; DDL `AppDatabase_Impl.java:68`.

### 4.5 `q6.C3090f` — Movie list item

| JSON | Java type | Room column | Notes |
|---|---|---|---|
| `id` | `String` | `id` (PK) | passed as `movie_id` to §3.8 and as intent extra `"id"` |
| `stream_display_name` | `String` | `streamDisplayName` | search target |
| `category_id` | `String` | `categoryId` | |
| `stream_icon` | `String` | `streamIcon` | poster |
| `backdrop` | `String` | `backdrop` | |
| `view_order` | `String` | `viewOrder` | sort key |
| `plot` | `String` | `plot` | |
| `rating` | `String` | `rating` | |
| `genre` | `String` | `genre` | |
| `cast` | `String` | `cast` | |
| `year` | `String` | `year` | |
| `stream_url` | `String` | `streamUrl` | **persisted but never read** |

Source: `p188q6/C3090f.java`; DDL `AppDatabase_Impl.java:67`.

### 4.6 `q6.C3092h` — Movie detail

| JSON | Java type | Notes |
|---|---|---|
| `id` | `String` | |
| `title` | `String` | intent extra `stream_name` |
| `trailer` | `String` | → `YouTubePlayerActivity` extra `trailer_link` |
| `catid` | `Integer` | |
| `icon` | `String` | |
| **`stream_url`** | **`q6.C3096l` (object)** | §4.7 |
| `genre` | `String` | |
| `MPAA` | `String` | |
| `release_date` | `String` | |
| `plot` | `String` | |
| `cast` | `String` | |
| `duration` | `String` | |
| `rating` | `String` | |
| `year` | `String` | |

Not persisted to Room. Source: `p188q6/C3092h.java`.

### 4.7 `q6.C3096l` — Movie stream quality map

| JSON | Java type | Selection priority |
|---|---|---|
| `4k` | `String` | **1st** |
| `1080p` | `String` | 2nd |
| `720p` | `String` | 3rd |
| `480p` | `String` | 4th |

Each value is a complete, directly playable URL. The client picks the first non-`""` value in the order above (`MovieInfoActivity.java:88-96`).

> **Contract requirement:** absent qualities must be emitted as `""`, **never `null`** — the client calls `.equals("")` on all four without a null guard.

Source: `p188q6/C3096l.java`.

### 4.8 `q6.C3095k` — Series category

Field-identical to §4.4 (`id`→`catId`, `category_name`→`catName`, `category_icon`→`catIcon`, `isLocked`, `stream_count`→`streamCount`, `cat_order`→`catOrder`, `parent_id`→`parentId`). Distinct table `seriesCat_table`.

Source: `p188q6/C3095k.java`; DDL `AppDatabase_Impl.java:70`.

### 4.9 `q6.C3094j` — Series list item

| JSON | Java type | Room column | Notes |
|---|---|---|---|
| `id` | `String` | `id` (PK) | passed as `series_id` to §3.12 |
| `title` | `String` | `title` | search target |
| `icon` | `String` | `icon` | poster |
| `catid` | `String` | `catid` | joins `C3095k.id` |
| `icon_big` | `String` | `iconBig` | |
| `backdrop` | `String` | `backdrop` | **string here** (contrast §4.10) |
| `genre` | `String` | `genre` | |
| `plot` | `String` | `plot` | |
| `cast` | `String` | `cast` | |
| `rating` | `String` | `rating` | |
| `director` | `String` | `director` | |
| `releaseDate` | `String` | `releaseDate` | camelCase in JSON |
| `view_order` | `int` | `viewOrder` NOT NULL | sort key |

Source: `p188q6/C3094j.java`; DDL `AppDatabase_Impl.java:69`.

### 4.10 `t6.C3314b` / `t6.C3313a` / `q6.C3093i` / `q6.C3085a` — Series detail tree

**`t6.C3314b`** (root):

| JSON | Java type |
|---|---|
| `info` | `t6.C3313a` |
| `seasons` | `List<q6.C3093i>` |

**`t6.C3313a`** (`info`):

| JSON | Java type | Read | Notes |
|---|---|---|---|
| `id` | `String` | ✘ | |
| `title` | `String` | ✔ | |
| `icon` | `String` | ✔ | |
| `catid` | `String` | ✘ | |
| `icon_big` | `String` | ✘ | |
| `backdrop` | **`List<String>`** | ✘ | **array here**, unlike §4.9 |
| `genre` | `String` | ✔ | |
| `plot` | `String` | ✔ | |
| `cast` | `String` | ✔ | |
| `rating` | `String` | ✔ | |
| `director` | `String` | ✘ | |
| `releaseDate` | `String` | ✔ | |
| `trailer` | `String` | ✔ | → `YouTubePlayerActivity` |
| `likes` | `Integer` | ✘ | |
| `dislikes` | `Integer` | ✘ | |

**`q6.C3093i`** (season): `season_num` (`int`), `episodes` (`List<q6.C3085a>`).

**`q6.C3085a`** (episode): `episode_num` (`String`), `episode_name` (`String`), **`stream_url` (`String`)** — used verbatim as the playback URL.

Sources: `p218t6/C3314b.java`, `p218t6/C3313a.java`, `p188q6/C3093i.java`, `p188q6/C3085a.java`.

### 4.11 `s6.C3235b` / `s6.C3234a` — EPG

**`s6.C3235b`**: `epg_listings` → `List<s6.C3234a>`, default `null`, `Serializable`.

**`s6.C3234a`** (all `String`, `Serializable`):

| JSON | Read | Notes |
|---|---|---|
| `id` | ✘ | |
| `epg_id` | ✘ | |
| **`title`** | ✔ | **Base64-encoded** — decoded with `Base64.decode(v, Base64.DEFAULT)` |
| `lang` | ✘ | |
| **`start`** | ✔ | `"yyyy-MM-dd HH:mm:ss"` in account timezone |
| **`end`** | ✔ | same format |
| `description` | ✘ | presumably Base64 too (**I**) — never decoded |
| `channel_id` | ✘ | |
| `start_timestamp` | ✘ | |
| `stop_timestamp` | ✘ | |

Only elements `[0]` (now) and `[1]` (next) are rendered. Sources: `p208s6/C3235b.java`, `p208s6/C3234a.java`, `LiveActivity.java:850-864`.

---

## 5. Stream URL derivation

### 5.1 Live TV — **C**

```
playbackUrl = channel.stream_url
                     .replace("{user}", PREF_KEY_USERNAME)
                     .replace("{pass}", PREF_KEY_PASSWORD)
```
The server supplies a complete URL; the client performs only these two literal replacements and `Uri.parse`. There is **no** client-side scheme/host/port/path/extension assembly, and **no** format negotiation.

Evidence: `LiveActivity.java:1019`, `:1473`, `:1502` — identical `replaceAll(Pattern.quote("{user}"), …).replaceAll(Pattern.quote("{pass}"), …)`.

> Implementation note: the original uses `String.replaceAll`, whose *replacement* argument is regex-aware. Credentials containing `$` or `\` corrupt the URL. Use plain `String.replace` (literal) in a rebuild.

### 5.2 Catchup / timeshift — **C**

```
{PREF_KEY_HOST}/timeshift/{username}/{password}/1200/{yyyy-MM-dd:kk-mm}/{streamId}.m3u8
```

| Segment | Value | Source |
|---|---|---|
| base | `PREF_KEY_HOST` (login `host`) | `C2606a.mo11196e0` |
| literal | `/timeshift/` | `C2606a.java:309` |
| `{username}` | `PREF_KEY_USERNAME` | |
| `{password}` | `PREF_KEY_PASSWORD` | |
| duration | `1200` — fixed, `TimeUnit.HOURS.toMinutes(20)` | `C1757c.m8024D` |
| start | `SimpleDateFormat("yyyy-MM-dd:kk-mm")` of `now − 20 h`, in `TimeZone.getTimeZone(PREF_KEY_TIME_ZONE)` | `C1757c.java:206-214` |
| `{streamId}` | `C3088d.id` | `LiveActivity.java:925` |
| extension | `m3u8` (hard-coded at the call site) | `LiveActivity.java:925` |

Offered only when `tv_archive != 0`. Always played in `VodActivity` (ExoPlayer), regardless of `PREF_KEY_PLAYER_TV_ARCHIVE`.

### 5.3 Movies — **C**

Verbatim from `movies_info` → `stream_url` object, first non-empty of `4k` → `1080p` → `720p` → `480p`. **No substitution applied.**

### 5.4 Series episodes — **C**

Verbatim from `series_info` → `seasons[].episodes[].stream_url`. **No substitution applied.**

---

## 6. Contract summary table

| # | Operation | Method | Endpoint | Discriminator | Extra params | Request auth | Response root | Confidence |
|---|---|---|---|---|---|---|---|---|
| 1 | Activate | POST | `{BASE_URL}` | `mode=active` | — | `code`+device | object `C3164a` | **C** |
| 2 | Login | POST | `{BASE_URL}` | `mode=login` | — | `user`/`pass`+device | object `C3164a` | **C** |
| 3 | Live categories | POST | `{BASE_URL}` | `mode=packages` | — | envelope | array `C3087c` | **C** |
| 4 | Live channels | POST | `{BASE_URL}` | `mode=channels` | — | envelope | array `C3088d` | **C** |
| 5 | Movie categories | POST | `{BASE_URL}` | `mode=movies_cat` | — | envelope | array `C3091g` | **C** |
| 6 | Movies | POST | `{BASE_URL}` | `mode=movies_list` | — | envelope | array `C3090f` | **C** |
| 7 | Latest movies | POST | `{BASE_URL}` | `mode=movies_latest` | — | envelope | array `C3090f` | **C** |
| 8 | Movie info | POST | `{BASE_URL}` | `mode=movies_info` | `movie_id` | envelope | array `C3092h` | **C** |
| 9 | Series categories | POST | `{BASE_URL}` | `mode=series_cat` | — | envelope | array `C3095k` | **C** |
| 10 | Series | POST | `{BASE_URL}` | `mode=series_list` | — | envelope | array `C3094j` | **C** |
| 11 | Latest series | POST | `{BASE_URL}` | `mode=series_latest` | — | envelope | array `C3094j` | **C** |
| 12 | Series info | POST | `{BASE_URL}` | `mode=series_info` | `series_id` | envelope | object `C3314b` | **C** |
| 13 | Short EPG | GET | `{player_api}` | `action=get_short_epg` | `stream_id` | `username`+`password` query | object `C3235b` | **C** |

---

## 7. Open contract questions

| # | Question | Status |
|---|---|---|
| 1 | Error envelope for `mode` operations 3–12 (array vs. object) | **U** — no error model exists; failures are silently swallowed |
| 2 | Difference between `status` 100 and 101 | **U** |
| 3 | Whether the middleware validates `model`, `mac`, `group`, or a control-plane User-Agent | **U** |
| 4 | Behaviour when `act_limit` is exceeded | **U** |
| 5 | Concrete shape of a live `stream_url` template | **U** — client never inspects it |
| 6 | Whether `apk_ver_code` / `force_update` gate API access server-side | **U** |
| 7 | Whether `description` in EPG is Base64 like `title` | **I** — never decoded by the client |
| 8 | Whether additional `mode` values exist beyond the 12 used | **U** |

Resolving any of these requires live interaction with the backend, which is out of scope for Phase 1.

---

*Companion documents: `ABK_STATIC_RECOVERY_REPORT.md`, `ABK_REBUILD_HANDOFF.md`.*
