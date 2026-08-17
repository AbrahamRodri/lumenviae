defmodule LumenViae.Rosary.Completions do
  @moduledoc """
  Secondary Context for rosary completions: every read and write of the
  `rosary_completions` table lives here and nowhere else.

  Completions are only ever reported alongside the set that was prayed, but
  this module returns set *ids*; `LumenViae.Rosary` looks the sets up in
  `LumenViae.Rosary.MeditationSets` and joins the two in memory.

  Private to `LumenViae.Rosary` - call the Primary Context instead of this
  module. See `docs/ARCHITECTURE.md` for the context rules.
  """

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.Completions.Completion

  def create(attrs \\ %{}) do
    %Completion{}
    |> Completion.changeset(attrs)
    |> Repo.insert()
  end

  def count do
    Repo.aggregate(Completion, :count)
  end

  def count_in_range(start_at, end_at) do
    from(rc in Completion, where: rc.completed_at >= ^start_at and rc.completed_at <= ^end_at)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns `[{set_id, count}]` for every set that has been completed at least
  once, most completed first.
  """
  def count_by_set do
    Repo.all(
      from rc in Completion,
        group_by: rc.meditation_set_id,
        select: {rc.meditation_set_id, count(rc.id)},
        order_by: [desc: count(rc.id)]
    )
  end

  @doc """
  The most recent completions, newest first.
  """
  def list_recent(limit) do
    Repo.all(
      from rc in Completion,
        order_by: [desc: rc.completed_at],
        limit: ^limit
    )
  end
end
