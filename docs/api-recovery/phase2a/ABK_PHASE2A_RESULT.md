# ABK / Eliaa Pro v3.4 — Phase 2A Result

```
v3.4 working app:        CONFIRMED by owner

Native fallback:
  http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php   (currently NXDOMAIN / dead)

Remote Config key:
  activity

Remote Config value:
  https://header21.b-cdn.net

Effective content API URL:
  https://header21.b-cdn.net        (HTTPS, root path; BunnyCDN → 185.111.111.158)

Evidence method:
  B — Firebase Remote Config fetch via the app's own embedded config
      (Firebase Installations + firebase:fetch REST), state=UPDATE,
      confirmed against the code path AppApiHelper.f7849a ← getString("activity"),
      f7849a used by mode=login/packages/channels POSTs.

Ready to rerun Phase 2:
  YES
```

## Server roles (kept distinct)
- Content middleware URL: `https://header21.b-cdn.net`  — CONFIRMED
- Streaming/account host: owner-supplied `nok3.zxmnbv04.xyz:80` (login-response `host` role, or stale) — NOT the content middleware; UNRESOLVED at runtime
- player_api: per-account, from login response — UNRESOLVED (login not run)
- epg_api: per-account, from login response (stored, unused) — UNRESOLVED (login not run)

## To rerun Phase 2 (next phase, not this one)
```
export ABK_CONTENT_BASE_URL='https://header21.b-cdn.net'
export ABK_USERNAME='<username>'   ABK_PASSWORD='<password>'
python3 tools/abk-compat/test_codec.py && python3 tools/abk-compat/abk_compat.py
```
