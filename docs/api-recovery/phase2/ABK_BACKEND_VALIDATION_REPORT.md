# ABK / Eliaa Pro — Phase 2 Backend Validation Report

**Type:** Authorized backend validation of the Phase 1 client contract (normal-client behaviour only).
**Date:** 2026-08-24 (~18:12 UTC).
**Harness:** `tools/abk-compat/` (Python 3 stdlib; no third-party packages; recovered XOR codec used directly; `libnative-lib.so` not reused).
**Credentials:** process-local env vars only (`ABK_HOST`/`ABK_USERNAME`/`ABK_PASSWORD`, also accepts `ABK_TEST_*`); redacted everywhere.

> This report and `ABK_COMPATIBILITY_REPORT.md` describe the **same single validation run**. They are consistent; this document follows the Phase 2 backend-validation outline, the other follows the compatibility-smoke outline.

---

## Executive result

- **Codec gate:** PASS (9/9, offline).
- **Backend:** **UNAVAILABLE.** Both already-known content hosts return **NXDOMAIN** on the local resolver and on Cloudflare public DNS (1.1.1.1); the parent domain `zxmnbv04.xyz` is also NXDOMAIN. A control host (`example.com`) resolved in the same run, proving network egress works.
- **Every server-dependent test:** BLOCKED. No request reached a server, so **no Phase 1 fact was confirmed or refuted at runtime.**
- **Rebuild readiness:** **BLOCKED** (on availability, not on demonstrated incompatibility).

---

## Test environment

| Property | Value |
|---|---|
| Owner-supplied host | `http://nok3.zxmnbv04.xyz:80` |
| Phase 1 native fallback | `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` |
| Device envelope | `mac=02:00:00:00:00:00`, `sn=02:00:00:00:00:00`, `model=generic`, `group=0` |
| Codec | repeating XOR, key `r+3e>@y](7wEEM[` (byte-wise) |
| Control DNS | `example.com` → `172.66.147.243` (OK) |

---

## Content base URL determination

Only already-known candidates were tested, each with a single normal `mode=login` POST.

| Candidate | Source | HTTP | Speaks XOR/content protocol | PASS/FAIL |
|---|---|---|---|---|
| `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` | Phase 1 native fallback | — (no connection) | no | **FAIL (NXDOMAIN)** |
| `http://nok3.zxmnbv04.xyz:80/iptv/V6APK/V6APKFaster.php` | owner host + recovered path | — (no connection) | no | **FAIL (NXDOMAIN)** |

Firebase Remote Config `activity` value was **not** retrievable in this harness (fetching it requires a Firebase Installations token issued to the app's config; not attempted as it would exceed "normal configuration" reproduction without the app runtime). It remains an allowed future candidate if the owner can surface the current value.

**Determination: no active content base URL could be established — all known candidates are unreachable.**

---

## Login result

**BLOCKED.** The normal login envelope was constructed exactly as documented —
`{code:"00000000", user, pass, mac, sn, model, group:0, mode:"login"}` XOR-obfuscated into form field `json` — but no content host resolved, so no login was sent to a live server. Success criterion `status ∈ {100,101}` was **not evaluable**.

## Sanitized account response fields

**Not available** (no response). All fields below remain unverified at runtime:
`status, message, host, player_api, epg_api, username, password, user_agent, timezone, expire, apk_ver_code, force_update, update_url`.

## Categories result — **BLOCKED**
`mode=packages` not exercised (no login/session).

## Channels result — **BLOCKED**
`mode=channels` not exercised.

## Observed live `stream_url` format — **NOT OBSERVED**
No channel data retrieved. Whether the runtime value carries literal `{user}`/`{pass}` placeholders (as Phase 1 infers) is **STILL UNRESOLVED**.

## Live media reachability result — **BLOCKED**
No channel → no URL to transform or probe.

## EPG result — **BLOCKED**
`player_api` unknown without a login response.

## Movies result — **NOT TESTED**
Gated on the core chain.

## Series result — **NOT TESTED**
Gated on the core chain.

## Device-envelope observations
The reconstructed envelope (`mac/sn/model/group`) was built with representative deterministic values and **not** cycled or randomized. Server acceptance is **UNRESOLVED** (no server contact). No device/client-mismatch signal was observed because no response was received.

## Status-code observations
No `status` observed. The 100-vs-101 distinction remains **UNRESOLVED**, exactly as in Phase 1.

---

## Compact evidence table

| Test | Result | Evidence | Interpretation |
|---|---|---|---|
| Codec gate | PASS | `test_codec.py` → "CODEC GATE: PASS" | request/response obfuscation reproduced correctly |
| Base URL (native fallback) | FAIL | `googeleb.xyz` NXDOMAIN (local + DoH `Status 3`) | Phase 1 middleware host gone |
| Base URL (owner host) | FAIL | `nok3.zxmnbv04.xyz` NXDOMAIN (local + DoH `Status 3`); parent `zxmnbv04.xyz` NXDOMAIN | owner host does not resolve |
| Network control | PASS | `example.com` → `172.66.147.243` | egress OK; failures are host-specific |
| Login | BLOCKED | no reachable endpoint | contract untestable |
| packages / channels / playback / EPG | BLOCKED | dependency chain | untestable |
| movies / series | NOT TESTED | dependency chain | — |

---

## Remaining unknowns

All Phase 1 runtime unknowns persist (login viability, username/password rewrite, `stream_url` runtime shape, live media playability, EPG model, `movies_info.stream_url` object type, device-envelope acceptance, status semantics), **plus** the new availability blocker: the known content hosts are absent from global DNS.

## Final rebuild readiness verdict

**BLOCKED** — backend unavailable. The offline half of the contract (codec + request construction) is verified; the runtime half is entirely unconfirmed. Supplying a currently-resolvable content host (or the live Remote Config `activity` value) and re-running the harness is the single action required to proceed.
