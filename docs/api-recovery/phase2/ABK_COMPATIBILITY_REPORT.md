# ABK / Eliaa Pro — Phase 2 Client Compatibility Report

**Type:** Authorized client-compatibility smoke test (normal-client behaviour only).
**Date:** 2026-08-24 (~18:12 UTC).
**Harness:** `tools/abk-compat/` (Python 3, stdlib only; no third-party packages; no `libnative-lib.so` reuse).
**Credentials:** supplied via process-local environment variables (`ABK_HOST` / `ABK_USERNAME` / `ABK_PASSWORD`); never printed, never written to disk, never committed.
**Scope honoured:** only the operations documented in Phase 1 were attempted. No port scan, no route discovery, no URL guessing, no alternate accounts, no identity cycling, no malformed requests, no load testing.

---

## 1. Executive result

| Item | Result |
|---|---|
| Local codec gate | **PASS** (9/9 checks) |
| Backend reachability | **BLOCKED** — both known content hosts do not exist in DNS (NXDOMAIN) |
| Login compatibility | **BLOCKED** (backend unreachable) |
| Categories / channels / playback / EPG | **BLOCKED** (dependency chain) |
| Movies / series | **NOT TESTED** (dependency chain) |
| **Rebuild state** | **BLOCKED** |

**Bottom line:** the recovered request-construction is provably correct *offline* — the XOR codec round-trips exactly and the login envelope is built exactly as documented. However, **neither of the two already-known content endpoints is reachable**: the Phase 1 native fallback host `googeleb.xyz` and the owner-supplied host `nok3.zxmnbv04.xyz` both return **NXDOMAIN** from the local resolver *and* from Cloudflare public DNS (1.1.1.1). The parent domain `zxmnbv04.xyz` also does not resolve. The control host `example.com` resolved normally in the same run, so the local network is up — the target domains simply do not exist in global DNS at test time.

Because no request could reach a server, **nothing in the static Phase 1 contract was either confirmed or refuted at runtime.** This is a *backend-availability* blocker, not a demonstrated incompatibility.

---

## 2. Test environment

| Property | Value |
|---|---|
| Content base URL candidates (known only) | `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` (Phase 1 native fallback); owner host + recovered path `http://nok3.zxmnbv04.xyz:80/iptv/V6APK/V6APKFaster.php` |
| Device envelope | `mac = 02:00:00:00:00:00`, `sn = 02:00:00:00:00:00`, `model = generic`, `group = 0` (deterministic, representative of original Android 10+ behaviour) |
| Codec | recovered repeating-XOR, key `r+3e>@y](7wEEM[` (15 bytes), byte-wise |
| Network sanity | control host `example.com` → resolved (`172.66.147.243`) |

---

## 3. Evidence table

| Test | Result | Evidence | Interpretation |
|---|---|---|---|
| Codec — empty / ASCII / JSON / key-wraparound / round-trip / symmetry | **PASS** | `test_codec.py` → "CODEC GATE: PASS" (9/9) | Request/response obfuscation is reproduced correctly; safe to send well-formed requests |
| Content base URL — native fallback | **FAIL (unreachable)** | `googeleb.xyz` → `gaierror` / NXDOMAIN (local + Cloudflare DoH `Status 3`) | Phase 1 middleware host does not resolve |
| Content base URL — owner host + recovered path | **FAIL (unreachable)** | `nok3.zxmnbv04.xyz` → `gaierror` / NXDOMAIN (local + Cloudflare DoH `Status 3`); parent `zxmnbv04.xyz` also NXDOMAIN | Owner-supplied host does not resolve |
| Network sanity control | **PASS** | `example.com` → `172.66.147.243` | Local network egress works; the failures above are host-specific, not environmental |
| Login (`mode=login`) | **BLOCKED** | no reachable base URL | Cannot exercise |
| Live categories (`mode=packages`) | **BLOCKED** | depends on login | Cannot exercise |
| Live channels (`mode=channels`) | **BLOCKED** | depends on login | Cannot exercise |
| Playback URL (`{user}`/`{pass}` transform + media probe) | **BLOCKED** | depends on channels | Cannot exercise |
| Short EPG (`action=get_short_epg`) | **BLOCKED** | depends on login `player_api` | Cannot exercise |
| Movies (`movies_cat`/`list`/`info`) | **NOT TESTED** | gated on core chain | — |
| Series (`series_cat`/`list`/`info`) | **NOT TESTED** | gated on core chain | — |

---

## 4. Area-by-area compatibility

### 4.1 Codec — **PASS**
The Phase 1 codec was re-implemented from the documented key alone (no native library). All gate cases pass, including key wraparound past the 15-byte boundary and exact encode→decode round-trip. Request construction for the content protocol is therefore trustworthy; a future failed request cannot be attributed to the codec.

### 4.2 Login compatibility — **BLOCKED**
The normal `mode=login` envelope (`code="00000000"`, `user`, `pass`, `mac`, `sn`, `model`, `group=0`) was built exactly as documented and offered to each known content host. No host resolved, so no login response was obtained. Success criterion (`status ∈ {100,101}`) could not be evaluated.

### 4.3 Categories compatibility — **BLOCKED**
`mode=packages` depends on a reachable content endpoint; not exercised.

### 4.4 Channels compatibility — **BLOCKED**
`mode=channels` depends on a reachable content endpoint; not exercised. The runtime shape of `stream_url` (in particular whether it carries literal `{user}`/`{pass}` placeholders) remains **STILL UNRESOLVED**.

### 4.5 Playback URL compatibility — **BLOCKED**
The documented transform (literal replacement of `{user}`/`{pass}`) is implemented in the harness and unit-safe, but with no channel list there is no URL to transform or probe.

### 4.6 EPG compatibility — **BLOCKED**
`player_api` is only known from a login response; without login it is unavailable. Not exercised.

### 4.7 Movies compatibility — **NOT TESTED**
Gated behind the core chain.

### 4.8 Series compatibility — **NOT TESTED**
Gated behind the core chain.

---

## 5. Unresolved compatibility issues

Everything that required the live backend remains open, unchanged from Phase 1:

1. Whether the supplied account authenticates (`status` 100 vs 101).
2. Whether the server rewrites `username` / `password`.
3. Runtime shape of `stream_url` (placeholders vs. fully-substituted).
4. Whether a live channel URL responds as playable media (HLS/TS/DASH/progressive).
5. Whether `player_api?action=get_short_epg` returns the documented `epg_listings` model with Base64 titles.
6. Whether `movies_info.stream_url` is the documented quality-map **object**.
7. Whether the reconstructed device envelope is accepted.

**Newly surfaced blocker (Phase 2):** the two already-known content hosts are not resolvable on the public internet. Either the service domains have rotated/been taken down (common for this class of middleware), or the supplied host string is stale. This must be resolved before any runtime validation is possible.

---

## 6. Rebuild readiness

**State: BLOCKED.**

Rationale: the completion gate requires the live chain `content endpoint → login → status 100/101 → packages → channels → playable stream_url`. The chain cannot start because no known content endpoint resolves in DNS. Per the Phase 2 stop conditions ("all known content base URLs fail / backend unavailable"), validation halts here without scope expansion.

Note the distinction for planning: this is **BLOCKED-on-availability**, not **BLOCKED-on-incompatibility**. The offline-verifiable half of the recovered contract (codec + request construction) is confirmed correct. If a resolvable, current host is supplied, the same harness can complete the full chain unchanged.

### What is needed to unblock
1. A **currently-resolvable** content base URL (owner to confirm the middleware host, or provide the current Firebase Remote Config `activity` value), **or** confirmation that the owner-supplied host is meant to be reached by the content (XOR) protocol at a specific path.
2. Re-run: `python3 tools/abk-compat/test_codec.py` then `ABK_HOST=… ABK_USERNAME=… ABK_PASSWORD=… python3 tools/abk-compat/abk_compat.py`.

---

## 7. Method & safety notes

- Credentials read only from environment variables; redacted from every printed and persisted line (username and password strings, plus their URL-encoded forms, are replaced with `***USER***` / `***PASS***`).
- Only known Phase 1 candidates were contacted. The single "owner host + recovered path" candidate applied the **already-known** Phase 1 path to the owner host — it did not guess or enumerate paths.
- On confirming NXDOMAIN, no attempt was made to locate a replacement host, scan ports, or probe unrelated routes.
- Companion log: `ABK_COMPATIBILITY_LOG.md`. Deeper cross-reference: `ABK_BACKEND_VALIDATION_REPORT.md`, `ABK_RUNTIME_API_CONTRACT.md`, `ABK_PHASE2_TEST_LOG.md`.
