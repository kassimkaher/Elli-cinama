# abk-compat — ABK / Eliaa Pro client compatibility smoke test

Reproduces **only** the normal application requests documented in Phase 1
(`docs/api-recovery/ABK_API_CONTRACT.md`) to check whether the recovered client
contract still works against the project's backend.

It does **not** discover routes, scan ports, guess URLs, enumerate the
catalogue, cycle identities, or send malformed requests.

## Files
- `abk_codec.py` — recovered repeating-XOR codec (key from Phase 1; no native lib reused).
- `test_codec.py` — offline codec gate. Must pass before any network call.
- `abk_compat.py` — orchestrates login → packages → channels → one playback URL → short EPG → (optional) movies/series.

## Server roles — do not conflate (corrected after Phase 2A)
There are **two different servers**:

- **Content middleware URL** — receives `mode=login/packages/channels` POSTs
  (form field `json` = XOR(payload)). Phase 2A **CONFIRMED** this is the Firebase
  Remote Config `activity` value: **`https://header21.b-cdn.net`** (overrides the
  now-dead native fallback `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php`).
  Pass it via **`ABK_CONTENT_BASE_URL`**.
- **Streaming / account host** — the login-response `host` / `player_api` role
  (channel stream URLs, EPG). The owner-supplied `nok3.zxmnbv04.xyz:80` belongs
  here (or is stale), and is passed via **`ABK_HOST`**. It is **NOT** the content
  middleware and is no longer used as a content-base candidate.

## Credentials & config (never hard-code, never commit)
Supplied via process-local environment variables. Both naming schemes work:

```
export ABK_CONTENT_BASE_URL='https://header21.b-cdn.net'   # content middleware (RC `activity`)
export ABK_HOST='http://<streaming-host>:<port>'           # streaming/account host (or ABK_TEST_HOST)
export ABK_USERNAME='<username>'                           # or ABK_TEST_USERNAME
export ABK_PASSWORD='<password>'                           # or ABK_TEST_PASSWORD
# optional:
export ABK_DEV_MAC='02:00:00:00:00:00'
export ABK_DEV_MODEL='generic'
```

The content base URL is **not hard-coded in source** — pass it via
`ABK_CONTENT_BASE_URL`. To re-read it from Firebase at any time:
`python3 fetch_remote_config.py` (reads the app's own config from strings.xml).

## Run
```
python3 test_codec.py        # gate — exit 0 required
python3 abk_compat.py        # validation chain
```

## Output & safety
- Prints `PASS` / `FAIL` / `BLOCKED` per stage.
- Writes `last_run.sanitized.json` (gitignored) — credentials and their
  URL-encoded forms are redacted to `***USER***` / `***PASS***`; full
  credential-bearing media URLs are reduced to host+path only.
- No plaintext password, no env values, and no full stream URL are ever logged.

## Content base URL determination
Tests only already-known candidates in order: `ABK_CONTENT_BASE_URL` (the
Remote Config `activity` value), then the Phase 1 native fallback
(`http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php`, currently dead). The
first candidate that speaks the XOR content protocol wins. The owner host
(`ABK_HOST`) is **not** a content candidate — it is the streaming/account host.
If no candidate responds, the run is `BLOCKED` and stops — no host discovery is
attempted.
