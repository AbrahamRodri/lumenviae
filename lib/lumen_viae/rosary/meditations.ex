defmodule LumenViae.Rosary.Meditations do
  @moduledoc """
  Secondary Context for meditations: every read and write of the
  `meditations` table lives here and nowhere else.

  Queries here never join another resource's table. Where a meditation
  question depends on set membership (which sets is it in? is it in any
  set?), this module takes or returns plain ids and `LumenViae.Rosary`
  composes the answer with `LumenViae.Rosary.SetMemberships`.

  Private to `LumenViae.Rosary` - call the Primary Context instead of this
  module. See `docs/ARCHITECTURE.md` for the context rules.
  """

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.Meditations.Meditation

  def count do
    Repo.aggregate(Meditation, :count)
  end

  def list do
    Meditation |> Repo.all() |> Repo.preload(:mystery)
  end

  @doc """
  Lists every meditation with its mystery and meditation sets preloaded.

  Used by the admin meditations list so each row can show set membership
  and be filtered by it.
  """
  def list_with_sets do
    from(m in Meditation, order_by: [asc: m.id])
    |> Repo.all()
    |> Repo.preload([:mystery, :meditation_sets])
    |> Enum.map(&%{&1 | meditation_sets: Enum.sort_by(&1.meditation_sets, fn s -> s.id end)})
  end

  @doc """
  Fetches the given meditations, with mysteries preloaded, in the order the
  ids were given. Ids with no matching row are dropped.
  """
  def list_by_ids([]), do: []

  def list_by_ids(ids) do
    by_id =
      from(m in Meditation, where: m.id in ^ids)
      |> Repo.all()
      |> Repo.preload(:mystery)
      |> Map.new(&{&1.id, &1})

    Enum.flat_map(ids, fn id ->
      case Map.fetch(by_id, id) do
        {:ok, meditation} -> [meditation]
        :error -> []
      end
    end)
  end

  def get(id) do
    case Repo.get(Meditation, id) do
      nil -> nil
      meditation -> Repo.preload(meditation, :mystery)
    end
  end

  def get!(id) do
    Meditation |> Repo.get!(id) |> Repo.preload(:mystery)
  end

  def create(attrs \\ %{}) do
    %Meditation{}
    |> Meditation.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Meditation{} = meditation, attrs) do
    meditation
    |> Meditation.changeset(attrs)
    |> Repo.update()
  end

  def delete(%Meditation{} = meditation) do
    Repo.delete(meditation)
  end

  def change(%Meditation{} = meditation, attrs \\ %{}) do
    Meditation.changeset(meditation, attrs)
  end

  @doc """
  Builds a changeset for a meditation that does not exist yet, so callers
  can validate attributes without inserting (used by the CSV import's dry
  run and preview).
  """
  def change_new(attrs \\ %{}) do
    Meditation.changeset(%Meditation{}, attrs)
  end

  @doc """
  Archives a meditation without deleting it.

  Archived meditations stay fully editable in the admin, but they are
  excluded from every public surface, and any set containing one is hidden
  from public listings and the API.
  """
  def archive(%Meditation{} = meditation) do
    meditation
    |> Ecto.Changeset.change(archived_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc """
  Restores an archived meditation, making it (and its sets) public again.
  """
  def unarchive(%Meditation{} = meditation) do
    meditation
    |> Ecto.Changeset.change(archived_at: nil)
    |> Repo.update()
  end

  def archived?(%{archived_at: archived_at}), do: not is_nil(archived_at)

  def list_archived_ids do
    Repo.all(from m in Meditation, where: not is_nil(m.archived_at), select: m.id)
  end

  def count_archived do
    from(m in Meditation, where: not is_nil(m.archived_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Counts active (non-archived) meditations that have no audio file yet.
  """
  def count_active_missing_audio do
    from(m in Meditation,
      where: is_nil(m.archived_at) and (is_nil(m.audio_url) or m.audio_url == "")
    )
    |> Repo.aggregate(:count)
  end

  def count_excluding_ids([]), do: count()

  def count_excluding_ids(ids) do
    from(m in Meditation, where: m.id not in ^ids)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns a map of mystery_id => meditation count for every mystery that has
  at least one meditation.
  """
  def count_by_mystery do
    from(m in Meditation, group_by: m.mystery_id, select: {m.mystery_id, count(m.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns `%{meditation_id => %{audio?: boolean, archived?: boolean}}` for
  every meditation, so per-set statistics can be folded together without a
  cross-table aggregate.
  """
  def list_audio_and_archive_flags do
    from(m in Meditation, select: {m.id, m.audio_url, m.archived_at})
    |> Repo.all()
    |> Map.new(fn {id, audio_url, archived_at} ->
      {id, %{audio?: audio_url not in [nil, ""], archived?: not is_nil(archived_at)}}
    end)
  end

  @doc """
  Returns whichever of the given S3 keys are already claimed by a
  meditation, so an import can warn before it overwrites their audio.
  """
  def list_taken_audio_urls([]), do: []

  def list_taken_audio_urls(audio_urls) do
    Repo.all(from m in Meditation, where: m.audio_url in ^audio_urls, select: m.audio_url)
  end
end
