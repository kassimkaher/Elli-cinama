"""ABK / Eliaa Pro client compatibility smoke test.

Reproduces ONLY the normal application requests documented in Phase 1:
  login -> packages -> channels -> (one) playback URL -> short EPG
  -> (optional) movies_cat/movies_list/movies_info
  -> (optional) series_cat/series_list/series_info

It does NOT discover routes, guess URLs, scan, enumerate, cycle identities,
or send malformed requests. Credentials come from the environment and are
redacted from every printed / persisted line.

Env (either naming scheme is accepted):
  ABK_HOST      | ABK_TEST_HOST        owner-supplied host (e.g. http://host:port)
  ABK_USERNAME  | ABK_TEST_USERNAME    account username
  ABK_PASSWORD  | ABK_TEST_PASSWORD    account password
  ABK_DEV_MAC   (optional, default 02:00:00:00:00:00)
  ABK_DEV_MODEL (optional, default generic)
  ABK_CONTENT_BASE_URL (optional, forces the content endpoint)

Stdlib only; no third-party packages, no libnative-lib.so.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from abk_codec import encode_payload, decode_body

# ---- Phase 1 recovered constants -------------------------------------------
NATIVE_FALLBACK = "http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php"
RECOVERED_PATH = "/iptv/V6APK/V6APKFaster.php"
CONTENT_TIMEOUT = 20
MEDIA_TIMEOUT = 15

# ---- config from env -------------------------------------------------------
def env(*names, default=None):
    for n in names:
        v = os.environ.get(n)
        if v:
            return v
    return default

HOST = env("ABK_HOST", "ABK_TEST_HOST", default="")
USERNAME = env("ABK_USERNAME", "ABK_TEST_USERNAME", default="")
PASSWORD = env("ABK_PASSWORD", "ABK_TEST_PASSWORD", default="")
DEV_MAC = env("ABK_DEV_MAC", default="02:00:00:00:00:00")
DEV_MODEL = env("ABK_DEV_MODEL", default="generic")
FORCED_BASE = env("ABK_CONTENT_BASE_URL", default="")

# ---- redaction -------------------------------------------------------------
_SECRETS = {}  # value -> placeholder

def register_secret(value, placeholder):
    if value:
        _SECRETS[value] = placeholder

register_secret(PASSWORD, "***PASS***")
register_secret(USERNAME, "***USER***")

def redact(text):
    if not isinstance(text, str):
        text = str(text)
    for value, ph in _SECRETS.items():
        if value:
            text = text.replace(value, ph)
            text = text.replace(urllib.parse.quote(value, safe=""), ph)
    return text

def host_only(url):
    try:
        p = urllib.parse.urlsplit(url)
        return f"{p.scheme}://{p.hostname}" + (f":{p.port}" if p.port else "") + p.path
    except Exception:
        return "<unpar+seable>"

# ---- structured log --------------------------------------------------------
EVENTS = []

def log_event(op, endpoint, http_status, resp_type, note, result):
    row = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "op": op,
        "endpoint": redact(host_only(endpoint)) if endpoint else "",
        "http": http_status,
        "resp_type": resp_type,
        "note": redact(note),
        "result": result,
    }
    EVENTS.append(row)
    print(f"  [{result:7}] {op:22} http={http_status} type={resp_type} {redact(note)}")
    return row

# ---- envelope --------------------------------------------------------------
def base_envelope(mode, user, pwd, extra=None):
    env_obj = {
        "code": "00000000",
        "user": user,
        "pass": pwd,
        "mac": DEV_MAC,
        "sn": DEV_MAC,
        "model": DEV_MODEL,
        "group": 0,
        "mode": mode,
    }
    if extra:
        env_obj.update(extra)
    return env_obj

# ---- transport -------------------------------------------------------------
def content_post(base_url, payload):
    """POST {base_url} with json=XOR(payload). Returns (http, decoded_obj_or_None, note)."""
    body_json = json.dumps(payload, separators=(",", ":"))
    cipher = encode_payload(body_json)
    body = b"json=" + urllib.parse.quote_from_bytes(cipher, safe="").encode("ascii")
    req = urllib.request.Request(
        base_url, data=body, method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded",
                 "Accept-Encoding": "identity"},
    )
    try:
        with urllib.request.urlopen(req, timeout=CONTENT_TIMEOUT) as r:
            raw = r.read()
            http = r.status
    except urllib.error.HTTPError as e:
        return e.code, None, f"http-error {e.code} (body not decoded, per Phase 1)"
    except urllib.error.URLError as e:
        return None, None, f"connectivity/DNS error: {type(e.reason).__name__}"
    except Exception as e:  # noqa
        return None, None, f"transport error: {type(e).__name__}"

    if not raw:
        return http, None, "empty response body"
    try:
        decoded = decode_body(raw).strip()
    except Exception as e:  # noqa
        return http, None, f"XOR decode error: {type(e).__name__}"
    try:
        obj = json.loads(decoded)
    except Exception:
        preview = decoded[:60].replace("\n", " ")
        return http, None, f"malformed JSON after decode (preview: {preview!r})"
    return http, obj, "ok"

def plain_get(url, ua=None):
    # Xtream panels 403 unknown UAs (e.g. Python-urllib); use an OkHttp-like UA
    # (or the account user_agent) so the documented EPG call behaves as in-app.
    req = urllib.request.Request(url, headers={
        "Accept-Encoding": "identity",
        "User-Agent": ua or "okhttp/3.12.1",
    })
    try:
        with urllib.request.urlopen(req, timeout=CONTENT_TIMEOUT) as r:
            raw = r.read()
            http = r.status
    except urllib.error.HTTPError as e:
        return e.code, None, f"http-error {e.code}"
    except urllib.error.URLError as e:
        return None, None, f"connectivity/DNS error: {type(e.reason).__name__}"
    except Exception as e:  # noqa
        return None, None, f"transport error: {type(e).__name__}"
    try:
        obj = json.loads(raw.decode("utf-8", errors="replace").strip())
    except Exception:
        return http, None, "not JSON"
    return http, obj, "ok"

def media_probe(url, ua):
    """Minimal media reachability check. Reads a few KB, classifies, stops."""
    headers = {"Range": "bytes=0-4095"}
    if ua:
        headers["User-Agent"] = ua
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=MEDIA_TIMEOUT) as r:
            http = r.status
            ctype = r.headers.get("Content-Type", "")
            final = r.geturl()
            chunk = r.read(4096)
    except urllib.error.HTTPError as e:
        return e.code, "", "", f"http-error {e.code}"
    except urllib.error.URLError as e:
        return None, "", "", f"connectivity error: {type(e.reason).__name__}"
    except Exception as e:  # noqa
        return None, "", "", f"transport error: {type(e).__name__}"

    kind = "unknown"
    if chunk.startswith(b"#EXTM3U"):
        kind = "HLS (m3u8 playlist)"
    elif b"\x47" == chunk[:1] or (len(chunk) > 188 and chunk[0] == 0x47 and chunk[188] == 0x47):
        kind = "MPEG-TS (0x47 sync)"
    elif chunk[4:8] == b"ftyp":
        kind = "ISO-BMFF / MP4"
    elif b"application/vnd.apple.mpegurl" in ctype.encode() or "mpegurl" in ctype:
        kind = "HLS (by content-type)"
    elif "dash" in ctype or b"<MPD" in chunk[:256]:
        kind = "DASH (MPD)"
    redirected = (final != url)
    note = f"content-type={ctype!r}; redirected={redirected}; classified={kind}"
    return http, ctype, kind, note

# ---- schema checks (compatibility, not enumeration) ------------------------
def check_keys(obj, keys):
    return {k: (k in obj and obj.get(k) not in (None,)) for k in keys}

# ============================================================================
def main():
    results = {"stages": {}, "determination": [], "meta": {}}
    print("ABK / Eliaa Pro compatibility smoke test")
    print(f"  device envelope: mac={DEV_MAC} model={DEV_MODEL} group=0")
    print(f"  streaming/account host ABK_HOST (redacted, NOT content middleware): "
          f"{host_only(HOST) if HOST else '(unset)'}")
    print(f"  content base ABK_CONTENT_BASE_URL: {host_only(FORCED_BASE) if FORCED_BASE else '(unset)'}")
    print()

    if not (USERNAME and PASSWORD):
        print("BLOCKED: missing ABK_USERNAME / ABK_PASSWORD in environment.")
        results["stages"]["config"] = "BLOCKED"
        emit(results)
        return 2

    # ---- Stage A: determine active content base URL ------------------------
    # Phase 2A CONFIRMED the effective content middleware URL is the Firebase
    # Remote Config `activity` value (https://header21.b-cdn.net at that time),
    # NOT the owner-supplied host. Pass it via ABK_CONTENT_BASE_URL.
    # ABK_HOST is the STREAMING/ACCOUNT host (login-response `host`/`player_api`
    # role) and is intentionally NOT used as a content-base candidate.
    print("[A] Content base URL determination (known candidates only)")
    candidates = []
    if FORCED_BASE:
        candidates.append(("env ABK_CONTENT_BASE_URL", FORCED_BASE))
    candidates.append(("Phase-1 native fallback", NATIVE_FALLBACK))
    if not FORCED_BASE:
        print("  note: set ABK_CONTENT_BASE_URL to the Remote Config `activity` value "
              "(the content middleware URL); ABK_HOST is the streaming host, not content.")

    active_base = None
    login_obj = None
    login_http = None
    for source, url in candidates:
        payload = base_envelope("login", USERNAME, PASSWORD)
        http, obj, note = content_post(url, payload)
        speaks = obj is not None and isinstance(obj, dict) and "status" in obj
        row = {
            "source": source,
            "endpoint": redact(host_only(url)),
            "http": http,
            "speaks_content_protocol": bool(speaks),
            "note": redact(note),
            "result": "PASS" if speaks else "FAIL",
        }
        results["determination"].append(row)
        log_event(f"probe:{source}", url, http,
                  "content-json" if speaks else "n/a", note,
                  "PASS" if speaks else "FAIL")
        if speaks and active_base is None:
            active_base = url
            login_obj = obj
            login_http = http
            break  # first candidate that speaks the protocol wins

    if active_base is None:
        print("\nBLOCKED: no known content base URL responded with the XOR protocol.")
        results["stages"]["base_url"] = "BLOCKED"
        results["meta"]["rebuild_state"] = "BLOCKED"
        emit(results)
        return 2

    results["meta"]["active_base_url"] = redact(host_only(active_base))
    print(f"  -> active content base URL: {redact(host_only(active_base))}")
    print()

    # ---- Stage B: login ----------------------------------------------------
    print("[B] Login compatibility")
    status = login_obj.get("status")
    ok = status in (100, 101)
    fields = ["status", "message", "host", "player_api", "epg_api",
              "username", "password", "user_agent", "timezone", "expire",
              "apk_ver_code", "force_update", "update_url"]
    present = check_keys(login_obj, fields)
    srv_user = login_obj.get("username")
    srv_pass = login_obj.get("password")
    # register any server-returned secrets for redaction, then compute deltas
    register_secret(srv_pass, "***PASS***")
    register_secret(srv_user, "***USER***")
    user_rewritten = bool(srv_user) and (srv_user != USERNAME)
    pass_rewritten = bool(srv_pass) and (srv_pass != PASSWORD)
    login_stage = {
        "http": login_http,
        "status": status,
        "success": ok,
        "fields_present": present,
        "username_rewritten": user_rewritten,
        "password_rewritten": pass_rewritten,
        "message": redact(str(login_obj.get("message", ""))),
        "user_agent": str(login_obj.get("user_agent", "")),
        "timezone": str(login_obj.get("timezone", "")),
        "expire": str(login_obj.get("expire", "")),
        "player_api_host": redact(host_only(login_obj.get("player_api", "") or "")),
        "host_field": redact(host_only(login_obj.get("host", "") or "")),
        "result": "PASS" if ok else "FAIL",
    }
    results["stages"]["login"] = login_stage
    log_event("login", active_base, login_http,
              "account-object",
              f"status={status} success={ok} user_rewritten={user_rewritten} "
              f"pass_rewritten={pass_rewritten}",
              "PASS" if ok else "FAIL")
    if not ok:
        print("\nStop: login not successful (status not in {100,101}); "
              "dependent checks skipped.")
        results["meta"]["rebuild_state"] = "BLOCKED"
        emit(results)
        return 1

    # effective creds for later calls (server may rewrite)
    eff_user = srv_user or USERNAME
    eff_pass = srv_pass or PASSWORD
    ua = login_obj.get("user_agent") or None
    player_api = login_obj.get("player_api") or ""

    # ---- Stage C: packages -------------------------------------------------
    print("\n[C] Live categories (mode=packages)")
    http, cats, note = content_post(active_base, base_envelope("packages", eff_user, eff_pass))
    cats_ok = isinstance(cats, list)
    sample_cat = {}
    if cats_ok and cats:
        c0 = cats[0]
        sample_cat = {k: (k in c0) for k in ("id", "category_name", "category_icon",
                                             "view_order", "ch_count")}
    results["stages"]["packages"] = {
        "http": http, "is_array": cats_ok,
        "count": len(cats) if cats_ok else None,
        "sample_field_presence": sample_cat,
        "result": "PASS" if cats_ok else "FAIL",
    }
    log_event("packages", active_base, http, type(cats).__name__,
              f"array={cats_ok} count={len(cats) if cats_ok else 'n/a'}",
              "PASS" if cats_ok else "FAIL")

    # ---- Stage D: channels -------------------------------------------------
    print("\n[D] Live channels (mode=channels)")
    http, chans, note = content_post(active_base, base_envelope("channels", eff_user, eff_pass))
    chans_ok = isinstance(chans, list)
    with_url = 0
    tpl_user = tpl_pass = 0
    sample_chan = {}
    chosen = None
    if chans_ok:
        for ch in chans:
            su = ch.get("stream_url") or ""
            if su:
                with_url += 1
                if "{user}" in su:
                    tpl_user += 1
                if "{pass}" in su:
                    tpl_pass += 1
        if chans:
            c0 = chans[0]
            sample_chan = {k: (k in c0) for k in ("id", "stream_display_name",
                                                  "category_id", "stream_icon",
                                                  "tv_archive", "has_epg", "stream_url")}
        # choose one ordinary channel that has a stream_url and an id
        for ch in chans:
            if (ch.get("stream_url") or "") and ch.get("id") is not None:
                chosen = ch
                break
    results["stages"]["channels"] = {
        "http": http, "is_array": chans_ok,
        "count": len(chans) if chans_ok else None,
        "with_stream_url": with_url,
        "stream_url_has_user_placeholder": tpl_user,
        "stream_url_has_pass_placeholder": tpl_pass,
        "sample_field_presence": sample_chan,
        "result": "PASS" if (chans_ok and with_url > 0) else "FAIL",
    }
    log_event("channels", active_base, http, type(chans).__name__,
              f"array={chans_ok} count={len(chans) if chans_ok else 'n/a'} "
              f"with_url={with_url} tpl_user={tpl_user} tpl_pass={tpl_pass}",
              "PASS" if (chans_ok and with_url > 0) else "FAIL")

    # ---- Stage E: one playback URL ----------------------------------------
    print("\n[E] Playback URL compatibility (one channel)")
    if chosen is None:
        results["stages"]["playback"] = {"result": "BLOCKED",
                                         "note": "no channel with stream_url"}
        log_event("playback", None, None, "n/a", "no playable channel returned", "BLOCKED")
    else:
        raw_url = chosen.get("stream_url")
        # Phase 1 transform: literal replacement of {user}/{pass}
        play_url = raw_url.replace("{user}", eff_user).replace("{pass}", eff_pass)
        had_tpl = ("{user}" in raw_url) or ("{pass}" in raw_url)
        shape = redact(host_only(play_url))
        ext = play_url.rsplit(".", 1)[-1].split("?")[0][:6] if "." in play_url else ""
        http, ctype, kind, note = media_probe(play_url, ua)
        media_ok = http is not None and http < 400 and kind != "unknown"
        results["stages"]["playback"] = {
            "channel_id": chosen.get("id"),
            "template_had_placeholders": had_tpl,
            "url_shape": shape,
            "url_extension": ext,
            "http": http,
            "media_type": kind,
            "result": "PASS" if media_ok else ("PARTIAL" if http and http < 400 else "FAIL"),
            "note": redact(note),
        }
        log_event("playback", play_url, http, kind,
                  f"tpl={had_tpl} ext={ext} {note}",
                  "PASS" if media_ok else ("PARTIAL" if http and http < 400 else "FAIL"))

    # ---- Stage F: EPG ------------------------------------------------------
    print("\n[F] Short EPG compatibility")
    if player_api and chosen is not None:
        params = urllib.parse.urlencode({
            "username": eff_user, "password": eff_pass,
            "action": "get_short_epg", "stream_id": str(chosen.get("id")),
        })
        epg_url = player_api + ("&" if "?" in player_api else "?") + params
        http, epg, note = plain_get(epg_url, ua=ua)
        listings = epg.get("epg_listings") if isinstance(epg, dict) else None
        epg_ok = isinstance(listings, list)
        b64_ok = None
        item_fields = {}
        if epg_ok and listings:
            it = listings[0]
            item_fields = {k: (k in it) for k in ("title", "start", "end",
                                                  "start_timestamp", "stop_timestamp")}
            import base64
            try:
                base64.b64decode(str(it.get("title", "")), validate=False)
                b64_ok = True
            except Exception:
                b64_ok = False
        results["stages"]["epg"] = {
            "http": http, "is_object": isinstance(epg, dict),
            "has_epg_listings_array": epg_ok,
            "listing_count": len(listings) if epg_ok else None,
            "item_field_presence": item_fields,
            "title_base64_decodable": b64_ok,
            "result": "PASS" if epg_ok else "FAIL",
        }
        log_event("get_short_epg", player_api, http,
                  type(epg).__name__ if epg is not None else "n/a",
                  f"listings={epg_ok} count={len(listings) if epg_ok else 'n/a'} "
                  f"title_b64={b64_ok}",
                  "PASS" if epg_ok else "FAIL")
    else:
        results["stages"]["epg"] = {"result": "BLOCKED",
                                    "note": "no player_api or no channel id"}
        log_event("get_short_epg", None, None, "n/a",
                  "player_api absent or no channel", "BLOCKED")

    # ---- Stage G: movies (optional smoke) ---------------------------------
    print("\n[G] Movies smoke (optional)")
    run_optional(results, active_base, eff_user, eff_pass, ua, family="movies")

    # ---- Stage H: series (optional smoke) ---------------------------------
    print("\n[H] Series smoke (optional)")
    run_optional(results, active_base, eff_user, eff_pass, ua, family="series")

    # ---- verdict -----------------------------------------------------------
    login_pass = login_stage["result"] == "PASS"
    pkg_pass = results["stages"]["packages"]["result"] == "PASS"
    chan_pass = results["stages"]["channels"]["result"] == "PASS"
    play = results["stages"]["playback"]["result"]
    core = login_pass and pkg_pass and chan_pass and play in ("PASS", "PARTIAL")
    if not login_pass:
        state = "BLOCKED"
    elif core and play == "PASS":
        state = "READY"
    elif core:
        state = "PARTIALLY READY"
    else:
        state = "PARTIALLY READY" if login_pass else "BLOCKED"
    results["meta"]["rebuild_state"] = state
    print(f"\nREBUILD STATE: {state}")
    emit(results)
    return 0


def run_optional(results, base, user, pwd, ua, family):
    cat_mode = f"{family[:-1] if False else family}_cat" if False else (
        "movies_cat" if family == "movies" else "series_cat")
    list_mode = "movies_list" if family == "movies" else "series_list"
    info_mode = "movies_info" if family == "movies" else "series_info"
    id_field = "movie_id" if family == "movies" else "series_id"

    http, cats, _ = content_post(base, base_envelope(cat_mode, user, pwd))
    cats_ok = isinstance(cats, list)
    log_event(cat_mode, base, http, type(cats).__name__,
              f"array={cats_ok} count={len(cats) if cats_ok else 'n/a'}",
              "PASS" if cats_ok else "FAIL")

    http, lst, _ = content_post(base, base_envelope(list_mode, user, pwd))
    lst_ok = isinstance(lst, list)
    log_event(list_mode, base, http, type(lst).__name__,
              f"array={lst_ok} count={len(lst) if lst_ok else 'n/a'}",
              "PASS" if lst_ok else "FAIL")

    info_result = {"result": "NOT TESTED"}
    if lst_ok and lst:
        item_id = lst[0].get("id")
        http, info, _ = content_post(
            base, base_envelope(info_mode, user, pwd, extra={id_field: str(item_id)}))
        if family == "movies":
            # movies_info -> array; element[0].stream_url is an OBJECT (quality map)
            arr_ok = isinstance(info, list)
            su_type = None
            quality_keys = []
            if arr_ok and info:
                su = info[0].get("stream_url")
                su_type = type(su).__name__
                if isinstance(su, dict):
                    quality_keys = sorted(su.keys())
            info_result = {
                "http": http, "is_array": arr_ok,
                "stream_url_runtime_type": su_type,
                "quality_keys": quality_keys,
                "matches_static_contract": (su_type == "dict"),
                "result": "PASS" if arr_ok and su_type == "dict" else
                          ("PARTIAL" if arr_ok else "FAIL"),
            }
            log_event(info_mode, base, http, type(info).__name__,
                      f"array={arr_ok} stream_url_type={su_type} keys={quality_keys}",
                      info_result["result"])
        else:
            # series_info -> object { info, seasons:[{season_num, episodes:[...]}] }
            obj_ok = isinstance(info, dict)
            has_info = obj_ok and isinstance(info.get("info"), dict)
            seasons = info.get("seasons") if obj_ok else None
            seasons_ok = isinstance(seasons, list)
            ep_fields = {}
            if seasons_ok and seasons:
                eps = seasons[0].get("episodes")
                if isinstance(eps, list) and eps:
                    ep_fields = {k: (k in eps[0]) for k in
                                 ("episode_num", "episode_name", "stream_url")}
            info_result = {
                "http": http, "is_object": obj_ok,
                "has_info": has_info, "has_seasons_array": seasons_ok,
                "episode_field_presence": ep_fields,
                "result": "PASS" if (has_info and seasons_ok) else
                          ("PARTIAL" if obj_ok else "FAIL"),
            }
            log_event(info_mode, base, http, type(info).__name__,
                      f"object={obj_ok} has_info={has_info} seasons={seasons_ok}",
                      info_result["result"])
    results["stages"][family] = {
        "cat": {"http": http, "is_array": cats_ok, "count": len(cats) if cats_ok else None},
        "list": {"is_array": lst_ok, "count": len(lst) if lst_ok else None},
        "info": info_result,
        "result": info_result.get("result", "NOT TESTED"),
    }


def emit(results):
    # sanitized machine-readable summary for report authoring
    results["log"] = EVENTS
    out = json.dumps(results, indent=2, ensure_ascii=False)
    out = redact(out)
    path = os.path.join(os.path.dirname(__file__), "last_run.sanitized.json")
    with open(path, "w") as f:
        f.write(out)
    print(f"\n[sanitized summary written to {os.path.basename(path)}]")
    print("=== SUMMARY-JSON-BEGIN ===")
    print(out)
    print("=== SUMMARY-JSON-END ===")


if __name__ == "__main__":
    sys.exit(main())
