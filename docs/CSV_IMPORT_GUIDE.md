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
  - When provided, the system will automatically generate audio using ElevenLabs API
  - The generated audio will be uploaded to S3 with this filename
  - If audio generation fails, the meditation will still be created without audio

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

**Seven Sorrows:**
- The Prophecy of Simeon
- The Flight into Egypt
- The Loss of Jesus in the Temple
- Mary Meets Jesus on the Way to Calvary
- Jesus Dies on the Cross
- Mary Receives the Dead Body of Jesus in Her Arms
- Jesus is Placed in the Tomb

Note: These names are taken from `priv/repo/seeds.exs`, which is the source
of truth. If a name here ever disagrees with the seeds, trust the seeds (or
better, check the database).

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

When the `audio_filename` column is provided, the system will:

1. Use the meditation content to generate audio via the ElevenLabs text-to-speech API
2. Upload the generated audio to Amazon S3
3. Associate the audio with the meditation for playback during prayer

### Requirements for Audio Generation

To enable audio generation, ensure the following environment variables are configured:

- `ELEVEN_LABS_API_KEY` - Your ElevenLabs API key (the voice ID is set in
  `config/runtime.exs`)
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
- `AWS_S3_BUCKET` - Your S3 bucket name (defaults to lumenviae-audio)
- `AWS_REGION` - AWS region (defaults to us-east-2)

### Audio Processing During Import

- Audio generation happens during the CSV import process
- Each meditation with an audio_filename will trigger an API call to ElevenLabs
- Synthesis takes roughly 10-60 seconds per meditation; the client waits up
  to 2 minutes per attempt before treating the request as timed out
- Transient failures (timeouts, rate limits, ElevenLabs 5xx, S3 hiccups) are
  retried up to 3 times with increasing backoff; permanent failures (bad API
  key, missing AWS credentials, rejected request) fail immediately
- If audio generation or upload still fails, the meditation is created
  without audio and the row is reported as a warning naming the reason
- Success messages will indicate "(with audio)" for meditations that have audio generated
- Re-running a failed row's audio means re-importing that row; delete the
  audio-less meditation first so the import does not create a duplicate

## Notes

- The CSV file must use comma (`,`) as the delimiter
- Text fields with commas or line breaks should be enclosed in double quotes
- To include a quote character within quoted text, double it: `"He said ""Hello"""`
- The first row must be the header row with column names
- Only one CSV file can be uploaded at a time
- You can import multiple meditations for the same mystery (e.g., different authors or perspectives)
