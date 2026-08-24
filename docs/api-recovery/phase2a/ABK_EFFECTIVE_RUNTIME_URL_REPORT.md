# ABK / Eliaa Pro v3.4 — Effective Runtime Content API URL (Phase 2A)

**Objective:** determine the exact content API base URL the working v3.4 app uses at runtime today.
**Result:** **CONFIRMED.**
**Date:** 2026-08-24.

---

## Answer

| Item | Value | Confidence |
|---|---|---|
| **Effective content API base URL** | **`https://header21.b-cdn.net`** | **CONFIRMED** |
| Source of that value | Firebase Remote Config key `activity` (overrides native fallback) | CONFIRMED |
| Native fallback | `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` | CONFIRMED (binary) |
| Native fallback resolves today? | **No — NXDOMAIN** (dead) | CONFIRMED |
| Recovered host resolves today? | **Yes — `185.111.111.158` (BunnyCDN)** | CONFIRMED |

The v3.4 app keeps working with username+password only because Firebase Remote Config hands it a **live** content URL at startup, replacing the dead native fallback. The override value is a BunnyCDN host (`*.b-cdn.net`) that fronts the content middleware.

---

## Server roles (do not conflate)

| Role | Value | Confidence |
|---|---|---|
| **Content middleware URL** (receives `mode=login/packages/channels` POSTs) | `https://header21.b-cdn.net` | **CONFIRMED** |
| **Streaming / account host** (login-response `host`; channel stream URLs) | per-account; owner-supplied `nok3.zxmnbv04.xyz:80` fits this role (or is stale) | UNRESOLVED at runtime (login not run this phase) |
| **player_api** (EPG endpoint) | login-response `player_api`, per-account | UNRESOLVED (login not run) |
| **epg_api** (stored, unused by client) | login-response `epg_api` | UNRESOLVED (login not run) |

> The owner-supplied `nok3.zxmnbv04.xyz:80` is **not** the content middleware. The content middleware is `https://header21.b-cdn.net`, proven below. The owner host is a different server role (streaming/account host), to be confirmed only when login is run in the next phase.

---

## Firebase project identity (embedded in the APK)

From `app/src/main/res/values/strings.xml`:

| Key | Value |
|---|---|
| `project_id` | `eliaapro` |
| `gcm_defaultSenderId` (project number) | `722642815778` |
| `google_app_id` | `1:722642815778:android:81593e922af4127dd0737b` |
| `google_api_key` (client key) | `AIzaSyBZyxL8c2-…` (public in APK) |
| `google_storage_bucket` | `eliaapro.appspot.com` |
| Signing cert SHA-1 (from `META-INF/CERT.RSA`) | `FB85099F501D54139F6901B6D848D8265575BC1F` |

---

## Exact startup resolution flow (v3.4 code)

```
QuickPlayerApp  (static init)
  System.loadLibrary("native-lib")
AppApiHelper.f7849a = getValue()                       // native → http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php (DEAD)
        │
IntroActivity.onCreate → m7860v0()
  FirebaseRemoteConfig.getInstance()
    .setConfigSettingsAsync(minimumFetchIntervalInSeconds = 360)
    .fetchAndActivate().addOnCompleteListener(this, C1723a)
        │
IntroActivity$C1723a.onComplete(Task<Boolean>)          // IntroActivity.java:84-96
  if (task.isSuccessful()) {
      String v = remoteConfig.getString("activity");    // RC key literal "activity"  (IntroActivity.java:91)
      if (!v.isEmpty())
          AppApiHelper.m7814a(v);                        // OVERRIDE: f7849a = v         (IntroActivity.java:93)
  }
        │
All content POSTs use the final f7849a:
  AppApiHelper.mo66Q/mo67W/mo72r0/mo73v0/…              // login, packages, channels, …
    C1867b.m8505b(f7849a).m9405s("json", XOR(payload)).…  // POST {f7849a}, form field json
```

**Classes / methods / fields involved:**
- `com.mbm_soft.eliaapro.remote.AppApiHelper` — static field `f7849a` (the base URL), native `getValue()`, setter `m7814a(String)`.
- `com.mbm_soft.eliaapro.p037ui.intro.IntroActivity.m7860v0()` and inner `C1723a.onComplete(...)` — RC fetch/activate and the `getString("activity")` → `m7814a(...)` override.
- `p048d8.C1867b.m8505b(f7849a)` — builds the POST to `f7849a` for every `mode=*` content call.

This ties the recovered value directly to the content POST path for `mode=login`, `mode=packages`, and `mode=channels`.

---

## Recovered current `activity` value

```
activity = https://header21.b-cdn.net
```

Remote Config fetch returned `state = UPDATE` with a single entry (`activity`); no other keys were present. This is a URL with **no path** — the client POSTs to the CDN **root** `https://header21.b-cdn.net` (HTTPS/443), and BunnyCDN forwards to the origin middleware. (The native fallback carried a `/iptv/V6APK/V6APKFaster.php` path; the override replaces the entire base string, path included.)

---

## Method used & evidence

**Method B — read Remote Config through the app's own Firebase configuration** (least invasive available; methods A/C/D require a running device or a buildable project, neither available for the decompiled artifact).

Harness: `tools/abk-compat/fetch_remote_config.py` (Python stdlib), which:
1. reads the Firebase config from the project's own `strings.xml`;
2. registers a Firebase Installation (FIS) → `http=200`, auth token issued;
3. calls the Remote Config `firebase:fetch` REST endpoint with that installation → `http=200`, `state=UPDATE`;
4. extracts **only** the `activity` entry (other keys are not enumerated; none were present anyway).

Nothing in Remote Config was modified. No content request (login/packages/channels) was sent — that is deferred to the next phase.

**Corroborating evidence:**
- Code trace above (static, from the decompiled sources).
- RC fetch output: `state=UPDATE`, `activity = https://header21.b-cdn.net`.
- DNS: `header21.b-cdn.net → 185.111.111.158` (live, BunnyCDN); `googeleb.xyz → NXDOMAIN` (dead). This explains why the app works today without the fallback.

---

## Confidence

**CONFIRMED** — the exact current content middleware URL (`https://header21.b-cdn.net`) is observed via the app's own Firebase mechanism and is tied by code to the content POST path (`f7849a` ← RC `activity`; `f7849a` used by every `mode=*` POST).

The streaming/account host, `player_api`, and `epg_api` roles remain per-account values that only a login response reveals; they are intentionally **not** resolved in this phase.
