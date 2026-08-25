# QA Login Autofill

A development/QA-only convenience that fills the login username/password fields with
the authorized test account. It is an **autofill only** — it never submits, validates, or
bypasses authentication. The user still presses **Login**.

## How it is enabled

The helper reads QA credentials from **compile-time `--dart-define`** values. It appears
only when both are present:

| Key | Purpose |
|---|---|
| `ABK_QA_USERNAME` | test account username |
| `ABK_QA_PASSWORD` | test account password |

Run a dev/QA build with:

```bash
flutter run \
  --dart-define=ABK_QA_USERNAME=<qa-username> \
  --dart-define=ABK_QA_PASSWORD=<qa-password>
```

(Integration/QA runs typically also pass `ABK_USERNAME`/`ABK_PASSWORD` for the backend
tests; the QA autofill uses the separate `ABK_QA_*` keys.)

## Why it is excluded from production

- Credentials are **not hard-coded** anywhere in UI/production code — they arrive only via
  `--dart-define` (`lib/core/config/qa_config.dart`, `String.fromEnvironment`).
- A production/release build for end users is compiled **without** these defines, so
  `qaCredentialsProvider` resolves to `null` and the card is **not rendered at all**.
- No plaintext credentials are printed to logs; the password is never logged.

```dart
// lib/core/config/qa_config.dart
final qaCredentialsProvider = Provider<QaCredentials?>((ref) {
  const u = String.fromEnvironment('ABK_QA_USERNAME');
  const p = String.fromEnvironment('ABK_QA_PASSWORD');
  return (u.isNotEmpty && p.isNotEmpty) ? const QaCredentials(u, p) : null;
});
```

## How to use it

1. Launch a dev/QA build with the two defines above.
2. On the login screen a **QA account** card appears under the Login button.
3. Tap it → the username and password fields are filled.
4. Both fields stay **editable** — adjust if needed.
5. Press **Login** as usual. (Tapping the card never logs you in by itself.)

## Behaviour / safety summary

| Rule | Status |
|---|---|
| Fills username field | ✅ |
| Fills password field | ✅ |
| Fields remain editable | ✅ |
| Auto-submit / auto-login | ❌ never |
| Bypasses validation/auth | ❌ never |
| Visible in production/release | ❌ hidden (no defines) |
| Password printed to logs | ❌ never |
| Normal login flow changed | ❌ unchanged |

## Tests

`test/widget/login_qa_autofill_test.dart`:
- card hidden when QA creds absent (production);
- card shown in QA/dev configuration;
- tapping fills username + password and does **not** auto-login;
- populated values remain editable, and the normal Login button still submits.

## Secret scan

The test account values live only in `--dart-define` (and, for local runs, a git-ignored
scratch env file) — never in tracked source. Run the project secret scan after changes.
