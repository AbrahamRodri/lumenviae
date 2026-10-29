# Watching a deploy

Every merge to `main` deploys to production (docs/CI.md). Work ships in
batches, and each batch is watched until it is known not to be broken
before the next one starts.

## What production must do

What the iPhone and Android apps depend on, and how `bin/prod-feature-check`
proves each one, the way the apps call it:

| Feature | Checked by |
| --- | --- |
| Up, database answering, serving the commit just merged | `/healthz` |
| Today's mysteries, the schedule, the mysteries and categories, the streak milestones | `/api/v2/rosary-content` with those sections |
| Meditation sets by category (iPhone) | `/api/meditation-sets?category=` for the four categories |
| A set's meditations, with a signed audio link that opens | `/api/meditation-sets/:id`, then a one-byte GET of the first link |
| Refreshing one meditation's audio link (iPhone) | `/api/meditations/:id/audio`, and the link opens |
| A set's meditations and narrations (Android) | `/api/v2/meditation-sets/:id?include=...`, and a narration opens |
| Artwork | a set's `image_url` opens as an image |
| Narration voices | `/api/v2/voices` (a default voice) and `/api/voices` |
| The spoken Rosary | `/api/v2/rosary-audio?voice=`, and a clip opens |
| The Prayer Book with its orders of prayer | `/api/v2/prayer-book`: 100+ prayers, 11 orders, 4 songs to Mary, every order's prayers present |
| The Chant Library | `/api/v2/chant-library`, and a recording opens |
| The Consecration, True Devotion, St. Carlo Acutis, the Marian Library, Spiritual Reading | each document with its sections non-empty (34 Consecration days; every book has a Gutenberg number and a chapter pattern) |
| The Divine Office | today's day and Lauds in v2, and v1 `/api/office/<today>` |
| The admin console | `/admin/login` answers with a password field |
| The website | `/` answers |
| Recording a finished Rosary | **not checked**: `POST /api/v2/completions` has no dry run, and a check must not record one |

It only reads: GETs, and a one-byte ranged GET of one audio file, one
image and one chant to prove the links open. It never writes, records or
generates anything, ElevenLabs included. Each feature prints `ok` or
`FAIL <why>` on one line, and any failure exits non-zero.

```
bin/prod-feature-check                    # about ten seconds
EXPECT_COMMIT=<sha> bin/prod-feature-check  # and /healthz must serve <sha>
```

When a batch adds something the apps depend on, add it to the table and to
the script in the same batch.

## Before merging

Merge `origin/main` into the batch branch, then mark the PR ready for
review, which runs CI on it (docs/CI.md). Wait for that run to finish, with
its jobs actually run, before merging: while the PR was a draft its checks
were skipped, and a skipped check counts as passing. The run tests the
branch as it is, and branch protection does not ask for it to be up to
date with `main`, so merge `main` in first.

## Right after the deploy

The deploy job's last two steps check production with the merged commit
expected on `/healthz`: `bin/post-deploy-check` (up and the launch calls,
retrying for about a minute while the new machine settles), then
`bin/prod-feature-check` (every feature above). A failure marks the run
red. It never rolls anything back.

## The status endpoint

`GET /ops/status` is a deeper look for an agent or a person: the release
and commit, the database, whether S3 signs a link and reaches the audio
bucket, the Office engine, geolocation, whether an ElevenLabs key is set
(never called), every job queue's counts by state and the ten most recent
failed jobs (worker, queue, state, the first line of the error). It names
no key, URL or argument.

It answers only `authorization: Bearer <OPS_STATUS_TOKEN>`; without the
variable set, or with a wrong token, it is a 404. Seats cannot set Fly
secrets, so Abraham sets it once, and the same value for the scheduled
check. `fly secrets set` restarts the app on a new release, so run it when
a restart is fine (or add `--stage`, and the next deploy picks it up).
The `gh` half runs as the personal account, since the active one cannot
reach this repo:

```
TOKEN=$(openssl rand -hex 32); fly secrets set OPS_STATUS_TOKEN=$TOKEN --app lumenviae && GH_TOKEN="$(gh auth token --user AbrahamRodri)" gh secret set OPS_STATUS_TOKEN --repo AbrahamRodri/lumenviae --body "$TOKEN"
```

`bin/prod-feature-check` reads it when `OPS_STATUS_TOKEN` is in its
environment and fails on any check in `error`; without it, it says it
skipped it.

## Three times a day, unattended

`.github/workflows/prod-check.yml` runs `bin/prod-feature-check` at 06:00,
12:00 and 18:00 UTC, and can be started by hand. A failure fails the run,
and GitHub emails the repository's owner. It reads production only.

## The watch: 15 to 30 minutes

Read-only, with the agent token (`fly-ro`, or the `lumenviae-prod-logs`
skill). No step here changes production.

1. `fly-ro status --app lumenviae`: one machine, started, on the new
   release; the release number went up by one.
2. `fly-ro logs --app lumenviae --no-tail`, then again every few minutes.
   Each request is one line, `request method= path= status= duration_ms=`,
   and every failure is an `[error]` line:
   - `fly-ro logs --app lumenviae --no-tail | grep '\[error\]'`: nothing
     new. The kinds: `request ... status=5xx`, `request_failed` (a request
     that raised, with its exception), `job_failed` (a job attempt, with its
     worker, attempt and error), and crash reports (`** (`,
     `GenServer ... terminating`).
   - `... | grep 'status=5'`: no run of 5xx.
   - `... | grep -E 'duration_ms=[0-9]{4,}'`: no request taking a second or
     more, beyond the Office's first fetch of a day.
   - no `DBConnection` errors: the database is one small machine, and an
     out-of-memory restart looks like a wave of these (docs/PROD_ACCESS.md).
3. `bin/prod-feature-check` once more at the end (with the token, if you
   have it).
4. For a batch that changed something the apps read, open it on a phone:
   the screens the batch touched load.

Fifteen quiet minutes is enough for a docs or content batch; give a batch
with a migration, a dependency upgrade or new routes the full thirty.

Fly's own metrics (requests, response times, memory) are on the app's
Metrics tab in the Fly dashboard, free, through Abraham's login; the agent
token cannot read them.

## When it is broken

Fix forward when the cause is clear and small: the fix goes through the
same PR, CI and deploy as anything else. Otherwise roll back at once.

**Roll back by reverting the merge on `main`.** The revert is the new tip,
and CI deploys it like any other commit (docs/CI.md, "The deploy only ever
moves forward").

1. Find the last good merge: `git log --first-parent --oneline origin/main`;
   the one before the batch's merge commit.
2. Revert the batch's merge commit on a branch and open a PR:
   `git revert -m 1 <merge sha>`.
3. Run CI on the branch, merge it, and watch that deploy too.

A revert does not undo a migration. If the batch migrated the database,
check the revert still runs against the new schema before merging it; if it
does not, fix forward instead.

**An image rollback is Abraham's, never a seat's** (seats have no Fly write
access). To put the previous release back without waiting for CI, he would
run, from his own login:

```
fly releases --app lumenviae --image   # the last good release's image
fly deploy --app lumenviae --image <that image>
```

`main` then still holds the broken commit, so revert it on `main` as well,
or the next deploy brings it back.
