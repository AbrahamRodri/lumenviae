# Production Access

How to inspect and edit production data for the `lumenviae` Fly app.

The standing default for both reports and edits is a **remote IEx shell
against the running release**, using the app's own context modules. There is
no separate database user and no direct `psql` access by default.

Rationale: `LumenViae.Rosary` and friends already expose the queries reports
need, and writes go through Ecto changesets, so app invariants (label
vocabulary, category inclusion, meditation set ordering) are enforced. Raw
SQL bypasses all of it - an `UPDATE` on `meditation_set_meditations` can
silently corrupt set ordering in a way nothing notices until someone prays
that set.

## Prerequisite

`flyctl` must be authenticated on the machine running the commands. This
opens a browser, so it cannot be delegated:

```
flyctl auth login
```

Verify with `fly auth whoami`.

Machines do not auto-stop (`auto_stop_machines = 'off'`,
`min_machines_running = 1` in fly.toml), so a machine is always available
to ssh into.

## Opening the shell

```
fly ssh console --app lumenviae
/app/bin/lumen_viae remote
```

This attaches to the running node. `Ctrl+C Ctrl+C` detaches. Detaching does
not stop the app, but do not run `System.halt/0` - that kills the node.

For a single command without an interactive session, use `rpc`, which runs
the expression on the running node with the application (and the Repo)
already started:

```
fly ssh console --app lumenviae -C "/app/bin/lumen_viae rpc 'IO.inspect(LumenViae.Rosary.count_meditations())'"
```

`eval` is different: it boots a separate node WITHOUT starting the
application, so context functions crash there with "could not lookup Ecto
repo LumenViae.Repo because it was not started". Use `eval` only for the
`LumenViae.Release.*` tasks, which start the repo themselves via
`Ecto.Migrator.with_repo`. For everything else: `rpc` for one-off reads,
`remote` for exploration.

If the app ever runs more than one machine, pin commands to a specific one
with `--machine <id>` (`fly machine list` shows ids) - /tmp and shell state
are per-machine.

## Reports (read-only)

Use the context functions rather than writing queries where one exists:

```elixir
alias LumenViae.Rosary

Rosary.count_mysteries()
Rosary.count_meditations()
Rosary.count_meditation_sets()
Rosary.count_archived_meditations()
Rosary.count_active_meditations_missing_audio()
Rosary.count_meditations_not_in_any_set()

# Per-set meditation counts, keyed by set id
Rosary.meditation_set_stats()

# Completions
Rosary.count_total_completions()
Rosary.count_completions_today()
Rosary.count_completions_last_days(30)
Rosary.get_completions_by_set()
Rosary.get_recent_completions(10)
```

Set completeness, for finding sets with the wrong number of meditations:

```elixir
stats = Rosary.meditation_set_stats()
count = fn set -> get_in(stats, [set.id, :meditation_count]) || 0 end

Rosary.list_meditation_sets()
|> Enum.reject(&(count.(&1) == Rosary.expected_meditation_count(&1.category)))
|> Enum.map(&{&1.name, &1.category, count.(&1)})
```

Meditation counts per category, composed from context functions rather than
a query:

```elixir
counts = Rosary.meditation_counts_by_mystery()

Rosary.list_mysteries()
|> Enum.group_by(& &1.category)
|> Map.new(fn {category, mysteries} ->
  {category, mysteries |> Enum.map(&Map.get(counts, &1.id, 0)) |> Enum.sum()}
end)
```

If no context function fits, add one rather than writing a query in the
shell. `LumenViae.Rosary` is the only way into the domain (see
docs/ARCHITECTURE.md), and a one-off `Repo.all` here is both unreviewed and
unrepeatable.

## Edits

Prefer the admin UI at https://www.lumenviae.org/admin for routine content
work. It exists for this and goes through the same validations.

Use the shell only when the admin UI cannot express the change. When you do:

1. Confirm a recent snapshot exists on the Postgres app's volume (the
   lumenviae app itself has no volumes, and the snapshots subcommand
   requires a volume id):

   ```
   fly volumes list --app <postgres-app-name>
   fly volumes snapshots list <volume-id> --app <postgres-app-name>
   ```
2. Read the current value first, so the change can be reversed by hand.
3. Go through `LumenViae.Rosary`, never `Repo.update_all/2` or raw SQL. The
   context functions run the same validations the admin UI does.

```elixir
set = Rosary.get_meditation_set!(42)
set.description

Rosary.update_meditation_set(set, %{description: "..."})
```

Rules for anyone (including Claude) operating this shell:

- Never run destructive statements without explicit, specific confirmation
  of the exact statement. A general "go ahead" does not cover deletes.
- Never `Repo.delete_all/1` or `TRUNCATE`.
- Do not print secrets. Check presence only, e.g. `System.get_env("X") != nil`.

## Seeding and imports

Seeding is idempotent (matched on category + order, existing rows skipped):

```
fly ssh console --app lumenviae -C "/app/bin/seed"
```

Note: `rel/overlays/bin/seed` sets `RESET_DB=true FORCE_SEED=true`. Neither
variable is read anywhere in the codebase today, so the script is safe, but
do not wire those names up to destructive behavior without renaming them
first.

CSV imports have their own workflow, including the mandatory dry run - see
[CSV_IMPORT_GUIDE.md](CSV_IMPORT_GUIDE.md) and the `/import-meditations`
command.

## If you need psql anyway

For heavy analytical queries where IEx is awkward, tunnel to the database
and use a read-only role rather than the app's credentials:

```
fly proxy 15432:5432 --app <postgres-app-name>
```

First confirm the actual database and app-role names rather than assuming
them (Fly Postgres may name the database after the app, e.g. `lumenviae`):

```sql
\l
SELECT current_database(), current_user;
```

Then, substituting the confirmed names:

```sql
CREATE ROLE claude_ro LOGIN PASSWORD '...';
GRANT CONNECT ON DATABASE <database> TO claude_ro;
GRANT USAGE ON SCHEMA public TO claude_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO claude_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE <app-role> IN SCHEMA public
  GRANT SELECT ON TABLES TO claude_ro;
```

The `FOR ROLE <app-role>` clause matters: without it, the default applies
only to tables created by the admin role running the statement. Tables
created by future migrations run as the app's DATABASE_URL role, so
omitting the clause leaves every new table unreadable by claude_ro.

Do NOT put the connection string in `.env`: dev.sh exports every line of
that file into each local dev server's environment, which would hand prod
credentials to the dev app (and its `export $(cat .env | xargs)` mangles
values containing spaces). Keep it in a separate gitignored file such as
`.env.prod-ro` and source it only in the shell session doing the reporting:

```
source .env.prod-ro && psql "$DATABASE_RO_URL" -c '...'
```
