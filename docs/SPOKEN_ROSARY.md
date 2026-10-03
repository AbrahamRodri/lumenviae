# The Spoken Rosary

Every prayer of the Rosary, one announcement per mystery and the Scriptural
Rosary's verse for every Hail Mary, recorded in each narration voice, so the
iOS app and the website can pray a whole Rosary aloud, bead by bead.

| Piece | Where |
| --- | --- |
| The clips, their text and S3 keys, and the order a Rosary is said in | `LumenViae.Rosary.PrayerAudio` |
| Recording them | `mix lumen_viae.generate_rosary_audio`, `LumenViae.Release.generate_rosary_audio/1`, which enqueue `LumenViae.Curation.Jobs.RecordRosaryClip` jobs |
| Coverage (is every clip in the bucket) | `LumenViae.Curation.RosaryAudioGeneration.coverage/1` |
| The app's manifest | `GET /api/rosary/audio` |
| Listening to and checking every clip | `/admin/rosary-audio`, and a row on the dashboard when anything is missing |
| Praying aloud on the website | the "Pray aloud" switch on `/meditation-sets/:id/pray`, the `SpokenRosary` hook |
| Whether a Rosary was prayed aloud | `rosary_completions.prayed_aloud`, see docs/COMPLETION_ANALYTICS.md |

---

## The clips

Three kinds, each recorded once per voice at
`voices/<voice>/rosary/<kind>s/<name>-<hash>.mp3`. The hash covers the
spoken text and the voice's synthesis settings, so a reworded prayer gets a
new key and nothing already recorded is overwritten.

**Prayers** (12), keyed by the app's prayer ids in `RosaryPrayers.swift`:

| Id | Used in |
| --- | --- |
| `sign_of_cross`, `our_father`, `hail_mary`, `glory_be` | every Rosary and the chaplet |
| `apostles_creed`, `fatima_prayer`, `hail_holy_queen`, `rosary_closing_prayer` | the four Rosaries |
| `act_of_contrition`, `sorrows_closing_prayer` | the Seven Sorrows chaplet |
| `memorare`, `st_michael_prayer` | optional prayers after the Rosary |

**Announcements** (27), keyed `"<category>_<order>"`: "The First Joyful
Mystery: The Annunciation", "The First Sorrow of Mary: The Prophecy of
Simeon".

**Verses** (249), ten per mystery and seven per sorrow, from
`priv/rosary_audio/scriptural_rosary.json` (the app's own export).

The wording is the app's. The prayers say "Holy Spirit" (a deliberate choice,
24 Sept 2026); the verses are Douay-Rheims verbatim and so say "Holy Ghost".
Change a prayer in `PrayerAudio` and `RosaryPrayers.swift` in the same
change, then record.

---

## The order a Rosary is said in

`PrayerAudio.script/3` is the server's copy of the app's
`SpokenRosaryScript`, and the two must agree.

**Joyful, Sorrowful, Glorious, Luminous**

1. Sign of the Cross, Apostles' Creed, Our Father, three Hail Marys (faith,
   hope, charity), Glory Be
2. Each decade: announcement, the set's meditation, Our Father, ten Hail
   Marys (in the Scriptural Rosary each preceded by its verse), Glory Be,
   Fatima Prayer
3. Hail, Holy Queen, the closing prayer, then any optional prayers - for the
   Holy Father's intentions (Our Father, Hail Mary, Glory Be), the Memorare,
   the Prayer to Saint Michael, in that order - and the Sign of the Cross

**The Seven Sorrows chaplet** (the Servite form)

1. Sign of the Cross, Act of Contrition
2. Each sorrow: announcement, meditation, Our Father, seven Hail Marys, Glory
   Be. No Fatima Prayer: it belongs to the Dominican Rosary.
3. Three Hail Marys in honour of Our Lady's tears, "Pray for us, O most
   sorrowful Virgin" with its prayer, the Sign of the Cross

The optional closing prayers are not added to the chaplet.

The app has three styles of the same order: with the set's meditation after
each announcement, the Scriptural Rosary with a verse before each Hail Mary,
and the "Rosary Aloud" with neither (80 steps for the four Rosaries without
extras). `script/3` takes `style: :plain` for the last; the website uses the
meditation style. None of them needs a recording the others do not.

---

## `GET /api/rosary/audio`

```
GET /api/rosary/audio?voice=female&include=prayers,announcements
```

| Param | |
| --- | --- |
| `voice` | a slug from `GET /api/voices`; the default voice when absent. Unknown is a 400. |
| `include` | any of `prayers`, `announcements`, `verses`, comma-separated; all when absent. Unknown is a 400. |

```jsonc
{
  "data": {
    "voice": "female",
    "version": "8a336a86aa",            // fingerprints the voice's whole catalogue
    "expires_at": "2026-09-25T12:00:00Z",
    "prayers": { "hail_mary": { "file": "hail_mary-3f0c1e9a2b.mp3", "audio_url": "https://..." } },
    "announcements": { "joyful_1": { "file": "...", "audio_url": "...", "text": "The First Joyful Mystery: The Annunciation" } },
    "verses": { "joyful_1": [ { "file": "...", "audio_url": "...", "reference": "Luke 1:26" } ] }
  }
}
```

A kind left out by `include` is absent, not empty. `file` changes whenever
its recording would, so it is the device's cache key; `version` changes
whenever any file in the voice's catalogue does, so one field says whether an
offline pack is current. URLs are signed for `Rosary.audio_url_ttl/0` and the
response is `private, no-store`. A signing failure is a 503
`audio_unavailable`.

The manifest does not check the bucket. A clip that has not been recorded is
still listed and its URL answers 403, which is why the admin console watches
coverage.

---

## Recording

Always dry-run first:

```
mix lumen_viae.generate_rosary_audio --dry-run
mix lumen_viae.generate_rosary_audio
```

Options: `--voice SLUG` and `--kind KIND` (each repeatable; `prayers`,
`announcements`, `verses` or `book`), `--force`, and `--concurrency N`
(recordings at once, default 3). A run skips every clip already at its
key, so an interrupted run is simply run again. It needs
`ELEVEN_LABS_API_KEY` and AWS credentials (`./dev.sh` loads both locally).

A real run checks which clips are missing (one HEAD each) and enqueues one
job per missing clip on the `elevenlabs` queue. The task's own node runs the
jobs and waits for the last of them, printing each clip as it lands (`REC`,
`SKIP`, `RETRY`, `FAIL`) and the failures at the end; it exits non-zero if
any clip failed. The clips go to S3 and never to a table, but the jobs live
in the database of wherever the task runs - a laptop's dev database
(`DEV_DATABASE` if set) - so an interrupted run's jobs wait there and the
next run, or the next `./dev.sh`, records them. The dry run enqueues
nothing and needs no database.

Each job pays ElevenLabs once for its clip. A retry finds the job's own
upload at the key and stops; a 429 or a 5xx produced no audio and is
retried with backoff; a timeout or a dropped connection may have been
charged for and is cancelled with the reason rather than retried, and the
next run records the clip if it is really missing. A clip whose wording
changed after it was queued has a new key, and its old job is cancelled
rather than recording the old words. See `LumenViae.Audio.Recording`.

> **Before recording from a laptop, stop every other dev server on the
> same database, or give the task its own.** Every worktree shares
> `lumen_viae_dev`, and any `./dev.sh` running this branch's code runs the
> `elevenlabs` queue too, so it can pick up the task's jobs and record them
> with its own code and its own `.env`. A server on a branch without these
> workers runs no `elevenlabs` queue and leaves them alone, but a server on
> an older revision of this one would not. Either stop the other servers,
> or run the task against a copy:
> `createdb -h localhost -U postgres -T lumen_viae_dev <name>` and
> `DEV_DATABASE=<name> mix lumen_viae.<task> ...`.

### Record before you deploy

A reworded prayer has a new key, and the deployed manifest names the new
file at once. So run the task **from the branch, before deploying it**:
the branch's catalogue is what computes the keys and the text, the laptop
records into the production bucket with the production credentials in
`.env`, and by the time the deploy names the new files they exist. Until
then the app says that prayer from its old copy, or skips it on a device
that never had one.

In production the same task enqueues on production's queue, and the web
app records:

```
/app/bin/lumen_viae eval 'LumenViae.Release.generate_rosary_audio(dry_run: true)'
/app/bin/lumen_viae eval 'LumenViae.Release.generate_rosary_audio()'
```

`eval` starts no queues, so the release task only enqueues, then reads the
batch from the jobs table every five seconds until it is done and prints
the failures (`wait: false` returns at once). That keeps working when it is
run detached, with its output in a log file. But production's catalogue is
the deployed one, so this records what is already live; it is for filling a
gap, not for getting ahead of a deploy.

Adding a narration voice to `:narration_voices` means recording its whole
catalogue (about 67,000 characters) before the app offers it for praying
aloud. The dashboard's "Spoken Rosary clips missing" row shows the gap until
then.

---

## The admin screen

`/admin/rosary-audio` lists every clip for one voice with its text, whether
it is in the bucket, and a player. Coverage is one HEAD per clip (the scoped
IAM user cannot list the bucket), run after the page is up. A bucket that
cannot be reached - usually a server started without `./dev.sh` - shows as
"Unknown", never as "Missing".

While a recording run is under way the screen follows it live: it reads
the clips still waiting when it opens, then marks a clip "Recording" while
its job waits and "Recorded" when it lands, from the jobs' PubSub
broadcasts (`LumenViae.Curation.AudioJobs`), with no further trip to the
bucket. The jobs themselves are at `/admin/jobs`.

Use it for the listening pass after any recording: a run proves a file
exists, not that the narrator said "Pontius Pilate" properly. A bad clip is
fixed by adjusting the text (or the voice's settings) and recording again,
which gives it a new key.

---

## The website

The prayer page has a "Pray aloud" switch and a voice choice; both ride in
the URL (`aloud=true`, `voice=male`). With the switch on, the LiveView builds
the whole script with signed URLs and hands it to the `SpokenRosary` hook,
which plays it through one `Audio` element (the bucket sends no CORS
headers, so `fetch` cannot be used) with the lock-screen Media Session
controls. When the voice reaches a new decade the hook sends `spoken_at` and
the page turns to that mystery; when the reader turns the page the LiveView
sends `spoken_seek` and the voice follows. Pressing Complete is still what
records the Rosary, now with `prayed_aloud`.

The voice choice also picks the meditation narration. A meditation not yet
recorded in the chosen voice plays in whichever voice it has.

---

## The Prayer Book

The app's Prayer Book (Morning and Night Prayers, the Angelus, the prayers
before and after Mass and Confession, Our Lady's antiphons, the litanies)
is said aloud from the same catalogue, as a fourth kind of clip, `book`:
one clip per prayer per voice, at
`voices/<voice>/rosary/books/<id>-<hash>.mp3`, keyed by the app's book
prayer ids. The prayers the Rosary also says (the Our Father, the
Memorare...) are not in it; the app plays their `prayers` clips.

- **The words** are the app's. `Tools/PrayerBook/export.py` in the app
  writes `prayer_book.json` already in the words a narrator says: a
  litany's response after every invocation, ℣ ℟ ✠ and the mediant
  asterisk gone, "Let us pray" said and gestures ("strike the breast")
  silent, the directions of the guided texts (the examens, making a
  confession) said as guidance. It is copied verbatim to
  `priv/rosary_audio/prayer_book.json`. Blank lines between stanzas stay,
  and the pipeline turns each into the voice's own pause.
- **Served** only when asked for: `GET /api/rosary/audio?include=book`
  (the app asks for `prayers,book`). Without `include` the manifest and
  its `version` are the spoken Rosary's alone, as before, so older builds
  see no change.
- **Recorded** with `mix lumen_viae.generate_rosary_audio --kind book`
  (dry-run first; about 55,000 characters a voice). The longest prayers
  (the Examination of Conscience, the Litany of the Holy Name) can take
  eleven_v3 longer than the default 120 s; record the stragglers with a
  longer receive timeout, e.g.
  `mix run -e 'Application.put_env(:lumen_viae, :eleven_labs_req_options, receive_timeout: 300_000); LumenViae.Curation.RosaryAudioGeneration.run(kinds: [:book])'`.
- **A changed prayer** is re-exported in the app, copied here, and
  recorded before deploying, as with the Rosary's prayers.

---

## Not built

- **Prayer Book in the admin screen.** `/admin/rosary-audio` lists the
  Rosary's clips; the `book` kind is recorded and served but not yet shown
  there.
- **Latin audio.** The app shows every prayer in Latin, but only English is
  recorded. It needs a decision on pronunciation (ecclesiastical) and a
  listening pass before ElevenLabs output can be trusted.
- **CarPlay.** It needs Apple to grant the CarPlay audio entitlement to the
  app first.
