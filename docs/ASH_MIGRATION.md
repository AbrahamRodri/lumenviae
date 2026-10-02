# Moving the domain to Ash

What the branch `claude/ash-graphql-refactor-5d58e3` changes, what it
deliberately does not, and how to deploy it. It began as the working plan
for the sessions that did the work; the architecture it describes now
lives in docs/ARCHITECTURE.md. Delete this file once the branch has been
deployed and has settled.

## What changed

**The domain runs on Ash.** The seven hand-written Ecto contexts and their
schemas are gone. `LumenViae.Rosary` is an Ash domain over seven resources
mapped onto the existing tables exactly as they were (verified by building
the schema Ash would create and diffing it against the real one: every
column, index, constraint and sequence identical). Visibility, prayer
order, the byline and the artwork fallback are expressions and
calculations on the resources. Every caller (LiveViews, controllers,
curation services, mix tasks, the release module, seeds) goes through the
domain's code interface. docs/ARCHITECTURE.md describes the result, and
`context_rules_test.exs` enforces it.

**LiveView stays the UI.** Every page is still a LiveView; pages that
create or update a record use AshPhoenix forms (`Rosary.form_to_*`).

**The REST API is unchanged** by anything a shipped build reads. Its
contract is recorded in docs/IOS_API_CONTRACT.md and pinned by the
contract tests, which were hardened before the port began (about thirty
assertions from an audit of every shipped iOS build).

**Added:**

- **GraphQL** at `/api/graphql` (AshGraphql), alongside REST: the
  visible sets, set detail in prayer order, narration refresh, voices, the
  spoken Rosary, the Divine Office and completion recording. Its schema is
  committed and pinned. See docs/GRAPHQL.md.
- **AshPaperTrail**: a snapshot version of every change to meditations,
  sets, mysteries and authors, named by the action that made it.
- **AshAdmin** at `/admin/data`: a generic browser over every resource,
  behind the console's login.
- **UsageRules**: the Ash packages' guidance for coding agents, in
  docs/USAGE_RULES.md.

**Fixed along the way:**

- **The admin console could be reached without the password**, by live
  navigation from any public page. The site, the login and the console
  are now separate live sessions, and the console's mount hook refuses a
  socket without an admin session. Also shipped on its own as PR #38.
- Every LiveView form with `phx-change` has an id, so LiveView can restore
  it after a reconnect.
- A CSV update that corrected text after the last narration pause no
  longer drops the pause annotations it supplied.
- Deleting a mystery that still has meditations is an error and a flash,
  not a crashed page; the confirmation no longer promises a cascade the
  foreign key refuses.
- Two curation reports no longer crash on an untitled meditation whose
  mystery was not loaded.
- A test that failed whenever its seven-day window crossed a month.

**Changed on purpose:**

- **A set with no meditations is hidden**, like one holding an archived
  meditation: off the site and both APIs, its prayer page a 404 rather
  than a silent bounce home. The console names the two reasons a set is
  hidden, each with its own count and filter. (There are no empty sets in
  the current data.)
- **daisyUI is removed.** Its one live use, the console's flash toast, now
  has the console's own style. Every public page is pixel-identical; the
  compiled CSS falls from 217,869 to 126,468 bytes.
- Every dependency is on its latest release, including Phoenix 1.8 final,
  LiveView 1.2, gettext 1.0 and hackney 4, and the asset toolchain
  (Tailwind 4.3.3, esbuild 0.28.2, heroicons 2.2.0).

Admin-visible wording that changed: a missing required field reads "is
required" where it read "can't be blank"; forms keep what was typed when a
save fails; a blank focal point is refused rather than silently recentred.

## Deploying

1. **Merge PR #38 first, if it is not merged yet.** It is the security fix
   on its own, and should not wait for this branch. This branch contains
   the same commits, so merging it afterwards is clean.
2. **Confirm production Postgres is version 17 or newer.**
   `LumenViae.Repo.min_pg_version/0` says 17, and AshPostgres writes SQL to
   that version. Local development moved to 17 to match production, but
   check before the first deploy, through the IEx remote:
   `LumenViae.Repo.query!("select version()")`.
3. **Merge to `main`, which deploys.** Fly runs `/app/bin/migrate`
   (`LumenViae.Release.migrate/0`) before the new release starts. Three
   migrations, all additive:
   - `20261001112950_initialize_extensions_1` installs Ash's SQL helper
     functions (`ash_raise_error`, `ash_elixir_or` and the rest). No table.
   - `20261001114644_install_ash_required_function` installs one more,
     `ash_required`. No table. Upstream caveat: it is declared with
     `SET search_path = ''` and calls `ash_raise_error` unqualified, so its
     error branch would fail; AshPostgres does not call it on this app's
     path (it inlines a `CASE` unless the repo sets
     `immutable_expr_error?`). Do not turn that on without checking.
   - `20261001163951_add_paper_trail_versions` creates four tables,
     `meditations_versions`, `meditation_sets_versions`,
     `mysteries_versions` and `authors_versions`. No existing table is
     altered.
4. **Smoke test** once it is live:
   - `GET /api/meditation-sets?category=joyful`, one set's detail,
     `/api/voices` and `/api/rosary/audio` answer as before (the app
     depends on them).
   - `POST /api/graphql` with `{ voices { slug default } }` answers.
   - The console's dashboard loads; `/admin/data` loads behind the login;
     editing a set saves and leaves a row in `meditation_sets_versions`.
   - Open `/admin` from a public page in a fresh browser: it asks for the
     password.

**Rolling back** is redeploying the previous `main`. The migrations are
additive, so the old release runs against the new functions and tables
without noticing them. Nothing needs to be rolled back in the database.

### Admin accounts and policies

The branch that put AshAuthentication and Ash policies in (`claude/ash-auth-policies`)
replaces the shared `ADMIN_PASSWORD` with admin accounts. Deploy it in this
order:

1. **Check the app's Postgres role can create `citext`.** The first
   migration runs `CREATE EXTENSION IF NOT EXISTS "citext"`, which needs a
   superuser or the database owner. Through the IEx remote:
   `LumenViae.Repo.query!("select rolsuper from pg_roles where rolname = current_user")`
   and `LumenViae.Repo.query!("select * from pg_extension where extname = 'citext'")`.
   If the role cannot and the extension is not there, create it once as the
   `postgres` user (see docs/PROD_ACCESS.md, "If you need psql anyway")
   before deploying; the migration then does nothing.
2. **Merge to `main`, which deploys.** Two migrations, both additive:
   - `20261002023417_add_admin_accounts_extensions_1` installs `citext`.
   - `20261002023418_add_admin_accounts` creates `admins` and
     `admin_tokens`. No existing table is altered.
   No new secret is needed: the token signing key is derived from
   `SECRET_KEY_BASE` unless `TOKEN_SIGNING_SECRET` is set.
3. **Create the first admin straight away.** Until you do, nobody can sign
   in to the console; the public site and both APIs are unaffected.
   `LumenViae.Release.create_admin("you@example.com")`, as in
   docs/PROD_ACCESS.md, "Console admins". Copy the printed password.
4. **Smoke test**:
   - The iOS endpoints answer as before: `GET /api/meditation-sets?category=joyful`,
     one set's detail, `/api/voices`, `/api/rosary/audio`, and
     `POST /api/completions`.
   - `POST /api/graphql` with `{ voices { slug default } }` answers, and
     `recordCompletion` still records.
   - In a fresh browser, `/admin` and `/admin/data` send you to
     `/admin/login`; signing in opens the dashboard; editing a set saves;
     signing out and pressing Back does not reopen the console.
5. **Remove `ADMIN_PASSWORD` only once rolling back is off the table.**
   Leave it in place for the first days.
   `fly secrets unset ADMIN_PASSWORD --app lumenviae` when you are sure.

Rolling back is redeploying the previous `main`. The new tables are
ignored by the old release, but the old release signs in with
`ADMIN_PASSWORD`, and when that secret is missing it falls back to the
password `changeme` (`config/runtime.exs` on that release). So if you
roll back after step 5, set a strong one first, in the same breath:
`fly secrets set ADMIN_PASSWORD=<long random value> --app lumenviae`,
then redeploy. Never roll back with the secret unset.

## The repository after this

- New tables and columns come from `mix ash.codegen <name>`, never a
  hand-written migration. Read the generated migration before committing.
- Any change to what GraphQL exposes is a diff in
  `priv/graphql/schema.graphql`; regenerate it deliberately.
- docs/IOS_API_CONTRACT.md stays binding for as long as any installed
  build calls the REST API, whatever new builds call.
- Dev: `DEV_DATABASE=<copy>` runs a checkout against its own copy of the
  dev database; tests take `MIX_TEST_PARTITION`.

## Left for later

Asked for by the iOS review and deferred, because each needs a data
source or a new column rather than a change to how existing data is
served: an Office day's English feast name, rank label and liturgical
colour; an authored subtitle on a set; and each recording's size, so a
download can say what it will cost. Moving the iOS app to GraphQL is its
own project; the review recommends plain URLSession and Codable over
Apollo.
