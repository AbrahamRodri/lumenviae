defmodule LumenViae.Repo.Migrations.AddObanJobs do
  use Ecto.Migration

  @moduledoc """
  Oban's own tables: `oban_jobs` and the unlogged `oban_peers`, with the
  `oban_job_state` type and their indexes.

  Hand-written because these are not Ash resources, so `mix ash.codegen`
  knows nothing about them; Oban's migrations are the only supported way
  to create them. The version is pinned, so a later Oban release that adds
  a migration version changes nothing until a new migration asks for it.

  Every statement runs against empty tables, so the migration is quick and
  takes no lock anybody is waiting on. See docs/ARCHITECTURE.md,
  "Background jobs".
  """

  def up, do: Oban.Migration.up(version: 14)

  # Down to nothing: removes the tables, and every job in them, outright.
  def down, do: Oban.Migration.down(version: 1)
end
