defmodule LumenViae.Ops.Database do
  @moduledoc """
  The database as Postgres reports it: how big it is, which tables make it
  so, how many connections are open and how often a read is served from
  memory.

  Production's database is one small Fly machine (docs/PROD_ACCESS.md), so
  these are the numbers that say when it is outgrowing itself: the size
  against its volume, and the cache hit ratio, which falls once the
  working set no longer fits in its memory. Every query reads a catalog or
  a statistics view: none scans a table.
  """

  alias LumenViae.Repo

  @doc """
  Answers a map of `size_bytes`, `server_version`, `connections`,
  `max_connections`, `pool_size`, `cache_hit_ratio` (nil before anything
  has been read) and `tables` (the largest `:tables`, default 8, as
  `%{name:, bytes:, rows:}`, rows being Postgres's estimate).
  """
  def snapshot(opts \\ []) do
    limit = Keyword.get(opts, :tables, 8)

    %{
      size_bytes: value(Repo.query!("SELECT pg_database_size(current_database())")),
      server_version: value(Repo.query!("SHOW server_version")),
      connections:
        value(
          Repo.query!("SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()")
        ),
      max_connections: Repo.query!("SHOW max_connections") |> value() |> String.to_integer(),
      pool_size: Repo.config()[:pool_size],
      cache_hit_ratio:
        Repo.query!("""
        SELECT sum(heap_blks_hit)::float8
               / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0)
        FROM pg_statio_user_tables
        """)
        |> value(),
      tables: tables(limit)
    }
  end

  defp tables(limit) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT c.relname, pg_total_relation_size(c.oid), greatest(c.reltuples, 0)::bigint
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'r' AND n.nspname = 'public'
        ORDER BY 2 DESC
        LIMIT $1
        """,
        [limit]
      )

    Enum.map(rows, fn [name, bytes, rows] -> %{name: name, bytes: bytes, rows: rows} end)
  end

  defp value(%{rows: [[value]]}), do: value
end
