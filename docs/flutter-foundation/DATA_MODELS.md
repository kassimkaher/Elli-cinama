# ABK Flutter — Data Models & Shape Traps

Domain entities live in `features/*/domain/entities.dart`; JSON mapping in
`features/*/data/models.dart` (auth uses `AccountModel`). Field coercion is
lenient (`core/utils/json_utils.dart`) because the middleware mixes string/number
types.

## Account (`features/auth`) — login response
`status` (int?), `message`, `host`, `player_api`, `epg_api`, `username`,
`password`, `user_agent`, `timezone`, `expire`, `apk_ver_code`, `force_update`
(int?), `update_url`. `isSuccess = status ∈ {100,101}`. `roles` → `ServerRoles`;
`roles.playerApiPhp` appends `/player_api.php` to the host.

## LiveCategory (`packages`)
`id` (String; `"-1"` reserved for a client FAVORITE row), `category_name`,
`category_icon`, `view_order` (String; sort via `viewOrderInt`), `ch_count`,
`category_type`, `parent`, `isLocked` (coerced bool).

## LiveChannel (`channels`)
`id` (**int — the stream id**; used for EPG/favourites/URL), `stream_display_name`,
`category_id` (int?), `stream_icon`, `view_order`, `tv_archive` (int; `hasArchive`),
`has_epg` (int; `hasEpgData`), **`stream_url`** (template with literal
`{user}`/`{pass}`).

## MovieCategory / MovieListItem (`movies_cat` / `movies_list`)
Category: `id`, `category_name`, `category_icon`, `stream_count`, `cat_order`,
`parent_id`. List item: `id`, `stream_display_name`, `category_id`, `stream_icon`,
`backdrop`, `plot`, `rating`, `genre`, `cast`, `year`, `view_order`. (List-item
`stream_url` is intentionally **not** modeled/used — playback goes through info.)

## MovieInfo + StreamQualities (`movies_info`)
Response is an **array**; read `[0]`. `MovieInfo` = `id`, `title`, `trailer`,
`icon`, `genre`, `MPAA`, `release_date`, `plot`, `cast`, `duration`, `rating`,
`year`, **`stream_url` → `StreamQualities`**.
**Trap:** `stream_url` is an **object** `{ "480p","720p","1080p","4k" }`, not a
string; absent qualities are `""` (never null). `StreamQualities.best` picks
`4k → 1080p → 720p → 480p`, used **verbatim** (no substitution).

## SeriesCategory / SeriesListItem (`series_cat` / `series_list`)
Category same shape as movie category. List item: `id`, `title`, `icon`, `catid`,
`icon_big`, `backdrop` (**String here**), `genre`, `plot`, `cast`, `rating`,
`director`, `releaseDate`, `view_order`.

## SeriesInfo / Season / Episode (`series_info`)
Response is an **object** `{ info, seasons[] }`. `SeriesDetail.backdrop` is a
**List<String> here** (contrast the list item's String). `Season` =
`{ season_num, episodes[] }`; `Episode` = `{ episode_num, episode_name,
stream_url }` — episode `stream_url` used **verbatim**.

## EpgListing (`get_short_epg`)
`title` (**Base64** — `EpgListing.title` decodes to UTF-8, tolerant padding),
`start`, `end`, `start_timestamp`, `stop_timestamp`. Response
`{ epg_listings: [] }`; an empty list is a **normal** state (`has_epg=0`
account-wide at runtime).

## Local-only (no backend)
`FavoritesRepository` (sets per kind live/movie/series), `ResumeRepository`
(positions + ordered recents), `ParentalLockRepository` (PIN in secure storage,
no default; locked id sets), `SettingsRepository`, `CatalogueCacheMeta`
(freshness TTLs). `LocalSearch` filters loaded lists.

## Shape-trap checklist (must preserve)
1. `movies_info` → **array**, `stream_url` → **object**; empty qualities `""`.
2. `series_info` → **object**; `info.backdrop` → **list**, list-item `backdrop` → **string**.
3. `LiveChannel.id` is the numeric **stream id**, distinct from any row index.
4. Live `stream_url` carries literal `{user}`/`{pass}`; movies/episodes verbatim.
5. `status` and `force_update` are ints that may arrive as strings — coerced.
6. EPG `title` is Base64; empty EPG is not an error.
