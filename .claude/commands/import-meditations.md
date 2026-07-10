---
description: Import a meditations CSV with mandatory dry-run first (local or prod)
---

Import a meditations CSV file into LumenViae. Arguments: $ARGUMENTS

The first argument is the CSV path (default: the most recently modified CSV
in priv/repo/imports/). If the arguments include the word "prod", run the
production workflow; otherwise run locally.

CSV content must follow docs/MEDITATION_CURATION_GUIDE.md (verbatim text,
standalone context, paragraph breaks). If a CSV clearly violates it, flag
this to the user before importing.

## Rules (non-negotiable)

1. ALWAYS dry-run before any real import. Never skip this.
2. If the dry run reports any errors, STOP. Report the errors and do not run
   the real import.
3. Before a real import, confirm with the user exactly what will be created
   (rows, set name, audio filenames) and that audio generation will spend
   ElevenLabs credits and upload to the production S3 bucket.
4. Never print secret values. Check presence only (e.g. `env | grep -c KEY`).

## Local workflow

1. `mix compile` - stop on any compilation error.
2. `mix lumen_viae.import <csv> --dry-run` - review output with the user.
3. On explicit user confirmation: `mix lumen_viae.import <csv>`.
4. Report results and remind the user to verify at localhost /admin.

Local runs write to the dev database, but real runs still generate real
audio and upload to the shared S3 bucket. Offer `--skip-audio` if the user
only wants to test database writes.

## Prod workflow

1. Confirm the new import code is deployed; if in doubt, `fly deploy` first
   (ask before deploying).
2. `fly secrets list` - verify ELEVEN_LABS_API_KEY, AWS_ACCESS_KEY_ID, and
   AWS_SECRET_ACCESS_KEY exist (names only).
3. Upload the CSV: `fly ssh sftp shell`, then
   `put <csv> /tmp/<basename>.csv`, then exit.
4. Dry run:
   `fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.import_csv(\"/tmp/<basename>.csv\", dry_run: true)'"`
5. Review dry-run output with the user. On explicit confirmation, run the
   same command without `dry_run: true`.
6. Remind the user to verify at www.lumenviae.org/admin.

Machines auto-stop (min_machines_running = 0): if ssh fails to connect,
start a machine first with `fly machine start`. Steps 3-5 must run against
the same machine since /tmp is per-machine.
