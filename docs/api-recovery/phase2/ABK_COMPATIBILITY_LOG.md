# ABK / Eliaa Pro — Phase 2 Compatibility Test Log (sanitized)

Sanitized. Contains no plaintext passwords, no environment-variable values, and
no full credential-bearing media URLs. Username/password strings (and their
URL-encoded forms) are replaced with `***USER***` / `***PASS***`.

- Run date: 2026-08-24
- Harness: `tools/abk-compat/abk_compat.py` (+ `abk_codec.py`, `test_codec.py`)
- Transport: Python stdlib `urllib`; content = POST form field `json` = XOR(payload); EPG = plain GET
- Device envelope: `mac=02:00:00:00:00:00`, `sn=02:00:00:00:00:00`, `model=generic`, `group=0`

---

## Codec gate (offline, pre-network)

| Timestamp | Operation | Result |
|---|---|---|
| 2026-08-24 | key = recovered 15-byte constant | PASS |
| 2026-08-24 | empty string round-trip / encode-empty | PASS |
| 2026-08-24 | ASCII payload round-trip | PASS |
| 2026-08-24 | JSON payload round-trip | PASS |
| 2026-08-24 | key wraparound vs manual computation | PASS |
| 2026-08-24 | key wraparound round-trip | PASS |
| 2026-08-24 | xor symmetry (involution) | PASS |
| 2026-08-24 | ASCII input → all cipher bytes < 0x80 | PASS |

**CODEC GATE: PASS** (proceed to network).

---

## Network attempts

| Timestamp (UTC) | Operation | Endpoint (host/path) | HTTP | Decoded type | Count | Result |
|---|---|---|---|---|---|---|
| 2026-08-24T18:12:51Z | probe: Phase-1 native fallback | `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` | — | n/a | — | FAIL (DNS/NXDOMAIN) |
| 2026-08-24T18:12:51Z | probe: owner host + recovered path | `http://nok3.zxmnbv04.xyz:80/iptv/V6APK/V6APKFaster.php` | — | n/a | — | FAIL (DNS/NXDOMAIN) |
| 2026-08-24 | login (`mode=login`) | (no reachable base URL) | — | — | — | BLOCKED |
| 2026-08-24 | packages (`mode=packages`) | (dependency) | — | — | — | BLOCKED |
| 2026-08-24 | channels (`mode=channels`) | (dependency) | — | — | — | BLOCKED |
| 2026-08-24 | playback URL + media probe | (dependency) | — | — | — | BLOCKED |
| 2026-08-24 | get_short_epg | (dependency: player_api) | — | — | — | BLOCKED |
| 2026-08-24 | movies_cat / movies_list / movies_info | (dependency) | — | — | — | NOT TESTED |
| 2026-08-24 | series_cat / series_list / series_info | (dependency) | — | — | — | NOT TESTED |

---

## DNS diagnostics (evidence for the reachability failure)

| Host | Local resolver (192.168.0.1) | Cloudflare DoH (1.1.1.1) | Verdict |
|---|---|---|---|
| `example.com` (control) | resolved `172.66.147.243` | — | network egress OK |
| `nok3.zxmnbv04.xyz` (owner host) | NXDOMAIN | `Status 3` (NXDOMAIN), no answer | does not exist in DNS |
| `googeleb.xyz` (Phase-1 fallback) | NXDOMAIN | `Status 3` (NXDOMAIN), no answer | does not exist in DNS |
| `zxmnbv04.xyz` (parent) | NXDOMAIN | — | does not exist in DNS |

Raw resolver error for the ABK hosts: `socket.gaierror [Errno 8] nodename nor servname provided, or not known`.

---

## Classification of the terminal failure

| Class | Present? | Detail |
|---|---|---|
| connectivity (no egress) | no | control host resolved and network reachable |
| DNS (NXDOMAIN) | **yes** | both known content hosts + parent domain absent from global DNS |
| HTTP status | n/a | no connection established |
| XOR decode | n/a | no response |
| malformed JSON | n/a | no response |
| unexpected JSON shape | n/a | no response |
| auth rejection | n/a | login never sent |
| empty catalogue | n/a | — |
| playback URL failure | n/a | — |
| EPG failure | n/a | — |

**Terminal state: BLOCKED (backend unavailable — DNS NXDOMAIN on all known hosts).**

_No plaintext credentials, environment values, or credential-bearing URLs appear in this log._
