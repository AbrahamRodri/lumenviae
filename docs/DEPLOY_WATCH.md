# Watching a deploy

Every merge to `main` deploys to production (docs/CI.md). Work ships in
batches, and each batch is watched until it is known not to be broken
before the next one starts.

## Before merging

Merge `origin/main` into the batch branch, then start CI on it (docs/CI.md):
the run tests the branch as it is, and branch protection does not ask for
it to be up to date with `main`.

## Right after the deploy

The CI run's last step, "Check production", runs `bin/post-deploy-check`:
`/healthz` (up, database answering, and serving the commit just merged), two calls the iPhone
app makes (`/api/meditation-sets?category=joyful`, `/api/voices`) and the
Android app's daily document polls (`/api/v2/rosary-content`,
`/api/v2/prayer-book`, `/api/v2/consecration`). It retries each for about a
minute, then fails the run. It never rolls anything back. Run it by hand at
any time:

```
bin/post-deploy-check
```

When a batch adds a route the apps will call, add it to the script in the
same batch.

## The watch: 15 to 30 minutes

Read-only, with the agent token (`fly-ro`, or the `lumenviae-prod-logs`
skill). No step here changes production.

1. `fly-ro status --app lumenviae`: one machine, started, on the new
   release; the release number went up by one.
2. `fly-ro logs --app lumenviae --no-tail`, then again every few minutes:
   - no `[error]` lines and no crash reports (`** (`, `GenServer ... terminating`);
   - no run of 500s (`Sent 500`);
   - no `DBConnection` errors: the database is one small machine, and an
     out-of-memory restart looks like a wave of these (docs/PROD_ACCESS.md).
3. `bin/post-deploy-check` once more at the end.
4. For a batch that changed something the apps read, open it on a phone:
   the screens the batch touched load.

Fifteen quiet minutes is enough for a docs or content batch; give a batch
with a migration, a dependency upgrade or new routes the full thirty.

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
