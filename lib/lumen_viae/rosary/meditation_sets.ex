defmodule LumenViae.Rosary.MeditationSets do
  @moduledoc """
  Secondary Context for meditation sets: every read and write of the
  `meditation_sets` table lives here and nowhere else.

  Queries here never join another resource's table. Visibility is the main
  place that matters: a set is hidden when one of its meditations is
  archived, so `list/1` takes the hidden ids as `:exclude_ids` and
  `LumenViae.Rosary` works out which ids those are.

  Private to `LumenViae.Rosary` - call the Primary Context instead of this
  module. See `docs/ARCHITECTURE.md` for the context rules.
  """

  import Ecto.Query

  alias LumenViae.Repo
  alias LumenViae.Rosary.MeditationSets.MeditationSet

  @doc """
  Number of meditations a set of the given category is expected to hold. The
  Seven Sorrows are prayed as seven; every other category is a five-decade
  Rosary.
  """
  def expected_meditation_count("seven_sorrows"), do: 7
  def expected_meditation_count(_category), do: 5

  def count do
    Repo.aggregate(MeditationSet, :count)
  end

  @doc """
  Lists sets in a deterministic order: by category, then by creation order.

  The order is part of the iOS API contract - the app builds its filter
  chips and sections from first appearance across the list response - so it
  must stay stable.

  ## Options

    * `:category` - only sets in this category
    * `:exclude_ids` - ids to leave out (used to hide sets with archived
      meditations from public surfaces)
  """
  def list(opts \\ []) do
    MeditationSet
    |> filter_category(opts[:category])
    |> filter_excluded(opts[:exclude_ids])
    |> order_by([ms], asc: ms.category, asc: ms.id)
    |> Repo.all()
  end

  defp filter_category(query, nil), do: query
  defp filter_category(query, category), do: where(query, [ms], ms.category == ^category)

  defp filter_excluded(query, nil), do: query
  defp filter_excluded(query, []), do: query

  defp filter_excluded(query, ids) do
    ids = if is_struct(ids, MapSet), do: MapSet.to_list(ids), else: ids
    where(query, [ms], ms.id not in ^ids)
  end

  def list_by_ids([]), do: []

  def list_by_ids(ids) do
    Repo.all(from ms in MeditationSet, where: ms.id in ^ids)
  end

  def get!(id), do: Repo.get!(MeditationSet, id)

  # The id column is a bigint, and a number outside its range is rejected by
  # the driver as an encoding error rather than as a missing row - which
  # reached a client as a 500 with a stacktrace for what is only a nonsense
  # URL.
  @id_range 1..9_223_372_036_854_775_807

  @doc """
  Non-raising sibling of `get!/1`. Returns nil for an id that does not
  exist, for one that is not an id at all, and for a number no id could ever
  be, so a caller working from a URL segment does not have to guard the cast
  itself.
  """
  def get(id) when is_integer(id) do
    if id in @id_range, do: Repo.get(MeditationSet, id), else: nil
  end

  def get(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> get(id)
      _not_an_id -> nil
    end
  end

  def get(_id), do: nil

  @doc """
  Fetches a set with its meditations preloaded in id order. Prefer
  `LumenViae.Rosary.get_meditation_set_with_ordered_meditations!/1` when the
  order the set is prayed in matters.
  """
  def get_with_meditations!(id) do
    set = MeditationSet |> Repo.get!(id) |> Repo.preload(:meditations)
    %{set | meditations: Enum.sort_by(set.meditations, & &1.id)}
  end

  def get_by_name(name), do: Repo.get_by(MeditationSet, name: name)

  @doc """
  Raises the same `Ecto.NoResultsError` a missing row would.

  Visibility is decided in `LumenViae.Rosary` because it spans resources,
  but a set hidden by an archived meditation has to 404 exactly like one
  that was never there - and only this module knows the schema, so the raise
  belongs here.
  """
  def raise_not_found! do
    raise Ecto.NoResultsError, queryable: MeditationSet
  end

  def preload_meditations(sets) do
    Repo.preload(sets, :meditations)
  end

  def create(attrs \\ %{}) do
    %MeditationSet{}
    |> MeditationSet.changeset(attrs)
    |> Repo.insert()
  end

  def update(%MeditationSet{} = set, attrs) do
    set
    |> MeditationSet.changeset(attrs)
    |> Repo.update()
  end

  def delete(%MeditationSet{} = set) do
    Repo.delete(set)
  end

  def change(%MeditationSet{} = set, attrs \\ %{}) do
    MeditationSet.changeset(set, attrs)
  end

  @doc """
  Records a completed artwork upload: the S3 key and the dimensions
  `LumenViae.Curation.ArtworkUpload` measured, plus any metadata supplied
  with it.
  """
  def update_artwork(%MeditationSet{} = set, attrs) do
    set
    |> MeditationSet.artwork_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Records the artwork metadata a curator typed. Cannot reach the key or the
  dimensions, so a crafted form post cannot repoint a set at another object
  or desync the size the iOS hero reserves its crop from.
  """
  def update_artwork_metadata(%MeditationSet{} = set, attrs) do
    set
    |> MeditationSet.artwork_metadata_changeset(attrs)
    |> Repo.update()
  end

  def change_artwork(%MeditationSet{} = set, attrs \\ %{}) do
    MeditationSet.artwork_metadata_changeset(set, attrs)
  end

  @doc """
  How many sets are still waiting for a painting, for the admin dashboard.

  No index backs this: the table holds 27 rows, so the planner would never
  choose one.
  """
  def count_missing_artwork do
    MeditationSet
    |> where([ms], is_nil(ms.image_key))
    |> Repo.aggregate(:count)
  end

  @doc """
  Builds a changeset for a set that does not exist yet, so callers can
  validate attributes without inserting (used by the CSV import's dry run
  and preview).
  """
  def change_new(attrs \\ %{}) do
    MeditationSet.changeset(%MeditationSet{}, attrs)
  end
end
