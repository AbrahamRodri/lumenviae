# Ash audit and package roadmap

A read-only audit of the three Ash domains (`LumenViae.Rosary`,
`LumenViae.Office`, `LumenViae.Accounts`), of the code merged in #40 to
#44, and a survey of the Ash ecosystem. The first pass was taken on
3 October 2026 against `e45e77e`, the head of the admin accounts and
policies work. It was refreshed the same day against `main` at `b229436`,
after #40 to #45 had merged and deployed. Each finding names the file and
line it was read at, says what is wrong, and sketches the fix. One finding
(A2) has been fixed since, in #47; nothing else has changed in code. Part C
turns the findings and the packages into workstreams, each sized for one
session.

Line numbers are those of `b229436` and will drift; search for the
function or action named beside them.

## Contents

- [Summary](#summary)
- [Part A: audit findings](#part-a-audit-findings)
  - [Authorization and accounts](#authorization-and-accounts)
  - [Queries and growth](#queries-and-growth)
  - [Data integrity](#data-integrity)
  - [Background jobs (#41, #43)](#background-jobs-41-43)
  - [Rate limiting (#42)](#rate-limiting-42)
  - [The v2 JSON:API (#44)](#the-v2-jsonapi-44)
  - [CI and deploys (#40)](#ci-and-deploys-40)
  - [Security headers](#security-headers)
  - [Operations](#operations)
  - [The Ash way](#the-ash-way)
  - [The Office domain](#the-office-domain)
  - [The boundary test](#the-boundary-test)
  - [Stale documentation](#stale-documentation)
  - [Checked and correct](#checked-and-correct)
- [Part B: packages](#part-b-packages)
- [Part C: workstreams](#part-c-workstreams)

## Summary

### Top five next workstreams

Merge #47 first: it fixes A2, the one confirmed security defect, and is
ready.

1. **CI deploy safety** (C1-C4; S; Sonnet 5.5, high). Re-running a failed
   check on an older `main` run deploys that older commit over a newer
   one, after the newer one's migrations have run. One guard step closes
   it. [Workstream 1](#1-ci-deploy-safety).
2. **Public API edges** (R1, R2, R4, V1-V5; S-M; Opus 5.5, high). An IPv6
   caller gets a fresh completion budget on every request, and one v2 GET
   returns the whole catalogue with every recording signed.
   [Workstream 2](#2-public-api-edges).
3. **Completion analytics in the database** (Q1-Q3, Q7; M; Opus 5.5,
   high). The dashboard reads the whole completions table in Elixir, twice
   per visit. Grouped queries, not a rollup table.
   [Workstream 3](#3-completion-analytics-in-the-database).
4. **Identities, an atomic import row and job ownership** (D1-D3, J3, J6;
   M; Opus 5.5, xhigh). A reused audio filename now leaves a meditation
   silently without narration, and a failed attach orphans a meditation
   whose paid narration jobs are already queued.
   [Workstream 4](#4-identities-an-atomic-import-row-and-job-ownership).
5. **A Content-Security-Policy** (H1; M; Opus 5.5, high). No page sends
   one, the console included; it is Sobelow's one real high-confidence
   finding. [Workstream 5](#5-a-content-security-policy).

### Since the first pass

- **A2 is confirmed and fixed** in #47: a trailing slash or a doubled
  slash took a sign-in past the throttle.
- **AshOban, AshRateLimiter and AshJsonApi are adopted** (#41 and #43,
  #42, #44). Part B records them as adopted; their risks are findings
  J1-J8, R1-R4 and V1-V5.
- **Narration is durable** since #43: one Oban job per (meditation,
  voice), unique by S3 key, retried, paid once, followed over PubSub. The
  import's row writes still run in the admin's LiveView process.
- **No other first-pass finding was fixed by the merges.** D2 and D3 now
  matter more, because narration is queued rather than generated inline.
- **A1 was a recorded decision**, which the first pass missed: a test
  keeps REST accepting hidden sets on purpose. It stays a decision for the
  owner, now with the iOS app's behaviour as evidence.

### What needs work, in order

1. **The completion analytics read whole tables into memory**, and the
   completion reads are not paginated. It is the one table that grows
   with traffic, and the dashboard pays for it twice on every visit.
2. **The merged packages left edges**: a re-run that deploys an older
   commit (C1), the completion limit keyed on the full IPv6 address (R1),
   the catalogue in one v2 GET (V1), a deploy that kills a paid recording
   mid-request (J1), and a dev database sync that runs production's job
   queue (J2).
3. **Two missing identities** (set name per category, audio filename),
   which the import now relies on more than before (D1, D2, J3).
4. **The import is half durable.** Narration survives a closed tab or a
   deploy; the row writes do not (`import.ex:109`, `start_async`).
5. **No Content-Security-Policy**, anywhere (H1).
6. **The boundary test has blind spots**, several documents describe the
   app as it was before the Ash port, admin accounts or the jobs, and
   docs/ASH_MIGRATION.md is due for removal.

Decisions needed from the owner, in Part C's
[decisions list](#decisions-and-owner-steps): A1, A6 (V4 waits on it), and
four production steps no worker can take.

## Part A: audit findings

Severity: **High** is a defect that costs correctness, privacy or
availability today; **Medium** is one that will, or that leaks a little;
**Low** is tidiness or hardening.

### Authorization and accounts

**A1. Low (owner decision): REST completions are recorded against hidden
sets.** `create :record` (`lib/lumen_viae/rosary/completion.ex:175`),
used by `POST /api/completions`
(`lib/lumen_viae_web/controllers/api/completion_controller.ex:46`) and the
website's prayer page (`lib/lumen_viae_web/live/pray/index.ex:384`), has
no `validate SetIsVisible`. `:record_from_app` (line 197) has it (line
218, `before_action?: true`), and both GraphQL and `POST /api/v2/completions`
(`rosary.ex:186-190`) use that action. On REST a missing set answers 422
and a hidden set 201, so an anonymous caller can tell a hidden set's id
from a missing one, and add rows to a hidden set's analytics.

This is deliberate and tested.
`test/lumen_viae/rosary/completion_recording_test.exs:78-86` keeps REST
accepting a hidden set, so that a set downloaded for offline prayer and
hidden since still counts. The first pass missed that test and rated the
finding Medium.

What the iOS app does with a refusal, in its current source (`ios/app` at
`23ee536`): finishing a Rosary calls `try? await viewModel.recordCompletion()`
in a detached `Task` (`app/Views/Prayer/MysteryPrayerView.swift:1265`).
The view model sends at most once (`app/ViewModels/PrayerSessionViewModel.swift:788`).
There is no offline queue. `APIService.send` throws on any non-2xx
(`app/Services/APIService.swift:255-270`), and the `try?` discards it.
Only GETs retry, and only on connection errors. So a 422 neither breaks the
app nor loops: the completion is simply not counted. Older shipped builds
were not checked here.

Recommendation: refuse. Add `validate SetIsVisible` to `:record`, turn the
test round to expect the 422, add a REST test beside
`error_envelope_test.exs`, and record the refusal in
docs/IOS_API_CONTRACT.md. The cost is that a prayer of a since-hidden set,
downloaded for offline use, no longer counts. The leak it closes is small
too: set ids are sequential, and a hidden set reveals only that it exists.
Both sides are small, so the owner decides.

```elixir
create :record do
  # ...
  validate SetIsVisible, before_action?: true
end
```

**A2. High (confirmed; fixed in #47): the sign-in throttle matched the
literal request path.** `lib/lumen_viae_web/plugs/throttle_sign_in.ex:64`
matched `request_path: "/admin/auth/admin/password/sign_in"`, but the
router matches on `path_info`, which drops empty segments. A test that
posts through the router, with the email's budget already spent, signed in
with the right password at `/admin/auth/admin/password/sign_in/`,
`/admin//auth/admin/password/sign_in` and
`/admin/auth/admin/password//sign_in/`. None of those attempts was counted,
so guesses sent that way were unlimited, and each one ran bcrypt on a
shared-CPU machine. #47 matches on `path_info`, as the router does, and
adds the three tests. A percent-encoded segment (`sign%5Fin`) is not a
bypass: AshAuthentication's strategy router answers it 404.

**A3. Low: the session cookie is not `secure`, and SSL is not forced.**
`lib/lumen_viae_web/endpoint.ex:7-12` sets no `secure: true`, and
`force_ssl` is only the generator's comment in `config/runtime.exs:206-212`.
Fly's `force_https` redirects, but a first plain-HTTP request still
carries the admin cookie. Set `secure: true` in production (runtime
session options) and `force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto]]`
on the endpoint. TLS ends at Fly's proxy, so without `rewrite_on` every
request would redirect to itself.

**A4. Low: expired tokens are never deleted.**
`lib/lumen_viae/application.ex` starts Hammer and Oban (line 24) but not
`{AshAuthentication.Supervisor, otp_app: :lumen_viae}`, so `Token`'s
`:expunge_expired` (`accounts/token.ex:76`) never runs, and `admin_tokens`
(revocations included, and the dev sign-in's row per request) only grows.
Add the supervisor; it is the package's own way. An AshOban scheduled
action on `Token` would also work now that Oban runs.

**A5. Low: an open console socket outlives its token.**
`lib/lumen_viae_web/live/user_auth.ex` checks the token on mount only
(lines 26, 30). Sign-out and password changes close open sockets; a
seven-day expiry does not. Schedule a disconnect for the token's `exp` on
mount, alongside the existing `AdminSockets` broadcast.

**A6. Low (owner decision): any non-archived meditation is publicly
readable**, including one in no visible set, and so is its audio
(`meditation.ex:220-222`, `GET /api/meditations/:id/audio`). #44 added a
batch form: `POST /api/v2/meditations/audio` signs up to 200 ids per call
(V4). This matches the policy table and is tested. If unpublished
meditations should stay private, the policy becomes
`authorize_if expr(is_nil(archived_at) and in_a_visible_set?)`, and the
audio paths and the iOS contract need rechecking.

**A7. Low (hardening): `Admin.hashed_password` has no field policy**
(`accounts/admin.ex:168`). It is sensitive and not public, but an admin
actor can read it, so it shows in AshAdmin. A `field_policies` block that
lets only `AshAuthenticationInteraction` read it removes it from every
surface. /api/v2 does not expose it: its router serves only the Rosary
domain. See also J5.

### Queries and growth

**Q1. High: the dashboard counts completions in Elixir, twice per
visit.** In `lib/lumen_viae/rosary.ex`, `completion_locations/2` (line
1126) reads every completion in the window and folds it with
`Enum.frequencies_by`; `completions_by_day/2` (line 1231) reads every row
to draw a 30-point chart; `count_sets_completed_in_range/3` (line 1212)
reads every `meditation_set_id` and takes `Enum.uniq_by |> length`.
`lib/lumen_viae_web/live/admin/dashboard/dashboard.ex` calls them (lines
98-114) from `load/1`, which `mount` runs (line 37) with no
`assign_async`, so every figure is computed on the dead render and again
on connect. The cost grows linearly with traffic. #41 and #44 added no bulk
completion reads.

- Distinct sets is an aggregate today:
  ```elixir
  query
  |> Ash.aggregate!({:sets, :count, field: :meditation_set_id, uniq?: true}, opts)
  ```
- Ash has no GROUP BY. The per-day and per-place counts become generic
  actions on `Completion` whose `run` executes one grouped query, so the
  SQL stays inside the resource that owns the table:
  ```elixir
  action :daily_counts, {:array, :map} do
    argument :since, :utc_datetime, allow_nil?: false
    run LumenViae.Rosary.Completion.DailyCounts
  end
  ```
  ARCHITECTURE.md should name this as the one sanctioned use of an
  Ecto query in the domain. Days are Central-time buckets computed by hand
  (`central_time.ex`; the app has no tz database), so the query must
  bucket exactly as the Elixir code does today.
- Load the figures with `assign_async`, once, on connect.

A nightly rollup table is premature: "today" cannot be rolled up, the
rolling 24-hour `days_ago` windows do not align with daily buckets, and
the place lookup fills places in after the fact.

**Q2. High: no read is paginated, `Completion`'s included.**
`completion.ex:146` (`defaults [:read, :destroy]`), `:in_range` (148) and
`:recent` (163, which limits by hand). AshAdmin at `/admin/data` browses
the primary read, so opening completions there loads the table.
Pagination must stay optional (`required?: false`), because AshOban's
`:locate` worker reads through the primary read (policy at line 253).

```elixir
read :read do
  primary? true
  pagination keyset?: true, offset?: true, required?: false, default_limit: 50
end
```

The four PaperTrail version tables grow too, and `version_source_id` has
no index (`priv/repo/migrations/20261001163951_add_paper_trail_versions.exs:15,31,47,63`).
Lower priority, since only admins read them. `oban_jobs`, the newest
growing table, is pruned after seven days (`config/config.exs:186`).

**Q3. Medium: `get_completions_by_set/1` filters, sorts and limits in
Elixir** (`rosary.ex:1070`). It loads every set with its
`completion_count`, rejects zeros, sorts, and the dashboard takes six.
Make it a read on `MeditationSet` that filters on
`completion_count(since:, until:) > 0`, sorts on the same calculation and
takes `limit: 6`. A composite index on `rosary_completions
[:meditation_set_id, :completed_at]` serves the filtered count; there is
none today (`completion.ex:102-110`). The same "load all, reject zeros"
shape is in `meditation_set_stats/1` (965), `mystery_counts/2` (910) and
`meditation_set_counts_by_author/1` (690). Those tables are small, but
the fix is a one-line filter.

**Q4. Medium: `meditation_narrations/2` hides a query per meditation**
(`rosary.ex:479`). When `:narrations` is not loaded it reads them, so a
loop over unloaded meditations is an N+1 with no warning. Its one caller
that reaches the fallback (`live/meditations/list/row/row.ex:191`) passes
no options, so that read also runs without the actor: the Narration read
policy then hides an archived meditation's recordings even from an admin.
Drop the fallback (raise on `%Ash.NotLoaded{}`) and load `:narrations`
with the actor at the call site.

**Q5. Low: `record_narration/4` re-reads narrations on every call**
(`rosary.ex:448`). Since #43 its only caller is `NarrateMeditation`
(`curation/jobs/narrate_meditation.ex:122`), which discards the result.
It also checks the voice slug in Elixir. Return the narration, and move
the check to a validation on `Narration`'s `:record` action.

**Q6. Low: over-loaded reads filtered in Elixir.**
`lib/lumen_viae/curation/audio_regeneration.ex:89-91` reads
`list_meditations!` (mystery and narrations for every row), then rejects
archived ones and re-sorts by id, which `:detailed` already does;
`narration_relocation.ex:37-39` rejects blank `audio_url` the same way.
Add a `read :active_with_audio` with
`filter expr(not archived? and has_audio?)`. The set new and edit pages
(`sets/new/new.ex:9`, `sets/edit/edit.ex:15`) read `:detailed` and load
narrations they never show. `get_meditation_set` (`rosary.ex:279-282`)
defaults to loading `:meditations`, and its only caller
(`sets/list/list.ex:62`) loads the set to delete it.

**Q7. Low: `completion_summary/1` runs seven count queries**
(`rosary.ex:1197`). Indexed and acceptable; one `Ash.aggregate` call with
filtered counts makes it one.

### Data integrity

**D1. Medium: nothing makes a set name unique within its category.**
`MeditationSet` has no identity on `[:name, :category]`, and
`get_meditation_set_by_name/3` (`rosary.ex:657`) uses `Ash.read_one!`.
A duplicate pair would make the CSV import (`csv_import.ex:621`) raise
rather than report the row.

```elixir
identities do
  identity :unique_name_per_category, [:name, :category]
end
```

Check production for existing duplicates before `mix ash.codegen`.

**D2. Medium: nothing makes an audio filename belong to one meditation,
and since #43 a clash is silent.** `meditations.audio_url`
(`meditation.ex:256`) decides the S3 key for every voice. The import now
writes a meditation with a blank `audio_url`, and `NarrateMeditation`
sets it when the first recording lands (`narrate_meditation.ex:144-149`).
Jobs are unique by S3 key, so a second meditation with the same filename
gets `:already_queued` and is never recorded (J3), and one queued after
the first job finished re-records over it, paying again.

```elixir
identity :unique_audio_url, [:audio_url],
  where: expr(not is_nil(audio_url) and audio_url != "")
```

The partial unique index also serves the `:with_audio_filenames` filter
(line 112). Once it exists, a failed `ensure_audio_url` should cancel the
job rather than retry it to `max_attempts`.

**D3. Medium: an imported row is four writes, the next order is racy,
and a failed attach now strands paid jobs.** `csv_import.ex:688-764` runs
`create_meditation`, an `Oban.insert` per voice (`queue_narration`, line
711), `next_order_in_set` (a separate max query) and
`add_meditation_to_set`, independently. Two imports into one set can read
the same max and trip `unique_order_per_set`. The first pass's fix rested
on "audio is generated before these writes", which #43 changed: the jobs
are queued before the attach, so a failed attach orphans a meditation
whose narration jobs are already queued and will be paid for. Make it a
`create :import` on `Meditation` taking `set_id` and an optional `order`,
creating the membership in an `after_action` with the order computed
there, and insert the jobs inside the same transaction (Oban writes to
the same Repo, so a rollback drops them) or in an `after_transaction`.
With `--skip-audio`, rows can go through `Ash.bulk_create`.

### Background jobs (#41, #43)

#41 put the place lookup on an AshOban trigger and mounted Oban Web at
`/admin/jobs`; #43 made narration and the spoken Rosary plain Oban
workers. Both are careful (see "Checked and correct"); these are the
edges.

**J1. Medium: a deploy during a recording run pays ElevenLabs twice.**
`fly.toml` sets no `kill_timeout`, so Fly kills a machine a few seconds
after `SIGTERM`, before Oban's 15-second default `shutdown_grace_period`
has run out, and an ElevenLabs request takes 10 to 120 seconds. A
recording in flight at deploy time is killed and left `executing`; the
lifeline frees it after 30 minutes (`config/config.exs:187`), and the
retry finds nothing at the key and records again. `recording.ex:38-42`
and `docs/ARCHITECTURE.md:570` call the window "a second or two"; it is
the whole request. Every merge deploys, and the spoken-Rosary workflow
in CLAUDE.md puts recording runs next to deploys.

- Set `kill_timeout = 150` in `fly.toml` and
  `shutdown_grace_period: :timer.seconds(140)` in the Oban config.
- Treat an attempt that vanished without an error as possibly billed:
  the lifeline adds no error when it rescues a job.
  ```elixir
  orphaned? = job.attempt - 1 > length(job.errors)
  # orphaned and no upload of ours at the key ->
  {:cancel, "previous attempt was killed mid-request and may be billed"}
  ```

**J2. Medium: `sync_prod_db.sh` copies production's job queue into
dev.** The `pg_dump` (`sync_prod_db.sh:113`) excludes nothing, so it now
carries `oban_jobs` and its sequence. `./dev.sh` runs both queues, so dev
executes every job that was waiting, retryable or executing in production
when the dump was taken, and production runs the same jobs: both pay.
After a restore, dev job ids continue production's sequence, and
`already_right?/4` (`recording.ex:111`) accepts any object tagged with
the same job id without checking the fingerprint, so a production job
could adopt a clip a dev job recorded from locally edited text. Whether
dev's `.env` points at the production audio bucket was not confirmed.

```bash
--exclude-table-data=oban_jobs --exclude-table-data=oban_peers
```

and require the fingerprint on an own-job match:

```elixir
defp already_right?(%{"job" => j, "fingerprint" => f}, j, f, _opts), do: true
```

**J3. Medium: narration is claimed for the wrong meditation when a
filename is reused.** `AudioJobs.enqueue/2` (`curation/audio_jobs.ex:71-79`)
returns `{:ok, :already_queued}` for any conflict on the S3 key, without
asking which meditation the queued job belongs to, and the import reports
it as "narration queued" (`csv_import.ex:711-730`). The preview's
duplicate-filename check (`csv_import.ex:441`) reads only `audio_url`,
which is blank until a recording lands, so it cannot see filenames whose
jobs are still queued. Scenario: an admin stops an import, corrects the
CSV and imports again. No overwrite warning; the new rows' jobs merge
into the old rows' jobs, which record the old text and set `audio_url` on
the old meditations; the corrected ones never get audio, and nothing
says so. `csv_import.ex:40` says `--only-missing` fills such gaps later,
but regeneration skips a meditation with no `audio_url`
(`docs/CSV_IMPORT_GUIDE.md:411`). Fix: have `enqueue/2` return the
conflicting job and treat a different `args["meditation_id"]` as an
error; add pending `NarrateMeditation` filenames to the preview's taken
set; keep the intended filename durably even when every voice fails. D2's
identity is the database half of the same fix.

**J4. Low: a failed place lookup is never retried.**
`Geolocation.locate/1` (`services/geolocation.ex:96-105`) turns every
failure (timeout, 429, 5xx) into `nil` and caches it for 24 hours per
network prefix, so `:add_place` succeeds with nothing changed and
`max_attempts 3` (`completion.ex:135`) never applies. Stamp's moduledoc
("retries a failure", `stamp.ex:29-30`) is wrong. Once ipapi.co's daily
quota runs out, every prefix asked about after that stays placeless.
Return `{:error, :transient}` without caching it, and let `LookUpPlace`
(`look_up_place.ex:28-33`) add an error so Oban retries with backoff.

**J5. Low: the whole admin record goes into Oban Web's page.**
`ObanResolver.resolve_user/1` (`lib/lumen_viae_web/oban_resolver.ex:21`)
returns `conn.assigns[:current_admin]`, and Oban Web puts it in its
LiveView session, which is signed into `data-phx-session` but not
encrypted. The `Admin` struct, `hashed_password` included, is readable by
any script on that page. The viewer is always that admin, so exposure is
limited.

```elixir
def resolve_user(conn) do
  with %{} = admin <- conn.assigns[:current_admin],
       do: %{id: admin.id, email: to_string(admin.email)}
end
```

**J6. Low: a database hiccup cancels narration jobs as "meditation no
longer exists".** `narrate_meditation.ex:97-101` turns any `{:error, _}`
from `get_meditation` into a permanent cancel, including a dropped
connection (production's database is known to drop them). Nothing is
spent, but for a fresh import there may be no way back (J3). Cancel only
on `Ash.Error.Query.NotFound`; return `{:error, reason}` otherwise. Not
confirmed for the proxy-drop case.

**J7. Low: the spoken-Rosary run can crash partway (not confirmed).**
`curation/rosary_audio_generation.ex:68-71, 165`: up to 16 tasks each
HEAD S3 and then enqueue, through the two-connection pool `with_repo`
gives a release task, each with a 60-second timeout. A slow HEAD or a
pool checkout can take down `Task.async_stream` and the run with it.
Re-running is safe. Do the HEADs concurrently, enqueue one at a time in
the caller, and set `on_timeout: :kill_task`.

**J8. Low: words that no longer match the code.**
`docs/ARCHITECTURE.md:608` and `config/config.exs:163` say geolocation
runs one lookup at a time; queue limits are per machine, so it is two.
The "Stop import" confirmation (`import.html.heex:298`) does not say that
narration jobs already queued keep running and spending. A `force`
regeneration is merged into a job already waiting for the same key, so no
second take happens. `lumen_viae.import` and `lumen_viae.regenerate_audio`
tell you to export `DATABASE_URL`, which `config/dev.exs` ignores (older
than #43).

### Rate limiting (#42)

**R1. Medium: an IPv6 caller gets a fresh completion budget on every
request.** The key is the full address (`lib/lumen_viae/limits.ex:43`,
`completion/rate_limit.ex:46-52`), and
`test/lumen_viae_web/completion_rate_limit_test.exs:226` pins that.
Anyone with an IPv6 /64, which most VPSs and many home lines have, can
send each request from a new address and record unlimited completions:
rows in the 256MB database, noise in the analytics, and an ETS key per
request held for an hour. `NotAutomated` reads only the user agent, so it
is no backstop. Key IPv6 on its /64 (or /56). Honest use sits far below
the limit, so a site-wide ceiling is cheap too. The sign-in throttle's address
budget has the same weakness; its per-email budget still holds.

**R2. Low: `Fly-Client-IP` is trusted from any peer.**
`lib/lumen_viae_web/client_ip.ex:40-45`, with the endpoint on `::`
(`config/runtime.exs:172`). A request over Fly's private network
(`lumenviae.internal:8080` from another app in the organisation, such as
a self-hosted Divinum Officium) bypasses the proxy and can claim any
address. For public traffic, safety rests on Fly overwriting the header,
which the code cannot show. Trust the header only from the proxy's
address, once it is known how the proxy appears as the peer.

**R3. Low (accepted): counters are per machine and reset on restart**
(`lib/lumen_viae/hammer.ex:9-19`). Two machines make the real ceiling 40
an hour, and every deploy wipes the counters. Documented and accepted;
listed for completeness.

**R4. Low: a 429 carries no `Retry-After`**
(`controllers/api/fallback_controller.ex:52-56`, `limits.ex:88-101`).
Hammer already returns the time left in the window. The app ignores 429s,
but a client generated from the v2 document could honour it. Adding a
header is additive to the iOS contract.

### The v2 JSON:API (#44)

**V1. Medium: one GET returns the whole catalogue.** The list route is
`paginate? false` (`rosary.ex:127-133`), and the includes allowed on
`MeditationSet` (`meditation_set.ex:108`) apply to the list too. So
`GET /api/v2/meditation-sets?include=set_memberships.meditation.mystery&fields[meditation]=title,content,narrations`
returns every visible set, membership, meditation text and mystery, with
every recording signed, uncached and unlimited. v1's list returns sets
only, and GraphQL caps cost at `max_complexity 500` (`router.ex:243-244`).
The size is bounded by the catalogue (hundreds of rows), so this is a
load multiplier rather than an unbounded query, but a modest loop ties up
the pool against the one 256MB Postgres. Not measured. Refuse `include`
on the list route with a plug in the `:json_api` pipeline (AshJsonApi 1.7
has no per-route includes), and consider a per-address read limit for
`/api/v2` and `/api/graphql`.

**V2. Low: `/api/v2/docs` runs a third-party script on the console's
origin.** `router.ex:250-252` serves OpenApiSpex's Swagger UI, which loads
swagger-ui from cdnjs with no integrity attribute, in a scope with no
pipeline: no secure headers, no CSP. It shares an origin with `/admin`
and its Lax session cookie, so a compromised CDN script could drive the
console if a signed-in admin opened the page. Make it dev-only, like
`/dev/graphiql`.

**V3. Low: `/api/v2/open_api` rebuilds the document on every request**
(`lib/lumen_viae_web/json_api_router.ex:17-24`): uncached CPU work anyone
can trigger. Serve the committed file
(`open_api_file: Application.app_dir(:lumen_viae, "priv/openapi/v2.json")`);
`open_api_test.exs` still compares the generated document with it.

**V4. Low: batch audio signing reaches unpublished meditations.**
`POST /api/v2/meditations/audio` (`:audio_for`, `meditation.ex:216-221`,
route at `rosary.ex:151-158`) signs any non-archived meditation by id,
200 per call. Ids are sequential, so a few calls sweep paid recordings
that are not yet in a visible set. GraphQL and v1 follow the same rule
one id at a time. This is A6's question; filter on `in_a_visible_set?`
if the owner decides unpublished meditations stay private.

**V5. Low: `sort_included` is honoured, though the docs say sort is
ignored** (not confirmed end to end). AshJsonApi reads the related
resource's `derive_sort` under the wrong key
(`deps/ash_json_api/lib/ash_json_api/request.ex:474`), against
`docs/JSON_API.md:91-94`, so `sort_included[set_memberships]=-order`
should reverse prayer order. Strip `sort_included` and `included_page` in
the pipeline, and test it.

### CI and deploys (#40)

**C1. Medium: re-running an older `main` run deploys a stale commit.**
The `deploy` job (`.github/workflows/ci.yml:182-195`) deploys the commit
its run was started for. Commit A's Test flakes, so A does not deploy; B
merges and deploys; someone then chooses "Re-run failed jobs" on A, as
`docs/CI.md:78-82` says to. A passes and deploys over B: a silent
rollback, with B's migrations already run, so A's code meets a newer
schema. Re-running any older green run does the same. In `deploy`,
compare `github.sha` with `git ls-remote origin refs/heads/main` and skip
unless it is the tip; correct docs/CI.md.

**C2. Low: the deploy runs code from a moving branch.**
`superfly/flyctl-actions/setup-flyctl@master` (`ci.yml:192`) installs the
`flyctl` the next step runs with `FLY_API_TOKEN`; other actions use
movable tags (`ci.yml:47`, `.github/actions/setup-elixir/action.yml:27,36`).
Pin every action to a commit SHA; Dependabot keeps SHA pins current.

**C3. Low: `FLY_API_TOKEN` is a repository secret, not tied to `main`**
(`ci.yml:193-195`). Any branch in the repository (any writer, including
agent sessions with the owner's token) could add a workflow that reads
it; forks cannot. Whether it is an app-scoped deploy token was not
visible. Move it to an `environment: production` limited to `main`,
holding a token from `fly tokens create deploy -a lumenviae`.

**C4. Low: the production build is first tested by the deploy.** Every
job runs with `MIX_ENV: test` (`ci.yml:24-25`), so a fault only in
`prod.exs`, `runtime.exs` or the Dockerfile first shows in
`flyctl deploy`. `fly.toml` has no HTTP health check, and the deploy job
no `timeout-minutes`. Add a `docker build .` job to `needs`, a health
check, and a timeout.

### Security headers

**H1. Medium: no page sends a Content-Security-Policy.** The `:browser`
pipeline (`router.ex:9-23`) uses `put_secure_browser_headers` with no
policy, nothing else sets one, and `/api/v2/docs` has no headers at all
(V2). Sobelow reports it (`Config.CSP`, high confidence), and PR #40's
body confirms it is real; Sobelow runs report-only in CI. There is no
known injection today; a policy is the backstop for the day there is one,
and the console shares the origin. What a policy must allow:

- `script-src 'self'` for `app.js` (both root layouts); AshAdmin
  (`/admin/data`) and Oban Web (`/admin/jobs`) need a per-request nonce,
  which both accept (`ash_admin` takes `csp_nonce_assign_key`).
- `style-src 'self' fonts.googleapis.com` plus, at first, `'unsafe-inline'`:
  39 template lines under `lib/lumen_viae_web` carry `style=` or
  `onclick=`.
- `font-src fonts.gstatic.com`.
- `media-src` for presigned audio from `s3.us-east-2.amazonaws.com`
  (`config/runtime.exs:19`), and `img-src` for artwork from the public
  bucket or `PUBLIC_ASSET_BASE_URL`.
- `connect-src 'self'` and the LiveView websocket.

Ship it as `Content-Security-Policy-Report-Only` first, check every page
(including both library consoles and the prayer page's audio), then
enforce.

### Operations

**OP1. Low (owner step): `ADMIN_PASSWORD` is still set in production**
as a rollback guard. The current release no longer reads it; releases
from before admin accounts sign in with it and fall back to `changeme`
when it is missing. docs/PROD_ACCESS.md:174-184 already says when and how
to unset it. Nobody can see production from here, so this is a deploy
step for the owner, once rolling back past `723d422` is off the table:

```bash
fly secrets unset ADMIN_PASSWORD --app lumenviae
```

Rolling back after that needs a strong `ADMIN_PASSWORD` set first.

**OP2. Low: the repository is not format-clean.** At `b229436`, 26 files
fail `mix format --check-formatted`: 22 `.heex` and 3 `.ex` under
`lib/lumen_viae_web/`, and
`test/lumen_viae_web/live/meditations/sets/edit/labels_section_test.exs`.
That is the count PR #40 reported. CI checks only changed files. PR #40's
body has the plan: on a fresh branch from `main`, run `mix format`,
commit "Format the whole repo", add that commit to
`.git-blame-ignore-revs`, switch the format job to
`mix format --check-formatted`, and set `blame.ignoreRevsFile` locally.
It conflicts with every open branch, so it runs between rounds, when
none is open (workstream 15).

### The Ash way

**W1. Low: four `get_*` defines generate a non-bang read**, against the
"reads are bang-only" rule: `get_mystery`, `get_meditation`,
`get_meditation_set` and `get_author` (`rosary.ex:235, 249, 279, 305`)
lack `functions: @read`. Four callers use the tuple form:
`curation/csv_update.ex:159`, `curation/audio_regeneration.ex:79`,
`curation/jobs/narrate_meditation.ex:98` (new in #43) and
`controllers/api/meditation_controller.ex:58`. Either document the
`get_*` exception in ARCHITECTURE.md, or restrict them and rescue
`Ash.Error.Invalid` in the callers. Naming is also mixed:
`get_completions_by_set` (1070) and `get_recent_completions` (1092)
return lists and raise without a `!`.

**W2. Low: the `require_atomic? false` updates, judged one by one.**

| Action | Line | Judgement |
| --- | --- | --- |
| `Mystery.update` | `mystery.ex:89` | Justified: lets the paper trail skip a version for a save that changes nothing. |
| `Author.update` | `author.ex:92` | Justified, same reason. But `:record_artwork` and `:update_artwork_metadata` are paper-trailed and atomic, so they do version no-op saves. Make the two consistent. |
| `MeditationSet.update` | `meditation_set.ex:230` | Its comment's reason does not hold: `NormalizeLabels` and `ManagedLabels` read only the incoming value. Give each an `atomic/3`, or cite the paper-trail reason instead. |
| `Meditation.update` | `meditation.ex:166` | Acceptable (admin-only, low volume). `ResetStaleAnnotations` could go atomic with an `expr(if content != ^new, ...)`. |
| `Completion.add_place` | `completion.ex:229` | Justified: `LookUpPlace` calls the provider in `before_transaction`. |

**W3. Low: unused or duplicated interface.**
`SetMembership`'s `:in_prayer_order` and `:holding_archived` reads
(`set_membership.ex:80, 85`) are never called, and neither, since #41
replaced it with `:add_place`, is `Completion`'s `:place` (`completion.ex:222`).
`list_visible_meditation_sets_with_meditations` and
`list_visible_meditation_sets_by_category` are one read, since
`:category` is optional. `count_completions_last_days`,
`narration_counts_by_voice`, `meditation_ids_with_narration`,
`count_mysteries` and `count_meditation_sets` are used only by tests and
docs/PROD_ACCESS.md; keep the ones the runbook needs and drop the rest.
`narration_counts_by_voice` counts by loading every narration.

**W4. Low: two numericality validations where one will do**
(`set_membership.ex:107-108`), and the set edit LiveView repeats the 1..7
check (`sets/edit/edit.ex:144`). Merge them into
`validate numericality(:order, greater_than: 0, less_than_or_equal_to: 7)`
and let the form show the action's error.

### The Office domain

`LumenViae.Office` is a real Ash domain: one data-layer-less resource,
`Breviary`, with five generic actions returning `Ash.TypedStruct` types,
Splode errors with AshGraphql messages, and an ETS cache. It is used
well, and unchanged since the first pass. The REST `OfficeController`
calls the domain's plain functions rather than the actions, so REST
bypasses policies and Ash telemetry; the docs say that is deliberate.
/api/v2 does not serve the Office.

**O1. Low: concurrent cold misses all reach the engine**
(`lib/lumen_viae/office.ex:171-177`). A burst for today's hours at
midnight sends one identical request per caller to Divinum Officium.
Serialise misses per key (a per-key lock in the `Cache` GenServer, or
`:global.trans`).

**O2. Low: the Office tests share the global cache.** All three files are
`async: true` and stay correct only because each test uses its own date.
`Cache.reset/0` exists but nothing calls it. Namespace the keys per test,
or make the cache table name configurable.

**O3. Withdrawn.** `:hours` does halt on the first failed hour
(`breviary/read.ex:40`), but docs/GRAPHQL.md:279-280 already says
`officeHours` is all or nothing, and did at the first pass.

### The boundary test

No code outside the domains names a resource, calls `Ash` on one, builds
a form or touches the Repo, and nothing added in #41 to #44 does either:
the jobs go through `LumenViae.Rosary`, the JSON:API router names only the
domain, and the only new Repo use is `curation/audio_jobs.ex` on
`oban_jobs`, which the test allows. But
`test/lumen_viae/rosary/context_rules_test.exs` would not catch some
future violations:

**B1. Medium: aliased names slip through.** Rule 1 (lines 60-62, 177)
matches only the full literal `LumenViae.Rosary.Meditation`, so
`alias LumenViae.Rosary.{Meditation, MeditationSet}` and
`Rosary.Meditation` after `alias LumenViae.Rosary` pass. The web-layer
check has the same blind spot. Also match the brace form and
`Rosary\.<Resource>\b`, excluding `<Resource>\.[A-Z]` so documentation
mentions of submodules (`limits.ex:7`, `services/geolocation.ex:35`) do
not trip it.

**B2. Low: the resource list is incomplete** (line 28): it lacks
`narration_voice`, `spoken_rosary` and the `*.Version` modules (the
lookahead deliberately rejects `Meditation.Version`). The lookahead also
lets through the newer internal modules: `Completion.RateLimit`,
`NotAutomated`, `LookUpPlace`, the generated `Completion.LocateWorker`,
and `Rosary.Errors.AudioUnavailable` and `AutomatedClient`.

**B3. Low: rule 2's regex is narrow** (lines 94-98). It misses
`Ash.read_one`, `Ash.run_action`, `Ash.calculate`, `Ash.aggregate`,
`Ash.stream!`, `Ash.ActionInput`, `Ash.Resource.*`,
`AshPhoenix.Form.for_read`, and now `AshOban.build_trigger` and
`AshOban.run_trigger`. Flag `\bAsh\.[a-z]` and `AshPhoenix\.Form\.for_`
with a short allowlist (`Ash.Error`, `Ash.PlugHelpers`, `Ash.UUID` for
`limits.ex:94`). `require_admin.ex` would then need its dev-only
`Ash.Resource.put_metadata` call allowed by name. Rule 3 allows the whole
of `curation/audio_jobs.ex` (test lines 111-117), so a Rosary query added
to that file would pass; limit the exception to queries on `Oban.Job`.

**B4. Low: nothing enforces the Office rule.** CLAUDE.md and
ARCHITECTURE.md say nothing outside `office/` names its internals, but
the test exempts the Office everywhere. Add a check like the Accounts one
for `LumenViae.Office.[A-Z]`, allowing `application.ex:20` and the
documentation mention in `rosary/errors/audio_unavailable.ex:9`.

### Stale documentation

| Document | What is stale | Fix |
| --- | --- | --- |
| README.md | Says Elixir 1.14+ (line 39) where `mix.exs:8` needs 1.15; describes "one context + schema per resource" (line 73); no Ash, GraphQL, v2, jobs, Office or admin accounts; the docs list (lines 94-99) names 5 of 15 documents, now missing CI.md and JSON_API.md too. | Rewrite the architecture and docs sections to point at ARCHITECTURE.md. |
| docs/API_EXPANSION_PLAN.md | A pre-port status document: "nothing below is deployed", names files and a context rule that no longer exist, and modules never built. | Mark it historical at the top, or delete it. |
| docs/UPCOMING_FEATURES.md (section 5, lines 26-37) | Lists sign-in throttling, failed sign-in logging and credential rotation as open; all three shipped. | Keep only what is still open (MFA, an admin action log beyond PaperTrail); note admin-only accounts shipped and public accounts remain open. Take in ASH_MIGRATION.md's "Left for later". |
| docs/ASH_MIGRATION.md | Due for removal; see below the table. | Delete it. |
| docs/ARCHITECTURE.md:78-81 | "Every table-backed resource also has a version resource": only four do. | Name the four. |
| docs/ARCHITECTURE.md, "Who may do what" (line 173) | Partly fixed: the `authorize?: false` list (220-230) now names the narration jobs and drops Stamp, and an AshOban paragraph was added. It still omits Meditation's `in_any_set?` and `in_a_visible_set?` aggregates (`meditation.ex:350-357`). | Add them. |
| docs/ARCHITECTURE.md, lib tree (lines 35-75) | Worse. Names `rate_limit.ex`, deleted in #42 (now `limits.ex`, `limits/backend.ex`, `hammer.ex`); misses `accounts/`, `ash_opts.ex`, `bot_detection.ex`, `audio/recording.ex`, `curation/audio_jobs.ex`, `curation/jobs/`, `rosary/version_policies.ex`, `rosary/errors/`, `rosary/types/`, `rosary/narration_voice/`, `rosary/spoken_rosary/` and the office files. The web tree (709-715) lacks `graphql/`, `json_api/`, `json_api_router.ex`, `graphql_schema.ex` and `oban_resolver.ex`; its plugs line omits `guard_completions`, `put_client_ip` and `throttle_sign_in`. | Regenerate both trees. |
| docs/ARCHITECTURE.md, "These rules are tested" (lines 161-171) | Worse: says only the Repo module and `release.ex` may use the Repo, but the test also allows `audio_jobs.ex`; and it claims more than the test checks (B1-B4). | Fix the test, then the claim. |
| docs/ARCHITECTURE.md:570, `audio/recording.ex:38-42` | Call the paid-twice window "a second or two" (J1). | Correct with J1's fix. |
| docs/ARCHITECTURE.md:608, `config/config.exs:163` | "One lookup at a time": two, one per machine (J8). | Correct. |
| docs/CI.md:78-82 | Recommends "Re-run failed jobs" on a `main` run, which can deploy an older commit (C1). | Correct with C1's fix. |
| `LumenViaeWeb.UserAuth` | Lives at `live/user_auth.ex`, breaking "module names match file paths". | Move it to `lumen_viae_web/user_auth.ex`. |
| CLAUDE.md | The database list omits `admins`, `admin_tokens`, `oban_jobs` and `oban_peers`; "every table is reached through `LumenViae.Rosary`" is less true than ever; narration is described as generated at import, where it is now queued as jobs; Ovo is listed as an admin font but is used nowhere. | Add the Accounts and Oban tables; say narration is queued; drop Ovo. |
| `root.html.heex:40` | The public layout still loads Ovo and Work Sans from Google Fonts. | Drop Ovo; load Work Sans only in the admin root layout. |
| Office docs | `parser.ex:17` names `parse_hour/2` (it is `/1`); OFFICE_API.md lists four fixtures of five; the ARCHITECTURE office tree (685-697) omits `breviary/read.ex`, `errors/` and `types/`. | Correct each. |

**docs/ASH_MIGRATION.md is due for removal.** It says to delete it once
the port has deployed and settled (line 6), and every part is now done,
duplicated or wrong:

- Lines 3-7 describe the branch `claude/ash-graphql-refactor-5d58e3`,
  merged as #39 and deployed.
- "Deploying" (78-115) is the #38 and #39 deploy, done.
- "Admin accounts and policies" (117-168) names the branch
  `claude/ash-auth-policies` (line 119); its ten commits went straight
  onto `main` between #39 and #40, with no PR of their own. Steps 1 to 4
  describe a deploy that has happened. Step 5 and the rollback warning
  are the only live parts, and docs/PROD_ACCESS.md:174-184 already
  carries them (OP1).
- "The repository after this" (170-179) restates rules CLAUDE.md,
  ARCHITECTURE.md and GRAPHQL.md already hold, and says nothing of
  /api/v2's pinned OpenAPI document.
- "Left for later" (181-189) is the iOS review's deferred list; it
  belongs in docs/UPCOMING_FEATURES.md.
- Nothing in it covers #40 to #45.

Three places cite it and need repointing: `lib/lumen_viae/rosary.ex:62`,
`test/lumen_viae/rosary/context_rules_test.exs:4` and
docs/PROD_ACCESS.md:184.

### Checked and correct

- Every Rosary resource opens with the `ActorIsAdmin` bypass, which
  matches on the `Admin` struct; a lookalike map is tested and refused.
- Public reads: sets by `visible?` (built on unauthorized aggregates, so
  the answer does not change with who asks), memberships through their
  set, narrations by their meditation's archive state, mysteries and
  authors open, the table-less resources only through their named
  actions. /api/v2 uses the same actions.
- Completions: the public reads nothing (forbidden, not empty); the IP
  comes from server context, never an argument or `X-Forwarded-For`;
  `ip_prefix` and `completed_at` are forced; `time_zone`, `locale` and
  `source` are bounded. Only AshOban's worker may `:read` and
  `:add_place` (`completion.ex:253`). All four ways to record one (REST,
  the prayer page, GraphQL, v2) carry the same `RateLimit` change on one
  key, and a crawler is refused before it spends any budget.
- Every content write is admin-only and tested; version resources are
  admin-read-only with no GraphQL or JSON:API type and no code interface.
- Every LiveView passes `actor: @current_admin`; REST, GraphQL and v2 run
  with no actor, and an admin's cookie does not change that on v2
  (tested). The `:graphql` and `:json_api` pipelines have no session.
- AshAdmin keeps authorization on, blocks `toggle_authorizing` and
  `clear_actor`, and sits behind both `RequireAdmin` and the mount hook.
  Oban Web at `/admin/jobs` sits behind the same two, for every HTTP
  request (its assets included) and every socket mount.
- Accounts: no admin bypass on `Admin`, no registration, bcrypt with a
  12-72 character password, stored tokens required, a password change
  logs out everywhere, sign-out disconnects open sockets, sign-in errors
  do not say which field was wrong, the signing secret is derived from
  `SECRET_KEY_BASE`.
- Every `authorize?: false` in `lib/` has a comment and is in a
  documented place, except the two aggregates in the stale-docs table.
  #43 added one (`narrate_meditation.ex:44`, listed); #41 removed
  Stamp's in favour of a policy on AshOban's check.
- Side effects run outside transactions: Stamp enqueues the place lookup
  in `after_transaction`, `LookUpPlace` calls the provider in
  `before_transaction`, and no job holds a connection across an HTTP
  call. The exception is D3's `Oban.insert` between create and attach.
- Oban: pruner (seven days), lifeline (30 minutes, beyond the five-minute
  job timeout) and stager are valid; one leader across both machines; no
  cron, so no duplicate scheduled runs; the PG notifier adds no
  connection; tests run with `testing: :manual`; the migration is pinned
  to Oban's version 14.
- Narration jobs: small arguments with no secrets, uniqueness under an
  advisory lock with an indexed lookup, a unique (meditation, voice)
  upsert, uncertain or fatal ElevenLabs answers cancelled, 429s and 5xx
  retried five times with backoff.
- v2: `show_fields` and the include list are allowlists; a hidden set is
  the same 404 as a missing one, and the same 422 on a completion; no
  route exposes S3 keys, versions, accounts or completion reads; the
  completion body is closed to two fields; no CORS, and AshJsonApi's 415
  blocks cross-site form posts; responses are `private, no-store`;
  `open_api_test.exs` pins the document byte for byte.
- CI: the deploy waits for Test and Assets build in the same run, on the
  merge commit's own SHA; runs on `main` are serialised; forks get
  `pull_request` with read-only contents and no secret; Test runs on
  Postgres 17 with the Dockerfile's Elixir and OTP, `--warnings-as-errors`,
  `--check-locked`, `--check-unused` and `ash.codegen --check`.

## Part B: packages

Versions are from the hex.pm API on 3 October 2026, or `mix.lock` for
adopted packages. "Effort" is S (a day or less), M (a few days), L (a
week or more).

| Package | Version | Use here | Effort | Risk | Verdict |
| --- | --- | --- | --- | --- | --- |
| **AshOban** (+ Oban, Oban Web) | ash_oban 0.9.0, oban 2.24.1, oban_web 2.13.0 | The place lookup as a trigger (#41); narration and the spoken Rosary as plain Oban workers (#43); Oban Web at `/admin/jobs` | - | J1-J8 | **Adopted** in #41 and #43 |
| **AshRateLimiter** | 2.0.1 | Limits on every completion create action, through Hammer's ETS backend | - | R1-R4 | **Adopted** in #42 |
| **AshJsonApi** | 1.7.1 | `/api/v2` with a pinned OpenAPI document, beside REST and GraphQL | - | V1-V5 | **Adopted** in #44 |
| **Tidewave** | 0.9.1 | Dev-only MCP: runtime eval, logs, SQL, Ash introspection for coding agents | S | Low (dev only) | **Adopt now** (workstream 16) |
| **Reactor** | 1.0.7 | The 800-line CSV import as steps with compensation | M-L | Medium (rewrites a working pipeline) | **Adopt later**, after workstream 10 |
| **Cinder** | 0.17.0 | Query-backed admin tables with URL state, replacing the in-memory filter in `live/meditations/filtering.ex` | M | Medium (pre-1.0, single maintainer; must match the console's design) | **Trial** on one list (workstream 17). Already compiled: `ash_admin` depends on it |
| **opentelemetry_ash** | 0.1.4 | Traces across actions, Postgres, Req (ElevenLabs, Divinum Officium, geo), S3 and now Oban | S-M | Low; needs a trace backend first, which may cost money | **Trial** once there is a collector (workstream 17) |
| **AshAi** | 1.1.1 | Its dev MCP plug only | S | Low (dev) | **Trial** (dev MCP, workstream 16); never for meditation text |
| **AshStateMachine** | 0.2.13 | The states of an import run, if workstream 10 adds that resource | S | Low | Only with workstream 10 |
| **AshArchival** | 2.0.3 | Archival is already hand-rolled on purpose (`archived_at`, `:archive`, the `:archived` read): it means "out of circulation", not deleted | M | Medium (changes default reads everywhere) | Skip |
| **AshEvents** | 0.8.2 | Overlaps AshPaperTrail | M | Medium | Skip |
| **AshCloak** | 0.4.0 | Nothing secret is stored; the IP is already truncated | S | Low | Skip |
| **AshOps** | 0.2.4 | Generated mix tasks; the release has no mix and uses `LumenViae.Release` | S | Low | Skip |
| **AshCsv** | 0.9.9 | A CSV data layer, not an import tool | M | Medium | Skip |
| **AshSlug** | 0.2.1 | Set URLs use ids, and so does the iOS contract | S | Low | Skip unless SEO slugs become a goal |
| **ash_translation** | 0.2.6 | Translated meditation text | M | Medium (small community package) | Skip until multilingual content is planned |
| **ash_geo** | 0.3.0 | Completions store place names, not coordinates | M | High (no release in two years) | Skip |
| AshTypescript, AshMoney, AshDoubleEntry, AshSqlite, multitenancy | - | No TypeScript client, money, ledger, SQLite or tenants | - | - | Skip |
| Spark, Igniter, usage_rules | - | Already adopted | - | - | Keep `mix usage_rules.sync` current |

**AshOban, as adopted.** #41 moved the completion place lookup from a
`Task.Supervisor` child onto an AshOban trigger (`completion.ex:128-143`,
no scheduler, one job per completion) and mounted Oban Web under
`/admin`, outside the console's design language. #43 chose plain Oban
workers for narration (`curation/jobs/`), unique by S3 key, with five
attempts and cancellation on any answer that may already have been
billed; the import queues one job per (meditation, voice) and the page
follows progress over PubSub. What the first pass proposed and #43 did
not do: an `--only-missing` scheduled trigger. That is deliberate, and
this refresh agrees: a nightly gap-fill would spend money with nobody
looking (a voice added to config means a whole-library run), so it
becomes a dashboard button with a count instead (workstream 13). The
import's row writes are still in the LiveView process (workstream 10).
The risks found in the merged code are J1-J8.

**AshRateLimiter and AshJsonApi, as adopted.** #42 replaced
`LumenViae.RateLimit` with declarative limits on every completion create
action; the sign-in throttle stays a plug, for the reason its moduledoc
gives. #44 added `/api/v2` against the first pass's "skip": the first
pass weighed a third API against the frozen REST contract, but #44 serves
what GraphQL serves, with a committed OpenAPI document for generating the
app's Swift client, and leaves REST untouched. Its risks are V1-V5.

**Tidewave and the AshAi dev MCP** give coding agents the running dev app
(eval, SQL, logs, resource and action metadata), which suits the
usage_rules workflow. Both go in `only: :dev` and stay out of
`runtime.exs`. AshAi's LLM-backed actions are not for this content:
docs/MEDITATION_CURATION_GUIDE.md requires verbatim public-domain text.

**Cinder.** The admin lists load every meditation and filter in memory,
which is fine at today's size but duplicates what read actions express.
`ash_admin` already depends on Cinder 0.17.0, so it compiles with this
Ash and LiveView. Trial it on `/admin/authors` with a theme on the
`--color-admin-*` tokens, and keep it only if it matches `.admin-table`
without a fight. Pin the minor version.

**Not verified:** opentelemetry_ash against the current `opentelemetry`
API; check it before a trial. The newer packages (ash_boundary,
search_ash, ash_paper_plane and others from 2025-2026) are all too small
to recommend yet; search_ash is worth watching if meditation search
becomes a feature.

## Part C: workstreams

Each workstream is one session and one PR, written as a worker brief.
Every one reads docs/ARCHITECTURE.md and docs/USAGE_RULES.md first, adds
tests, generates any migration with `mix ash.codegen`, runs with its own
`MIX_TEST_PARTITION`, and never touches production: a production step
goes in the PR under "Deploy steps" for the owner. The constraints that
recur below:

- **The 256MB database.** Production Postgres is one 256MB Fly machine
  that has run out of memory before. Anything that adds rows, indexes,
  connections or query load says how much.
- **The iOS contract.** REST under `/api` is frozen by
  docs/IOS_API_CONTRACT.md for every installed build. Additive changes
  only; GraphQL and v2 changes show up as a diff in `schema.graphql` or
  `v2.json`.
- **Cost.** ElevenLabs bills per character, whether or not the answer
  arrives; AWS bills requests and storage.

### Order

Merge #47 first. Workstreams 1, 2, 3, 6 and 7 touch separate files and
can run in parallel; 4 and then 10 and 13 run in sequence; 5 follows 2
(both touch `router.ex`); 11 and 12 follow the workstreams whose code
they describe or tidy; 15 runs alone, between rounds.

| # | Workstream | Findings | Size | Model | Effort | After |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | [CI deploy safety](#1-ci-deploy-safety) | C1-C4 | S | Sonnet 5.5 | high | - |
| 2 | [Public API edges](#2-public-api-edges) | R1, R2, R4, V1-V3, V5 | S-M | Opus 5.5 | high | - |
| 3 | [Completion analytics in the database](#3-completion-analytics-in-the-database) | Q1-Q3, Q7 | M | Opus 5.5 | high | - |
| 4 | [Identities, an atomic import row and job ownership](#4-identities-an-atomic-import-row-and-job-ownership) | D1-D3, J3, J6 | M | Opus 5.5 | xhigh | - |
| 5 | [A Content-Security-Policy](#5-a-content-security-policy) | H1 | M | Opus 5.5 | high | 2 |
| 6 | [Console session hardening](#6-console-session-hardening) | A3-A5, A7, J5 | S | Opus 5.5 | medium | - |
| 7 | [Deploy-safe recording and the dev sync](#7-deploy-safe-recording-and-the-dev-sync) | J1, J2, J4, J7 | S | Opus 5.5 | high | - |
| 8 | [Who changed what: version attribution and meditation history](#8-who-changed-what-version-attribution-and-meditation-history) | Feature | M | Opus 5.5 | high | - |
| 9 | [Scheduled publishing and a draft gate](#9-scheduled-publishing-and-a-draft-gate) | Feature | S-M | Opus 5.5 | high | 4 |
| 10 | [A durable import run](#10-a-durable-import-run) | Summary item 4 | M-L | Opus 5.5 | high | 4 |
| 11 | [Boundary test and documentation](#11-boundary-test-and-documentation) | B1-B4, J8, stale docs | M | Sonnet 5.5 | high | 1-7 |
| 12 | [Interface tidy-up](#12-interface-tidy-up) | Q4-Q6, W1-W4 | S-M | Sonnet 5.5 | high | 3, 4 |
| 13 | [A narration gap-fill button](#13-a-narration-gap-fill-button) | Feature | S | Sonnet 5.5 | high | 4 |
| 14 | [Office cache](#14-office-cache) | O1, O2 | S | Sonnet 5.5 | medium | - |
| 15 | [The one-time repository format](#15-the-one-time-repository-format) | OP2 | S | Sonnet 5.5 | medium | a quiet moment |
| 16 | [Dev tooling](#16-dev-tooling) | Part B | S | Sonnet 5.5 | medium | - |
| 17 | [Trials](#17-trials) | Part B | S each | Sonnet 5.5 | medium | - |

### 1. CI deploy safety

- **Packages:** none (GitHub Actions).
- **Changes:** `deploy` skips unless `github.sha` is `main`'s tip
  (`git ls-remote`) (C1); every action pinned to a commit SHA, including
  `setup-flyctl` (C2); `environment: production`, limited to `main`, for
  the token (C3); a `docker build .` job in `deploy`'s `needs`, a
  `timeout-minutes` on `deploy`, and an HTTP health check in `fly.toml`
  on a cheap route that does not touch the database (C4); docs/CI.md's
  re-run advice corrected.
- **Likely files:** `.github/workflows/ci.yml`,
  `.github/actions/setup-elixir/action.yml`, `fly.toml`, `docs/CI.md`,
  `router.ex` if a health route is added.
- **Risks:** a health check that fails takes a machine out of rotation;
  test the route locally and keep its grace period generous. A Docker
  build adds CI minutes. An environment with required reviewers would
  stall every deploy; use only the branch rule.
- **Owner steps:** create the `production` environment, mint a deploy
  token (`fly tokens create deploy -a lumenviae`) and move the secret.
- **Depends on:** nothing.

### 2. Public API edges

- **Packages:** AshRateLimiter, AshJsonApi (both adopted).
- **Changes:** key IPv6 completion limits on the /64, and the sign-in
  address budget the same way (R1); trust `Fly-Client-IP` only from the
  proxy, if the proxy's peer address can be pinned, otherwise document
  why not (R2); `Retry-After` on a 429 (R4); refuse `include` on the v2
  list route with a plug in `:json_api` (V1); `/api/v2/docs` dev-only
  (V2); serve the committed `v2.json` (V3); strip `sort_included` and
  `included_page`, with a test (V5). Optionally drop the stray `category`
  parameter on `getMeditationSet` and declare 404 and 429 responses in
  the document, which the Swift client would want.
- **Likely files:** `lib/lumen_viae/limits.ex`,
  `rosary/completion/rate_limit.ex`, `plugs/throttle_sign_in.ex`,
  `client_ip.ex`, `controllers/api/fallback_controller.ex`, `router.ex`,
  `json_api_router.ex`, a new plug under `plugs/`,
  `priv/openapi/v2.json`, `completion_rate_limit_test.exs` (line 226
  pins the old key) and the v2 tests.
- **Risks:** the iOS contract allows only additive REST changes:
  `Retry-After` is additive, a different 429 body is not. A /64 is one
  household or one phone on most networks, but a few carriers share one
  /64 among many devices; the limit is 20 an hour, far above real use.
  V1's refusal is a behaviour change for v2 callers; none exists yet.
  V4 waits on the owner's A6 decision.
- **Depends on:** nothing. Do it before 5.

### 3. Completion analytics in the database

- **Packages:** none new.
- **Changes:** generic actions on `Completion` for per-day and per-place
  counts, each running one grouped query (Q1); the distinct-set
  aggregate (Q1); optional pagination on every completion read (Q2); a
  `most_completed` read on `MeditationSet` with the filter, sort and
  limit in the query (Q3); the composite index (Q3); one filtered
  `Ash.aggregate` for the summary (Q7); the dashboard loads with
  `assign_async`, on connect only; ARCHITECTURE.md names the grouped
  query as the sanctioned Ecto use. No rollup table.
- **Likely files:** `rosary/completion.ex` and new modules beside it,
  `rosary/meditation_set.ex`, `rosary.ex`,
  `live/admin/dashboard/dashboard.ex` and its template, a migration from
  `mix ash.codegen`, `docs/ARCHITECTURE.md`, tests.
- **Risks:** the dashboard's figures must not change: pin them with tests
  before the rewrite, including a day that crosses a DST change, since
  `central_time.ex` buckets by hand. The `:locate` worker reads through
  the primary read, so pagination must stay optional. The index is small
  and cheap at today's size.
- **Depends on:** nothing. Conflicts with 12 in `rosary.ex`.

### 4. Identities, an atomic import row and job ownership

- **Packages:** none new.
- **Changes:** identities on set name per category (D1) and on non-blank
  `audio_url` (D2); a `create :import` on `Meditation` that creates the
  membership and computes the order inside its transaction, with the
  narration jobs inserted in the same transaction or after it commits
  (D3); `AudioJobs.enqueue/2` returns the conflicting job and the import
  treats a different meditation's job as an error (J3); queued
  `NarrateMeditation` filenames join the preview's taken set (J3); the
  intended filename survives every voice failing (J3); a failed
  `ensure_audio_url` cancels; only `NotFound` cancels a job (J6).
- **Likely files:** `rosary/meditation_set.ex`, `rosary/meditation.ex`,
  `rosary.ex`, `curation/csv_import.ex`, `curation/audio_jobs.ex`,
  `curation/jobs/narrate_meditation.ex`, migrations from
  `mix ash.codegen`, the import tests.
- **Risks:** the migrations fail on existing duplicates, so production
  must be checked first (owner step below). Cost: jobs must never be
  queued for a row that rolls back, and a merged job must never be
  reported as queued. The unique index builds on `meditations` while it
  is written to; small at today's size.
- **Owner steps:** before merging, through the IEx remote, count
  duplicate `(name, category)` pairs in `meditation_sets` and duplicate
  non-blank `audio_url` in `meditations`, and resolve any.
- **Depends on:** nothing. Comes before 9, 10 and 13.

### 5. A Content-Security-Policy

- **Packages:** none (a plug), plus the `csp_nonce_assign_key` options of
  AshAdmin and Oban Web.
- **Changes:** a plug in `:browser` that sets a per-request nonce and the
  policy H1 lists, first as `Content-Security-Policy-Report-Only`; the
  nonce on both root layouts' script tags and passed to `ash_admin` and
  `oban_dashboard`; inline `onclick` handlers moved into hooks where
  cheap; a test for the header. Enforcing the policy is a second, small
  PR after it has run clean.
- **Likely files:** a new `plugs/content_security_policy.ex`,
  `router.ex`, `components/layouts/root.html.heex` and
  `root_admin.html.heex`, templates with `onclick`, `config/runtime.exs`
  for the S3 and asset hosts, tests.
- **Risks:** a policy that is too strict breaks things quietly: the
  prayer page's audio (presigned S3), fonts, the LiveView socket, both
  library consoles. Check every page in a browser, signed in and out.
  Report-Only first means nothing breaks while it is checked.
- **Depends on:** 2 (V2 takes the third-party Swagger script off the
  production origin, so the policy need not allow cdnjs).

### 6. Console session hardening

- **Packages:** AshAuthentication (adopted).
- **Changes:** `secure: true` on the production session cookie and
  `force_ssl` with HSTS and `rewrite_on: [:x_forwarded_proto]` (A3);
  `AshAuthentication.Supervisor` in the application's children (A4); a
  scheduled disconnect at the token's `exp` (A5); a field policy on
  `hashed_password` (A7); `ObanResolver.resolve_user/1` returns only id
  and email (J5).
- **Likely files:** `endpoint.ex`, `config/runtime.exs`,
  `application.ex`, `live/user_auth.ex`, `accounts/admin.ex`,
  `oban_resolver.ex`, tests.
- **Risks:** `force_ssl` without `rewrite_on` loops behind Fly's proxy,
  and a secure cookie breaks plain-HTTP dev: production only, and verify
  in the Docker release check, not just tests. HSTS is sticky in
  browsers; start with a short `max-age`.
- **Depends on:** nothing.

### 7. Deploy-safe recording and the dev sync

- **Packages:** Oban (adopted).
- **Changes:** `kill_timeout` in `fly.toml` and Oban's
  `shutdown_grace_period` (J1); an orphaned attempt with no upload of its
  own cancels instead of recording again (J1); the dump excludes
  `oban_jobs` and `oban_peers` data (J2); an own-job match requires the
  fingerprint (J2); transient geolocation failures are not cached and
  are retried (J4); the spoken-Rosary run enqueues one at a time with
  `on_timeout: :kill_task` (J7); the "a second or two" wording corrected.
- **Likely files:** `fly.toml`, `config/config.exs`,
  `audio/recording.ex`, `sync_prod_db.sh`, `services/geolocation.ex`,
  `rosary/completion/look_up_place.ex`, `stamp.ex`'s moduledoc,
  `curation/rosary_audio_generation.ex`, `docs/ARCHITECTURE.md`, tests.
- **Risks:** a longer `kill_timeout` slows every deploy by up to that
  much when a recording is in flight; that is the point. The orphan rule
  must never cancel a job that genuinely uploaded. Retried geolocation
  must respect ipapi.co's quota, so back off rather than retry hard.
- **Depends on:** nothing.

### 8. Who changed what: version attribution and meditation history

The candidate "version history and restore in the console".

- **Packages:** AshPaperTrail (adopted).
- **Changes:** first, `belongs_to_actor :admin` on the four
  paper-trailed resources (`meditation.ex:84`, `meditation_set.ex:162`,
  `mystery.ex:64`, `author.ex:70`), with a migration adding `admin_id`
  and the missing `version_source_id` index (Q2). Attribution is not
  retroactive, so this half is worth doing soon even if the rest waits.
  Then a history panel on the meditation edit page, and a restore of a
  meditation's text fields through `:update`, passing the annotations
  explicitly so `ResetStaleAnnotations` keeps them.
- **Likely files:** the four resources, a migration from
  `mix ash.codegen`, `context_rules_test.exs` (it forbids naming
  `Accounts.Admin` outside `accounts/`, so a sanctioned exception),
  the meditation edit LiveView and a `_partials` panel, `rosary.ex` for a
  code interface, tests.
- **Risks:** restore never touches `audio_url` or `archived_at`. Audio
  does not roll back: the recordings keep speaking the newer text, so the
  panel says so and offers re-recording as a separate, deliberate button
  (it costs money). Set memberships are not versioned, so set restore is
  out of scope. Writes from jobs, mix tasks and the release stay
  unattributed. Version rows hold whole meditation texts, but edits are
  rare; small for the 256MB database.
- **Depends on:** nothing.

### 9. Scheduled publishing and a draft gate

The candidate "scheduled set publishing", built without a job.

- **Packages:** none. An AshOban trigger is not needed: visibility is an
  expression Postgres evaluates on every read.
- **Changes:** a nullable `publish_at` on `MeditationSet`; `visible?`
  gains `and (is_nil(publish_at) or publish_at <= now())`; the set form
  sets it; the dashboard and set list show "scheduled"; the import can
  set a set's `publish_at` far ahead so a new set stays a draft until its
  narration is recorded. Today a set goes public as soon as its first
  meditation is attached, before any recording exists.
- **Likely files:** `rosary/meditation_set.ex`, the set new and edit
  LiveViews, `rosary.ex` (`hidden_meditation_set_ids`), the dashboard,
  `curation/csv_import.ex`, a migration, tests across REST, GraphQL, v2
  and the prayer page.
- **Risks:** `nil` must mean published, or every existing set disappears.
  `visible?` drives the public read policy, `SetIsVisible` and
  `in_a_visible_set?`, so test every surface. Keep `publish_at` out of
  GraphQL and v2, so `schema.graphql` and `v2.json` do not change. The
  iOS app sees a set on its next fetch; nothing caches sets server side.
  A scheduled set's meditations stay readable by id (A6).
- **Depends on:** 4, if the import is to use it.

### 10. A durable import run

- **Packages:** Oban (adopted); AshStateMachine only if an import-run
  resource earns it.
- **Changes:** the CSV import's row writes move out of the LiveView's
  `start_async` (`import.ex:109`) into a job, with progress over PubSub
  as narration already has, and a record of each run (when, who, how
  many rows, which failed) the page can reopen. The dry run stays
  synchronous.
- **Likely files:** `curation/csv_import.ex`, `curation/jobs/`,
  `live/admin/meditations_import/import/`, possibly a new resource and
  migration, `docs/CSV_IMPORT_GUIDE.md`, tests.
- **Risks:** two machines: a job may run on the machine that did not
  receive the upload, so the CSV must travel in the job's arguments or a
  table, not a temp file. Meditation text in `oban_jobs` is pruned after
  seven days; say so, since content stays out of git but would sit in the
  database briefly. Cost: the run must not re-queue narration for rows
  already written if it is retried.
- **Depends on:** 4 (the atomic row action).

### 11. Boundary test and documentation

- **Packages:** none.
- **Changes:** tighten the test first (B1-B4) and fix anything it then
  finds; then the stale-docs table, J8's wording, and the removal of
  docs/ASH_MIGRATION.md with its three references repointed and its
  "Left for later" moved to docs/UPCOMING_FEATURES.md; move `UserAuth`
  to match its module name.
- **Likely files:** `test/lumen_viae/rosary/context_rules_test.exs`,
  README.md, CLAUDE.md, `docs/ARCHITECTURE.md`, `docs/UPCOMING_FEATURES.md`,
  `docs/API_EXPANSION_PLAN.md`, `docs/OFFICE_API.md`, `docs/PROD_ACCESS.md`,
  `lib/lumen_viae/rosary.ex:62`, `root.html.heex`, `live/user_auth.ex`.
- **Risks:** CLAUDE.md is every agent's instructions: change facts, not
  rules. Docs go stale with every workstream, so this one runs after the
  others in its round.
- **Depends on:** 1-7, so the trees and lists describe their result.

### 12. Interface tidy-up

- **Packages:** none.
- **Changes:** the narration fallback raises and callers load with the
  actor (Q4, which also fixes archived recordings hidden from admins);
  `record_narration` returns the narration and validates the voice in the
  action (Q5); `read :active_with_audio` and lighter loads (Q6); the
  `get_*` decision (W1); the `require_atomic?` judgements (W2); unused
  reads and interface removed (W3); one numericality validation (W4).
- **Likely files:** `rosary.ex`, `rosary/meditation.ex`,
  `rosary/narration.ex`, `rosary/set_membership.ex`,
  `rosary/completion.ex`, `curation/audio_regeneration.ex`,
  `curation/narration_relocation.ex`, the set and meditation LiveViews,
  tests.
- **Risks:** removing interface that docs/PROD_ACCESS.md's runbook uses;
  check it first.
- **Depends on:** 3 and 4, which rewrite parts of `rosary.ex`.

### 13. A narration gap-fill button

The candidate "nightly self-healing narration", turned into a button.

- **Packages:** Oban (adopted).
- **Changes:** on the dashboard's "Meditations missing a voice" row
  (`dashboard.ex:170`), a button that shows what it would record (how
  many clips, roughly how many characters) and enqueues
  `NarrateMeditation` for `:missing_a_voice` (`meditation.ex:136`) with a
  per-run cap; it refuses when S3 credentials fail, which needs
  `S3.audio_metadata` (`storage/s3.ex:238`) to stop treating a 403 as
  "missing".
- **Likely files:** `live/admin/dashboard/`, `curation/audio_jobs.ex`,
  `curation/audio_regeneration.ex`, `storage/s3.ex`, tests.
- **Risks:** cost, which is why it is a button and not a nightly job: a
  voice added to config means a whole-library run, and cancelled jobs
  may already have been billed. The app sends plain text, not the
  hand-tagged scripts, so gap-fills can sound different.
- **Depends on:** 4 (J3, D2), so a gap-fill cannot attach audio to the
  wrong meditation.

### 14. Office cache

- **Packages:** none.
- **Changes:** one engine request per cold key (O1); a cache the tests
  can isolate (O2).
- **Likely files:** `lib/lumen_viae/office.ex`, the `Cache` module, the
  three Office test files.
- **Risks:** a lock held across a slow Divinum Officium request must time
  out, or one stuck request blocks that hour for everyone.
- **Depends on:** nothing.

### 15. The one-time repository format

- **Packages:** none.
- **Changes:** OP2's plan from PR #40: `mix format` across the repo, the
  commit in `.git-blame-ignore-revs`, and the CI format job switched to
  the whole repo.
- **Likely files:** the 26 files, `.git-blame-ignore-revs`,
  `.github/workflows/ci.yml`, `docs/CI.md`.
- **Risks:** it conflicts with every open branch; run it when none is
  open, and merge it straight away. Read the `.heex` diffs: the formatter
  re-indents comments and whitespace in templates.
- **Depends on:** a moment with no other branch open.

### 16. Dev tooling

- **Packages:** Tidewave, AshAi (its dev MCP plug only).
- **Changes:** both as `only: :dev` dependencies, mounted in the dev
  endpoint, documented for agents.
- **Likely files:** `mix.exs`, `mix.lock`, `lib/lumen_viae_web/endpoint.ex`
  (dev-only block), `config/dev.exs`, CLAUDE.md or a docs page.
- **Risks:** nothing reaches production if the dependencies are `:dev`
  only; the Docker build (`mix deps.get --only prod`) proves it.
- **Depends on:** nothing.

### 17. Trials

- **Packages:** Cinder (already compiled), opentelemetry_ash.
- **Changes:** time-boxed. Cinder on `/admin/authors`, themed on the
  console tokens, kept only if it matches `.admin-table`. opentelemetry_ash
  once a trace backend is chosen.
- **Risks:** a hosted trace backend costs money; choose it first.
- **Depends on:** nothing.

### Later, or not at all

- **Reactor for the import:** after 10, once the import has settled on
  jobs.
- **A typed Swift client from `v2.json`:** the server side is done
  (`docs/JSON_API.md`; workstream 2 can tidy the document). The work is
  in the iOS app, which has no Swift packages yet and a working hand-
  written client against REST; offline storage depends on its models.
  Do it when the app needs something only v2 serves.
- **Nightly completion rollups:** not needed; workstream 3's grouped
  queries suffice at this scale, and rollups fight the Central-time
  buckets and late-filled places.
- **Nightly self-healing narration:** replaced by workstream 13.
- **Editor and admin roles:** `Admin` has no role; adding one touches
  about ten policy sites, three route guards, and the import page, whose
  spending is an Oban insert no policy sees. Revisit when a less-trusted
  curator joins.

### Decisions and owner steps

Decisions needed from the owner:

- **A1:** should REST refuse completions for hidden sets? Recommended:
  yes, given the iOS app's fire-and-forget call; the cost is not counting
  offline prayers of since-hidden sets.
- **A6:** do meditations in no visible set stay publicly readable, with
  their audio? V4 follows this answer.

Production steps no worker can take:

- Unset `ADMIN_PASSWORD` once rolling back past `723d422` is off the
  table (OP1).
- Create the `production` environment and an app-scoped deploy token
  (workstream 1).
- Count duplicate set names and audio filenames before workstream 4
  merges.
- Schedule workstream 15 for a moment with no open branch.
