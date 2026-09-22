# CSV Import Guide for Meditations

## Overview

The CSV import feature allows administrators to batch create meditations by uploading a CSV file. This is particularly useful for importing meditation collections from various authors or sources.

## Accessing the Feature

1. Navigate to the Admin Dashboard at `/admin`
2. Click on "Import Meditations (CSV)" in the Meditations Management section
3. Or go directly to `/admin/meditations/import`

## CSV File Format

Your CSV file must include the following columns:

### Required Columns

- **mystery_name** - The exact name of the mystery (e.g., "The Annunciation")
  - Must match an existing mystery in the database exactly
- **content** - The meditation text/content

### Optional Columns

- **title** - A title for the meditation (optional)
- **author** - The author of the meditation (e.g., "Bishop Fulton J. Sheen")
- **source** - The source of the meditation (e.g., "The Fifteen Mysteries of the Rosary")
- **audio_filename** - The filename for the audio file (e.g., "joyful_1_annunciation.mp3")
  - When provided, the system will automatically generate audio using ElevenLabs API,
    once per narration voice (see "Narration Voices" below)
  - Each voice's recording is uploaded to S3 at `voices/<voice>/<audio_filename>`
  - If audio generation fails for a voice, the meditation is still created and
    the missing voice can be filled in later with `regenerate_audio --only-missing`

### Meditation Set Columns

All optional, and all describing the set rather than the row's meditation.
Put the same set columns on every row that belongs to the set; the set is
found or created once, from the first row that names it.

- **set_name** - find-or-create a set with this name and attach the row's
  meditation to it
- **set_category** - required when the set does not exist yet: one of
  joyful, sorrowful, glorious, luminous, seven_sorrows
- **set_description** - what the set is, shown under its name in the picker
- **set_author** - the set's own byline, e.g. "Bl. Anne Catherine Emmerich"
  - Leave it out and the byline is derived from the set's meditations, but
    only when every one of them agrees. A set of four Emmerich passages and
    one Liguori shows no byline unless you write one here.
- **set_source** - the work the set is drawn from, e.g. "The Dolorous
  Passion of Our Lord Jesus Christ"
- **set_labels** - pipe-separated labels from the managed vocabulary
  (Intentions, Saints, Scriptural, Contemplative, Considerations)
  - Order matters: the first label is the set's primary group in the picker
  - At most three, and at most one of Contemplative or Considerations
- **order** - the meditation's position within the set; when omitted, rows
  are appended after the set's current highest order

Every set column except `set_name` is used **only when the set is created**.
Importing more rows into a set that already exists will not change its
description, byline or labels - edit those in the admin instead.

There is no column for artwork: a CSV cannot carry the bytes. Upload a
painting on the set's admin page.

## Available Mystery Names

The following mystery names are available (must match exactly):

**Joyful Mysteries:**
- The Annunciation
- The Visitation
- The Nativity
- The Presentation
- The Finding in the Temple

**Sorrowful Mysteries:**
- The Agony in the Garden
- The Scourging at the Pillar
- The Crowning with Thorns
- The Carrying of the Cross
- The Crucifixion

**Glorious Mysteries:**
- The Resurrection
- The Ascension
- The Descent of the Holy Spirit
- The Assumption
- The Coronation of Mary

**Luminous Mysteries:**
- The Baptism of Jesus
- The Wedding at Cana
- The Proclamation of the Kingdom
- The Transfiguration
- The Institution of the Eucharist

**Seven Sorrows:**
- The Prophecy of Simeon
- The Flight into Egypt
- The Loss of Jesus in the Temple
- Mary Meets Jesus on the Way to Calvary
- The Crucifixion and Death of Jesus
- Mary Receives the Body of Jesus
- The Burial of Jesus

Note: the database is the source of truth, because `mystery_name` has to
match a stored name character for character. `priv/repo/seeds.exs` is kept
in step with it, but if this list ever disagrees with what is deployed,
trust the database:

```
fly ssh console -C "/app/bin/lumen_viae eval \
  'LumenViae.Rosary.list_mysteries() |> Enum.each(&IO.puts(&1.name))'"
```

## Sample CSV File

A sample CSV file is provided at `priv/repo/sample_meditations.csv` with three example meditations from Bishop Fulton J. Sheen.

### Example Format

```csv
mystery_name,title,content,author,source,audio_filename
The Annunciation,,"In the Annunciation, the birth of the Son of God...",Bishop Fulton J. Sheen,The Fifteen Mysteries of the Rosary,joyful_1_annunciation.mp3
The Visitation,,"The first miracle worked by our Lord...",Bishop Fulton J. Sheen,The Fifteen Mysteries of the Rosary,joyful_2_visitation.mp3
```

Note: The audio_filename column is optional. You can omit it entirely or leave it empty for meditations that don't need audio.

## Using the Import Feature

1. Prepare your CSV file following the format above
2. Navigate to `/admin/meditations/import`
3. Click "Click to upload CSV file" or drag and drop your CSV file
4. Review the file details shown
5. Click "Import Meditations" to begin the import
6. The system will display:
   - Success messages for meditations that were created
   - Error messages for any meditations that failed validation

## Validation Rules

The file itself is validated before any rows are processed:

- The header row must include `mystery_name` and `content`
- Unknown or duplicate column names are rejected (they are usually typos
  that would otherwise be silently ignored)
- A UTF-8 BOM (added by some spreadsheet exports) is tolerated
- Fully blank rows are skipped

Each row is then validated against the following rules:

- `content` is required and cannot be empty
- `mystery_name` must exactly match an existing mystery in the database
- The row must have the same number of fields as the header (a mismatch
  usually means an unescaped comma)
- The same `audio_filename` cannot appear on more than one row (the second
  upload would overwrite the first meditation's audio in S3)

## Error Handling

Each row finishes in one of three states:

- **OK** - the meditation was created exactly as requested
- **Warning** - the meditation was created, but something non-fatal went
  wrong: audio generation failed after retries, or the meditation could not
  be attached to its set. Check these meditations afterwards
- **Error** - the row failed validation and nothing was written for it

If a meditation fails validation, the error message will include:
- The mystery name that the meditation was intended for
- The specific validation errors (e.g., missing content, mystery not found)

Successfully imported meditations will not be affected by validation errors in other rows.

## Tips for Multi-Line Content

- Meditation content often contains multiple paragraphs
- To include line breaks in your CSV, enclose the entire content field in double quotes (`"`)
- Example:
  ```csv
  mystery_name,content
  The Annunciation,"Paragraph one.

  Paragraph two with a line break above."
  ```

## Audio Generation

When the `audio_filename` column is provided, the system will, for every
configured narration voice:

1. Use the meditation content to generate audio via the ElevenLabs text-to-speech API
   (model `eleven_v3`, set by `config :lumen_viae, :eleven_labs_model_id`)
2. Upload the generated audio to Amazon S3 at `voices/<voice>/<audio_filename>`
3. Record the narration against the meditation, so the API can offer that voice

### Narration Voices

The voices live in `config/config.exs` under `:narration_voices`: a slug the
app and the S3 layout use (`female`, `male`), a display name, and the
ElevenLabs voice id behind it. Exactly one is the default; it is the voice
the website plays and the one the API's legacy single `audio_url` field
carries, so an app build that predates voices keeps working. Every other
voice reaches the app through `narrations` on each meditation and
`GET /api/voices`.

Adding a voice is a config line plus one regeneration run:

```
mix lumen_viae.regenerate_audio --all --voice newvoice
```

Pass `--voice` to an import to record fewer voices than are configured
(`mix lumen_viae.import file.csv --voice female`), for instance to hear a set
in one voice before paying for the rest.

### Narration Pauses

Narration pauses only ever exist in the text sent to ElevenLabs; the stored
and displayed meditation content never contains pause markup.

- Every paragraph break (blank line) automatically becomes a spoken pause.
  The default duration is 1.2 seconds, set by
  `config :lumen_viae, :tts_paragraph_break_seconds` (override in production
  with the `TTS_PARAGRAPH_BREAK_SECONDS` environment variable)
- For a spot that needs a longer or shorter pause, put an inline
  `{pause:N}` marker in the CSV content, where N is seconds (decimals
  allowed, capped at 3). Example:
  `And the Word was made flesh. {pause:2.5} And dwelt among us.`
- How the seconds are spoken depends on the model. Models before Eleven v3
  take an SSML `<break time="Ns" />` tag and honor the duration exactly.
  Eleven v3 (the configured model) does not support break tags and offers
  three fixed pauses instead, so the seconds are bucketed: under 1s becomes
  `[short pause]` (about a second), under 2.5s becomes `[pause]` (about two
  seconds, where the paragraph default lands), and 2.5s or more becomes
  `[long pause]` (several seconds, for a deliberate reflective stop)
- A marker on its own line between two paragraphs replaces that paragraph
  break's default pause instead of adding a second pause:
  ```csv
  mystery_name,content
  The Annunciation,"Paragraph one.

  {pause:2.5}

  Paragraph two, reached after a 2.5s pause instead of the default."
  ```
- Markers are stripped before the meditation is saved; their positions are
  stored separately and used again by `mix lumen_viae.regenerate_audio`
- Malformed markers (e.g. `{pause:abc}`) and literal `<break` tags are
  rejected at validation, so run a dry run to catch them

### Regenerating Audio

To apply new pause logic, a new model, or a new voice to already-imported
meditations without re-importing, regenerate their audio in place. The S3
objects are replaced under their voice keys, the narration records are
updated, and no meditation rows are created or modified:

```
mix lumen_viae.regenerate_audio --set "Set Name" --dry-run
mix lumen_viae.regenerate_audio --set "Set Name"
mix lumen_viae.regenerate_audio --id 42
mix lumen_viae.regenerate_audio --all --voice female --only-missing
```

`--voice` limits the run to one voice (repeatable; every configured voice
otherwise), and `--only-missing` skips recordings that already exist, so an
interrupted run can be resumed without paying ElevenLabs twice. The admin
dashboard's "Meditations missing a voice" check counts what `--all
--only-missing` would fill in.

Always dry-run first: it lists each recording with its pause plan and
spends no ElevenLabs credits. On Fly:

```
fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.regenerate_audio(set: \"Set Name\")'"
fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.regenerate_audio(all: true, voices: [\"female\"], only_missing: true)'"
```

### The voice layout, and the one-time move into it

Before voices, each meditation's `audio_url` was the whole S3 key of its
one recording - a root-level object such as `Glorious-Fulton-1.mp3`. It is
now the *filename*, and every voice's object sits at
`voices/<voice>/<filename>`. The migration that created the narrations
table recorded every existing recording as the `male` voice at its new
key; the objects are moved there (server-side copies, originals left in
place) by:

```
fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.copy_narration_to_voice_prefix()'"
```

It is idempotent - re-run it after any failure - and reports a meditation
whose original object is missing as a warning. Once the new keys have been
verified to play, the root-level originals can be deleted by hand.

### Requirements for Audio Generation

To enable audio generation, ensure the following environment variables are configured:

- `ELEVEN_LABS_API_KEY` - Your ElevenLabs API key (the voices and model are
  set in `config/config.exs`)
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
- `AWS_S3_BUCKET` - Your S3 bucket name (defaults to lumenviae-audio)
- `AWS_REGION` - AWS region (defaults to us-east-2)

### Audio Processing During Import

- Audio generation happens during the CSV import process
- Each meditation with an audio_filename will trigger one API call to
  ElevenLabs per configured voice
- Synthesis takes roughly 10-60 seconds per meditation; the client waits up
  to 2 minutes per attempt before treating the request as timed out
- Transient failures (timeouts, rate limits, ElevenLabs 5xx, S3 hiccups) are
  retried up to 3 times with increasing backoff; permanent failures (bad API
  key, missing AWS credentials, rejected request) fail immediately
- If audio generation or upload still fails for a voice, the meditation is
  still created and the row is reported as a warning naming the voice and
  the reason; when every voice fails it is created without audio
- Success messages will indicate "(with audio)" for meditations that have
  at least one voice recorded
- A failed voice is filled in later with
  `mix lumen_viae.regenerate_audio --all --only-missing`; nothing needs
  re-importing

## Notes

- The CSV file must use comma (`,`) as the delimiter
- Text fields with commas or line breaks should be enclosed in double quotes
- To include a quote character within quoted text, double it: `"He said ""Hello"""`
- The first row must be the header row with column names
- Only one CSV file can be uploaded at a time
- You can import multiple meditations for the same mystery (e.g., different authors or perspectives)
