# What the Android app calls

The contract between this backend and the Android app: what the app
calls, how, and what it keeps on the device. Written on 4 October 2026,
when the server's half of the Android plan (docs/ANDROID_BACKEND_PLAN.md)
had landed and no Android build existed.

**This becomes binding once an Android build ships**, as
docs/IOS_API_CONTRACT.md is for the iPhone app: from then on, nothing an
installed Android build calls or decodes may be removed or renamed until no
installed build calls it. Until then it is the specification the Android
app is written against, and the place to change first when the two
disagree.

The details of each route and section are in docs/JSON_API.md; this
document says which of them the app uses and what it does with them.

## The API

| | |
| --- | --- |
| Base URL | `https://www.lumenviae.org` |
| API | `/api/v2`, JSON:API (docs/JSON_API.md) |
| Media type | `application/vnd.api+json`, on every request with a body and in `Accept` |
| Client | generated from `priv/openapi/v2.json` (docs/JSON_API.md, "Generating the Kotlin client") |
| Authentication | none: every request is anonymous |

**Use `www.lumenviae.org`, and nothing else.** It is the canonical host
and the one the OpenAPI document names. The API also answers on
`lumenviae.org` and `lumenviae.fly.dev` with no redirect (only the
website's pages are redirected, 301, to `www`), but those names belong to
the hosting, and the iPhone app's older builds are what keep
`lumenviae.fly.dev` answering. A page redirect would turn a POST into a
GET, so a client must never rely on one.

**Android calls `/api/v2` and nothing else.** v1 (`/api`) is frozen for
installed iPhone builds and serves nothing v2 does not. GraphQL
(`/api/graphql`) serves the same data through the same actions; the
Android app does not need it.

**The Kotlin client needs three settings the document cannot carry**:
`typeMappings` to kotlinx's `JsonElement` and `JsonObject`, a
`schemaMappings` entry for `included_resource`, and a converter for
`application/vnd.api+json` (the generated default, `application/json`, is
answered `415 unsupported_media_type`). They and the exact commands are in
docs/JSON_API.md, "Generating the Kotlin client"; do not copy them here.

### The user agent

Every request the app makes to the API carries

```
LumenViae-Android/<versionName> (Android <release>; <model>)
```

for example `LumenViae-Android/1.0 (Android 15; Pixel 8)` (decision D4).
Set it once, on the HTTP client (an OkHttp interceptor), never per call,
and never let a request go out with the library's default: OkHttp's
`okhttp/<version>` is on the server's list of scripted clients, and a
completion sent with it is refused `403 automated_client`, which a client
drops without retrying, so Android's completions would silently never be
counted (`LumenViae.BotDetection`). The server reads the agent for two
things only, to turn crawlers away and to record a completion as
Android's (`Completion.AppSource`: any agent containing `Android`), and
keeps it nowhere. Downloads of recordings from their presigned URLs may
send any agent.

### Timeouts and retries

The server runs on a machine that sleeps when idle, and the first request
after a quiet spell wakes it. As the iPhone app does
(`Services/APIService.swift`):

- **15 seconds** to connect and between bytes of a response, and 45 for a
  whole request (OkHttp `connectTimeout` and `readTimeout` 15 s,
  `callTimeout` 45 s). A recording's download is not an API request and
  takes as long as it takes.
- **One retry, after 1.5 seconds, for a GET that failed to connect**: a
  timeout, a refused or reset connection, an unknown host or a failed DNS
  lookup. The first request often wakes the machine just in time for the
  second. Nothing else retries: not a 4xx, not a decoding failure, not a
  cancelled request, and **never a POST**.
- `429 rate_limited` carries `Retry-After` in whole seconds; `503
  audio_unavailable` means the server cannot sign recordings just now.
  Both are worth a later attempt; neither is worth a loop.

### Keys

The app and the server name things by the app's keys, which never change:

| Thing | Key | Example |
| --- | --- | --- |
| A category | its slug | `joyful`, `sorrowful`, `glorious`, `luminous`, `seven_sorrows` |
| A mystery | `<category>_<order>` | `joyful_1`, `seven_sorrows_7` |
| A prayer | the app's prayer id | `hail_mary`, `sorrows_closing_prayer` |
| A narration voice | its slug | `frederick`, `female` |
| A meditation set, a meditation | the server's integer id, a string in JSON:API | `"42"` |
| A Rosary's style | the script's style | `meditation`, `scriptural`, `plain` |
| An optional prayer after the Rosary | its id | `holy_father`, `memorare`, `st_michael` |
| A set's label | the string the set stores | `Considerations` (shown as Reflections) |

**Never key anything on a mystery's database id.** The iPhone app's
mysteries are numbered 1 to 27 and production's begin at 46; a mystery is
its `key`. A set's meditations name their mystery by relationship, and the
included mystery carries its `key`.

**A stored voice is a preference.** Store the slug the listener chose. A
retired voice is answered by its successor, and `GET /voices/retired`
names it (`replaced_by`) so a stored choice can be moved on.

**Unknown values are passed over, never an error.** The document grows
without notice (docs/JSON_API.md: "may gain fields without notice").
Ignore keys you do not know, and pass over an item whose vocabulary value
you do not know: a prayer's `group`, a step's `kind`, a course section's
`shows`, a reading door's `kind` or `target`, a schedule's `id`. A new
value is added to a vocabulary, never a renamed one.

## The routes the app uses

| Call | When | Asked as |
| --- | --- | --- |
| `GET /api/v2/rosary-content` | at launch and once a day | bare: `version` and `updated_at` only |
| `GET /api/v2/rosary-content?fields[rosary_content]=...` | when `version` differs from the saved copy's | every section the app uses (below) |
| `GET /api/v2/meditation-sets?category=<slug>` | a mysteries' page's shelf | default fields |
| `GET /api/v2/meditation-sets/<id>?include=set_memberships.meditation.mystery&fields[meditation]=title,content,author,source,narrated_voices,narrations` | a set is opened or saved for offline | with its meditations, in prayer order, and their signed narrations |
| `POST /api/v2/meditations/audio` | a saved set's narration links have expired, or one would not load | `{"data": {"meditation_ids": [...], "voice": "<slug>"}}`, at most 200 ids |
| `GET /api/v2/voices` | the voice picker | default fields |
| `GET /api/v2/voices/retired` | a stored voice is no longer offered | default fields |
| `GET /api/v2/rosary-audio?voice=<slug>&fields[spoken_rosary]=version,expires_at,prayers,announcements,verses` | before a Rosary is said aloud, or saved for offline | only the kinds needed (below) |
| `POST /api/v2/completions` | a meditation set's Rosary is finished | `{"data": {"type": "completion", "attributes": {"meditation_set_id": 42, "prayed_aloud": true}}}` |

The sections of the content document the Rosary needs are `prayers`,
`schedule`, `script`, `mysteries`, `categories`, `verses`, `learn`,
`guided_rosary`, `quotes`, `milestones`, `reminders`, `labels` and
`forms`: ask for them by name
(`fields[rosary_content]=version,updated_at,prayers,schedule,...`). A
section added later is not sent until it is named, so an old build never
pays for it.

`GET /api/v2/rosary-script` is not needed to pray. It is the server's
expansion of the `script` templates, the reference a client's own
expansion is checked against (docs/SPOKEN_ROSARY.md, "The templates"), and
a test in the app should compare the two. `GET /api/v2/mysteries` serves
what the content document's `mysteries` section already holds.

## Offline

A Rosary app prays with no connection, so everything the Rosary needs is
kept on the device and the network only refreshes it.

### The content document

- **Ship a copy in the app**, fetched at build time, so the first launch
  prays offline. Thereafter the saved copy is the app's content.
- **Poll the version**: the bare request at launch and at most once a day.
  When `version` differs from the saved copy's, fetch the sections and
  replace the copy whole, only once the whole response has arrived and
  decoded; a failed fetch keeps the old copy. `version` fingerprints every
  section whether or not it was asked for, so compare it, never parse it.
- **The version moves when the UTC year turns**, because `schedule`
  serves every Lent and Advent from last year to three years ahead; a
  client refetches once a year for that alone, and its seasons move on
  with it. It also moves when a curator edits a mystery, and when a
  painting is published.
- **Paintings are null until the owner publishes them**
  (docs/MYSTERY_PAINTINGS.md). As of this writing every mystery's
  `artwork` and every category's `card_artwork` is null. Keep the bundled
  paintings, show the served one once a field is not null, and fetch it
  from its `url`, which is public and never expires.
- **A reading door of kind `library`** names a reading the iPhone app
  holds and this document does not serve (the Marian Library's `montfort`
  and `cana`). A client that has no such reading leaves the door out.

### Meditation sets

- The shelf (`GET /meditation-sets?category=`) is cached per category and
  refreshed when the page is shown with a connection.
- A set opened or saved is cached as the whole detail response. Its
  narrations are `narrations`, every voice, the default first, each
  `{voice, audio: {url, expires_at}}`; an empty list means nothing is
  recorded, and null means recordings exist but could not be signed just
  now. Play the listener's voice when the meditation has it, else the
  default.
- A narration file is cached under the meditation's id and the voice. When
  a set's links have passed `expires_at`, or a load fails, ask
  `POST /meditations/audio` for that set's ids and voice; an id with
  nothing to play is left out of the answer, never failing the batch.
- A set the server no longer serves (404) stays playable from what is
  saved.

### The spoken Rosary's recordings

As the iPhone app keeps them (`Services/RosaryAudioPack.swift`), one voice
at a time:

- **Ask for the kinds the Rosary needs** in `fields[spoken_rosary]`:
  `prayers` and `announcements` always, `verses` for the Scriptural
  Rosary. (`book` is the Prayer Book's, which is not in this programme.)
  The bare request (`version`, `expires_at`) is how to ask whether a saved
  set of recordings is current.
- **A recording's `file` is its cache key.** It is `<name>-<hash>.mp3`,
  and the hash covers the words said and the voice's settings, so new
  words are a new file name. Keep each file under its `file`; a saved file
  with the same name never needs checking again, and a file the manifest
  no longer names is an old recording, to delete.
- **A saved manifest is used while every recording asked for is in it and
  its links live more than five minutes more** (`expires_at`, about a day
  after it was signed). Otherwise fetch the manifest again before
  downloading anything: a manifest about to expire is not one to begin a
  round of downloads on. When kinds are fetched separately and the
  `version` is unchanged, keep the saved kinds not asked for, and the
  merged manifest expires when the first of its links does; when the
  `version` has changed, the old kinds are dropped.
- **With no connection, the saved manifest answers**, and the Rosary is
  said from the files on disk. With none saved in the chosen voice, say
  the Rosary in a voice that has one (the default voice's first) rather
  than not at all.
- A voice the server no longer knows (a stale list) is still answered:
  v2 serves the default voice, and the answer's `id` names the voice
  actually served.

### Presigned URLs

Every recording's `url` is a presigned S3 URL: a plain GET with **no
headers** (no `Authorization`, no API key, no special `Accept`), valid
until its `expires_at`, whole-second UTC. Responses from the API itself
are `cache-control: private, no-store`, because they may carry such URLs;
cache the data the app needs, never the HTTP responses.

## Recording a completion

The app posts a completion **only when a meditation set's Rosary is
finished**, at its last bead's Amen, as the iPhone app does
(`PrayerSessionViewModel.recordCompletion`): the set's id and whether it
was prayed aloud as the Whole Rosary (`prayed_aloud`). The Scriptural
Rosary, the Rosary Said Aloud and "Your First Rosary" post nothing, and
neither does a Rosary abandoned before its Amen.

- **At most once per Rosary**, guarded against a double tap; fire and
  forget, so the completion screen never waits on it.
- **Never retried, never queued.** A completion that could not be sent is
  not sent later: the figures are aggregates, and a completion posted
  hours late would be counted at the wrong time and place. `403
  automated_client` (the user agent) and `429 rate_limited` are dropped.
- **Only a set the server served.** A set id the API does not know is
  `400 invalid_argument`.
- The server records the moment, an approximate place from the request's
  address (truncated before it is stored) and the surface, Android, from
  the user agent. The app sends nothing else and may not
  (docs/COMPLETION_ANALYTICS.md). Nothing identifies the person, the
  device or the installation.

## Privacy

The privacy policy at `www.lumenviae.org/privacy-policy` binds the
Android app (decision D5), and the Google Play Data safety answers must
match it. It says, of the Android app:

- **No analytics, advertising or crash-reporting SDK**, from anyone. Not
  Firebase Analytics, not Crashlytics, not an ad network.
- **No location permission.** The approximate place of a completion is
  worked out on the server from the request's address; the app never asks
  the device where it is.
- **What is kept stays on the phone**: the prayer record and streak, the
  journal, places in books, settings. It leaves the phone only through
  Android's own backup to the Google Account, if the person has it on.
- **Reminders are scheduled on the device**, by Android. There are no push
  notifications.
- The one thing the app sends about praying is the completion above.

A change to what the Android app collects is a change to the policy
(`lib/lumen_viae_web/live/privacy_policy/index.ex`), the Data safety
answers and docs/COMPLETION_ANALYTICS.md, together.

## What stays on the device

The server serves the content and the rules; these are decided by the app
alone, about the person praying, and are never sent. Each is the iPhone
app's, and the Android app should do the same so the two read alike.
Paths are under the iOS repository's `app/`.

- **The prayer day turns at four in the morning**, not at midnight
  (`Models/PrayerDay.swift`). An instant before four belongs to the day
  before, so Night Prayers and a late Rosary count for the evening they
  close. A prayer day is named by its calendar date; it runs from four to
  four, 23 hours when the clocks spring forward within it and 25 when they
  fall back. It decides what counts as prayed, the streak and when a
  milestone fires; **which mysteries are today's stays on the calendar
  day** (the `schedule` section): a Rosary begun at half past midnight on a
  Wednesday prays Wednesday's mysteries and counts for Tuesday.
- **The streak** (`Services/PrayerHistoryService.swift`, `currentStreak`):
  the consecutive prayer days ending today, or ending yesterday when
  nothing has been prayed yet today, so a streak is not broken until
  today's day turns. The longest streak counts days between the days'
  dates, so a day the clocks change on is still one day.
- **When a milestone fires**: once, on the completion screen, when the
  streak is exactly a milestone's `days` and the prayer just recorded is
  the first of its prayer day. The rule and the wording are in
  docs/JSON_API.md, "The companion sections" (`milestones`).
- **An unfinished Rosary is kept for 24 hours**
  (`Services/PrayerResumeService.swift`), at its mystery and bead, and
  offered back until then; the Pray button continues one left off the
  same prayer day rather than beginning another over it.
- **"Your First Rosary" keeps its place for 24 hours**
  (`Models/GuidedRosary.swift`, `Place`), from the content document's
  `guided_rosary.first_kept_step` on, with the number of steps and the
  bead it stood on; the place is offered back only while both still match
  the served steps, so a changed guide never resumes on the wrong bead.
- **The beads unlock once the meditation has been heard**
  (`ViewModels/PrayerSessionViewModel.swift`, `beadsUnlocked`). On a
  mystery's Our Father the strand is locked until the narration plays to
  its end, unless there is nothing to wait for: no narration, a narration
  that would not load, or the Rosary said aloud (the voice moves the
  beads). Once the hand has moved past the Our Father the mystery stays
  unlocked; reading the meditation, rather than hearing it, never locks.
- **Two languages pair line for line** (`Data/BilingualPrayer.swift`,
  `formatBilingual`). A prayer's `text.en` and `text.la` have the same
  number of lines (the server refuses to compile a prayer whose do not).
  In a two-language view, each English line stands beside its Latin one
  (Latin first when Latin is the primary choice); a pair of blank lines is
  kept as a blank line, a line whose partner is blank, or the same word in
  both ("Amen."), stands alone. Were the counts ever to differ, the two
  languages are shown as two blocks, never misaligned.
- **The order a Rosary is said in** comes from the `script` section and is
  expanded on the device; how is in docs/SPOKEN_ROSARY.md, "The
  templates". The quotes' rotation and the reminders' weekly choice are
  rules on the device too, stated in docs/JSON_API.md, "The companion
  sections".

## How this is held

- `priv/openapi/v2.json` is the API's whole shape, and
  `test/lumen_viae_web/json_api/open_api_test.exs` fails on any change to
  it; a change to what v2 serves is a diff in that file, in review.
- The v2 tests (`test/lumen_viae_web/json_api/`) hold each route's answer;
  `test/lumen_viae/rosary/content_test.exs` holds every content file's
  version history, and `test/lumen_viae/rosary/spoken_rosary_clips_test.exs`
  every recording's file name, so no change rewords a clip unnoticed.
- `test/lumen_viae_web/bot_detection_test.exs` and
  `test/lumen_viae_web/json_api/record_completion_test.exs` pin the Android
  user agent: it passes, and its completion is recorded as Android.
- The Kotlin client, like the Swift one, was generated from the document
  and decoded 58 responses captured across all ten operations, every
  section of the content document and every style of script among them,
  and encoded them back unchanged (docs/JSON_API.md, "Generating the
  Kotlin client").

v2 is additive: fields, sections, routes and vocabulary values are added,
never removed or renamed. Removing or renaming anything is a v3.
