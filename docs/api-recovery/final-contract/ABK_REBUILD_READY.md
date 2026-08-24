# ABK — Rebuild Readiness

```
Backend contract:   CONFIRMED
Authentication:     PASS        (status=100, "Login Success.", no credential rewrite)
Live:               PASS        (packages=124, channels=8604 all with {user}/{pass}, live stream = MPEG-TS)
Movies:             PASS        (cat=30, list=20484, movies_info.stream_url = object {480p,720p,1080p,4k})
Series:             PASS        (cat=36, list=7455, series_info = info + seasons + episodes)
EPG:                NOT AVAILABLE  (endpoint reachable with a normal UA; account has no EPG data, has_epg=0 everywhere)

v4.3 backend delta: UNCHANGED   (v4.3 = alternative direct-Xtream path; v3.4 middleware contract still fully valid)
Current content middleware: https://header21.b-cdn.net   (Firebase Remote Config `activity`)
Streaming host (runtime):    http://domaio40.hype04.site:80
nok3.zxmnbv04.xyz:80:        stale / unrelated (matches no runtime role)

Clean rebuild:      READY
```

## Blockers that would actually stop the new app
**None.** The core chain (login → packages → channels → live stream) works end-to-end against the live middleware today.

## Non-blocking must-dos (already in the contract)
- Read the content base URL from Firebase Remote Config `activity` at startup (it can rotate) — don't hardcode.
- Send a normal **User-Agent** on streaming-host requests (stream + EPG); unknown UAs get HTTP 403.
- Handle large, unpaginated catalogues (8.6k / 20k / 7.5k).
- Treat EPG-empty and `movies_info.stream_url` object shape correctly.

Authoritative details: `ABK_FINAL_BACKEND_CONTRACT.md`. Evidence: `ABK_RUNTIME_VALIDATION_FINAL.md`, `ABK_V43_BACKEND_DELTA.md`.
```
Next phase: clean implementation of the new application (not started).
```
