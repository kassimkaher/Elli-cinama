"""Phase 2A: read the Remote Config `activity` value via the app's own Firebase
configuration — the same mechanism the v3.4 client uses at startup.

Flow (standard Firebase client protocol):
  1. Firebase Installations (FIS): register an installation -> auth token.
  2. Remote Config fetch: POST firebase:fetch with the installation id/token.
  3. Extract ONLY the `activity` entry (the effective content base URL override).

Config (api key, app id, project) is read from the project's own
app/src/main/res/values/strings.xml — nothing is hard-coded. Other Remote
Config keys are NOT enumerated or printed; only `activity` is reported.
"""
import base64
import json
import os
import re
import secrets
import ssl
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
STRINGS = os.path.join(REPO, "app", "src", "main", "res", "values", "strings.xml")
PKG = "com.mbm_soft.eliaapro"
CERT_SHA1 = "FB85099F501D54139F6901B6D848D8265575BC1F"  # from META-INF/CERT.RSA
CTX = ssl.create_default_context()


def sval(name, text):
    m = re.search(r'<string name="%s">([^<]*)</string>' % re.escape(name), text)
    return m.group(1) if m else None


def load_cfg():
    with open(STRINGS) as f:
        t = f.read()
    return {
        "api_key": sval("google_api_key", t),
        "app_id": sval("google_app_id", t),
        "project_id": sval("project_id", t),
        "project_number": sval("gcm_defaultSenderId", t),
    }


def gen_fid():
    b = bytearray(secrets.token_bytes(17))
    b[0] = 0x70 | (b[0] & 0x0F)            # force version nibble 0111
    return base64.urlsafe_b64encode(bytes(b)).decode("ascii").rstrip("=")[:22]


def post_json(url, body, headers):
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST", headers=headers)
    with urllib.request.urlopen(req, timeout=25, context=CTX) as r:
        return r.status, json.loads(r.read().decode("utf-8"))


def register_installation(cfg, fid):
    url = ("https://firebaseinstallations.googleapis.com/v1/projects/%s/installations"
           % cfg["project_id"])
    headers = {
        "Content-Type": "application/json",
        "Cache-Control": "no-cache",
        "X-Android-Package": PKG,
        "X-Android-Cert": CERT_SHA1,
        "x-goog-api-key": cfg["api_key"],
    }
    body = {"fid": fid, "appId": cfg["app_id"],
            "authVersion": "FIS_v2", "sdkVersion": "a:17.0.1"}
    status, resp = post_json(url, body, headers)
    return status, resp.get("authToken", {}).get("token"), resp.get("fid", fid)


def fetch_remote_config(cfg, fid, auth_token):
    url = ("https://firebaseremoteconfig.googleapis.com/v1/projects/%s/namespaces/"
           "firebase:fetch?key=%s" % (cfg["project_number"], cfg["api_key"]))
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": cfg["api_key"],
        "X-Android-Package": PKG,
        "X-Android-Cert": CERT_SHA1,
    }
    body = {
        "appInstanceId": fid,
        "appInstanceIdToken": auth_token,
        "appId": cfg["app_id"],
        "packageName": PKG,
        "languageCode": "en-US",
        "platformVersion": "30",
        "appVersion": "3.4",
        "sdkVersion": "21.2.0",
    }
    return post_json(url, body, headers)


def main():
    cfg = load_cfg()
    print("Firebase config (from app strings.xml):")
    print(f"  project_id     = {cfg['project_id']}")
    print(f"  project_number = {cfg['project_number']}")
    print(f"  app_id         = {cfg['app_id']}")
    print(f"  api_key        = {cfg['api_key'][:10]}… (client key, public in APK)")
    print()

    try:
        fid = gen_fid()
        st, token, fid = register_installation(cfg, fid)
        print(f"[FIS] installation registered: http={st}, token={'yes' if token else 'no'}")
        if not token:
            print("RESULT: UNRESOLVED (no installation auth token)")
            return 1
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:300]
        print(f"[FIS] HTTP {e.code}: {detail}")
        print("RESULT: UNRESOLVED (installations request rejected)")
        return 1
    except Exception as e:  # noqa
        print(f"[FIS] error: {type(e).__name__}: {e}")
        print("RESULT: UNRESOLVED (installations request failed)")
        return 1

    try:
        st, rc = fetch_remote_config(cfg, fid, token)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:300]
        print(f"[RC ] HTTP {e.code}: {detail}")
        print("RESULT: UNRESOLVED (remote config fetch rejected)")
        return 1
    except Exception as e:  # noqa
        print(f"[RC ] error: {type(e).__name__}: {e}")
        print("RESULT: UNRESOLVED (remote config fetch failed)")
        return 1

    state = rc.get("state")
    entries = rc.get("entries", {}) or {}
    activity = entries.get("activity")
    other_count = len([k for k in entries if k != "activity"])
    print(f"[RC ] http={st} state={state} entries_total={len(entries)} "
          f"(other keys present but not enumerated: {other_count})")
    print()
    if activity is not None:
        print("=== ABK_EFFECTIVE_CONTENT_BASE_URL (Remote Config `activity`) ===")
        print(f"activity = {activity}")
        print("RESULT: CONFIRMED")
        return 0
    print("`activity` key not present in the returned template.")
    print("RESULT: PARTIAL (override mechanism reachable; key absent/empty)")
    return 2


if __name__ == "__main__":
    sys.exit(main())
