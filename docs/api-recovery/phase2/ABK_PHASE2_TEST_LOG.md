# ABK / Eliaa Pro — Phase 2 Test Log (sanitized)

Sanitized. No plaintext passwords, no environment-variable values, no full
credential-bearing media URLs. Credential strings and their URL-encoded forms
are redacted to `***USER***` / `***PASS***`.

- Run date: 2026-08-24
- Harness: `tools/abk-compat/` (`abk_codec.py`, `test_codec.py`, `abk_compat.py`)
- Device envelope: `mac=02:00:00:00:00:00`, `sn=02:00:00:00:00:00`, `model=generic`, `group=0`

| Timestamp (UTC) | Operation | Endpoint (host/path) | HTTP | Decoded type | Counts | Result |
|---|---|---|---|---|---|---|
| 2026-08-24 | codec gate (9 checks) | (local) | — | — | 9/9 | PASS |
| 2026-08-24T18:12:51Z | probe: native fallback | `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` | — | n/a | — | FAIL (NXDOMAIN) |
| 2026-08-24T18:12:51Z | probe: owner host + recovered path | `http://nok3.zxmnbv04.xyz:80/iptv/V6APK/V6APKFaster.php` | — | n/a | — | FAIL (NXDOMAIN) |
| 2026-08-24 | login (`mode=login`) | (no reachable base URL) | — | — | — | BLOCKED |
| 2026-08-24 | packages (`mode=packages`) | (dependency: login) | — | — | — | BLOCKED |
| 2026-08-24 | channels (`mode=channels`) | (dependency: login) | — | — | — | BLOCKED |
| 2026-08-24 | playback URL + media probe | (dependency: channels) | — | — | — | BLOCKED |
| 2026-08-24 | get_short_epg | (dependency: player_api) | — | — | — | BLOCKED |
| 2026-08-24 | movies_cat / movies_list / movies_info | (dependency: login) | — | — | — | NOT TESTED |
| 2026-08-24 | series_cat / series_list / series_info | (dependency: login) | — | — | — | NOT TESTED |

## DNS evidence

| Host | Local resolver | Cloudflare DoH (1.1.1.1) |
|---|---|---|
| `example.com` (control) | `172.66.147.243` | — |
| `nok3.zxmnbv04.xyz` | NXDOMAIN | `Status 3` (NXDOMAIN) |
| `googeleb.xyz` | NXDOMAIN | `Status 3` (NXDOMAIN) |
| `zxmnbv04.xyz` (parent) | NXDOMAIN | — |

Resolver error string (ABK hosts): `socket.gaierror [Errno 8] nodename nor servname provided, or not known`.

## Failure classification

connectivity=no · **DNS(NXDOMAIN)=yes** · HTTP=n/a · XOR-decode=n/a · malformed-JSON=n/a · unexpected-shape=n/a · auth-rejection=n/a · empty-catalogue=n/a · playback=n/a · EPG=n/a

**Terminal state: BLOCKED (backend unavailable).**

_No secrets are stored in this log._
