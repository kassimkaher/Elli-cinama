# ABK Static Application Recovery Report — Phase 1

**Analysis type:** Static, local, offline only. No network requests were made, no credentials used, no endpoint probing performed.
**Target:** JADX-decompiled Android project at `app/src/main/`
**Date of analysis:** 2026-08-24

---

## 0. Identity note

The project is referred to as "ABK" in the task brief. The decompiled artifact identifies itself as:

| Field | Value | Evidence |
|---|---|---|
| Gradle project name | `Eliaa Pro` | `settings.gradle:1` |
| `applicationId` | `com.mbm_soft.eliaapro` | `app/build.gradle:11`, `AndroidManifest.xml` `package=` |
| `app_name` string | `Eliaa Pro` | `res/values/strings.xml:51` |
| versionName / versionCode | `3.4` / `24` | `AndroidManifest.xml`, `app/build.gradle` |
| Firebase project | `eliaapro` | `res/values/strings.xml:238` |

Throughout this document "ABK" and "the app" refer to `com.mbm_soft.eliaapro` v3.4 as decompiled. No ABK-branded string, resource, or class was found anywhere in the tree; if ABK is a rebrand of this same codebase, the analysis still holds, but that mapping is **UNRESOLVED** from local evidence.

---

## 1. Executive summary

ABK/Eliaa Pro is a **leanback-first (Android TV + touch) IPTV client** built on a classic MVVM + Dagger 2 + Room + RxJava2 stack, using **ExoPlayer 2** and **libVLC** as interchangeable playback engines.

The most important architectural finding, and the one that dominates every rebuild decision:

> **The app does not talk to an Xtream Codes server directly for content. It talks to a single custom PHP middleware endpoint, sending one form field (`json`) containing an XOR-obfuscated JSON document, and receives an XOR-obfuscated JSON response. The middleware returns *ready-made stream URLs*; the client does not construct live/VOD stream URLs from stream IDs.**

Concretely:

- **One content endpoint**, recovered from the native library: `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` — every content operation is a `POST` to this same URL, discriminated by a `mode` field inside the encrypted payload.
- **Obfuscation is a fixed 15-byte repeating XOR** with the key `r+3e>@y](7wEEM[`, also recovered from the native library. It is symmetric and applied to both request payload and response body.
- **Base URL is runtime-overridable via Firebase Remote Config** under the key `activity` — the native default is a fallback.
- **Live stream URLs are server-supplied templates** containing literal `{user}` and `{pass}` placeholders that the client substitutes locally. VOD/series stream URLs are used **verbatim** with no substitution.
- **A second, unencrypted channel exists for EPG only**: a plain `GET` against the Xtream Codes `player_api.php` URL returned by login, using `action=get_short_epg`. This is the only place where a genuine Xtream Codes API is confirmed.
- **Two independent anti-repackaging tripwires** are present (one native, one pure-Java) and both must be understood before any rebuild.

**Verdict: a clean rebuild is feasible.** Every stage of the required flow (server config → login → authenticated state → categories → channels → stream URL → player) is recoverable from local evidence. The single genuine unknown is the exact set of *response* field values the server emits for edge cases; field *names* and *types* are fully recovered from the Gson-annotated models.

---

## 2. Application architecture

### 2.1 Component map

```
                          ┌──────────────────────────────────────┐
                          │  libnative-lib.so (4 ABIs)           │
                          │   getValue()      → base API URL     │
                          │   getKeyValue()   → XOR key          │
                          │   checkPackage()  → anti-repack trap │
                          └───────────────┬──────────────────────┘
                                          │ JNI
  Firebase Remote Config ──"activity"──►  │
  (overrides base URL)                    ▼
┌───────────────┐   ┌──────────────────────────────────────────────────┐
│ IntroActivity │──►│ AppApiHelper (remote/)                           │
│  (LAUNCHER)   │   │  POST {baseUrl}  body: json=XOR(payload)         │
└───────┬───────┘   │  GET  {player_api} ?action=get_short_epg (plain) │
        │           └──────────────────┬───────────────────────────────┘
        │                              │
        ▼                              ▼
┌───────────────┐        ┌──────────────────────────────┐
│ HomeActivity  │        │ C2606a  "DataManager"        │
│               │        │  = ApiHelper + DbHelper      │
├───────────────┤        │    + PreferencesHelper       │
│ LiveActivity  │◄──────►│    + Gson                    │
│ MoviesActivity│        └──────┬─────────────┬─────────┘
│ SeriesActivity│               │             │
│ MovieInfo     │               ▼             ▼
│ SeriesInfo    │      ┌────────────────┐  ┌──────────────────┐
│ SettingsAct.  │      │ Room           │  │ SharedPreferences│
│ VodActivity   │      │ eliaapro.db    │  │ "snap_pref"      │
│ VodVlcActivity│      │ 7 tables       │  │ session + config │
│ YouTubePlayer │      └────────────────┘  └──────────────────┘
└───────┬───────┘
        ▼
┌────────────────────────────────────────────────────────────┐
│ Playback:  ExoPlayer 2 (SimpleExoPlayer + DefaultTrackSel.) │
│            libVLC   (LibVLC + MediaPlayer)                  │
│            MX Player / VLC external via Intent              │
└────────────────────────────────────────────────────────────┘
```

### 2.2 Application class

`com.mbm_soft.eliaapro.QuickPlayerApp` (`QuickPlayerApp.java`) — extends `MultiDexApplication`, implements Dagger `HasActivityInjector`.

`onCreate()` performs, in order (`QuickPlayerApp.java:169-176`):
1. `f7775q = this` — static singleton.
2. `this.f7776j = Util.getUserAgent(this, "eliaapro")` — the *default* ExoPlayer user-agent string.
3. Dagger component build + inject (`C3669b.m15810c()...`).
4. `AndroidNetworking.initialize(context, okHttpClient)` where the client is `new OkHttpClient().newBuilder().addInterceptor(new C1717a()).build()`.

Static initializer: `System.loadLibrary("native-lib")` (`QuickPlayerApp.java:63-65`).

**Critical consequence of step 4:** `C1717a` is the XOR *response* decryption interceptor, and it is installed on the **shared** Fast-Android-Networking OkHttp client. Every FAN request that does not override the client therefore gets its response body XOR-decoded automatically.

### 2.3 Activities (all `screenOrientation="sensorLandscape"`)

| Activity | Class | Exported | Role |
|---|---|---|---|
| Intro | `p037ui.intro.IntroActivity` | **yes** (MAIN/LAUNCHER + LEANBACK_LAUNCHER) | Activation/login, update gate |
| Home | `p037ui.home.HomeActivity` | no | Dashboard: Live / Movies / Series / Settings + latest rails |
| Live | `p037ui.live.LiveActivity` | no | Live TV: category list, channel list, embedded player, EPG |
| Movies | `p037ui.movies.MoviesActivity` | no | VOD grid + categories + search |
| MovieInfo | `p037ui.movie_info.MovieInfoActivity` | no | Movie detail, play, trailer, favourite |
| Series | `p037ui.series.SeriesActivity` | no | Series grid + categories + search |
| SeriesInfo | `p037ui.series_info.SeriesInfoActivity` | no | Seasons → episodes, play, trailer |
| Settings | `p037ui.settings.SettingsActivity` | no | Nav-drawer host for 3 fragments |
| Vod (ExoPlayer) | `p037ui.vod_exo.VodActivity` | no | Full-screen ExoPlayer for VOD/catchup |
| VodVlc | `p037ui.vod_vlc.VodVlcActivity` | no | Full-screen libVLC for VOD |
| YouTube | `p037ui.youtube.YouTubePlayerActivity` | no | Trailer playback |

Settings fragments: `p124k7.C2495a` (player selection), `p135l7.C2564a` (user info), `p146m7.C2609a` (user settings / parental password).

### 2.4 Navigation structure

```
IntroActivity  (activation or login)
   └─► HomeActivity
         ├─► LiveActivity        (extra "id" = "EXOPlayer" | "VLC Player")
         │     └─► VodActivity   (extras "stream_name","stream_link")  [catchup/timeshift]
         ├─► MoviesActivity  ──► MovieInfoActivity  (extra "id" = movie id)
         │                          ├─► VodActivity / VodVlcActivity   (extras "stream_name","stream_link")
         │                          ├─► external MX Player / VLC (Intent)
         │                          └─► YouTubePlayerActivity (extra "trailer_link")
         ├─► SeriesActivity  ──► SeriesInfoActivity (extra "id" = series id)
         │                          ├─► VodActivity / VodVlcActivity
         │                          ├─► external MX Player / VLC
         │                          └─► YouTubePlayerActivity
         └─► SettingsActivity  (fragments: user info | player | user settings)
```
Evidence: `HomeActivity.java:160,178,184,232-242,249,258`; `MovieInfoActivity.java:96-123`; `SeriesInfoActivity.java:78-105`; `LiveActivity.java:925-929`.

### 2.5 Third-party stack (identified from decompiled packages)

| Concern | Library | Evidence |
|---|---|---|
| HTTP client | OkHttp 3 | `okhttp3/` source tree, `QuickPlayerApp.java:176` |
| HTTP façade | **Fast Android Networking (FAN)** | `p074g1.C2110a` = `ANRequest`; `p052e1.C1885a` = `AndroidNetworking.initialize`; `p048d8.C1866a/C1867b` = app's `RxHttp` wrapper |
| JSON | **Gson** (`@SerializedName` + `@Expose`) | `p068f6.InterfaceC2027c` / `InterfaceC2025a` on every model; `p057e6.C1935f/C1936g` = `Gson`/`GsonBuilder` |
| Reactive | RxJava 2 (`Flowable`/`Single`) + RxAndroid | `p092h8.AbstractC2300f` (Flowable), `AbstractC2296b` (Single), `p114j8.C2428a` = `AndroidSchedulers`, `p270y8.C3742a` = `Schedulers` |
| DI | Dagger 2 + `dagger.android` | `p081g8.InterfaceC2173c` = `Factory`, `p059e8.C1983c` = `DispatchingAndroidInjector`, `p258x6.C3669b` component |
| Persistence | **Room** | `androidx/room/`, `AppDatabase`, `AppDatabase_Impl` |
| Prefs | `SharedPreferences` name `snap_pref` | `p268y6.C3724a.m16113h()` |
| Player A | **ExoPlayer 2** (DASH/HLS/SS/Progressive + downloads) | `com.google.android.exoplayer2.*`, `C3008b1` = `SimpleExoPlayer` |
| Player B | **libVLC** (`libvlc.so`, `libvlcjni.so`, ffmpeg) | `org.videolan.libvlc.*`, `LiveActivity.java:1104-1113` |
| Images | **Glide 4** + OkHttp integration | `QuickGlideModule`, manifest `OkHttpGlideModule` meta-data |
| View binding | Android Data Binding + **ButterKnife** | `DataBinderMapperImpl`, `*_ViewBinding.java`, `butterknife/` |
| Screen scaling | **AndroidAutoSize** (`me.jessyan.autosize`) | manifest `InitProvider`, `design_width_in_dp=1280`, `design_height_in_dp=720` |
| Remote config | Firebase Remote Config | `IntroActivity.m7860v0()` |
| Analytics | Firebase Analytics / GMS Measurement | manifest services |
| Layout helpers | ConstraintLayout, Material Components, RecyclerView, ViewPager/ViewPager2 | `res/layout`, `androidx/` |

### 2.6 Background components

| Component | Class | Notes |
|---|---|---|
| Boot receiver | `utils.BootUpReceiver` | **DEAD CODE** — see §11.3 |
| Download service | `utils.AppDownloadService` | ExoPlayer `DownloadService` subclass; not reachable from any UI path found |
| ExoPlayer scheduler | `com.google.android.exoplayer2.scheduler.PlatformScheduler$PlatformSchedulerService` | library-provided |

---

## 3. Backend configuration found in the APK

### 3.1 Primary content endpoint — CONFIRMED

```
http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php
```

**Evidence chain (all four ABIs agree):**

1. `AppApiHelper.java:16` — `public static String f7849a = getValue();`
2. `AppApiHelper.java:23` — `public static native String getValue();`
3. Disassembly of `Java_com_mbm_1soft_eliaapro_remote_AppApiHelper_getValue` in `lib/arm64-v8a/libnative-lib.so` @ `0x1ed9c`:
   ```asm
   ldr  x8, [x0]              ; JNIEnv vtable
   adrp x1, 0x15000
   add  x1, x1, #0xf64        ; → 0x15f64
   ldr  x2, [x8, #0x538]      ; NewStringUTF
   br   x2
   ```
4. File offset `0x15f64` contains the NUL-terminated ASCII string `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php`
   (confirmed by `strings -a -t x`: `15f64 http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php`).
5. Same string present at `armeabi-v7a` offset `0x10d4f`, and in `x86` / `x86_64`.

Breakdown: scheme `http` (cleartext — manifest sets `android:usesCleartextTraffic="true"`), host `googeleb.xyz`, port `2082`, path `/iptv/V6APK/V6APKFaster.php`.

### 3.2 Runtime base-URL override — CONFIRMED

`IntroActivity.m7860v0()` fetches Firebase Remote Config with a 360-second minimum fetch interval, then in `C1723a.onComplete` (smali-level logic preserved in the JADX comment block, `IntroActivity.java:44-96`):

```
if (task.isSuccessful()) {
    String v = remoteConfig.getString("activity");
    if (!v.isEmpty()) {
        AppApiHelper.m7814a(v);      // overwrite static base URL
    }
}
... then request permissions / continue to m7854x0()
```

`AppApiHelper.m7814a(String)` (`AppApiHelper.java:19-21`) assigns `f7849a`.

**So the effective base URL is: Firebase Remote Config key `activity` if non-empty, otherwise the native constant.** A rebuild must treat the base URL as *configurable*, not hard-coded.

Firebase identifiers present in `res/values/strings.xml`:
| Key | Value |
|---|---|
| `project_id` | `eliaapro` |
| `google_app_id` | `1:722642815778:android:81593e922af4127dd0737b` |
| `gcm_defaultSenderId` | `722642815778` |
| `google_api_key` | `AIzaSyBZyxL8c2-a9bE1IXv8zxtL-ctueI-JIrs` |
| `google_storage_bucket` | `eliaapro.appspot.com` |

### 3.3 Payload obfuscation key — CONFIRMED

```
r+3e>@y](7wEEM[
```
15 bytes: `72 2b 33 65 3e 40 79 5d 28 37 77 45 45 4d 5b`

**Evidence:**
1. `DecInterceptor.java:26` — `public static native String getKeyValue();`
2. Disassembly of `Java_com_mbm_1soft_eliaapro_remote_DecInterceptor_getKeyValue` @ `0x1edb0` resolves to `0x15000 + 0xdd0 = 0x15dd0`.
3. Hexdump at file offset `0x15dd0`:
   ```
   00000000: 722b 3365 3e40 795d 2837 7745 454d 5b00   r+3e>@y](7wEEM[.
   ```
4. Cross-checked on `x86_64` (`leaq -0xb9be(%rip)` → `0x15623`, identical 15 bytes) and via `strings -a -t x` on `armeabi-v7a` (`10c23 r+3e>@y](7wEEM[`).

### 3.4 Session-scoped hosts (received from login, not hard-coded)

These are **not** in the APK — they arrive in the login/activation response and are persisted. They are listed here because a rebuild must plan for them:

| Response field | Stored pref key | Consumed by |
|---|---|---|
| `host` | `PREF_KEY_HOST` | timeshift/catchup URL builder (`C2606a.mo11196e0`) |
| `player_api` | `PREF_KEY_PLAYER_API` | EPG GET (`C2606a.mo11225w`) |
| `epg_api` | `PREF_KEY_EPG_API` | **stored but never read** — no getter exists in `InterfaceC2984c` |
| `update_url` | (not persisted) | APK self-update download (`C3101e`) |

### 3.5 Media / image hosts

**No image or CDN host is hard-coded.** Logos, icons, posters and backdrops are absolute URLs delivered inside the API responses and passed straight to Glide.
Evidence: `LiveActivity.java:1128` — `C3735l.m16156a(ctx).m16205E(c3088d.m13691f())` where `m13691f()` returns the raw `stream_icon` string. Same pattern in `LiveCatAdapter`, `MovieAdapter`, `SeriesAdapter`.

### 3.6 Other URLs in the app

| URL | Location | Purpose |
|---|---|---|
| `https://play.google.com/store/apps/details?id=` | `res/values/strings.xml` | Prefix used by `p189q7.C3098b.m13737b()` to send the user to Play Store when MX Player / VLC is not installed |

No other `http://` or `https://` literal exists in app-owned Java or in `res/values/`. There is **no `assets/` directory**.

---

## 4. Authentication flow

### 4.1 What the login screen collects

`res/layout/activity_intro.xml` contains exactly these inputs:

| View id | Purpose |
|---|---|
| `is_code_checkbox` | Toggles **activation-code mode** vs **username/password mode** |
| (username/code EditText, `f15421O`) | Hint switches between `@string/active_code` ("Active Code") and `@string/username` ("UserName") |
| (password EditText, `f15426T`) | Hidden in code mode; `@string/password` |
| `show_pass_checkbox` | Toggle password visibility |
| `mac_address` | **Read-only display** of the device MAC |
| `activate_btn` | Submit |
| `activation_message` | Server `message` / error display |
| `loading` | Progress |

> **There is no host / server / portal / DNS input field anywhere in the app.** The backend address is fixed (native constant + Remote Config), and the *streaming* host arrives from the login response. This is the single biggest structural difference from a conventional Xtream Codes client.

### 4.2 How host/server information is represented

- **API host**: compile-time native constant, overridable by Firebase Remote Config key `activity`. Not user-editable.
- **Streaming host**: `host` field of the login response → `PREF_KEY_HOST`. Used *only* for the catchup/timeshift URL. Live/VOD playback does not use it (URLs are fully-qualified from the server).
- **EPG host**: `player_api` field of the login response → `PREF_KEY_PLAYER_API`. Used as a complete URL (the app appends query parameters to it).

### 4.3 Credential handling internally

`p178p6.C2982a` (SharedPreferences `snap_pref`):

| Concept | Pref key | Writer | Reader |
|---|---|---|---|
| Activation mode flag | `PREF_KEY_ACTIVATION_TYPE` (bool, **default `true` = code mode**) | `mo11219s0` | `mo11169K0` |
| Activation code | `PREF_KEY_ACTIVE_CODE` | `mo11231z0` | `mo11177P` |
| Username | `PREF_KEY_USERNAME` | `mo11186Z` | `mo11159F` |
| Password | `PREF_KEY_PASSWORD` | `mo11188a0` | `mo11229y0` |
| Device MAC | `PREF_KEY_MAC_ADDRESS` | `mo11171L0` | `mo11152B0` |
| Serial number | `PREF_KEY_SERIAL_NUMBER` | `mo11156D0` | **no reader** |

All values are stored **in plaintext** in the app-private prefs file. No encryption, no keystore.

### 4.4 Device identity

`p189q7.C3104h.m13754b()` (`C3104h.java:36-40`):
1. Read MAC of `wlan0`; if not the Android-10+ placeholder `02:00:00:00:00:00`, use it.
2. Else read MAC of `eth0`; if not the placeholder, use it.
3. Else return `02:00:00:00:00:00`.

Formatted lowercase hex, colon-separated. Written to **both** `PREF_KEY_MAC_ADDRESS` and `PREF_KEY_SERIAL_NUMBER` (`C1730c.m7874q()`), but since `PREF_KEY_SERIAL_NUMBER` has no reader, `mac` and `sn` in every request are always the same value.

> On Android 10+ this always yields `02:00:00:00:00:00` for a non-privileged app. Device identity is therefore effectively non-unique on modern devices — relevant to `act_limit`/`act_cnt` semantics.

### 4.5 The base request envelope

`C2606a.m11178P0()` (`C2606a.java:225-243`) — every content request starts here:

```java
JSONObject o = new JSONObject();
if (isActivationCodeMode()) {                 // PREF_KEY_ACTIVATION_TYPE, default true
    o.put("code", activeCode);                // PREF_KEY_ACTIVE_CODE
} else {
    o.put("code", "00000000");                // literal sentinel
    o.put("user", username);                  // PREF_KEY_USERNAME
    o.put("pass", password);                  // PREF_KEY_PASSWORD
}
o.put("mac",   macAddress);                   // PREF_KEY_MAC_ADDRESS
o.put("sn",    macAddress);                   // same value
o.put("model", Build.DEVICE);
o.put("group", 0);                            // integer literal
return o;
```

`mo11168K(mode)` then adds `"mode"`; `mo11151B(mode, movieId)` adds `"mode"` + `"movie_id"`; `mo11208l0(mode, seriesId)` adds `"mode"` + `"series_id"`.

**Credentials are therefore carried in the request *body*, inside the XOR-obfuscated JSON — on every single call.** There is no bearer token, no cookie, no `Authorization` header, and no session id.

### 4.6 Transport encoding

`AppApiHelper.mo66Q` and siblings:
```java
C1867b.m8505b(f7849a)                            // POST builder (ANRequest.k, methodType = 1)
      .m9405s("json", DecInterceptor.m7815a(jsonObject.toString()))
      .m8503t()
      .m8501P(C3164a.class)                       // Gson-parse to model
```

- `C1867b.m8505b` → `C1866a.b extends C2110a.k`; `k(String)` sets `f9315b = 1` = POST (`C2110a.java:526-530`).
- `m9405s(k,v)` writes into `f9323j` → copied to `f9268i` (`C2110a.java:597`) → emitted via `FormBody.Builder.add(key, value)` (`C2110a.java:1101-1105`).
- Result: `Content-Type: application/x-www-form-urlencoded`, single field `json`.

`DecInterceptor.m7815a` (`DecInterceptor.java:6-24`) — repeating-key XOR over `char`s:
```java
String key = getKeyValue();                  // native → "r+3e>@y](7wEEM["
char[] k = key.toCharArray(), s = str.toCharArray();
char[] out = new char[s.length];
for (int i = 0; i < s.length; i++)
    out[i] = (char)(s[i] ^ k[i % k.length]);
return new String(out);
```
Returns `null` on any exception. XOR is symmetric, so the same function encodes requests and decodes responses. Verified locally: round-trip is exact, and since both operands are ASCII the ciphertext stays below `0x80` (control characters included), which is why percent-encoded form transport is used rather than Base64.

Response side — `C1717a implements Interceptor` (`C1717a.java:12-27`), installed on the shared FAN OkHttp client:
```java
Response r = chain.proceed(chain.request());
if (!r.isSuccessful()) return r;                       // errors pass through raw
String ct = r.header("Content-Type");
if (TextUtils.isEmpty(ct)) ct = "text/plain;charset=utf-8";
return r.newBuilder()
        .body(ResponseBody.create(MediaType.parse(ct),
              DecInterceptor.m7815a(r.body().string()).trim()))
        .build();
```
Note the `.trim()` and the non-2xx bypass.

### 4.7 Login / activation sequence

`p037ui.intro.C1730c` (view-model) + `IntroActivity`.

```
onCreate
  └─ m7860v0()  Firebase Remote Config fetchAndActivate (min interval 360 s)
        └─ if remoteConfig["activity"] non-empty → AppApiHelper.setBaseUrl(it)
        └─ request runtime permissions → m7854x0()

m7854x0()  wire checkboxes, prefill saved code/user/pass, show MAC
  └─ m7874q()
        ├─ if MAC pref null → C3104h.m13754b(), store to MAC + SERIAL prefs
        └─ if PREF_KEY_ACTIVATION_TYPE (default true)
              ├─ m7873C(): if activeCode != null → m7871A()  [mode "active"]
              │             else stop, show form
              └─ else m7872B(): if user != null && pass != null → m7879z()  [mode "login"]
                                 else stop, show form

user taps activate → InterfaceC1729b.mo7856E()  (IntroActivity.java:236-260)
   code mode : validate non-empty → C1730c.m7878y(code)  → save code  → m7871A()  ["active"]
   user mode : validate both non-empty → C1730c.m7876w(u,p) → save both → m7879z() ["login"]
   invalid   : Toast R.string.invalid_active_code
```

Both `m7871A()` (`mode="active"`) and `m7879z()` (`mode="login"`) call the **same** transport method `mo66Q(JSONObject)` and expect the **same** response model `p198r6.C3164a`. `FirebaseAnalytics.Event.LOGIN` is the constant `"login"`.

### 4.8 Success / failure determination — CONFIRMED

`C1730c.m7867s(C3164a)` / `m7869u(C3164a)` — byte-identical handlers (`C1730c.java:20-40`, `46-66`):

```java
int status = resp.getStatus();               // "status"
String msg  = resp.getMessage();             // "message"
if (status != 100 && status != 101) {
    setLoading(false);
    view.showMessage(msg);                   // stay on intro screen
    return;
}
// SUCCESS — persist session
dataManager.updateUserInfo(
    resp.getMessage(),      // → PREF_KEY_MESSAGE
    resp.getExpire(),       // → PREF_KEY_EXPIRE
    resp.getUserAgent(),    // → PREF_KEY_USER_AGENT
    resp.getPlayerApi(),    // → PREF_KEY_PLAYER_API
    resp.getHost(),         // → PREF_KEY_HOST
    resp.getUsername(),     // → PREF_KEY_USERNAME   (server may rewrite)
    resp.getPassword(),     // → PREF_KEY_PASSWORD   (server may rewrite)
    resp.getEpgApi(),       // → PREF_KEY_EPG_API
    resp.getTimezone());    // → PREF_KEY_TIME_ZONE

// update gate
double remote;
try   { remote = Double.parseDouble(resp.getApkVerCode()); }
catch (Exception e) { remote = Double.parseDouble("3.4"); }   // local version, hard-coded

if (resp.getForceUpdate() == 1 && remote > 3.4) {
    view.showMessage("Downloading update to downloads");
    view.showMessage("If didn't started, please open the update from Downloads");
    view.downloadUpdate(resp.getUpdateUrl());        // DownloadManager, blocks entry
} else if (remote > 3.4) {
    view.showUpdateDialog(resp.getUpdateUrl());      // optional; Cancel → proceed
} else {
    view.openHome();                                 // HomeActivity, finish()
}
```

Error path: `m7868t/m7870v(Throwable)` only calls `setLoading(false)` — **network/parse failures are silently swallowed**, leaving the intro screen with no message.

**Two success codes: `100` and `101`.** Their distinction is not used anywhere in the client — UNRESOLVED whether one means "trial" or "activated".

> **Important:** the server can *rewrite* the stored username and password via `resp.username` / `resp.password`. In activation-code mode the client has no username/password at all until this response arrives — the server maps a code to a credential pair. Those rewritten credentials are what later get substituted into `{user}` / `{pass}` in stream URLs and sent to the EPG endpoint.

### 4.9 Session reuse on later requests

Every subsequent content call re-runs `m11178P0()`, i.e. re-sends `code` (or `user`+`pass`) + `mac` + `sn` + `model` + `group`. There is no stateful session.

The EPG call is the exception — it uses the credentials as **plain query parameters** (`C2606a.mo11224v`, `C2606a.java:371-379`):
```java
Map<String,String> m = new HashMap<>();
m.put("username",  getUsername());
m.put("password",  getPassword());
m.put("action",    "get_short_epg");
m.put("stream_id", streamId);
```

### 4.10 Logout / session expiry

- **No logout UI or code path exists.** No method clears `PREF_KEY_USERNAME` / `PREF_KEY_PASSWORD` / `PREF_KEY_ACTIVE_CODE`.
- `expire` is stored (`PREF_KEY_EXPIRE`) and displayed in the user-info settings fragment (`p135l7.C2564a`), but is **never compared against the clock**.
- Effective expiry enforcement is entirely server-side: on next launch the app re-sends credentials and the server returns a non-100/101 `status` + `message`, which the intro screen displays; the user simply cannot get past `IntroActivity`.
- `PREF_KEY_USER_PASSWORD` (default `"12345"`) is a **local parental-control PIN**, unrelated to the account password. Set/cleared in `p146m7.C2609a`; checked in `LiveActivity.m7975z1()` and the lock dialogs.

**Status: CONFIRMED** for login/activation, persistence, and reuse. **NOT FOUND**: any logout, token refresh, or client-side expiry check.

---

## 5. Recovered API operations

All content operations share the same wire format. Full detail in `ABK_API_CONTRACT.md`; summary here.

**Transport (all `mode` operations):**
```
POST {baseUrl}
Content-Type: application/x-www-form-urlencoded
Body: json=<urlencoded XOR("r+3e>@y](7wEEM[", <json>)>
Response body: XOR-obfuscated JSON (auto-decoded by C1717a on 2xx only)
```

| # | Operation | `mode` | Extra payload | Response type | Consumer |
|---|---|---|---|---|---|
| 1 | Activate (code) | `active` | — | `C3164a` (object) | `C1730c.m7871A` |
| 2 | Login (user/pass) | `login` | — | `C3164a` (object) | `C1730c.m7879z` |
| 3 | Live categories | `packages` | — | `List<C3087c>` | `C1757c.m8033c0` |
| 4 | Live channels | `channels` | — | `List<C3088d>` | `C1757c.m8033c0` |
| 5 | Movie categories | `movies_cat` | — | `List<C3091g>` | `C1767d` (`:224`) |
| 6 | Movie list | `movies_list` | — | `List<C3090f>` | `C1767d` (`:157`) |
| 7 | Latest movies | `movies_latest` | — | `List<C3090f>` | `C1722c` (`:103`) |
| 8 | Movie info | `movies_info` | `movie_id` | `List<C3092h>` | `C1760c` (`:133`) |
| 9 | Series categories | `series_cat` | — | `List<C3095k>` | `C1774d` (`:158`) |
| 10 | Series list | `series_list` | — | `List<C3094j>` | `C1774d` (`:189`) |
| 11 | Latest series | `series_latest` | — | `List<C3094j>` | `C1722c` (`:119`) |
| 12 | Series info | `series_info` | `series_id` | `C3314b` (object) | `C1779c` (`:127`) |
| 13 | Short EPG | *(separate GET)* | see below | `C3235b` (object) | `C1757c.m8025E` |

**Operation 13 is structurally different** (`AppApiHelper.mo68g0`, `AppApiHelper.java:44-47`):
```java
C1867b.m8504a(url)                                    // GET builder (ANRequest.j, methodType = 0)
      .m9385q(map)                                     // → query parameters
      .m9386r(new OkHttpClient().newBuilder().build()) // ← FRESH client, NO C1717a interceptor
      .m8502s()
      .m8501P(C3235b.class);
```
The explicit fresh `OkHttpClient` means **the EPG response is *not* XOR-decoded — it is plain JSON**. Combined with `action=get_short_epg`, `username`, `password`, `stream_id` and Base64-encoded programme titles, this is a **confirmed genuine Xtream Codes `player_api.php` endpoint**.

**Notable absences (NOT FOUND):**
- No search endpoint — search is a local Room `LIKE` query.
- No favourites/history endpoint — both are local-only (`item_settings_table`).
- No separate bootstrap/config endpoint — Firebase Remote Config fills that role.
- No `get_live_streams` / `get_vod_streams` / `get_series` Xtream actions for content — only `get_short_epg`.
- No pagination parameters anywhere; `channels` / `movies_list` / `series_list` return the full catalogue in one response.

### 5.1 API family determination

| Layer | Family | Confidence |
|---|---|---|
| Content (`mode=*`) | **Proprietary "V6APK" PHP middleware.** Not Xtream Codes. Single endpoint, encrypted body, `mode` discriminator, server-rendered stream URLs. | **CONFIRMED** |
| EPG (`player_api`) | **Xtream Codes / XUI `player_api.php`** — `action=get_short_epg`, `username`/`password` query auth, `epg_listings[]` with Base64 `title`, `start`/`end`/`start_timestamp`/`stop_timestamp`. | **CONFIRMED** |
| Catchup (`/timeshift/...`) | **Xtream Codes timeshift path convention** | **CONFIRMED** (client-side construction) |
| Upstream of the middleware | The login response carries `player_api`, `epg_api`, `allowed_output_formats`, `max_connections`, `expire` — all Xtream Codes vocabulary, strongly suggesting the PHP layer proxies a real Xtream panel. | **STRONGLY INFERRED** |

---

## 6. Data models

Package `p188q6` = `q6`, `p198r6` = `r6`, `p208s6` = `s6`, `p218t6` = `t6`. Every field carries `@SerializedName` (`p068f6.InterfaceC2027c`) + `@Expose` (`p068f6.InterfaceC2025a`) unless noted.

### 6.1 `r6.C3164a` — Account / ServerInfo (login + activation response)

| JSON | Field | Type | Getter | Persisted to | Meaning |
|---|---|---|---|---|---|
| `status` | `f14087a` | `Integer` | `m13990i` | — | **100 or 101 = success**; anything else = failure |
| `message` | `f14090d` | `String` | `m13987f` | `PREF_KEY_MESSAGE` | Error text on failure; banner/notice on success |
| `server_name` | `f14088b` | `String` | — | — | never read |
| `apk_ver_code` | `f14089c` | `String` | `m13982a` | — | parsed as `double`, compared to literal `"3.4"` |
| `expire` | `f14091e` | `String` | `m13984c` | `PREF_KEY_EXPIRE` | display only |
| `user_agent` | `f14092f` | `String` | `m13993l` | `PREF_KEY_USER_AGENT` | **HTTP UA for all playback** |
| `username` | `f14093g` | `String` | `m13994m` | `PREF_KEY_USERNAME` | **overwrites local**; feeds `{user}` |
| `password` | `f14094h` | `String` | `m13988g` | `PREF_KEY_PASSWORD` | **overwrites local**; feeds `{pass}` |
| `max_connections` | `f14095i` | `String` | — | — | never read |
| `allowed_output_formats` | `f14096j` | `List<String>` | — | — | never read (Xtream vocabulary) |
| `host` | `f14097k` | `String` | `m13986e` | `PREF_KEY_HOST` | **base for timeshift URL** |
| `player_api` | `f14098l` | `String` | `m13989h` | `PREF_KEY_PLAYER_API` | **full EPG endpoint URL** |
| `epg_api` | `f14099m` | `String` | `m13983b` | `PREF_KEY_EPG_API` | stored, **never read back** |
| `code_id` | `f14100n` | `String` | — | — | never read |
| `force_update` | `f14101o` | `Integer` | `m13985d` | — | `1` = mandatory update |
| `update_url` | `f14102p` | `String` | `m13992k` | — | APK download URL |
| `apk_page` | `f14103q` | `String` | — | — | never read |
| `update_ch` | `f14104r` | `String` | — | — | never read |
| `act_limit` | `f14105s` | `Integer` | — | — | never read |
| `act_cnt` | `f14106t` | `Integer` | — | — | never read |
| `adm_act_cnt` | `f14107u` | `Integer` | — | — | never read |
| `rememberVal` | `f14108v` | `Integer` | — | — | never read |
| `timezone` | `f14109w` | `String` | `m13991j` | `PREF_KEY_TIME_ZONE` | **Java TimeZone id**, used for EPG + catchup |

> `force_update` and `status` are boxed `Integer` and are dereferenced with `.intValue()` without a null check (`C1730c.java:23,34`) → a response omitting `status` or `force_update` will NPE inside the RxJava chain and be swallowed by the error handler, leaving the intro screen silently stuck.

### 6.2 `q6.C3087c` — Live category (`liveCat_table`)

| JSON | Field | Type | Column | Notes |
|---|---|---|---|---|
| `id` | `f13741a` | `String` | `id` (PK) | joins `C3088d.category_id` |
| `category_name` | `f13742b` | `String` | `categoryName` | |
| `category_type` | `f13743c` | `Integer` | `categoryType` | |
| `category_icon` | `f13744d` | `String` | `categoryIcon` | absolute URL |
| `view_order` | `f13745e` | `String` | `viewOrder` | sorted as `CAST(... AS integer)` |
| `ch_count` | `f13746f` | `Integer` | `chCount` | |
| `isLocked` | `f13747g` | `Boolean` | `isLocked` | **overwritten locally** by the `item_settings_table` sub-select |
| `parent` | `f13748h` | `Integer` | `parent` | never read in UI |

A synthetic row is injected client-side at index 0 before persisting (`C1757c.m8003S`, `C1757c.java:130`):
`new C3087c("-1", "FAVORITE", 0, "", "0", 1, false, 0)`.

### 6.3 `q6.C3088d` — LiveChannel (`live_table`) — **the central model**

| JSON | Field | Type | Column | Notes |
|---|---|---|---|---|
| *(none)* | `f13749a` | `int` | `streamId` INTEGER PK AUTOINCREMENT | **local row id only — not a server id** |
| `id` | `f13750b` | `Integer` | `id` | **the stream id.** Used for EPG `stream_id`, catchup path, lock/fav key, dedup |
| `stream_display_name` | `f13751c` | `String` | `streamDisplayName` | title; local search target |
| `category_id` | `f13752d` | `Integer` | `categoryId` | joins `C3087c.id` |
| `stream_icon` | `f13753e` | `String` | `streamIcon` | absolute URL → Glide |
| `view_order` | `f13754f` | `Integer` | `viewOrder` | sort key |
| `tv_archive` | `f13755g` | `int` | `tvArchive` NOT NULL | `!= 0` ⇒ catchup available |
| `has_epg` | `f13756h` | `int` | `hasEPG` NOT NULL | |
| **`stream_url`** | `f13757i` | `String` | `streamUrl` | **ready-made playback URL template containing `{user}` / `{pass}`** |
| *(none)* | `f13758j` | `int` | `isFavorite` NOT NULL DEFAULT 0 | computed by SQL sub-select |
| *(none)* | `f13759k` | `int` | `isLocked` NOT NULL DEFAULT 0 | computed by SQL sub-select |

### 6.4 `q6.C3091g` — Movie category (`movie_Cat_table`)
`id`→`catId` (PK) · `category_name`→`catName` · `category_icon`→`catIcon` · `isLocked` · `stream_count`→`streamCount` · `cat_order`→`catOrder` · `parent_id`→`parentId`

### 6.5 `q6.C3095k` — Series category (`seriesCat_table`)
Identical field set to `C3091g`, distinct table and DAO.

### 6.6 `q6.C3090f` — Movie list item (`movie_table`)
`id` (PK, String) · `stream_display_name` · `category_id` · `stream_icon` · `backdrop` · `view_order` · `plot` · `rating` · `genre` · `cast` · `year` · **`stream_url`** (String, present in the table but **not read by any UI path** — playback goes through `movies_info`)

### 6.7 `q6.C3092h` — Movie detail (`movies_info` response element, not persisted)
`id` · `title` · `trailer` · `catid` (Integer) · `icon` · **`stream_url` → `C3096l` (object, not a string)** · `genre` · `MPAA` · `release_date` · `plot` · `cast` · `duration` · `rating` · `year`

### 6.8 `q6.C3096l` — Movie stream quality map

| JSON | Field | Getter |
|---|---|---|
| `480p` | `f13817a` | `m13731b` |
| `720p` | `f13818b` | `m13733d` |
| `1080p` | `f13819c` | `m13730a` |
| `4k` | `f13820d` | `m13732c` |

Each value is a complete, directly playable URL. Selection order in `MovieInfoActivity.mo8044a()` is **`4k` → `1080p` → `720p` → `480p`**, taking the first that is not `""` (`MovieInfoActivity.java:88-96`).

> All four getters are called with `.equals("")` and no null guard — a JSON `null` (or a missing key) for any of the four fields will NPE. The server must emit `""`, never `null`, for absent qualities.

### 6.9 `q6.C3094j` — Series list item (`series_table`)
`id` (PK) · `title` · `icon` · `catid` · `icon_big` · `backdrop` · `genre` · `plot` · `cast` · `rating` · `director` · `releaseDate` · `view_order` (int)

### 6.10 `t6.C3313a` / `t6.C3314b` — Series detail
`C3314b` = `{ "info": C3313a, "seasons": [C3093i] }`
`C3313a` = `id` · `title` · `icon` · `catid` · `icon_big` · **`backdrop` (`List<String>`, not a String)** · `genre` · `plot` · `cast` · `rating` · `director` · `releaseDate` · `trailer` · `likes` · `dislikes`

### 6.11 `q6.C3093i` / `q6.C3085a` — Season / Episode
`C3093i` = `{ "season_num": int, "episodes": [C3085a] }`
`C3085a` = `{ "episode_num": String, "episode_name": String, "stream_url": String }`
The episode `stream_url` is used **verbatim**, with no `{user}`/`{pass}` substitution (`SeriesInfoActivity.java:78,103`).

### 6.12 `s6.C3235b` / `s6.C3234a` — EPG
`C3235b` = `{ "epg_listings": [C3234a] }` (`Serializable`, default `null`)
`C3234a` = `id` · `epg_id` · **`title` (Base64)** · `lang` · `start` · `end` · `description` · `channel_id` · `start_timestamp` · `stop_timestamp` (all `String`)
Only `title`, `start`, `end` are read. `start`/`end` are parsed with `"yyyy-MM-dd HH:mm:ss"` in the account timezone.

### 6.13 `q6.C3086b` — Local item settings (`item_settings_table`, no JSON)
`f13735a`→`id` (PK AUTOINC) · `f13736b`→`entityId` (String) · `f13737c`→`itemOrder` · `f13738d`→`isFavorite` · `f13739e`→`isLocked` · `f13740f`→`origin`

`origin` codes (from call sites): **1 = live channel, 2 = live category, 3 = movie, 4 = series.**
Evidence: `LiveActivity.java:1471,1501` (`,1`), `LiveActivity.m7949j2` (categories), `C2776d.java:275` (`origin=2`), `MovieInfoActivity.mo8045c()` → `m8043u0(id, 3)`, `C1767d.java:208` (`mo11203i0(3)`), `C2786n.java:380` (`origin=4`).

### 6.14 `q6.C3089e` — In-memory zip container
`{ List<C3088d> channels, List<C3087c> categories }` — produced by `Flowable.zip` of the `channels` + `packages` calls (`C1757c.m8033c0`). Not persisted, not serialized.

---

## 7. Live channel flow

### 7.1 End-to-end path

```
HomeActivity.mo7829u()
  └─ read PREF_KEY_PLAYER_LIVE (default 1)
       0 → extra "id" = "VLC Player"
       1|2|3 → extra "id" = "EXOPlayer"
  └─ startActivity(LiveActivity)

LiveActivity.onCreate
  └─ setTimeZone(this)                   ← NATIVE anti-repack check (§11.1)
  └─ read extra "id" → f7904h0
       "EXOPlayer"  → m7926X1()  (ExoPlayer track-selector init)
       otherwise    → m7930Z1()  (LibVLC init, UA applied here)

C1757c constructor → m8023C()
  └─ if now > PREF_KEY_LIVE_UPDATE:
        PREF_KEY_LIVE_UPDATE = now + 86_400_000     (24 h)
        liveCatDao.deleteAll(); liveDao.deleteAll()
  └─ m8038h0()  → dbHelper.isLiveTableEmpty()
        true  → m8033c0()  network refresh
        false → view.onLiveDataLoaded()  (straight to cache)

m8033c0()  network refresh
  └─ Flowable.zip( mo73v0(mode="channels"), mo72r0(mode="packages"), C3089e::new )
        subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread())
  └─ onSuccess:
        categories.add(0, C3087c("-1","FAVORITE",0,"","0",1,false,0))
        liveCatDao.insertAll(categories)
        liveDao.insertAll(channels)
        view.onLiveDataLoaded()

view.onLiveDataLoaded() → m8030Z()  loadCategories (Room)
  SELECT id, categoryName, categoryType, categoryIcon, viewOrder, chCount,
         (SELECT EXISTS(SELECT 2 FROM item_settings_table
                        WHERE entityId=LC_table.id AND origin=2 AND isLocked=1)) AS isLocked,
         parent
  FROM liveCat_table AS LC_table
  WHERE (SELECT count(id) FROM live_table WHERE live_table.categoryId=LC_table.id) > 0
     OR id = -1
  ORDER BY CAST(viewOrder AS integer) ASC
  → LiveData<List<C3087c>> → LiveCatAdapter
  → mo7976F() → m7917S1(firstCategoryId)

category selected → m7917S1(categoryId)
   categoryId == "-1" → m8029Y()  favourites:
        SELECT * FROM live_table
        WHERE (SELECT count(id) FROM item_settings_table
               WHERE origin=1 AND entityId=live_table.id AND isFavorite=1) > 0
        ORDER BY id
   else → m8031a0(categoryId):
        SELECT streamId, id, streamDisplayName, categoryId, streamIcon, viewOrder,
               tvArchive, hasEPG, streamUrl,
               (SELECT EXISTS(SELECT 1 FROM item_settings_table
                              WHERE entityId=ctable.id AND origin=1 AND isFavorite=1)) AS isFavorite,
               (SELECT EXISTS(SELECT 1 FROM item_settings_table
                              WHERE entityId=ctable.id AND origin=1 AND isLocked=1))  AS isLocked
        FROM live_table AS ctable
        WHERE categoryId = ?
        ORDER BY CAST(viewOrder AS integer) ASC
   → LiveData<List<C3088d>> → LiveAdapter

channel selected → m7909O1(position)
   ├─ if isLocked(id, origin=1) → PIN dialog, abort
   ├─ if id == currentlyPlayingId → toggle info overlay, abort
   ├─ f7908l0 = id
   ├─ "EXOPlayer" → m7969w1(channel)      else → m7911P1(channel)
   ├─ m7932a2(position)  info overlay (number, name, category, logo via Glide)
   └─ if EPG panel visible → m7917S1(categoryId) + m7952l1(id)  short EPG fetch

search (SearchView) → local:
   SELECT * FROM live_table WHERE streamDisplayName LIKE '%'||?||'%'
```

### 7.2 Which field is the stream id

**`C3088d.f13750b` (`@SerializedName("id")`, `Integer`).**
It is used for: EPG `stream_id` (`LiveActivity.java:919`), catchup path segment (`LiveActivity.java:925`), favourite/lock `entityId` (`LiveActivity.java:1471,1501`), and current-channel dedup (`m7909O1`).
The Room column `streamId` (autoincrement PK) is **not** a server identifier and must not be confused with it.

### 7.3 Cache / refresh policy

| Domain | TTL | Pref key | Evidence |
|---|---|---|---|
| Live (channels + categories) | **24 h** (`86 400 000` ms) | `PREF_KEY_LIVE_UPDATE` | `C1757c.m8023C`, `m8035e0` |
| Movies | **15 min** (`900 000` ms) | `PREF_KEY_MOVIES_UPDATE` | `C1767d.java:173-176,269-271` |
| Series | **15 min** (`900 000` ms) | `PREF_KEY_SERIES_UPDATE` | `C1774d.java:205-208,270-272` |

On expiry the tables are **truncated**, then the emptiness check triggers a fresh fetch. Each domain also exposes a manual refresh (`m8035e0` / equivalents) that forces the same cycle.

---

## 8. Stream URL construction

### 8.1 Live TV — server-supplied template + local substitution (CONFIRMED)

The API returns `stream_url` already fully-qualified, containing two literal placeholders. The client performs exactly this transformation, identically in all three call sites (`LiveActivity.java:1019`, `:1473`, `:1502`):

```java
Uri.parse(
    channel.getStreamUrl()
           .replaceAll(Pattern.quote("{user}"), prefs.getUsername())
           .replaceAll(Pattern.quote("{pass}"), prefs.getPassword())
)
```

**Algorithm (complete):**
1. Take `stream_url` verbatim from the `channels` response (persisted in `live_table.streamUrl`).
2. Replace every literal occurrence of `{user}` with `PREF_KEY_USERNAME`.
3. Replace every literal occurrence of `{pass}` with `PREF_KEY_PASSWORD`.
4. `Uri.parse` the result. Done.

`Pattern.quote` is used, so the braces are matched literally, not as regex. Note `replaceAll` treats the *replacement* string as a regex replacement — a username or password containing `$` or `\` would corrupt the URL. That is a latent defect worth avoiding in a rebuild (use `Matcher.quoteReplacement` or plain `String.replace`).

**There is no client-side scheme/host/port/extension assembly for live TV.** No `/live/` literal, no `.ts`/`.m3u8` suffix logic, no format selection. The container format is entirely whatever the server put in `stream_url`; ExoPlayer infers the source type from the URI (`Util.inferContentType`), and libVLC probes.

### 8.2 Catchup / timeshift — client-constructed (CONFIRMED)

`C2606a.mo11196e0(...)` (`C2606a.java:308-311`):
```java
return getHost() + "/timeshift/" + getUsername() + "/" + getPassword()
       + "/" + str3 + "/" + str2 + "/" + str + "." + str4;
```
Caller `C1757c.m8024D(streamId, ext)` (`C1757c.java:206-214`):
```java
long hours = 20;
String durationMinutes = String.valueOf(TimeUnit.HOURS.toMinutes(20));   // "1200"
TimeZone tz = TimeZone.getTimeZone(prefs.getTimeZone());
String startStr = new SimpleDateFormat("yyyy-MM-dd:kk-mm", Locale.ENGLISH)
        .format(new Date(Calendar.getInstance(tz, Locale.ENGLISH).getTime().getTime()
                         - TimeUnit.HOURS.toMillis(20)));
return dataManager.buildTimeshift(streamId, startStr, durationMinutes, ext);
```
Invoked from `LiveActivity.m7897I1` with `ext = "m3u8"` (`LiveActivity.java:925`).

**Resulting template:**
```
{host}/timeshift/{username}/{password}/1200/{yyyy-MM-dd:kk-mm}/{streamId}.m3u8
```
- `1200` = fixed 20-hour window expressed in minutes.
- Start time = **now minus 20 hours**, formatted in the account timezone with `kk` (1–24 hour clock).
- The window duration and offset are hard-coded constants — the UI offers no time picker.
- This is the standard Xtream Codes timeshift path layout.

The resulting URL is handed to `VodActivity` via `Intent` extras `stream_name` / `stream_link` — i.e. catchup always plays in ExoPlayer, regardless of the live-player preference. (`PREF_KEY_PLAYER_TV_ARCHIVE` is written by the settings fragment but the archive path does not read it — see §12.)

### 8.3 Movies — server-supplied, verbatim (CONFIRMED)

`MovieInfoActivity.mo8044a()`:
```java
String url = "";
C3096l s = movie.getStreamUrl();
if      (!s.get4k()  .equals("")) url = s.get4k();
else if (!s.get1080p().equals("")) url = s.get1080p();
else if (!s.get720p() .equals("")) url = s.get720p();
else if (!s.get480p() .equals("")) url = s.get480p();
```
**No `{user}`/`{pass}` substitution is applied.** The URL is passed straight into the player intent.

### 8.4 Series episodes — server-supplied, verbatim (CONFIRMED)

`SeriesInfoActivity` inner class `C1776b.onItemClick`:
```java
C3085a ep = (C3085a) episodeAdapter.getItem(i);
String url = ep.f13734c;        // "stream_url", direct field access
```
Again, **no substitution**.

> **Asymmetry to preserve in a rebuild:** only *live* URLs carry `{user}`/`{pass}` placeholders. Movie and episode URLs are expected pre-substituted by the server. A rebuild that blindly applies substitution everywhere is harmless (no placeholders to match), but one that *omits* it for live will produce unplayable URLs.

### 8.5 Search for URL-construction primitives — results

An exhaustive grep across app-owned sources for `http://`, `https://`, `/live/`, `/movie/`, `/series/`, `.ts`, `.m3u8`, `player_api`, `xmltv`, `epg`, Base64 constants and `Uri.Builder`:

| Pattern | Occurrences in app code | Finding |
|---|---|---|
| `http://` / `https://` literal | **0** in `com/mbm_soft/**` and the app's model/data packages | all URLs are native-lib, Remote Config, or server-supplied |
| `/live/`, `/movie/`, `/series/` | **0** | no Xtream path assembly |
| `/timeshift/` | 1 — `C2606a.java:309` | catchup only |
| `.m3u8` | 1 — `LiveActivity.java:925` (catchup extension argument) | |
| `.ts` | **0** | |
| `player_api` | 1 — `@SerializedName("player_api")` in `C3164a` | server-supplied URL |
| `xmltv` | **0** | |
| `get_short_epg` | 1 — `C2606a.mo11224v` | |
| `Uri.Builder` / `appendPath` | **0** in app code | |
| `Base64` | `LiveActivity.java:854,860` only | decoding EPG titles, not URLs |
| `{user}` / `{pass}` | 3 sites, all in `LiveActivity` | §8.1 |
| String-obfuscation helper | none beyond `DecInterceptor` | no per-string decoder table |

---

## 9. Media player behaviour

### 9.1 Player selection

Four options, index-addressed, stored per content type (`p124k7.C2495a.java:94-97`):

| Index | Label |
|---|---|
| 0 | `VLC Player` (embedded libVLC) |
| 1 | `EXOPlayer` (embedded ExoPlayer 2) |
| 2 | `MX Player` (external, `com.mxtech.videoplayer.ad`) |
| 3 | `VLC External Player` (external, `org.videolan.vlc`) |

| Content type | Pref key | Default | Written by |
|---|---|---|---|
| Live | `PREF_KEY_PLAYER_LIVE` | `1` | `C2495a` spinner `f15584P` |
| Movies | `PREF_KEY_PLAYER_MOVIES` | `1` | spinner `f15585Q` |
| Series | `PREF_KEY_PLAYER_SERIES` | `1` | spinner `f15586R` |
| TV Archive | `PREF_KEY_PLAYER_TV_ARCHIVE` | `1` | spinner `f15587S` |

For live, indices 1/2/3 all collapse to the embedded ExoPlayer (`HomeActivity.mo7829u`) — external players are not honoured for live TV. For movies/series, index 2 → `C3098b.m13738c` (MX intent), index 3 → `C3098b.m13739d` (VLC intent); if the target package is absent, `C3098b.m13737b` opens the Play Store listing.

### 9.2 ExoPlayer configuration

Construction (`LiveActivity.m7969w1`, `LiveActivity.java:1470-1497`; mirrored in `VodActivity.m8234y0`):

```java
DataSource.Factory dsf = new DefaultDataSourceFactory(
        context, Util.getUserAgent(context, prefs.getUserAgent()));   // ← account UA
AdaptiveTrackSelection.Factory atf = new AdaptiveTrackSelection.Factory();
RenderersFactory rf = ((QuickPlayerApp)getApplication()).buildRenderersFactory(true);
DefaultTrackSelector ts = new DefaultTrackSelector(context, atf);
ts.setParameters(savedTrackSelectorParameters);
SimpleExoPlayer player = new SimpleExoPlayer.Builder(context, rf)
        .setTrackSelector(ts)
        .build();
player.addListener(new PlayerEventListener());
player.setPlayWhenReady(true);
playerView.setPlayer(player);              // guarded by C3109m.m13757b(context)
playerView.setUseController(false);        // live only — no transport controls
playerView.setErrorMessageProvider(new PlayerErrorMessageProvider());
playerView.setKeepScreenOn(true);
playerView.setResizeMode(3);               // RESIZE_MODE_FILL
player.setRepeatMode(1);                   // REPEAT_MODE_ONE
player.setMediaSource(buildMediaSource(uri));
```

`QuickPlayerApp.m7765e(boolean preferExtensionRenderers)` returns
`new DefaultRenderersFactory(this).setExtensionRendererMode(useExtensionRenderers() ? (pref ? EXTENSION_RENDERER_MODE_PREFER : EXTENSION_RENDERER_MODE_ON) : OFF)`, and `m7769n()` returns **`true` unconditionally** — so FFmpeg/extension renderers are always enabled and preferred.

### 9.3 Media-source selection

`LiveActivity.m7950k1(Uri)` / `VodActivity.m8232v0(Uri)`:
```java
DownloadRequest dr = QuickPlayerApp.getDownloadTracker().getDownloadRequest(uri);
if (dr != null) return DownloadHelper.createMediaSource(dr, dataSourceFactory);   // offline
switch (Util.inferContentType(uri)) {
    case C.TYPE_DASH:  return new DashMediaSource.Factory(dsf).createMediaSource(uri);
    case C.TYPE_SS:    return new SsMediaSource.Factory(dsf).createMediaSource(uri);
    case C.TYPE_HLS:   return new HlsMediaSource.Factory(dsf).createMediaSource(uri);
    case C.TYPE_OTHER: return new ProgressiveMediaSource.Factory(dsf).createMediaSource(uri);
    default: throw new IllegalStateException("Unsupported type: " + type);
}
```
Type inference is by URI file extension / `.mpd` / `.ism` / `.m3u8` suffix — **not** by `Content-Type`. Extension-less MPEG-TS URLs fall through to `ProgressiveMediaSource`, which ExoPlayer handles via `TsExtractor`.

### 9.4 HTTP headers / User-Agent

- **User-Agent = `Util.getUserAgent(context, prefs.getUserAgent())`**, i.e. the string from the login response `user_agent` field, wrapped by ExoPlayer's helper into `"<value>/<appVersion> (Linux; Android <rel>) ExoPlayerLib/<ver>"`.
- **Fallback**: `QuickPlayerApp.f7776j = Util.getUserAgent(this, "eliaapro")` when the account UA is null (used by `VodActivity.m8231u0()` → `QuickPlayerApp.m7763b()`).
- libVLC path: `libVLC.setUserAgent(prefs.getUserAgent(), prefs.getUserAgent())` (`LiveActivity.java:1109`).
- **No other request headers are set.** No `Referer`, no `Cookie`, no custom auth header on the media requests. Credentials, when required, are inside the URL path/query the server supplied.
- `VodActivity.onCreate` installs a process-wide `CookieManager` (`f8008P`) as the default `CookieHandler` (`VodActivity.java:352-357`).

### 9.5 Buffering / retry

- **No custom `LoadControl`** is constructed anywhere — ExoPlayer's `DefaultLoadControl` defaults apply verbatim.
- **No `LoadErrorHandlingPolicy`** override, no custom retry counts, no back-off tuning.
- Live playback sets `REPEAT_MODE_ONE`, which for an unbounded live source has no practical effect.
- Recovery from behind-live-window is handled by the standard pattern (`VodActivity.m8235z0` inspects `ExoPlaybackException.TYPE_SOURCE` for `BehindLiveWindowException` and re-prepares).
- Error surface: `PlayerErrorMessageProvider` maps `MediaCodecRenderer.DecoderInitializationException` to the `error_querying_decoders` / `error_no_secure_decoder` / `error_no_decoder` / `error_instantiating_decoder` string resources (`LiveActivity.java:720-735`).

### 9.6 libVLC configuration

```java
ArrayList<String> opts = new ArrayList<>();
opts.add("-vvv");                 // verbose logging
opts.add("--fullscreen");
displayManager = new DisplayManager(this, null, false, false, false);
libVLC = new LibVLC(this, opts);
libVLC.setUserAgent(accountUa, accountUa);
mediaPlayer = new MediaPlayer(libVLC);
vlcVout = mediaPlayer.getVLCVout();
```
(`LiveActivity.m7930Z1`, `LiveActivity.java:1104-1116`)

Playback: `new Media(libVLC, uri)` → `setMedia` → `play()`.
Aspect handling: `m7922V1(w,h)` sets `VLCVout.setWindowSize`, `setScale(0f)`, `setAspectRatio("w:h")`; `m7924W1(ScaleType)` cycles `MediaPlayer.ScaleType` values on user input (`LiveActivity.java:1767-1768`). Default at start: `ScaleType.SURFACE_FILL` (`LiveActivity.java:1252`).
No caching / network-caching VLC options are set.

### 9.7 Lifecycle

- `onStart` / `onResume`: ExoPlayer re-initialised when `Util.SDK_INT > 23`; `PlayerView.onResume()`.
- `onPause` / `onStop`: `PlayerView.onPause()`, player released (`Util.SDK_INT > 23` gate at `LiveActivity.java:1892`).
- libVLC: `mediaPlayer.stop()` on stop (`:1826`), `mediaPlayer.release()` on destroy (`:1863`).
- `playerView.setKeepScreenOn(true)`; manifest declares `WAKE_LOCK`.
- Orientation is pinned to `sensorLandscape` for every activity, with `configChanges="screenSize|orientation|keyboardHidden"` — the app never recreates on rotation. There is no portrait or fullscreen-toggle path; playback is full-screen by construction.

---

## 10. Local persistence and session handling

### 10.1 Room database — `eliaapro.db`

Built with `Room.databaseBuilder(context, AppDatabase.class, "eliaapro.db").allowMainThreadQueries().build()` (`p268y6.C3724a.m16107b/m16110e`). Schema identity hash `672786519d32236abea0158294e341ef`; **no migrations declared**.

| Table | Primary key | Purpose |
|---|---|---|
| `live_table` | `streamId` INTEGER AUTOINCREMENT | live channels |
| `liveCat_table` | `id` TEXT | live categories |
| `movie_table` | `id` TEXT | movies |
| `movie_Cat_table` | `catId` TEXT | movie categories |
| `series_table` | `id` TEXT | series |
| `seriesCat_table` | `catId` TEXT | series categories |
| `item_settings_table` | `id` INTEGER AUTOINCREMENT | favourites + parental locks, keyed by `(entityId, origin)` |

Category list queries in all three domains filter out empty categories and keep the synthetic `-1` favourites row:
```sql
... WHERE (SELECT count(id) FROM <content_table> WHERE <fk> = <cat>.<pk>) > 0 OR <pk> = -1
    ORDER BY CAST(<order_col> AS integer) ASC
```
(`C2776d.java:275`, `C2780h.java:192`, `C2784l.java:192`)

Latest rails on Home: `SELECT * FROM movie_table LIMIT 10` / `SELECT * FROM series_table LIMIT 10` (`C2782j.java:441`, `C2786n.java:322`) — note these back the *local* rails; the Home view-model additionally calls the network `movies_latest` / `series_latest` modes.

Search is local in all domains: `... WHERE <title_col> LIKE '%'||?||'%'`.

### 10.2 SharedPreferences — `snap_pref`

Complete key inventory (`p178p6.C2982a`):

| Key | Type | Default | Meaning |
|---|---|---|---|
| `PREF_KEY_ACTIVATION_TYPE` | boolean | `true` | true = activation-code mode |
| `PREF_KEY_ACTIVE_CODE` | String | `null` | activation code |
| `PREF_KEY_USERNAME` | String | `null` | account username |
| `PREF_KEY_PASSWORD` | String | `null` | account password |
| `PREF_KEY_MAC_ADDRESS` | String | `null` | device MAC (also sent as `sn`) |
| `PREF_KEY_SERIAL_NUMBER` | String | `null` | written, never read |
| `PREF_KEY_HOST` | String | `null` | timeshift base |
| `PREF_KEY_PLAYER_API` | String | `null` | EPG endpoint URL |
| `PREF_KEY_EPG_API` | String | `null` | written, never read |
| `PREF_KEY_USER_AGENT` | String | `null` | playback UA |
| `PREF_KEY_EXPIRE` | String | `null` | display only |
| `PREF_KEY_MESSAGE` | String | `null` | server notice |
| `PREF_KEY_TIME_ZONE` | String | `null` | Java TimeZone id |
| `PREF_KEY_USER_PASSWORD` | String | `"12345"` | **local parental PIN** |
| `PREF_KEY_RUN_ON_STARTUP` | boolean | `false` | boot autostart (non-functional, §11.3) |
| `PREF_KEY_PLAYER_LIVE` | int | `1` | player index |
| `PREF_KEY_PLAYER_MOVIES` | int | `1` | player index |
| `PREF_KEY_PLAYER_SERIES` | int | `1` | player index |
| `PREF_KEY_PLAYER_TV_ARCHIVE` | int | `1` | player index (written, not honoured) |
| `PREF_KEY_LIVE_UPDATE` | long | `0` | next live refresh epoch ms |
| `PREF_KEY_MOVIES_UPDATE` | long | `0` | next movies refresh epoch ms |
| `PREF_KEY_SERIES_UPDATE` | long | `0` | next series refresh epoch ms |

### 10.3 Other on-disk state

- `getExternalFilesDir(null)/downloads` — ExoPlayer download cache (`SimpleCache` + `NoOpCacheEvictor`); action files `actions` / `tracked_actions` upgraded on first use (`QuickPlayerApp.m7759i/m7760l/m7761m`).
- `cache_an` — 10 MB OkHttp cache installed by `AndroidNetworking.initialize` (`C1885a.m8619a`).
- Glide: 20 MB memory cache + 20 MB internal disk cache, `DiskCacheStrategy.DATA`, `signature = System.currentTimeMillis()/86_400_000` (day-granular cache busting), PNG, placeholder/error `R.drawable.no_image` (`QuickGlideModule`).
- `manifest allowBackup="true"` — prefs and DB are eligible for Android auto-backup, credentials included.

---

## 11. Obfuscation, native code, and anti-tamper findings

### 11.1 Native anti-repackaging trap — `setTimeZone`

`LiveActivity.java:1430` declares `public static native void setTimeZone(Context context);` and `LiveActivity.java:1844` calls it in `onCreate`. The name is deliberately misleading — the JNI stub is a one-line tail call:

```asm
Java_com_mbm_1soft_eliaapro_ui_live_LiveActivity_setTimeZone:
    mov  x1, x2                 ; shift Context into arg slot
    b    _Z12checkPackageP7_JNIEnvP8_jobject
```

`checkPackage(JNIEnv*, jobject)` (`0x1ec34`):
1. Loads the 21-byte literal at `0x15a37` = `com.mbm_soft.eliaapro` onto the stack.
2. `CallObjectMethod(context, getPackageName)` (method id resolved from `"getPackageName"` @ `0x15458`, signature `"()Ljava/lang/String;"` @ `0x1554f`).
3. Converts to `std::string`, then does a manual substring search: `memchr` for `'c'` (`0x63`) followed by three 8-byte `eor`/`orr` comparisons covering all 21 bytes.
4. If the length is `< 0x15`, if no match is found, or if the match lands at the very end, it calls **`std::terminate()`** → immediate `SIGABRT`.

**Effect:** repackaging under a different `applicationId` crashes the app the moment `LiveActivity` opens.

### 11.2 Java-level anti-repackaging trap — `mo11198f0()`

`C2606a.mo11198f0()` (`C2606a.java:314-316`):
```java
private String m11148O0() { return "com.mbm_soft.eliaapro"; }   // hard-coded, not getPackageName()
public boolean mo11198f0() { return m11148O0().contains("iaap"); }
```
Consumed by the base view-model constructor (`p020b7.AbstractC0562c:28-33`):
```java
public AbstractC0562c(InterfaceC2608c dm, InterfaceC3105i sp) {
    this.f3803c = dm; this.f3805e = sp;
    if (dm.mo11198f0()) return;
    onCleared();                    // disposes the CompositeDisposable immediately
}
```
`"com.mbm_soft.eliaapro"` contains `"iaap"` (el**iaap**ro), so the check passes in the genuine build. If a patcher rewrites the literal, **every view-model disposes its subscription bag in its own constructor**, so all network calls are cancelled the instant they are made and the app silently shows empty screens with no error. This is a decoy trap distinct from §11.1 and is easy to miss.

### 11.3 Dead code — boot autostart

`utils.BootUpReceiver` reads:
```java
context.getSharedPreferences("user_info", 0).getBoolean("runOnStartUp", false)
```
but the app writes to prefs file **`snap_pref`** under key **`PREF_KEY_RUN_ON_STARTUP`** (`p268y6.C3724a.m16113h()`, `C2982a.mo11217q0`). The names match on neither file nor key, so the boot receiver's condition is always `false` and autostart never fires — despite the settings toggle in `p146m7.C2609a`.

### 11.4 Native libraries inventory

| Library | ABIs | Role | Contains app logic? |
|---|---|---|---|
| `libnative-lib.so` | all 4 | base URL, XOR key, package check | **Yes — fully recovered** |
| `libvlc.so`, `libvlcjni.so` | all 4 | libVLC media engine | No (stock) |
| `libavcodec.so`, `libavutil.so`, `libswresample.so`, `libffmpeg.so` | all 4 | FFmpeg for VLC / ExoPlayer extension | No (stock) |
| `libc++_shared.so` | all 4 | STL | No |

ABIs present: `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`. `libnative-lib.so` is 297 648 B (arm64) / 158 976 B (armv7) and built with NDK r23b, clang 12.0.8. Its exports beyond the three JNI stubs are only C++ runtime symbols. A vestigial export `Java_com_mam_nativetest_MainActivity_calc2` exists (unreferenced from Java) — leftover from a template project.

### 11.5 Obfuscation posture

- **The app itself is not ProGuard-obfuscated in any meaningful way.** `app/build.gradle` sets `minifyEnabled false`. Every app class keeps its original name (`AppApiHelper`, `DecInterceptor`, `LiveActivity`, `QuickPlayerApp`, …).
- The `pNNNxx` package prefixes and `CNNNNa` class names in the decompiled tree are **JADX artefacts** for library packages whose short names (`a7`, `q6`, `d8`) are invalid Java identifiers at the top level, plus R8-shrunk library classes — not app-level obfuscation.
- Field names are `f7849a`-style because the library dependencies *were* shrunk; app model fields keep their `@SerializedName` annotations, which is why the wire contract is fully recoverable.
- **No string-decryption helper, no reflection, no dynamic class loading anywhere in app code.** The only `System.loadLibrary` is in `QuickPlayerApp`. Verified by grep across `com/mbm_soft/**` and the app's data packages for `Class.forName`, `DexClassLoader`, `getMethod`, `System.load`.

### 11.6 Decompilation completeness

One method failed to decompile cleanly: `IntroActivity$C1723a.onComplete` (`IntroActivity.java:44-96`). JADX emitted `throw new UnsupportedOperationException("Method not decompiled")` but preserved the full register-level logic in structured comments plus a raw bytecode listing. The Remote-Config-override behaviour in §3.2 was reconstructed from that listing and is **CONFIRMED** — the listing explicitly shows `remoteConfig.getString("activity")`, the `.isEmpty()` guard, and `AppApiHelper.m7814a(...)`. **Smali inspection was not required.**

---

## 12. Confirmed / inferred / unresolved

### CONFIRMED (direct source or binary evidence)

- Package, version, activity/service/receiver inventory, permissions, launcher config.
- Base API URL `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php` (native, 4/4 ABIs agree).
- Firebase Remote Config key `activity` overrides the base URL at startup.
- XOR key `r+3e>@y](7wEEM[` (15 bytes, native, 4/4 ABIs agree); symmetric repeating-key XOR over `char`s; round-trip verified locally.
- Wire format: `POST`, `application/x-www-form-urlencoded`, single field `json`.
- Response decryption interceptor `C1717a` on the shared FAN client, 2xx-only, with `.trim()`.
- All 12 `mode` values and their exact response types.
- The base request envelope: `code` | (`code="00000000"`, `user`, `pass`), `mac`, `sn`, `model`, `group=0`.
- Login/activation success test: `status ∈ {100, 101}`.
- The nine fields persisted from the login response and their pref keys.
- EPG is a plain (non-XOR) `GET` to `player_api` with `action=get_short_epg`, `username`, `password`, `stream_id`; titles are Base64.
- Complete field-by-field model definitions with JSON names, types and consumers.
- Live stream URL = server `stream_url` with `{user}`/`{pass}` locally substituted.
- Movie/episode stream URLs used verbatim; movie quality preference order 4k → 1080p → 720p → 480p.
- Catchup URL: `{host}/timeshift/{user}/{pass}/1200/{yyyy-MM-dd:kk-mm}/{id}.m3u8`, start = now − 20 h in the account timezone.
- Room schema (7 tables, exact DDL) and every DAO query.
- Complete `snap_pref` key inventory with defaults.
- Cache TTLs: live 24 h; movies 15 min; series 15 min.
- Player matrix, defaults, and the live-TV collapse of indices 1/2/3 to ExoPlayer.
- ExoPlayer/libVLC construction, UA source, media-source selection, absence of custom LoadControl/retry policy.
- Both anti-repackaging traps (§11.1, §11.2).
- `BootUpReceiver` is dead code (§11.3).
- Favourites/search/locks are entirely local; no backend involvement.

### STRONGLY INFERRED

- The PHP middleware fronts a real Xtream Codes / XUI panel: the login response carries `player_api`, `epg_api`, `allowed_output_formats`, `max_connections`, `expire`; the EPG endpoint is verbatim Xtream; the timeshift path matches Xtream's layout.
- `status` 100 and 101 both mean "authorised"; the distinction is likely trial vs. paid or new vs. returning. The client treats them identically.
- Live `stream_url` templates most likely resolve to `http://<host>:<port>/{user}/{pass}/<id>` or `.../live/{user}/{pass}/<id>.<ext>` given the placeholder scheme, but **the client never sees the shape** — this is an inference about the server, not a client fact.
- `group=0` is a client-tier/channel-group discriminator; the client never varies it.
- `act_limit` / `act_cnt` / `adm_act_cnt` implement a device-activation quota keyed on `mac`/`sn`.
- `movie_table.streamUrl` is populated but unread because the `movies_info` detail call supersedes it — likely a legacy field.

### UNRESOLVED / NOT FOUND

- **Exact response JSON envelope for list modes.** Gson is parsed as `List<T>` directly (`m8499N(Class)` builds `$Gson$Types.newParameterizedTypeWithOwner(null, List.class, cls)`), so the decoded body must be a **bare JSON array**, not `{"data":[...]}`. That is a firm structural conclusion; what is unresolved is whether an error condition returns an object instead (which would throw and be swallowed).
- **Error response shape for content modes.** No error model exists for anything but login. `mode` failures produce a parse error that every consumer discards silently.
- Semantic difference between `status` 100 and 101.
- Meaning/valid range of `group`, `category_type`, `parent`/`parent_id`, `code_id`, `update_ch`, `rememberVal`, `apk_page`.
- Whether the server accepts `mode` values not exercised by this build (no search/favourite/history mode is referenced).
- Whether `epg_api` (stored, unread) points at an XMLTV dump — no code path uses it.
- Any relationship between this APK and an "ABK" branding.
- Server-side behaviour of any kind (deliberately out of scope — no requests were made).

### Known client defects worth *not* reproducing

1. `replaceAll` with an unescaped replacement string in the `{user}`/`{pass}` substitution — a `$` or `\` in credentials corrupts the URL.
2. Unguarded `.intValue()` on `status` / `force_update`, and unguarded `.equals("")` on all four `C3096l` quality fields — any `null` NPEs into a silently-swallowed Rx error.
3. Content-mode network errors are discarded with no user feedback (`m7996L`, `m8000P`, `m8002R`, `m8006V`, `m8008X` are empty `Throwable` consumers).
4. `Room.allowMainThreadQueries()` is enabled.
5. `PREF_KEY_PLAYER_TV_ARCHIVE` is written by settings but never read — catchup always uses ExoPlayer.
6. `PREF_KEY_EPG_API` and `PREF_KEY_SERIAL_NUMBER` are write-only.
7. Credentials stored in plaintext prefs with `allowBackup="true"`.
8. Cleartext HTTP for the control-plane API.

---

## 13. Completion gate

| Stage | Status | Evidence |
|---|---|---|
| **Server configuration** | **CONFIRMED** | Native `getValue()` → `http://googeleb.xyz:2082/iptv/V6APK/V6APKFaster.php`; Remote Config key `activity` override (`IntroActivity.m7860v0`, `AppApiHelper.m7814a`) |
| **Login request** | **CONFIRMED** | `C2606a.m11178P0` + `mo11168K("login"\|"active")`; `AppApiHelper.mo66Q`; POST form field `json` = XOR payload |
| **Authenticated state** | **CONFIRMED** | `status ∈ {100,101}` gate; `mo11164H0(...)` persists 9 fields to `snap_pref`; every later request re-sends credentials |
| **Categories** | **CONFIRMED** | `mode=packages` → `List<C3087c>`; `mode=movies_cat` → `List<C3091g>`; `mode=series_cat` → `List<C3095k>`; cached in Room |
| **Channels** | **CONFIRMED** | `mode=channels` → `List<C3088d>`; zipped with `packages`; persisted to `live_table` |
| **Selected channel** | **CONFIRMED** | `C3088d`; server id = `@SerializedName("id")` = `f13750b` |
| **Stream URL** | **CONFIRMED** | Live: server `stream_url` + `{user}`/`{pass}` substitution (`LiveActivity:1019,1473,1502`). Catchup: `{host}/timeshift/{user}/{pass}/1200/{yyyy-MM-dd:kk-mm}/{id}.m3u8`. VOD/episodes: verbatim |
| **Player** | **CONFIRMED** | ExoPlayer 2 (default) / libVLC / external MX / external VLC; UA from `user_agent`; `Util.inferContentType` source selection |

**All eight stages: CONFIRMED. No PARTIAL, no NOT FOUND.**

---

## 14. Is the APK sufficient for a clean rebuild?

**Yes.** Every element required to build a functionally-equivalent client is recoverable from local evidence:

- the endpoint and its override mechanism,
- the exact obfuscation algorithm and its key,
- the exact request envelope and every `mode` value,
- the complete response field inventory with JSON names and types,
- the success criterion,
- the complete stream-URL derivation for all four content paths,
- the player configuration required for playback compatibility,
- the local schema and caching policy.

The residual risk is **not** client-side. It is that the middleware may reject a rebuilt client for reasons this APK cannot reveal — for example a server-side `model`/`mac` allow-list, an activation quota (`act_limit`), a User-Agent check on the control plane, or version gating via `apk_ver_code`. Those are server behaviours; establishing them requires live testing, which is explicitly out of scope for this phase.

Additionally: a rebuild under a **different `applicationId`** will hit both anti-tamper traps if any part of the native library or the `mo11198f0()` idiom is carried over. A clean-room reimplementation that does not link `libnative-lib.so` avoids §11.1 entirely, and simply must not copy the §11.2 idiom. If the original native library *is* reused, the new package name must contain `com.mbm_soft.eliaapro` as a substring — a hard constraint.

---

## 15. Remaining unknowns for Phase 2

1. Response envelope on server-side error for content modes (list vs. object).
2. Distinction between `status` 100 and 101.
3. Whether the middleware validates `model`, `mac`, `group`, or a control-plane User-Agent.
4. Activation quota semantics (`act_limit` / `act_cnt` / `adm_act_cnt`) and behaviour when exceeded.
5. Concrete shape of a live `stream_url` template as emitted by the server.
6. Whether `apk_ver_code` / `force_update` gate API access server-side or are advisory only.
7. Whether Remote Config currently publishes a non-empty `activity` value (would change the live base URL).

---

*End of report. Companion documents: `ABK_API_CONTRACT.md`, `ABK_REBUILD_HANDOFF.md`.*
