# What the iOS app depends on

An audit of every call the iOS app makes to this backend, and of exactly
what it decodes from each response. Taken on 1 October 2026 from the app's
HEAD (4.0, unreleased) and the shipped builds 1.0.1 (bb72c6d), 2.0
(8a3108a), 3.0 build 3 (308b1bf) and 3.0 build 4 (ab6d153). Brought up
to 4.1 (a373440) and 4.2 (f57d792, in App Review) on 6 November 2026.

`test/lumen_viae_web/controllers/api/contract_test.exs` and its siblings
enforce this. The gap list below records the assertions they were missing
on that date, each with an id the tests can cite.

**This stays binding when the app moves to GraphQL** (docs/GRAPHQL.md).
Moving a screen to GraphQL changes what new builds call, not what
installed ones do: builds 1.0 to 3.0 call the REST API and will go on
calling it for as long as anyone has one installed. Nothing here may be
relaxed until no installed build calls it.

## Two Swift rules decide what breaks

1. For an Optional field, a missing key and a null are the same thing. For
   a non-optional field, either one fails the **whole response**, and one
   bad element fails the whole list: one meditation with a null `content`
   means no set detail at all.
2. Swift's `Double?` and `Int?` accept any JSON number but fail on a
   string. `"0.5"`, which is what a `Decimal` becomes in Jason, fails.

## Gap list

Every item below now has its test (checked 14 Nov 2026), so this list is
the record of what each test pins rather than work still to do. Where to
find them:

- G1, G2, D1-D3, D6, C2: `test/lumen_viae_web/controllers/api/contract_test.exs`;
  G2 also per route, and G3's integer checks beside every id comparison.
- S1-S4: `test/lumen_viae_web/controllers/api/meditation_set_controller_test.exs`.
- D4, D5, A1, A2: `narration_test.exs`. V1: `voice_controller_test.exs`.
- R1-R7: `rosary_audio_controller_test.exs`.
- C1: `completion_context_test.exs`. C3: `completion_back_compat_test.exs`
  (the server's half; the app's user agent is an Xcode setting).
- O1-O3: `office_controller_test.exs`.

A new gap is added here with its id when a build starts reading something
no test pins.

### Global

- **G1.** No route under `/api` passes through the `:browser` pipeline.
  Walk `LumenViaeWeb.Router.__routes__()` and assert `:browser` is not in
  `pipe_through` for any path starting `/api`. In production `CanonicalHost`
  301s any other host to `www.lumenviae.org`. Builds up to 4.1 call
  `lumenviae.fly.dev`, now a pass-through proxy to `www`
  (`deploy/fly-proxy/`); 4.2 calls `www.lumenviae.org` itself. URLSession
  follows a 301 on a POST as a GET:
  completions would vanish with no error anywhere. The test host is
  localhost, so nothing else can see this.
- **G2.** Every GET route returns 200 JSON for `accept: */*`, URLSession's
  default; the app sets no Accept header on GETs. `POST /api/completions`
  sends `accept: application/json` and `content-type: application/json`.
- **G3.** Wherever a test asserts an id by equality to a struct field, it
  also asserts `is_integer`. Equality stays green if ids become UUIDs.

### GET /api/meditation-sets?category=

- **S1.** `?category=seven_sorrows` returns a set created in that category
  (with a meditation in it: an empty set is hidden),
  with `data[].category == "seven_sorrows"` exactly. The app sends the raw
  values `joyful`, `sorrowful`, `glorious`, `luminous`, `seven_sorrows`, and
  always sends `category`; no build calls the list unfiltered.
- **S2.** Types on every summary, independent of values: `description`,
  `author`, `source`, `image_url`, `image_alignment`, `image_alt` each a
  string or null; `image_focal_x`, `image_focal_y` each `is_number` or null
  (a string fails); `image_width`, `image_height` each `is_integer` or
  null; `image_attribution` null or a map whose `title`, `artist`, `year`,
  `source_url`, `license` are each a string or null. (`year` is `String?`
  on the device; an integer year fails the list for 2.0 and later.)
- **S3.** Order within a category is ascending id, tested against heap
  order: create A, B, C; update A; assert `[A, B, C]`. The app builds its
  label chips and sections from the first time each label appears.
- **S4.** No pagination: 30 sets in one category, all 30 come back.

### GET /api/meditation-sets/:id

- **D1.** `data.id` `is_integer`, `data.name` and `data.category`
  `is_binary`. Only the summary asserts these today.
- **D2.** For **every** element of `data.meditations`, not only the first:
  `id` `is_integer`; `content` `is_binary`, never null; `title`, `author`,
  `source`, `audio_url` each a string or null; `narrations` a list whose
  elements have `voice` and `audio_url` both `is_binary`; `mystery` a
  non-null map (an unloaded Ash relationship would be the failure); in
  `mystery`: `id` `is_integer`, `name` and `category` `is_binary`, `order`
  `is_integer`, `description` and `scripture_reference` each a string or
  null, and `days_prayed` a string or null (1.0 to 3.0 decode it as
  `String?`, so a list fails the whole set for them).
- **D3.** Meditations come back in `set_memberships.order`, not id order.
  Create M1, M2, M3; add them at M3:1, M1:2, M2:3; assert ids
  `[M3, M1, M2]`. The player reads `meditations[i]` as decade i.
- **D4.** `narrations[0].voice == Voices.default().slug`, compared with
  config rather than a literal. The app treats `narrations.first` as the
  default voice when the chosen one is missing.
- **D5.** `data.audio_expires_at` matches
  `~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/`. Untested today; an
  unparseable value reads as "not expired".
- **D6.** `cache-control == ["private, no-store"]`. The app's URLSession
  uses the default URLCache, so a cacheable response would replay
  presigned URLs after they expire.

### GET /api/meditations/:id/audio[?voice=]

- **A1.** `data.id` `is_integer`, `data.audio_url` and `data.voice`
  `is_binary`, `data.expires_at` matches the D5 pattern.
- **A2.** `cache-control == ["private, no-store"]`.

### GET /api/voices

- **V1.** Config-independent types: the list is non-empty; every element
  has `slug` and `name` `is_binary`, `default` `is_boolean` (a non-optional
  `Bool`; null fails), `description` a string or null; exactly one element
  has `default == true`, and it is the first.

### GET /api/rosary/audio

- **R1.** `data.voice` and `data.version` `is_binary`.
- **R2.** `data.expires_at` matches the D5 pattern. The app parses it with
  `ISO8601DateFormatter()` defaults, which reject fractional seconds, and a
  failed parse marks the manifest stale on every launch.
  `DateTime.from_iso8601` accepts things the app rejects.
- **R3.** A literal list of prayer ids, not `PrayerAudio.prayer_ids()`,
  which only compares the server with itself:
  `~w(sign_of_cross apostles_creed our_father hail_mary glory_be
  fatima_prayer hail_holy_queen rosary_closing_prayer act_of_contrition
  sorrows_closing_prayer memorare st_michael_prayer)`. Each has `file` and
  `audio_url`, both `is_binary`.
- **R4.** Literal announcement and verse keys: `joyful_1`..`joyful_5`,
  `sorrowful_1`..`sorrowful_5`, `glorious_1`..`glorious_5`,
  `luminous_1`..`luminous_5`, `seven_sorrows_1`..`seven_sorrows_7`. An
  announcement's `text` and a verse's `reference` are each a string or
  null.
- **R5.** Verse order: one mystery's whole reference list equals the
  export's bead order. The app reads `verses[key][n-1]` as Hail Mary n.
- **R6.** The `include` strings the app sends: it sorts and comma-joins its
  kinds, e.g. `announcements,prayers,verses`, `book` alone,
  `announcements,book,prayers,verses`. Test `book` alone and all four. A
  kind not asked for stays **absent**, never null or `{}`: the app treats
  any non-nil map as "this kind is held".
- **R7.** (Already tested; listed because the exact status matters.) An
  unknown voice is a 400. The app retries with the default voice on 400
  and only on 400.

### POST /api/completions

- **C1.** A raw JSON body through `Plug.Parsers`: set
  `content-type: application/json` and `accept: application/json`, post
  `Jason.encode!(%{meditation_set_id: id, prayed_aloud: true})`, expect 201
  and a stored `prayed_aloud` of true. Also post exactly
  `{"meditation_set_id": id}`, the 1.0 to 3.0 body. Every current test
  posts an Elixir map, which never reaches the JSON parser.
- **C2.** `data.id` and `data.meditation_set_id` `is_integer`.
- **C3.** The real user agents get through the guard:
  `app/5 CFNetwork/3826.500.111 Darwin/25.0.0` and
  `app/4 CFNetwork/1568.100.1 Darwin/24.0.0`. `PRODUCT_NAME` is the target
  name, `app`, and no build overrides the User-Agent.

### /api/office (shipped in 3.0)

- **O1.** For **every** section of an hour, `latin` and `vernacular` are
  each null or a map whose `lines` is a list of strings (never null) and
  whose `title` and `note` are each a string or null.
- **O2.** Day and calendar entries: `date` a `YYYY-MM-DD` string;
  `celebration` null or a map with `title` `is_binary` and `rank` a string
  or null; `detail` null or a map with `label` and `text` each a string or
  null; `note` and `letter` each a string or null; the calendar's days in
  ascending date order.
- **O3.** `cache-control` on the day and calendar routes, as on the hour
  route.

### Coverage notes

- `@mystery_keys` includes `days_prayed`. Stricter than the app needs;
  keep it, and assert the type (D2).
- `@meditation_keys` omits `narrations`. HEAD decodes it as optional, but
  where present every element needs `voice` and `audio_url` as strings.
- `GET /api/mysteries` is called by no build. Its contract test protects
  nothing the app reads; the mystery nested in the set detail (D2) is
  what matters.

## Inventory

**Success** is any 2xx; 201 is not required. The only status-specific
branch in the app is 400 on `/rosary/audio`. Any other non-2xx becomes
`APIError.serverError(status, code)`. The error envelope is decoded with
`try?`: `error.code` a non-optional String, `error.message` optional;
`code` appears only in error descriptions. Redirects are followed.
Content-Type is never checked. Cache-control is never read, but the
default URLCache honours it.

**Retries.** GETs (APIService and OfficeAPIService) retry once after 1.5
seconds on a connection-shaped `URLError` only; timeouts are 15 seconds
per request and 45 per resource. `POST /completions` never retries.

**Which builds call what.** 1.0 and 1.0.1: set list, set detail,
completions, `/prayers/:id/audio`. 2.0 adds `/meditations/:id/audio`. 3.0
adds the Office. 4.0 adds `/voices`, `/rosary/audio`, `narrations`,
`prayed_aloud`, and `voice` on the audio response; 4.0 (build 77 and
later) also reads the v2 `prayer-book` and `chant-library` (section 10).
4.2 adds, in every
language, `lines` on `/rosary/audio` (section 5) and `POST
/api/v2/meditations/audio` (section 15); and, in a Spanish app only,
`lang=es` on the set list and detail with `translations` and
`set_translation` (section 14) and the v2 Prayer Book and Consecration
with `lang=es` (sections 12 and 13).

### 1. GET /api/meditation-sets?category=<raw>

Callers: MeditationSelectionViewModel, Explore search,
MeditationCacheService, OfflineContentService (every category).

Which sets are listed: those the public may see, which is every set with
at least one meditation and none archived. A set a curator has created
but not yet filled is not listed, and answers 404 by id, exactly as a set
withdrawn by an archived meditation does. A build only ever sees fewer
sets for this; the shape of each is unchanged.

`data: [MeditationSetSummary]`. Required: `id` Int, `name` String,
`category` String. Optional: `description`, `labels` ([String]),
`author`, `source`, `image_url`, `image_alignment`, `image_focal_x`
(Double), `image_focal_y` (Double), `image_width` (Int), `image_height`
(Int), `image_alt`, `image_attribution` (`title`, `artist`, `year`,
`source_url`, `license`, each String?).

Assumes `labels` is `[]` rather than null when empty, the first label is
the group, and the list order is the display order. `image_url` must be
unsigned and immutable: ArtworkCache keys on the URL string and relies on
S3's immutable header, so a signed or per-request URL would mean a
download on every visit.

### 2. GET /api/meditation-sets/:id

Callers: MeditationSetResolver, MeditationCacheService,
OfflineContentService (the download, and re-signing a set saved from its
page).

`data: MeditationSet`: the summary fields, plus `meditations`
([Meditation]?, the list itself optional) and `audio_expires_at` (String?).

Meditation. Required: `id` Int, `content` String. Optional: `title`,
`author`, `source`, `audio_url`, `mystery` (Mystery?), `narrations`
([Narration]?). Narration: `voice` and `audio_url`, both required
Strings. Mystery. Required: `id` Int, `name` String, `category` String,
`order` Int. Optional: `description`, `scripture_reference`; 1.0 to 3.0
also decode `days_prayed` as String?.

`meditations[i]` is decade i; `narrations[0]` is the default voice. The
legacy `audio_url` plays when `narrations` is missing, which is every set
stored by a pre-4.0 build. Any error falls back to the copy saved on the
device, so a 404 for a hidden set still plays offline, by design.

Ids persist on the device: pinned sets, the resume snapshot, the offline
files `meditation_<id>_<voice>.mp3` and `set_<id>_<hash>.jpg`, and the
completion's set id. Integer primary key values must survive any
migration unchanged.

### 3. GET /api/meditations/:id/audio[?voice=<slug>] (2.0 and later)

Caller: `PrayerSessionViewModel.freshAudioURL`, inside `try?`. The slug
is interpolated unencoded.

`data`. Required: `id` Int, `audio_url` String. Optional: `voice` (HEAD
only), `expires_at`, parsed with `Date(_, strategy: .iso8601)`. Every
error falls back to a copy in another voice, then to skipping the
meditation; there is no status branch.

### 4. GET /api/voices (HEAD only)

Caller: NarrationVoiceCatalog, on every foreground.

`data: [NarrationVoice]`. Required: `slug` String, `name` String,
`default` Bool. Optional: `description`. An empty list is ignored and the
stored one kept. The default voice is the first with `default` true, else
`voices[0]`. Stored in UserDefaults.

### 5. GET /api/rosary/audio[?voice=<slug>][&include=<sorted,kinds>] (HEAD only)

Caller: RosaryAudioPack; both parameters go through URLQueryItem.

`data`. Required: `voice` String, `version` String. Optional:
`expires_at`, `prayers` ([String: Clip]), `announcements`
([String: Clip]), `verses` ([String: [Clip]]), `book` ([String: Clip]).
Clip. Required: `file` String, `audio_url` String. Optional: `text`,
`reference`, `lines` (added 5 Nov 2026, read by 4.2: `[{text, start,
end}]` in seconds, the clip's words a line at a time and when each is
heard, or null when that recording is not timed; it never changes
`version`). 4.2 reads `lines` leniently (`try?` in
RosaryAudioManifest): a `lines` that does not decode, a null `start`
included, is read as no lines, not as a failed manifest. Keep `text`,
`start` and `end` present and typed in every line anyway.

A 400 leads to one retry with no voice; any other error uses the saved
manifest, or a saved manifest in another voice. `file` is the on-disk name
and cache key and changes exactly when the recording does. `version` is
compared to decide whether to merge kinds. An expiry that is nil or under
five minutes away means stale. A kind not asked for is absent. `book` ids
are the app's PrayerBook ids; `angelus` is one. Clips are plain GETs to
presigned URLs, accepted on any 2xx.

### 6. POST /api/completions

Caller: `PrayerSessionViewModel.recordCompletion`, fired with `try?` from
MysteryPrayerView. Only meditation-set Rosaries post; the Scriptural,
Holy and Guided Rosaries never do.

Headers: `Content-Type: application/json`, `Accept: application/json`.
Body in HEAD: `{"meditation_set_id": <JSON int>, "prayed_aloud":
<JSON bool>}`. In 1.0 to 3.0: `{"meditation_set_id": <JSON int>}`. **No
build sends `time_zone` or `locale`.**

`data`, all required: `id` Int, `meditation_set_id` Int, `completed_at`
String (never parsed, so any format works). 403, 429 and 422 are
swallowed silently. A 429 also carries a `Retry-After` header, in whole
seconds: an added header that no build reads (the status is all it reads),
so nothing a build decodes changed.

### 7. /api/office (3.0 and later; OfficeAPIService)

Routes: `GET /api/office/:date`, `/api/office/:date/:hour`,
`/api/office/calendar/:year/:month`, each with
`?version=rubrics-1960&language=english`. `/office/versions` is never
called. `date` is `yyyy-MM-dd` in the device's zone; `hour` is one of
matutinum, laudes, prima, tertia, sexta, nona, vesperae, completorium;
`month` is an unpadded integer. Plain JSONDecoder: no key conversion, no
date strategy.

OfficeHour. Required: `date`, `hour`, `version`, `language` (Strings),
`sections` ([OfficeSection]), `source` (`name` and `url` Strings).
Optional: `celebration` (`title` String required, `rank` String?),
`tempora`. OfficeSection: `latin` and `vernacular`, each OfficeCell?.
OfficeCell. Required: `lines` [String]. Optional: `title`, `note`.

OfficeDay. Required: `date`. Optional: `celebration` (as above), `detail`
(`label`, `text`, each String?), `note`, `letter`. The day route's
`version` key is ignored. OfficeCalendarMonth, all required: `year` Int,
`month` Int, `version` String, `days` [OfficeDay]. Sections in reading
order; days in date order. `code` is read but not branched on.

### 8. GET /api/prayers/:id/audio (1.0 to 3.0 only)

Decoded as `{id String, audio_url String}`. Answers 410 now, and those
builds treat every error as "chant unavailable". In 3.0 that also leaves
"Download all" marked incomplete forever, which is already true in
production.

### 9. GET /api/mysteries

Never called by any build.

### 10. GET /api/v2/prayer-book and GET /api/v2/chant-library (4.0, build 77 and later)

Callers: the Prayer Book and Chant Library stores, at launch and on
foreground at most once a day. The bare request is decoded as `{version,
updated_at}`; when `version` differs from the saved copy's the app asks
for `fields[prayer_book]=version,updated_at,prayers,chapters` and
`fields[chant_library]=version,updated_at,groups,chants` (4.0, build 77 and later) and replaces its
copy only when the whole document decodes, so a field the app treats as
non-optional going null loses that refresh, not the screen: the bundled
seed or the last good copy stays. The shapes are docs/JSON_API.md, "The
Prayer Book and the Chant Library", pinned by
`test/lumen_viae_web/json_api/library_test.exs` and `priv/openapi/v2.json`.
Non-optional in the app: every field the contract does not mark `| null`,
including each chant's `audio` and every score page's `url`, `bytes` and
`sha256`. Ids are stored on the device and must never change.

The Prayer Book gained an optional `novenas` section on 14 Nov 2026
(docs/JSON_API.md, "`prayer_book`"). No shipped build names it, so 4.0 to
4.3 never receive it. What they do receive is each novena's twin: an
ordinary prayer in `prayers`, named by a chapter, holding the whole
novena as text, which they show as any other prayer. The build that adds
novenas names `novenas` in `fields[prayer_book]`, shows a novena in its
twin's place, and treats `list_title`, `latin_title`, `note`, `origin`,
`feast`, `painting`, `art` and a part's `prayer_id`, `times`, `id`,
`title`, `text` and `source` as optional. `kind` is a string, not an
enum: a kind the app does not know is shown as plain text.

A meditation's narrations in v2 and GraphQL (`narrations`,
`narration(preferring:)`, `POST /api/v2/meditations/audio`,
`meditationAudio`) gained an optional `lines` on 2 Nov 2026: the recording
line by line, `{text, start, end}` in seconds, null when not timed. 4.2
reads it, as optional, from `POST /api/v2/meditations/audio` (section
15). The v1 REST narrations (sections 2 and 3) do not carry it.

The chant files themselves (`audio.url`, `score[].url`) are fetched
outside Phoenix, below. Builds up to 4.0 bundle their chants and words
and call neither route.

### 11. GET /api/v2/rosary-content?lang=es (not yet called)

No build sends `lang` yet. A build that does gets each prayer's `title`
and `text` with `es` beside `en` and `la`, never null (the English where
there is no Spanish), `ai_translated: true` on a prayer whose Spanish
is partly the team's own translation (absent otherwise), the mysteries' `name` and `fruit` and the
sets' `name` and `devotion_title` in Spanish in the same fields, each
quote's `text`, `author` and cited `source` in Spanish (an
`ai_translated: true` on the team's translations, absent otherwise), and a
`version` of its own, so it keeps its Spanish
copy apart from the English one. Without `lang`, or with `lang=en`, the
document is exactly what every shipped build reads today, version and
date included, pinned by `test/lumen_viae_web/json_api/rosary_content_test.exs`
("lang"). The shapes are docs/JSON_API.md, "The Rosary in Spanish".

### 12. GET /api/v2/prayer-book?lang=es (4.2)

4.2, in a Spanish app only, asks for
`prayer-book?lang=es&fields[prayer_book]=version,updated_at,translations`
(LibraryContent); a failure keeps the English (`try?`). It reads the new
`translations` section: every prayer with a Spanish text, `{id, title,
text}` and `ai_translated: true` where part is the team's translation,
laid over the English by `id`; every other section is unchanged. The
Spanish document has a `version` of its own. Without `lang`, or with
`lang=en`, the document is exactly what every shipped build reads today,
version and date included, and `translations` is empty, pinned by
`test/lumen_viae_web/json_api/prayer_book_spanish_test.exs`. The shapes
are docs/JSON_API.md, "The Prayer Book in Spanish".

### 13. GET /api/v2/consecration?lang=es (4.2)

The app bundles the Consecration. 4.2, in a Spanish app only, asks for
`consecration?lang=es&fields[consecration]=version,updated_at,translations`
and keeps the English when that fails (`try?`). It reads the new
`translations` section: the
phases, days (title, journal question and readings by `order`), prayers
and feasts that have Spanish, each laid over the English by key, with
`ai_translated: true` where a part is the team's translation; every
other section is unchanged. The Spanish document has a `version` of its
own. Without `lang`, or with `lang=en`, the document is exactly what it
is today, version and date included, and `translations` holds four empty
lists, pinned by `test/lumen_viae_web/json_api/consecration_spanish_test.exs`.
The shapes are docs/JSON_API.md, "The Consecration in Spanish".

### 14. GET /api/meditation-sets/:id?lang=es (4.2)

4.2 sends `lang` on the set list (`&lang=`) and detail (`?lang=`) when the
app is in Spanish. It decodes `translations` as optional, each entry's
`id` Int and `content` String required and `title` and `source` optional,
and every `set_translation` key as optional, `image_alt` and
`ai_translated` included. With `lang` the response is the set exactly as in
section 2, plus `translations`: each meditation with a Spanish text,
`{id, title, content}` in prayer order (`title` null where the English
has none) and `ai_translated: true` on the team's own translation
(absent otherwise), laid over the English by `id`. A meditation not
listed shows its English, as does one whose English was edited after its
Spanish was made. `meditations`, `narrations` and every `audio_url` stay
English: the recordings are English in every language. Without `lang`
the response is exactly what every shipped build reads today, with no
`translations` key; `lang=en` or a language not served gives
`translations: []`. Pinned by
`test/lumen_viae_web/controllers/api/meditation_set_spanish_test.exs`.

With `lang`, it also carries `set_translation`, the set's own words in
Spanish: `{name, author, description, source, image_alt, ai_translated}`
(`name` and `author` in the usual Spanish forms, "San Alfonso María de
Ligorio"), each null
where it has no Spanish or its English was edited since (show the
English), `ai_translated: true` on the team's translation. The whole key
is null for `lang=en`, a language not served, or a set with no Spanish;
without `lang` there is no `set_translation` key, and the set's own
`name` and `author` stay as in section 2 in every language. The list,
`GET /api/meditation-sets?category=<slug>&lang=es` (and without
`category`), carries the same `set_translation` on each set; without
`lang` it is exactly section 1. Pinned by
`test/lumen_viae_web/json_api/meditation_set_text_spanish_test.exs`.
The words and their sources: docs/JSON_API.md, "The meditations in
Spanish".

### 15. POST /api/v2/meditations/audio (4.2)

Caller: APIService, for a meditation's timed narration. Sent with the
`application/vnd.api+json` headers. Each element decodes `meditation_id`
Int, `voice` String and `audio.url` String as required, and `lines`
(`[{text, start, end}]`, null when untimed) as optional; `expires_at` is
not read. The shapes are docs/JSON_API.md, "Fresh meditation audio", pinned by
`priv/openapi/v2.json` (getMeditationAudio).

### Outside Phoenix

S3 presigned narration and rosary clips (AVPlayer, or a plain GET), S3
artwork, the chant recordings and score pages (public, content-addressed,
downloaded in the background and checked against `sha256`; a recording
not yet saved streams), Missale Meum, Gutenberg, LibriVox. The one requirement on the
API: every URL it hands out must be GET-able with no headers and no auth.
