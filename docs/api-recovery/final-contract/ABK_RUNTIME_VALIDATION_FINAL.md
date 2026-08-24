# ABK — Final Runtime Validation

**Target:** live v3.4 content middleware `https://header21.b-cdn.net` (the Firebase Remote Config `activity` value confirmed in Phase 2A).
**Account:** authorized test account (redacted). **Date:** 2026-08-24 (~18:41 UTC).
**Harness:** `tools/abk-compat/abk_compat.py`. Credentials from env; redacted from this document. No full credential-bearing URL is shown.

## Results

| Operation | Result | Evidence (sanitized) |
|---|---|---|
| Content endpoint | **PASS** | `POST https://header21.b-cdn.net` → HTTP 200, valid XOR content JSON |
| **Login** (`mode=login`) | **PASS** | HTTP 200, decoded account object, **`status=100`**, message "Login Success." |
| Credential rewrite | **No** | returned `username`/`password` equal the supplied ones (no rewrite) |
| **packages** (categories) | **PASS** | JSON array, **124** live categories, expected fields present |
| **channels** | **PASS** | JSON array, **8,604** channels; **8,604** have `stream_url`; **all** carry literal `{user}` and `{pass}` |
| **live playback** | **PASS** | one channel (id `308779`): `{host}/***USER***/***PASS***/308779` → HTTP 200, `Content-Type: video/mp2t`, MPEG-TS (0x47 sync), via redirect → **STREAM COMPATIBLE** |
| **EPG** (`get_short_epg`) | **NOT AVAILABLE** | endpoint reachable (HTTP 200 with a normal User-Agent), but this account returns **no listings**; all 8,604 channels report `has_epg=0`. Transport OK, no data. |
| **movies** | **PASS** | `movies_cat`=30; `movies_list`=20,484; `movies_info.stream_url` is an **object** with keys `{480p,720p,1080p,4k}` (matches static contract) |
| **series** | **PASS** | `series_cat`=36; `series_list`=7,455; `series_info` = object with `info` + `seasons[]` (episodes carry `episode_num`/`episode_name`/`stream_url`) |

## Server-role resolution (C2)

Recovered from the live login response — the four roles are now distinct and confirmed:

| Role | Value | Notes |
|---|---|---|
| **CONTENT API** | `https://header21.b-cdn.net` | XOR middleware; RC `activity`; receives `mode=*` POSTs |
| **STREAMING HOST** | `http://domaio40.hype04.site:80` | login `host`; base for live/VOD stream URLs |
| **PLAYER API** | `http://domaio40.hype04.site:80/` | login `player_api` (panel root; canonical Xtream EPG path is `…/player_api.php`) |
| **EPG API** | present in login `epg_api` (stored, unused by v3.4 client) | — |
| account `user_agent` | `UA.UAGENT` | required for panel/stream requests (see edge cases) |
| account `timezone` / `expire` | `Europe/Berlin` / `2027-01-11` | — |

**Ambiguity resolved:** the owner-supplied `http://nok3.zxmnbv04.xyz:80` matches **none** of the runtime values. It is neither the content middleware (`header21.b-cdn.net`) nor the current streaming host (`domaio40.hype04.site`). Treat it as **stale/unrelated**.

## Important runtime edge cases

1. **User-Agent gating on the panel.** Direct requests to the streaming host (stream + EPG) return **HTTP 403** for unknown User-Agents (e.g. `Python-urllib/*`) and **HTTP 200** for `okhttp/*`, a browser UA, or the account `user_agent`. The rebuild must send a normal UA on all panel/stream requests. (The initial EPG 403 in an earlier run was purely this.)
2. **EPG path.** The middleware's `player_api` value is the panel **root** (trailing slash, no `.php`); `get_short_epg` must be issued at the canonical `…/player_api.php`. Even there, this account returns empty (`has_epg=0` for every channel).
3. **Live `stream_url` shape.** Runtime form is `{host}/{user}/{pass}/{id}` (no `/live/`, no extension); the panel redirects to the actual MPEG-TS. Substitute `{user}`/`{pass}` **literally** (not via regex replacement).
4. **Catalogue size / no pagination.** 8,604 live + 20,484 VOD + 7,455 series returned in single responses. The rebuild must handle large payloads (streaming parse, background load).
5. **`movies_info.stream_url` object.** Absent qualities are `""`, not `null`.

## Completion gate

`login + packages + channels + one live stream` → **all PASS** against the current content middleware ⇒ **core backend contract CONFIRMED.** Movies and series also PASS (confirmed). EPG is NOT AVAILABLE (no data for this account; transport verified).
