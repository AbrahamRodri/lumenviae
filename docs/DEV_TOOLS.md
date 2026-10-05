# Development tools

Three tools for looking inside the running app. Two are development only and
never reach a release; the third is a page of the admin LiveDashboard and
runs everywhere.

| Tool | Where | Environments |
| --- | --- | --- |
| Tidewave | `/tidewave/mcp` on the dev server, and `.mcp.json` | dev |
| LiveDebugger | its own server, `http://127.0.0.1:4007` (or the next free port) | dev |
| Ecto Stats (ecto_psql_extras) | `/admin/live/ecto_stats` | every one |

## Tidewave

An MCP server inside the running Phoenix app, for coding agents. Instead of
reading files and guessing, an agent can evaluate Elixir in the app
(`project_eval`), run SQL against the database the server is using
(`execute_sql_query`), read the server's log, and look up docs and source
locations for the exact versions in `mix.lock`.

It is plugged into `LumenViaeWeb.Endpoint` inside `if Mix.env() == :dev`,
and the dependency is `only: :dev`, so a release has neither. It answers
requests from loopback only.

`.mcp.json` registers it with Claude Code through `mix tidewave.proxy`, a
stdio server that adds a `port` argument to every tool and forwards the call
to the app on that port. That is what makes it work across worktrees, each
of which runs its server on its own `PORT`: tell the agent which port yours
is on. The proxy needs the dev dependencies compiled in the checkout it is
started from (`mix deps.get && mix compile`).

`project_eval` runs with no actor and no policy check unless the code passes
one. Treat it like an IEx session on your laptop: it can write to whatever
database `DEV_DATABASE` points at.

## LiveDebugger

A browser tool for LiveView: the component tree of a page, each process's
assigns as they change, and every callback with its arguments and timing.
Open `http://127.0.0.1:4007` while the dev server runs, or install the
Chrome or Firefox extension and use the DevTools panel.

The two root layouts (`root.html.heex` and `root_admin.html.heex`) render
`Application.get_env(:live_debugger, :live_debugger_tags)`, which is set only
when LiveDebugger is running and renders nothing otherwise. It adds a debug
button to each page and the element inspector.

`config/dev.exs` sets `auto_port: true`. With several worktrees each running
a server, the second would otherwise fail to start LiveDebugger on 4007; it
now takes 4008, and so on. The startup log names the port.

Compiling it prints a handful of `undefined attribute "type"` warnings from
the library's own templates. They are in the dependency, not in this app,
and do not affect `mix compile --warnings-as-errors`, which checks only this
app's code.

## Ecto Stats

`ecto_psql_extras` adds an Ecto Stats page to the LiveDashboard at
`/admin/live`, behind the console's guard like the rest of it. Its
Diagnose tab is the place to start: missing foreign key indexes, unused and
duplicate indexes, bloat, and cache hit ratios. The other tabs list table
and index sizes, vacuum stats, sequential scans, locks, blocking queries and
long-running queries.

It reads Postgres's own statistics and changes nothing. Two checks need
extensions the database does not have: `outliers` needs
`pg_stat_statements`, and `ssl_used` needs `sslinfo`. Both report themselves
as not enabled rather than failing.

On production, remember the database is one small Fly machine: the queries
are cheap, but do not leave the page polling on a short refresh interval.
