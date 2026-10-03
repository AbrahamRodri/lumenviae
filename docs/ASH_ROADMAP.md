# Ash audit and package roadmap

A read-only audit of the three Ash domains (`LumenViae.Rosary`,
`LumenViae.Office`, `LumenViae.Accounts`) and a survey of the Ash
ecosystem, taken on 3 October 2026 against the branch that adds admin
accounts and policies. Nothing here has been changed in code yet: each
finding names the file and line it was read at, says what is wrong, and
sketches the fix. The last section turns the findings and the adopted
packages into workstreams.

Line numbers are those of this branch's head and will drift; search for
the function or action named beside them.

## Contents

- [Summary](#summary)
- [Part A: audit findings](#part-a-audit-findings)
  - [Authorization and accounts](#authorization-and-accounts)
  - [Queries and growth](#queries-and-growth)
  - [Data integrity](#data-integrity)
  - [The Ash way](#the-ash-way)
  - [The Office domain](#the-office-domain)
  - [The boundary test](#the-boundary-test)
  - [Stale documentation](#stale-documentation)
  - [Checked and correct](#checked-and-correct)
- [Part B: packages](#part-b-packages)
- [Part C: backlog](#part-c-backlog)

## Summary

The domain is in good shape. Rules are expressions and aggregates on the
resources that own them, prayer order is loaded in batches, side effects
(S3, ElevenLabs, geolocation) stay outside transactions, every resource
opens with the admin bypass, and no code outside the domains names a
resource or touches the Repo. No high-severity authorization defect was
found.

What needs work, in order:

1. **The completion analytics read whole tables into memory**, and the
   completion reads are not paginated. It is the one table that grows
   with traffic, and the admin dashboard pays for it on every mount.
2. **REST completions accept hidden sets**, which lets an anonymous
   caller tell a hidden set from a missing one. GraphQL already refuses.
3. **Narration generation runs inside the admin's LiveView process.** A
   closed tab or a deploy stops an import partway with no record of it.
   AshOban is the fix and the one package worth adopting now.
4. **Two missing identities** (set name per category, audio filename)
   that the import relies on without the database enforcing them.
5. **The boundary test has blind spots**, and several documents describe
   the app as it was before the Ash port or before admin accounts.

## Part A: audit findings

Severity: **High** is a defect that costs correctness, privacy or
availability today; **Medium** is one that will, or that leaks a little;
**Low** is tidiness or hardening.

### Authorization and accounts

**A1. Medium: REST completions are recorded against hidden sets.**
`lib/lumen_viae/rosary/completion.ex:132` (`create :record`) has no
`validate SetIsVisible`; only `:record_from_app` (line 153, used by
GraphQL) does, at line 165. `POST /api/completions`
(`lib/lumen_viae_web/controllers/api/completion_controller.ex:46`) calls
`Rosary.record_completion/3`, which uses `:record`. A set id that does
not exist answers 422, a hidden set's id answers 201: an anonymous
caller can enumerate hidden set ids and add rows to their analytics.
`SetIsVisible`'s own moduledoc states the intent the REST path breaks.

```elixir
create :record do
  # ...
  validate SetIsVisible
  change Stamp
end
```

Check against docs/IOS_API_CONTRACT.md first: an iOS build that prayed a
set offline, which has since been hidden, would now get a 422 on sync.
The contract already accepts a 404 for a hidden set on read; confirm the
app drops a failed completion rather than retrying forever. Add a REST
test for the hidden case beside `error_envelope_test.exs`.

**A2. Medium: the sign-in throttle matches the literal request path.**
`lib/lumen_viae_web/plugs/throttle_sign_in.ex:44` matches
`request_path: @sign_in_path` exactly. Phoenix routes on
`conn.path_info`, which drops empty segments, so
`/admin/auth/admin/password/sign_in/` and `/admin//auth/...` most likely
reach the password strategy without being counted. That would make the
bcrypt guesses unthrottled. Not yet confirmed against the running app:
the first step is a test that posts to the trailing-slash path.

```elixir
def call(%Plug.Conn{method: "POST",
       path_info: ["admin", "auth", "admin", "password", "sign_in"]} = conn, opts)
```

**A3. Low: the session cookie is not `secure`, and SSL is not forced.**
`lib/lumen_viae_web/endpoint.ex:7-12` sets no `secure: true`, and
`force_ssl` is only the generator's comment in `config/runtime.exs:199`.
Fly's `force_https` redirects, but a first plain-HTTP request still
carries the admin cookie. Set `secure: true` in production (runtime
session options) and `force_ssl: [hsts: true]` on the endpoint.

**A4. Low: expired tokens are never deleted.**
`lib/lumen_viae/application.ex` does not start
`{AshAuthentication.Supervisor, otp_app: :lumen_viae}`, so
`Token`'s `:expunge_expired` never runs and `admin_tokens` (including
revocations, and the dev sign-in's row per request) only grows. Add it
to the children.

**A5. Low: an open console socket outlives its token.**
`lib/lumen_viae_web/live/user_auth.ex` checks the token on mount only.
Sign-out and password changes close open sockets; a seven-day expiry does
not. Schedule a disconnect for the token's `exp` on mount, alongside the
existing `AdminSockets` broadcast.

**A6. Low (design choice, recorded for a decision): any non-archived
meditation is publicly readable**, including one in no visible set, and
so is its audio (`meditation.ex:193-195`, `GET /api/meditations/:id/audio`).
This matches the policy table and is tested. If unpublished meditations
should stay private, the policy becomes
`authorize_if expr(is_nil(archived_at) and in_a_visible_set?)`, and the
audio path and the iOS contract need rechecking.

**A7. Low (hardening): `Admin.hashed_password` has no field policy.**
It is sensitive and not public, but an admin actor can read it, so it
shows in AshAdmin. A `field_policies` block that lets only
`AshAuthenticationInteraction` read it removes it from every surface.

### Queries and growth

**Q1. High: the dashboard counts completions in Elixir.**
In `lib/lumen_viae/rosary.ex`, `completion_locations/2` (line 1026)
reads every completion in the window (six columns) and folds it with
`Enum.frequencies_by`; `completions_by_day/2` (line 1131) reads every row
to draw a 30-point chart; `count_sets_completed_in_range/3` reads every
`meditation_set_id` and takes `Enum.uniq_by |> length`. All three run on
every mount of `lib/lumen_viae_web/live/admin/dashboard/dashboard.ex`,
so its cost grows linearly with traffic.

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
    argument :time_zone, :string, allow_nil?: false
    run LumenViae.Rosary.Completion.DailyCounts
  end
  ```
  ARCHITECTURE.md should name this as the one sanctioned use of an
  Ecto query in the domain.

**Q2. High: no read is paginated, `Completion`'s included.**
`completion.ex:103` (`defaults [:read, :destroy]`), `:in_range` (105)
and `:recent` (120, which limits by hand). AshAdmin at `/admin/data`
browses the primary read, so opening completions there loads the table.

```elixir
read :read do
  primary? true
  pagination keyset?: true, offset?: true, required?: false, default_limit: 50
end
```

The four PaperTrail version tables grow too, and `version_source_id` has
no index (`priv/repo/migrations/20261001163951_add_paper_trail_versions.exs:15,31,47,63`).
Lower priority, since only admins read them.

**Q3. Medium: `get_completions_by_set/1` filters, sorts and limits in
Elixir** (`rosary.ex:970`). It loads every set with its
`completion_count`, rejects zeros, sorts, and the dashboard takes six.
Make it a read on `MeditationSet` that filters on
`completion_count(since:, until:) > 0`, sorts on the same calculation and
takes `limit: 6`. A composite index on `rosary_completions
[:meditation_set_id, :completed_at]` serves the filtered count. The same
"load all, reject zeros" shape is in `meditation_set_stats/1`,
`mystery_counts/2` and `meditation_set_counts_by_author/1`. Those tables
are small, but the fix is a one-line filter.

**Q4. Medium: `meditation_narrations/2` hides a query per meditation**
(`rosary.ex:385`). When `:narrations` is not loaded it reads them, so a
loop over unloaded meditations is an N+1 with no warning. Its callers
pass no options, so that read also runs without the actor: the
Narration read policy then hides an archived meditation's recordings even
from an admin. Drop the fallback (raise on `%Ash.NotLoaded{}`) and load
`:narrations` with the actor at the call site.

**Q5. Low: `record_narration/4` re-reads narrations on every call**
(`rosary.ex:354`), once per voice per row during import, and both callers
discard the result. It also checks the voice slug in Elixir. Return the
narration, and move the check to a validation on `Narration`'s `:record`
action.

**Q6. Low: over-loaded reads filtered in Elixir.**
`lib/lumen_viae/curation/audio_regeneration.ex` reads
`list_meditations!` (mystery and narrations for every row), then rejects
archived ones and re-sorts by id, which `:detailed` already does;
`narration_relocation.ex` rejects blank `audio_url` the same way. Add a
`read :active_with_audio` with `filter expr(not archived? and has_audio?)`.
The set new and edit pages read `:detailed` and load narrations they
never show. `get_meditation_set` defaults to loading `:meditations`, and
its only caller loads the set to delete it.

**Q7. Low: `completion_summary/1` runs seven count queries.** Indexed and
acceptable; one `Ash.aggregate` call with filtered counts makes it one.

### Data integrity

**D1. Medium: nothing makes a set name unique within its category.**
`MeditationSet` has no identity on `[:name, :category]`, and
`get_meditation_set_by_name/3` (`rosary.ex:563`) uses `Ash.read_one!`.
A duplicate pair would make the CSV import (`csv_import.ex:614`) raise
rather than report the row.

```elixir
identities do
  identity :unique_name_per_category, [:name, :category]
end
```

Check production for existing duplicates before `mix ash.codegen`.

**D2. Medium: nothing makes an audio filename belong to one meditation.**
`meditations.audio_url` (`meditation.ex:229`) decides the S3 key for
every voice. The import warns about a clash (`list_taken_audio_urls`), but
two meditations with one filename overwrite each other's narration.

```elixir
identity :unique_audio_url, [:audio_url],
  where: expr(not is_nil(audio_url) and audio_url != "")
```

The partial unique index also serves the `:with_audio_filenames` filter
(line 85).

**D3. Medium: an imported row is four writes, and the next order is
racy.** `csv_import.ex:682-736` runs `create_meditation`,
`record_narrations`, `next_order_in_set` (a separate max query) and
`add_meditation_to_set` independently. A failed attach leaves an orphan
reported as a warning, and two imports into one set can read the same
max and trip `unique_order_per_set`. Audio is generated before these
writes, so a transaction around them is safe: a `create :import` on
`Meditation` taking `set_id` and an optional `order`, creating the
membership in an `after_action` inside the action's transaction, with
the order computed there. With `--skip-audio`, rows can go through
`Ash.bulk_create`.

### The Ash way

**W1. Low: four `get_*` defines generate a non-bang read**, against the
"reads are bang-only" rule: `get_mystery`, `get_meditation`,
`get_meditation_set` and `get_author` (`rosary.ex:141, 155, 185, 211`)
lack `functions: @read`. `curation/csv_update.ex` and
`curation/audio_regeneration.ex` use the tuple form. Either document the
`get_*` exception in ARCHITECTURE.md, or restrict them and rescue
`Ash.Error.Invalid` in the two callers. Naming is also mixed:
`get_completions_by_set` and `get_recent_completions` return lists and
raise without a `!`.

**W2. Low: the `require_atomic? false` updates, judged one by one.**

| Action | Line | Judgement |
| --- | --- | --- |
| `Mystery.update` | `mystery.ex:81` | Justified: lets the paper trail skip a version for a save that changes nothing. |
| `Author.update` | `author.ex:92` | Justified, same reason. But `:record_artwork` and `:update_artwork_metadata` are paper-trailed and atomic, so they do version no-op saves. Make the two consistent. |
| `MeditationSet.update` | `meditation_set.ex:195` | Its comment's reason does not hold: `NormalizeLabels` and `ManagedLabels` read only the incoming value. Give each an `atomic/3`, or cite the paper-trail reason instead. |
| `Meditation.update` | `meditation.ex:139` | Acceptable (admin-only, low volume). `ResetStaleAnnotations` could go atomic with an `expr(if content != ^new, ...)`. |

**W3. Low: unused or duplicated interface.**
`SetMembership`'s `:in_prayer_order` and `:holding_archived` reads
(`set_membership.ex:71, 76`) are never called.
`list_visible_meditation_sets_with_meditations` and
`list_visible_meditation_sets_by_category` are one read, since
`:category` is optional. `count_completions_last_days`,
`narration_counts_by_voice`, `meditation_ids_with_narration`,
`count_mysteries` and `count_meditation_sets` are used only by tests and
docs/PROD_ACCESS.md; keep the ones the runbook needs and drop the rest.
`narration_counts_by_voice` counts by loading every narration.

**W4. Low: two numericality validations where one will do**
(`set_membership.ex:98-99`), and the set edit LiveView repeats the 1..7
check. Merge them into
`validate numericality(:order, greater_than: 0, less_than_or_equal_to: 7)`
and let the form show the action's error.

### The Office domain

`LumenViae.Office` is a real Ash domain: one data-layer-less resource,
`Breviary`, with five generic actions returning `Ash.TypedStruct` types,
Splode errors with AshGraphql messages, and an ETS cache. It is used
well. The REST `OfficeController` calls the domain's plain functions
rather than the actions, so REST bypasses policies and Ash telemetry; the
docs say that is deliberate.

**O1. Low: concurrent cold misses all reach the engine**
(`lib/lumen_viae/office.ex:171-177`). A burst for today's hours at
midnight sends one identical request per caller to Divinum Officium.
Serialise misses per key (a per-key lock in the `Cache` GenServer, or
`:global.trans`).

**O2. Low: the Office tests share the global cache.** All three files are
`async: true` and stay correct only because each test uses its own date.
`Cache.reset/0` exists but nothing calls it. Namespace the keys per test,
or make the cache table name configurable.

**O3. Low: `:hours` halts on the first failed hour** and the whole list
is null. Acceptable, but docs/GRAPHQL.md does not say so.

### The boundary test

No code outside the domains names a resource, calls `Ash` on one, builds
a form or touches the Repo. But
`test/lumen_viae/rosary/context_rules_test.exs` would not catch some
future violations:

**B1. Medium: aliased names slip through.** Rule 1 matches only the full
literal `LumenViae.Rosary.Meditation`, so `alias
LumenViae.Rosary.{Meditation, MeditationSet}` and `Rosary.Meditation`
after `alias LumenViae.Rosary` pass. The web-layer check has the same
blind spot. Also match the brace form and `Rosary\.<Resource>\b`.

**B2. Low: the resource list is incomplete** (line 28): it lacks
`narration_voice`, `spoken_rosary` and the `*.Version` modules (the
lookahead deliberately rejects `Meditation.Version`).

**B3. Low: rule 2's regex is narrow.** It misses `Ash.read_one`,
`Ash.run_action`, `Ash.calculate`, `Ash.aggregate`, `Ash.stream!`,
`Ash.ActionInput`, `Ash.Resource.*` and `AshPhoenix.Form.for_read`. Flag
`\bAsh\.[a-z]` and `AshPhoenix\.Form\.for_` with a short allowlist
(`Ash.Error`, `Ash.PlugHelpers`). `require_admin.ex` would then need its
dev-only `Ash.Resource.put_metadata` call allowed by name.

**B4. Low: nothing enforces the Office rule.** CLAUDE.md and
ARCHITECTURE.md say nothing outside `office/` names its internals, but
the test exempts the Office everywhere. Add a check like the Accounts one
for `LumenViae.Office.[A-Z]`, allowing `application.ex`.

### Stale documentation

| Document | What is stale | Fix |
| --- | --- | --- |
| README.md | Describes "one context + schema per resource"; no Ash, GraphQL, Office or admin accounts; the docs list omits six documents; says Elixir 1.14+ where `mix.exs` needs 1.15. | Rewrite the architecture and docs sections to point at ARCHITECTURE.md. |
| docs/API_EXPANSION_PLAN.md | A pre-port status document: "nothing below is deployed", names files and a context rule that no longer exist, and modules never built. | Mark it historical at the top, or delete it. |
| docs/UPCOMING_FEATURES.md (section 5) | Lists sign-in throttling, failed sign-in logging and credential rotation as open; all three ship on this branch. | Keep only what is still open (MFA, an admin action log beyond PaperTrail); note admin-only accounts shipped and public accounts remain open. |
| docs/ASH_MIGRATION.md | Says to delete it once the port is deployed (PR #39 is merged); line 119 names the auth branch `claude/ash-auth-policies`. | Drop the finished first deploy, keep the admin-accounts runbook, name the real branch or PR. |
| docs/ARCHITECTURE.md:76-79 | "Every table-backed resource also has a version resource": only four do. | Name the four. |
| docs/ARCHITECTURE.md, "Who may do what" | The `authorize?: false` list omits Meditation's `in_any_set?` and `in_a_visible_set?` aggregates (`meditation.ex:322-331`). | Add them. |
| docs/ARCHITECTURE.md, lib tree | Missing `accounts/`, `ash_opts.ex`, `rate_limit.ex`, `rosary/version_policies.ex`, `rosary/errors/`, `rosary/types/`, `rosary/narration_voice/`, `rosary/spoken_rosary/`, the office files, the web `graphql/` directory and the newer plugs. | Regenerate the tree. |
| `LumenViaeWeb.UserAuth` | Lives at `live/user_auth.ex`, breaking "module names match file paths". | Move it to `lumen_viae_web/user_auth.ex`. |
| docs/ARCHITECTURE.md, "These rules are tested" | Claims more than the test checks (see B1-B4). | Fix the test, then the claim holds. |
| CLAUDE.md | Database list omits `admins` and `admin_tokens`; "every table is reached through `LumenViae.Rosary`" is no longer true; Ovo is listed as an admin font but is used nowhere. | Add the Accounts tables and domain; drop Ovo. |
| `root.html.heex:40` | The public layout still loads Ovo and Work Sans from Google Fonts. | Drop Ovo; load Work Sans only in the admin root layout. |
| Office docs | `parser.ex:17` names `parse_hour/2` (it is `/1`); OFFICE_API.md lists four fixtures of five; the ARCHITECTURE office tree omits `breviary/read.ex`, `errors/` and `types/`. | Correct each. |

### Checked and correct

- Every Rosary resource opens with the `ActorIsAdmin` bypass, which
  matches on the `Admin` struct; a lookalike map is tested and refused.
- Public reads: sets by `visible?` (built on unauthorized aggregates, so
  the answer does not change with who asks), memberships through their
  set, narrations by their meditation's archive state, mysteries and
  authors open, the table-less resources only through their named
  actions.
- Completions: the public reads nothing (forbidden, not empty); the IP
  comes from server context, never an argument; `ip_prefix` and
  `completed_at` are forced; `time_zone`, `locale` and `source` are
  bounded.
- Every content write is admin-only and tested; version resources are
  admin-read-only with no GraphQL type and no code interface.
- Every LiveView passes `actor: @current_admin`; REST and GraphQL run
  with no actor; the `:graphql` pipeline has no session.
- AshAdmin keeps authorization on, blocks `toggle_authorizing` and
  `clear_actor`, and sits behind both `RequireAdmin` and the mount hook.
- Accounts: no admin bypass on `Admin`, no registration, bcrypt with a
  12-72 character password, stored tokens required, a password change
  logs out everywhere, sign-out disconnects open sockets, sign-in errors
  do not say which field was wrong, the signing secret is derived from
  `SECRET_KEY_BASE`.
- Every `authorize?: false` in `lib/` has a comment and is in a
  documented place, except the two aggregates in the stale-docs table.
- Side effects run outside transactions; `Completion.Stamp` uses
  `after_transaction`.

## Part B: packages

Versions are from the hex.pm API on 3 October 2026. "Effort" is S (a day
or less), M (a few days), L (a week or more).

| Package | Version | Use here | Effort | Risk | Verdict |
| --- | --- | --- | --- | --- | --- |
| **AshOban** (+ Oban) | ash_oban 0.9.0, oban 2.24 | Narration per (meditation, voice) and the completion geo lookup as durable, retried jobs | M | Low-medium | **Adopt now** |
| **Tidewave** | 0.9.1 | Dev-only MCP: runtime eval, logs, SQL, Ash introspection for coding agents | S | Low (dev only) | **Adopt now** |
| **Reactor** | 1.0.7 | The 800-line CSV import as steps with compensation | M-L | Medium (rewrites a working pipeline) | **Adopt later**, after AshOban |
| **AshRateLimiter** | 2.0.1 | Declarative limits on `Completion`'s create actions in place of `LumenViae.RateLimit` | S | Low; still per node unless Hammer's backend is shared | **Adopt later** |
| **Cinder** | 0.17.0 | Query-backed admin tables with URL state, replacing the in-memory filter in `live/meditations/filtering.ex` | M | Medium (pre-1.0, single maintainer; must match the console's design) | **Trial** on one list |
| **opentelemetry_ash** | 0.1.4 | Traces across actions, Postgres, Req (ElevenLabs, Divinum Officium, geo) and S3 | S-M | Low; needs a trace backend first | **Trial** once there is a collector |
| **AshAi** | 1.1.1 | Its dev MCP plug only | S | Low (dev) | **Trial** (dev MCP); never for meditation text |
| **AshStateMachine** | 0.2.13 | Only if an import-run resource is added with AshOban | S | Low | Skip for now |
| **AshArchival** | 2.0.3 | Archival is already hand-rolled on purpose (`archived_at`, `:archive`, the `:archived` read): it means "out of circulation", not deleted | M | Medium (changes default reads everywhere) | Skip |
| **AshEvents** | 0.8.2 | Overlaps AshPaperTrail | M | Medium | Skip |
| **AshCloak** | 0.4.0 | Nothing secret is stored; the IP is already truncated | S | Low | Skip |
| **AshOps** | 0.2.4 | Generated mix tasks; the release has no mix and uses `LumenViae.Release` | S | Low | Skip |
| **AshCsv** | 0.9.9 | A CSV data layer, not an import tool | M | Medium | Skip |
| **AshJsonApi** | 1.7.1 | The REST shape is frozen by the iOS contract; this would be a third API | L | High | Skip |
| **AshSlug** | 0.2.1 | Set URLs use ids, and so does the iOS contract | S | Low | Skip unless SEO slugs become a goal |
| **ash_translation** | 0.2.6 | Translated meditation text | M | Medium (small community package) | Skip until multilingual content is planned |
| **ash_geo** | 0.3.0 | Completions store place names, not coordinates | M | High (no release in two years) | Skip |
| AshTypescript, AshMoney, AshDoubleEntry, AshSqlite, multitenancy | - | No TypeScript client, money, ledger, SQLite or tenants | - | - | Skip |
| Spark, Igniter, usage_rules | - | Already adopted | - | - | Keep `mix usage_rules.sync` current |

**AshOban.** The CSV import runs in the admin's LiveView
(`lib/lumen_viae_web/live/admin/meditations_import/import/import.ex:95`,
`start_async`), and from there
`CsvImport` calls `Audio.Pipeline.generate_and_upload` for each row and
voice: ElevenLabs over Req, then S3, with retries that sleep in the
process. Closing the tab, a dropped socket or a deploy stops the import
partway, with no record of the run; the repair is
`mix lumen_viae.regenerate_audio --only-missing` by hand. The completion
geo lookup (`completion/stamp.ex:62`) is a `Task.Supervisor` child, lost
on restart. With AshOban:

- the import writes the rows and enqueues one job per (meditation,
  voice); the page follows progress over PubSub;
- `--only-missing` becomes a scheduled trigger over meditations missing
  a narration in some voice;
- the geo lookup becomes a trigger on completions with no city, recent
  enough to be worth placing.

The jobs run without an actor, so each is an `authorize?: false` system
write with a comment, listed in ARCHITECTURE.md. Oban's tables come from
its installer (`mix igniter.install ash_oban`); any new column from
`mix ash.codegen`. Production runs two Fly machines, which Oban handles
on the shared Postgres. `oban_web` could mount under `/admin` beside
AshAdmin, outside the console's design language.

**Tidewave and the AshAi dev MCP** give coding agents the running dev app
(eval, SQL, logs, resource and action metadata), which suits the
usage_rules workflow. Both go in `only: :dev` and stay out of
`runtime.exs`. AshAi's LLM-backed actions are not for this content:
docs/MEDITATION_CURATION_GUIDE.md requires verbatim public-domain text.

**Cinder.** The admin lists load every meditation and filter in memory,
which is fine at today's size but duplicates what read actions express.
Trial it on `/admin/authors` with a theme on the `--color-admin-*`
tokens, and keep it only if it matches `.admin-table` without a fight.
Pin the minor version.

**Not verified:** Cinder 0.17's compatibility with Ash 3.33 and LiveView
1.2, and opentelemetry_ash against the current `opentelemetry` API. Check
both before a trial. The newer packages (ash_boundary, search_ash,
ash_paper_plane and others from 2025-2026) are all too small to
recommend yet; search_ash is worth watching if meditation search becomes
a feature.

## Part C: backlog

Each workstream is one PR unless noted, ordered by value for effort.
Every one follows docs/USAGE_RULES.md, adds tests, and generates any
migration with `mix ash.codegen`.

| # | Workstream | Findings | Size | Notes |
| --- | --- | --- | --- | --- |
| 1 | **Completion analytics in the database** | Q1, Q2, Q3, Q7 | M | Generic grouped-count actions on `Completion`, the distinct-set aggregate, pagination on every completion read, the `most_completed` set read, the composite index. Dashboard figures must not change: pin them with tests before the rewrite. |
| 2 | **Auth hardening** | A1, A2, A3, A4, A5, A7 | S | Small, independent fixes; A1 needs the iOS contract check first. Can ride the admin-accounts branch or follow it. |
| 3 | **Identities and an atomic import row** | D1, D2, D3 | M | Query production for existing duplicates first; the migrations fail on them. |
| 4 | **Durable narration with AshOban** | Part B | M-L | Depends on 3 (the import row action). Two PRs: Oban and the geo trigger first (small, proves the setup), then narration jobs with a progress page. |
| 5 | **Boundary test and docs** | B1-B4, stale docs, O3 | S | Tighten the test first and fix anything it then finds; then the docs table above. Moving `UserAuth` belongs here. |
| 6 | **Interface tidy-up** | Q4, Q5, Q6, W1-W4 | S-M | The narration fallback (Q4) also fixes the archived-recording visibility for admins. |
| 7 | **Office cache** | O1, O2 | S | Single-flight misses; a configurable table for tests. |
| 8 | **Dev tooling** | Tidewave, AshAi dev MCP | S | Dev-only dependencies; no production change. |
| 9 | **Trials** | Cinder, opentelemetry_ash | S each | Time-boxed. OpenTelemetry waits on choosing a trace backend. |
| 10 | **Later** | Reactor import, AshRateLimiter | M, S | After 4, once the import has settled on jobs. |

Decisions needed from the owner before work starts: whether REST should
refuse hidden sets for completions (A1, an iOS contract question), and
whether unpublished meditations stay publicly readable (A6).
