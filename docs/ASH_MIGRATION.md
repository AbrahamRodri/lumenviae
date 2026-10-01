# Moving the domain to Ash

The working plan for replacing the hand-written Ecto contexts with the Ash
framework and adding a GraphQL API. It is written for the sessions doing
the work and is deleted, or folded into docs/ARCHITECTURE.md, when the
migration lands.

## What changes and what does not

**Ash takes the domain, data and API layers.** Resources, actions,
validations, relationships, aggregates, calculations, the Postgres data
layer and the GraphQL API.

**Phoenix LiveView stays the UI.** Every page stays a LiveView. Ash does
not replace it; it gives the LiveViews a better domain to call. Use the
tool that is best at each job:

- Forms: `AshPhoenix.Form` (through the domain's `form_to_*` functions)
  wherever a page creates or updates a record. It replaces hand-built
  changesets and keeps validation in the resource.
- Interaction, streaming, uploads, the prayer flow, filtering an
  already-loaded admin list: plain LiveView, exactly as today.
- Presentation-only helpers stay next to their LiveView (see
  docs/ARCHITECTURE.md, "View-model helpers").

**The REST API under `/api` does not change.** The iOS app in the wild
decodes it with non-optional Swift properties. Every response keeps its
keys, types, ordering, status codes and headers. The controllers and JSON
views stay; only what they call underneath changes.
`test/lumen_viae_web/controllers/api/contract_test.exs` is the guarantee.
docs/IOS_API_CONTRACT.md records exactly what every shipped build decodes,
and its gap list is being turned into tests before the port lands.

**GraphQL is added alongside, not instead.** `/api/graphql` (AshGraphql on
Absinthe), with GraphiQL in development.

## The team

| Session | Model | Owns |
| --- | --- | --- |
| Ash refactor - manager (integration) | Opus 5.5 | this plan, the integration branch, all merges, GraphQL, policies, final cleanup |
| Ash refactor - Fable (Rosary domain) | Fable 5.1 | the Rosary domain port, its LiveView forms, the curation services |
| Ash refactor - Sonnet (small tasks) | Sonnet 5.5 | small, well-bounded tasks the manager hands out one at a time |
| Ash refactor - iOS API contract | Opus 5.5 | read-only audit of what the iOS app depends on; GraphQL client review |

## Branches

- **Integration branch:** `claude/ash-graphql-refactor-5d58e3`. Everything
  merges here, and only the manager merges. It is not merged to `main`
  until the whole migration is done, the full suite is green and the user
  has approved it. Merging to `main` deploys.
- **Work branches:** each session works in its own worktree on its own
  branch, started from the integration branch:

  ```
  git fetch . claude/ash-graphql-refactor-5d58e3 2>/dev/null; git reset --hard claude/ash-graphql-refactor-5d58e3
  ```

  (Do that only in a fresh worktree with nothing in it. The worktrees share
  one `.git`, so the integration branch is visible locally without a
  remote.)
- **Handing work back:** commit on your branch, run the full suite, then
  message the manager with the branch name, the commit range and the test
  result. Do not merge into the integration branch yourself.
- **Picking up others' work:** when the manager says the integration
  branch has moved, `git rebase claude/ash-graphql-refactor-5d58e3` (or
  merge it in) before continuing.
- Never use bare `git stash`. The stash is shared across worktrees.
- **Tests run against your own database.** Every worktree shares one
  Postgres server, so give each session its own test partition:
  `MIX_TEST_PARTITION=_fable mix test`, `_sonnet`, and so on.

## House rules (from CLAUDE.md, restated because they bite)

- No emojis anywhere: code, comments, docs, commit messages.
- No `Co-Authored-By` Claude line on commits or PRs.
- Run `mix format` only on files you touched. The repo is not
  format-clean, and a bare `mix format` churns unrelated files.
- Never touch production: no `fly`, no prod database, no S3 writes, no
  ElevenLabs calls.
- Fix general problems you find along the way, in their own commits, and
  say so in your hand-back message.
- Keep the module docs. This codebase explains *why* in its moduledocs;
  carry those explanations over to the resource that replaces a schema or
  context. Do not drop them.

## Target shape

### The domain

`LumenViae.Rosary` becomes an `Ash.Domain`. It stays the domain's only
public entry point, the same rule as today, now expressed as Ash code
interfaces (`define` inside the `resources` block) instead of
`defdelegate`. Composition that cannot be an action, calculation or
aggregate stays as an ordinary function on the domain module.

Resources live directly under `lib/lumen_viae/rosary/`, one file each:

| Resource | Table | Replaces |
| --- | --- | --- |
| `LumenViae.Rosary.Mystery` | `mysteries` | `Mysteries` + `Mysteries.Mystery` |
| `LumenViae.Rosary.Meditation` | `meditations` | `Meditations` + `Meditations.Meditation` |
| `LumenViae.Rosary.MeditationSet` | `meditation_sets` | `MeditationSets` + `MeditationSets.MeditationSet` |
| `LumenViae.Rosary.SetMembership` | `meditation_set_meditations` | `SetMemberships` + `SetMemberships.SetMembership` |
| `LumenViae.Rosary.Completion` | `rosary_completions` | `Completions` + `Completions.Completion` |
| `LumenViae.Rosary.Author` | `authors` | `Authors` + `Authors.Author` |
| `LumenViae.Rosary.Narration` | `meditation_narrations` | `Narrations` + `Narrations.Narration` |

The value modules (`Categories`, `Labels`, `Artwork`, `Voices`,
`PrayerAudio`) stay. `Artwork`'s two changesets become two update actions
on each resource that carries artwork, with the same accept lists, so the
managed fields stay out of reach of the metadata form.

### The rules, restated for Ash

The old rules were about keeping queries in one place. Ash keeps them in
the resource by construction, so the rules become:

1. **Nothing outside `lib/lumen_viae/rosary/` names a Rosary resource.**
   Outside code calls `LumenViae.Rosary` code interfaces and the value
   modules. LiveView forms use `Rosary.form_to_<action>` (the `AshPhoenix`
   domain extension), never `AshPhoenix.Form.for_create(Resource, ...)`.
2. **Nothing calls `Ash.read/create/update/destroy` on a Rosary resource
   from outside the domain.** Add a code interface instead.
3. **Nothing touches `Repo` or `Ecto.Query` for Rosary data.** Queries
   are read actions, filters, preparations, aggregates and calculations on
   the resource. Raw SQL is a `fragment` inside the resource that owns it.
   `release.ex` keeps `Ecto.Migrator`.
4. **Cross-resource composition uses relationships.** The old rule
   (never join; compose ids in Elixir) existed because Ecto made joins
   hand-written. Ash expressions (`exists/2`, aggregates, relationship
   paths) are declared once on the resource and cannot drift. Visibility,
   prayer order, attribution and the reporting figures should become
   expressions, aggregates or calculations where they can.

`test/lumen_viae/rosary/context_rules_test.exs` is rewritten to enforce
these four rules at the end of the migration (manager), and
docs/ARCHITECTURE.md is updated with it.

### Mapping onto the existing tables

The resources map onto the tables exactly as they exist. **No migration
may alter an existing table as part of the port.**

- `integer_primary_key :id`. The ids are integers and the iOS app decodes
  them as `Int`.
- Timestamps: the tables have `timestamp(0) without time zone`
  `inserted_at`/`updated_at` from Ecto's `timestamps()`. Match the type
  (naive datetime) rather than Ash's default `utc_datetime_usec`.
  `rosary_completions` has no `updated_at`.
- Ecto `:string` columns are `varchar(255)`. Give those attributes
  `constraints max_length: 255` so an over-long value fails validation
  instead of failing in Postgres. `:text` columns get no limit.
- `meditations.tts_annotations` is `jsonb[]` (`{:array, :map}`),
  `meditation_sets.labels` is `varchar(255)[]`, both `NOT NULL DEFAULT '{}'`.
- Foreign keys and their `on_delete` go in each resource's
  `postgres do references do ... end end`, matching the migrations:
  meditations -> mysteries `restrict`; memberships, completions and
  narrations -> their parent `delete_all`; meditation_sets -> authors
  `nilify_all`.
- Unique indexes become `identities`: mysteries `[category, order]`,
  memberships `[meditation_set_id, meditation_id]` and
  `[meditation_set_id, order]`, narrations `[meditation_id, voice]`,
  authors `[name]`.
- Generate snapshots, not migrations, for the existing tables:
  `mix ash_postgres.generate_migrations --snapshots-only`. Afterwards
  `mix ash_postgres.generate_migrations --check` must report nothing to
  do. Any new table from here on (paper trail versions, for example) is
  generated with `mix ash.codegen <name>`.

### Contract hazards Ash defaults would introduce

Found by the iOS audit. Each one passes the current tests and breaks
installed builds, so none of them is up for discussion:

- **Integer ids, unchanged.** Never `uuid_primary_key`. The app decodes
  every id as `Int` and stores them on the device: pinned sets, offline
  files named `meditation_<id>_<voice>.mp3`, the resume snapshot.
- **`image_focal_x` / `image_focal_y` stay `:float`.** A `:decimal` is
  encoded by Jason as a JSON string, Swift's `Double?` fails on it, and
  that fails the whole set list, not only the painting.
- **`category` serialises as the same strings** (`joyful`, `sorrowful`,
  `glorious`, `luminous`, `seven_sorrows`) whatever type backs it.
  **`days_prayed` stays a string or null**, never a list.
- **No pagination on any read behind the REST API.** `config :ash,
  default_page_type: :keyset` only applies to actions that declare
  `pagination`, and a paginated set list would quietly return one page to
  an app that never pages.
- **Expiry strings keep their exact form**, `YYYY-MM-DDTHH:MM:SSZ`: no
  fractional seconds, always `Z`. The app parses `audio_expires_at` and
  both `expires_at` fields with `ISO8601DateFormatter` defaults, which
  reject fractional seconds, and a naive datetime (no zone) fails every
  Swift parser. Serialise from a truncated `DateTime`, as today.
- **Order is explicit.** Sets in creation order, meditations in
  `set_memberships.order`, default voice first. An Ash read with no
  `sort` returns heap order, which matches insertion order in a test and
  drifts in production. Every read the API depends on declares its sort.

### Authorization

No policies during the port. The manager adds `Ash.Policy.Authorizer`
and policies when GraphQL exposes each resource: public reads of visible
content, the completion create, and admin-only writes. Internal callers
(LiveViews behind `RequireAdmin`, mix tasks, curation services, release
tasks) keep working without an actor. The exact mechanism is decided in
the GraphQL phase and documented here.

### Errors

The API's error envelope must not change
(`test/lumen_viae_web/controllers/api/error_envelope_test.exs`). The
fallback controller learns to render `Ash.Error.Invalid` the way it
renders an `Ecto.Changeset` today. A missing record must still be a 404
on every surface: LiveView `get_*!` routes, `/api/meditation-sets/:id`
for missing and hidden sets alike.

## Phases

### Phase 0 - foundation (manager) - done

All dependencies on their latest releases. Ash, AshPostgres, AshPhoenix,
AshGraphql, Absinthe Plug, AshAdmin, AshPaperTrail, Igniter and
UsageRules added. `LumenViae.Repo` is an `AshPostgres.Repo` (still an
`Ecto.Repo`, so the existing contexts run unchanged). The suite is green.

### Phase 1 - resources alongside the old contexts (Fable)

All seven resources, mapped onto their tables, registered in the domain,
with snapshots generated and nothing else changed. The old Secondary
Contexts and schemas keep serving everything, so the app behaves
identically and the suite stays green. Each resource gets
`extensions: [AshGraphql.Resource]` and a `graphql do type :<snake_name>
end` block so the GraphQL work can start without editing these files.

Hand back as soon as this milestone is green: the GraphQL work waits on
it.

### Phase 2 - port the domain (Fable)

Resource by resource, move every `LumenViae.Rosary` function onto Ash:
replace each `defdelegate` with a code interface or a function built on
actions, port the composition functions, then the LiveView forms
(AshPhoenix), the API fallback controller, the curation services, mix
tasks, `release.ex` and `priv/repo/seeds.exs`. Keep public function names
where the meaning is unchanged so callers move as little as possible.

**Do not delete** a Secondary Context or Ecto schema until nothing
references it. The Ecto schemas reference each other through
associations, so deleting one early breaks the others. Delete them all
together at the end of the phase.

Hand back in milestones, each green: (a) Mystery and Author,
(b) Meditation, Narration and SetMembership, (c) MeditationSet
(visibility, prayer order, attribution, artwork fallback),
(d) Completion and the analytics, (e) curation services, tasks and
cleanup.

### Phase 3 - GraphQL (manager, alongside Phase 2)

The Office domain moves to Ash first: it owns no tables, so its hours,
days and calendar become generic actions on resources with no data
layer, which is what AshGraphql needs in order to expose them. It does
not depend on the Rosary port, so it starts immediately.


`/api/graphql` and GraphiQL at `/dev/graphiql` in development. Public
queries for visible sets, set detail in prayer order with signed
narration URLs, mysteries, voices, the spoken Rosary manifest, and the
Divine Office; the completion mutation, with the same crawler guard and
rate limit as `POST /api/completions`. Policies arrive with each exposed
resource. Every query gets a test.

### Phase 4 - easy wins (manager, with Sonnet on bounded pieces)

- **AshAdmin** at `/admin/data`, behind `RequireAdmin`: a generic
  browser over every resource, for the cases the console has no screen
  for. It brings its own look, which is acceptable for a power tool off
  the console's navigation.
- **AshPaperTrail** on Meditation, MeditationSet, Mystery and Author: a
  version row for every change, so an edit to a saint's verbatim text
  can always be seen and reversed. New tables via `mix ash.codegen`.
- **UsageRules**: the Ash packages' own guidance for coding agents,
  synced into `docs/USAGE_RULES.md` and linked from CLAUDE.md.

Considered and left out, for now:

- **AshArchival**: it hides archived rows from every read, but archived
  meditations stay visible to the admin and only hide the sets that hold
  them. The semantics do not match.
- **AshJsonApi**: produces JSON:API documents, not the shapes the iOS
  app decodes. It cannot serve the existing API.
- **AshAuthentication**: the admin login is one shared password. Real
  accounts are a feature, not a refactor.
- **AshOban**: the app has no Oban and no job that needs one yet.

### Phase 5 - finish (manager)

Rewrite `context_rules_test.exs` for the Ash rules, update
docs/ARCHITECTURE.md, CLAUDE.md and the other docs that name the old
modules, run the full suite and the `verify` skill against the running
app, check the release build, then ask the user before anything merges
to `main`.

## Deploy notes

- `priv/repo/migrations/20261001112950_initialize_extensions_1.exs`
  installs Ash's SQL helper functions (`ash-functions`). It runs on
  deploy with the other migrations and touches no table.
- `LumenViae.Repo.min_pg_version/0` is 17, matching production.
