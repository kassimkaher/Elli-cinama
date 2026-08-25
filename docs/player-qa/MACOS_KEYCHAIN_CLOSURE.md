# macOS Keychain — Closure

## Symptom
On macOS the app repeatedly asked for the system password ("… wants to use your
confidential information stored in … in your keychain"), including when opening movies,
series/episodes, and starting playback — several prompts per session.

## Root cause (two compounding factors)
1. **Per-content Keychain reads.** The parental-lock PIN lived in the Keychain and
   `hasPin()` / `verify()` were called on **every** content-open and play path (via the
   parental gate) plus in some UI builds (`hasParentalPinProvider`). Each call was a
   Keychain read.
2. **Ad-hoc code signing** (`CODE_SIGN_IDENTITY = "-"` in the macOS project). The macOS
   **legacy** Keychain authorises access by the reading process's code signature. An
   ad-hoc signature changes on every build, so each rebuilt app is treated as a *different*
   app and macOS prompts for permission — and "Always Allow" only lasts until the next
   rebuild. With per-content reads, that meant a prompt for essentially every action.

## Fix (architecture — session read once, macOS off the Keychain)

### 1. Read secrets once, serve from memory
- Session/credentials are restored from secure storage **once** at startup into the
  in-memory `RuntimeSession`; repositories, stream-URL construction, and the player all
  read the in-memory session — never secure storage (verified: `ResolveLiveStreamUrl`
  takes `RuntimeSession`).
- `ParentalLockRepository` now caches the PIN in memory: it reads secure storage **at most
  once** (a `warmUp()` at bootstrap), then serves `hasPin()`/`verify()` from the cache.
  `setPin`/`clearPin` write once and update the cache. Verified by
  `test/unit/parental_cache_test.dart` (20 hasPin/verify calls → exactly 1 read).

### 2. macOS never uses the Keychain
`secureStoreProvider` selects, **on macOS only**, a `MacOsFileSecureStore` that persists an
obfuscated file inside the app's **App Sandbox container** (Application Support) instead of
the Keychain:

```dart
final secureStoreProvider = Provider<SecureStore>(
    (_) => Platform.isMacOS ? MacOsFileSecureStore() : FlutterSecureStore());
```

The App Sandbox container is already private to this app (the OS isolates it), so no
Keychain is involved and **no system-password prompt can occur — regardless of signing**.
iOS and Android keep `flutter_secure_storage` (iOS Keychain items are app-scoped by
entitlement and do not prompt; Android uses EncryptedSharedPreferences) — neither platform
has this problem, so neither is changed.

## Session architecture (as required)
```
startup → secure read ONCE → in-memory RuntimeSession + cached PIN
          → repositories / API / stream-URL / player read in-memory state
login    → secure write (once)
logout   → secure delete + in-memory clear
open channel/movie/episode/detail/player/EPG → NO secure reads
```

## Verification (real macOS Release-type run)
`integration_test/macos_qa_test.dart` and `integration_test/player_ui_test.dart` on
`-d macos`:
- Auth test performs login → **restart-restore** (a second `bootstrap()`) → logout →
  re-login. It **completed without blocking** — a Keychain prompt would have hung the run.
- Real-UI player test logged in and played a live channel with **no prompt**.
- `login` step ≈ 458 ms; session restored from the sandbox file store.

## Residual
None from normal use. Old Keychain items from previous builds are simply ignored on macOS
now (the user re-logs in once, after which the sandbox file store persists the session).

## Status
**MACOS KEYCHAIN: CLOSED** — no repeated prompts; session read once; restore/logout correct.
