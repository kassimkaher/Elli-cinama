# ABK / Eliaa Pro — Runtime API Contract (additive to Phase 1)

**Purpose:** record only runtime-confirmed facts on top of the static Phase 1 contract. This is **additive** — it does not replace `ABK_API_CONTRACT.md`.

**Status of this document:** the Phase 2 validation run of 2026-08-24 could **not reach the backend** (both known content hosts NXDOMAIN — see `ABK_BACKEND_VALIDATION_REPORT.md`). Therefore **no facts could be promoted to RUNTIME CONFIRMED.** Everything that requires the server is marked **STILL UNRESOLVED (backend unreachable)**. The offline-verifiable codec is marked **RUNTIME CONFIRMED (offline)** because it was independently re-implemented and exercised.

Legend:
- **STATIC CONFIRMED** — proven from the APK in Phase 1.
- **RUNTIME CONFIRMED** — additionally proven against the live backend in Phase 2.
- **RUNTIME CONFIRMED (offline)** — proven by local execution not requiring the backend.
- **STILL UNRESOLVED** — not provable without a reachable backend.

---

## Transport & codec

| Fact | Static | Runtime |
|---|---|---|
| Content op = `POST {BASE_URL}`, form field `json` = XOR(payload) | STATIC CONFIRMED | STILL UNRESOLVED (no server contact) |
| XOR key `r+3e>@y](7wEEM[` (15 bytes), repeating, symmetric | STATIC CONFIRMED | **RUNTIME CONFIRMED (offline)** — codec gate 9/9, exact round-trip incl. key wraparound |
| ASCII payload ⇒ cipher bytes < 0x80 ⇒ percent-encoded form value | STATIC CONFIRMED | **RUNTIME CONFIRMED (offline)** |
| Response XOR-decoded only on HTTP 2xx, then `.trim()` | STATIC CONFIRMED | STILL UNRESOLVED |
| EPG = plain GET on `player_api`, no XOR | STATIC CONFIRMED | STILL UNRESOLVED |

## Base URL

| Fact | Static | Runtime |
|---|---|---|
| Native fallback `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` | STATIC CONFIRMED (binary) | **STILL UNRESOLVED** — host NXDOMAIN at test time |
| Remote Config key `activity` overrides base URL | STATIC CONFIRMED | STILL UNRESOLVED — value not retrieved |
| Owner host `nok3.zxmnbv04.xyz` is the active content endpoint | (owner-supplied) | **STILL UNRESOLVED** — host NXDOMAIN; relationship to the content protocol unproven |

## Authentication envelope

| Field | Static | Runtime |
|---|---|---|
| `code="00000000"` + `user` + `pass` (user/pass mode) | STATIC CONFIRMED | STILL UNRESOLVED |
| `mac`, `sn` (= mac), `model`, `group=0` | STATIC CONFIRMED | STILL UNRESOLVED (envelope built as documented; server acceptance untested) |
| Success ⟺ `status ∈ {100,101}` | STATIC CONFIRMED | STILL UNRESOLVED |
| Server may rewrite `username`/`password` | STATIC CONFIRMED (code path) | STILL UNRESOLVED (not observed) |

## Operations

| Operation | `mode` | Static response shape | Runtime |
|---|---|---|---|
| Activate | `active` | object `C3164a` | STILL UNRESOLVED |
| Login | `login` | object `C3164a` | STILL UNRESOLVED |
| Live categories | `packages` | array | STILL UNRESOLVED |
| Live channels | `channels` | array | STILL UNRESOLVED |
| Movie categories | `movies_cat` | array | STILL UNRESOLVED |
| Movies | `movies_list` | array | STILL UNRESOLVED |
| Latest movies | `movies_latest` | array | STILL UNRESOLVED |
| Movie info | `movies_info` | array; `[0].stream_url` = **object** (quality map) | STILL UNRESOLVED |
| Series categories | `series_cat` | array | STILL UNRESOLVED |
| Series | `series_list` | array | STILL UNRESOLVED |
| Latest series | `series_latest` | array | STILL UNRESOLVED |
| Series info | `series_info` | object `{info, seasons[]}` | STILL UNRESOLVED |
| Short EPG | GET `get_short_epg` | object `{epg_listings[]}`, Base64 `title` | STILL UNRESOLVED |

## Stream URL derivation

| Fact | Static | Runtime |
|---|---|---|
| Live: server `stream_url` with literal `{user}`/`{pass}` substitution | STATIC CONFIRMED | STILL UNRESOLVED (transform implemented & unit-safe; no runtime URL to apply it to) |
| Catchup: `{host}/timeshift/{user}/{pass}/1200/{yyyy-MM-dd:kk-mm}/{id}.m3u8` | STATIC CONFIRMED | STILL UNRESOLVED |
| Movie: first non-empty of 4k→1080p→720p→480p, verbatim | STATIC CONFIRMED | STILL UNRESOLVED |
| Episode: `stream_url` verbatim | STATIC CONFIRMED | STILL UNRESOLVED |

## Summary

No runtime promotions were possible this phase except the codec (offline). The static contract stands unchallenged and unconfirmed at the network layer. Re-run against a resolvable host to populate the Runtime column.
