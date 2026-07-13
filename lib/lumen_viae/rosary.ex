defmodule LumenViae.Rosary do
  @moduledoc """
  The Rosary context.
  """

  import Ecto.Query, warn: false
  alias LumenViae.Repo

  alias LumenViae.Rosary.{
    Mystery,
    Meditation,
    MeditationSet,
    MeditationSetMeditation,
    RosaryCompletion
  }

  ## Mysteries

  def count_mysteries do
    Repo.aggregate(Mystery, :count)
  end

  def list_mysteries do
    Repo.all(from m in Mystery, order_by: [m.category, m.order])
  end

  def list_mysteries_by_category(category) do
    Repo.all(from m in Mystery, where: m.category == ^category, order_by: m.order)
  end

  def get_mystery!(id), do: Repo.get!(Mystery, id)

  def create_mystery(attrs \\ %{}) do
    %Mystery{}
    |> Mystery.changeset(attrs)
    |> Repo.insert()
  end

  def update_mystery(%Mystery{} = mystery, attrs) do
    mystery
    |> Mystery.changeset(attrs)
    |> Repo.update()
  end

  def change_mystery(%Mystery{} = mystery, attrs \\ %{}) do
    Mystery.changeset(mystery, attrs)
  end

  def delete_mystery(%Mystery{} = mystery) do
    Repo.delete(mystery)
  end

  ## Meditations

  def count_meditations do
    Repo.aggregate(Meditation, :count)
  end

  def list_meditations do
    Repo.all(Meditation) |> Repo.preload(:mystery)
  end

  @doc """
  Lists every meditation with its mystery and meditation sets preloaded.

  Used by the admin meditations list so each row can show set membership
  and be filtered by it.
  """
  def list_meditations_with_sets do
    Repo.all(from m in Meditation, order_by: [asc: m.id])
    |> Repo.preload([:mystery, meditation_sets: from(ms in MeditationSet, order_by: ms.id)])
  end

  def list_meditations_by_mystery(mystery_id) do
    Repo.all(from m in Meditation, where: m.mystery_id == ^mystery_id)
  end

  def get_meditation!(id) do
    Repo.get!(Meditation, id) |> Repo.preload(:mystery)
  end

  def create_meditation(attrs \\ %{}) do
    %Meditation{}
    |> Meditation.changeset(attrs)
    |> Repo.insert()
  end

  def update_meditation(%Meditation{} = meditation, attrs) do
    meditation
    |> Meditation.changeset(attrs)
    |> Repo.update()
  end

  def change_meditation(%Meditation{} = meditation, attrs \\ %{}) do
    Meditation.changeset(meditation, attrs)
  end

  def delete_meditation(%Meditation{} = meditation) do
    Repo.delete(meditation)
  end

  @doc """
  Archives a meditation without deleting it.

  Archived meditations stay fully editable in the admin, but they are
  excluded from every public surface, and any set containing one is hidden
  from public listings and the API (see the `visible` set functions).
  """
  def archive_meditation(%Meditation{} = meditation) do
    meditation
    |> Ecto.Changeset.change(archived_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc """
  Restores an archived meditation, making it (and its sets) public again.
  """
  def unarchive_meditation(%Meditation{} = meditation) do
    meditation
    |> Ecto.Changeset.change(archived_at: nil)
    |> Repo.update()
  end

  @doc """
  Generates a pre-signed URL for a meditation's audio file.

  Returns the pre-signed URL string if the meditation has an audio_url (S3 key),
  or nil if no audio is available or if URL generation fails.

  ## Examples

      iex> get_meditation_audio_url(%Meditation{audio_url: "meditation1.mp3"})
      "https://lumenviae-audio.s3.us-east-2.amazonaws.com/meditation1.mp3?..."

      iex> get_meditation_audio_url(%Meditation{audio_url: nil})
      nil
  """
  def get_meditation_audio_url(%Meditation{audio_url: nil}), do: nil
  def get_meditation_audio_url(%Meditation{audio_url: ""}), do: nil

  def get_meditation_audio_url(%Meditation{audio_url: s3_key}) when is_binary(s3_key) do
    LumenViae.Storage.S3.generate_presigned_url!(s3_key)
  end

  ## Meditation Sets

  def count_meditation_sets do
    Repo.aggregate(MeditationSet, :count)
  end

  # Set ordering is part of the iOS API contract: the app builds its filter
  # chips and sections from first appearance across the list response, so the
  # list queries keep a deterministic creation order.
  def list_meditation_sets do
    Repo.all(from ms in MeditationSet, order_by: [asc: ms.category, asc: ms.id])
  end

  def list_meditation_sets_with_meditations do
    list_meditation_sets()
    |> Repo.preload(:meditations)
  end

  def list_meditation_sets_by_category(category) do
    Repo.all(from ms in MeditationSet, where: ms.category == ^category, order_by: [asc: ms.id])
    |> Repo.preload(:meditations)
  end

  ## Visible Meditation Sets (public surfaces)
  #
  # A set is "visible" when none of its meditations are archived. Archiving a
  # single meditation therefore hides every set that contains it from the
  # public site and the iOS API, while the admin functions above keep
  # returning everything.

  def list_visible_meditation_sets do
    visible_meditation_sets_query()
    |> order_by([ms], asc: ms.category, asc: ms.id)
    |> Repo.all()
  end

  def list_visible_meditation_sets_with_meditations do
    list_visible_meditation_sets()
    |> Repo.preload(:meditations)
  end

  def list_visible_meditation_sets_by_category(category) do
    visible_meditation_sets_query()
    |> where([ms], ms.category == ^category)
    |> order_by([ms], asc: ms.id)
    |> Repo.all()
    |> Repo.preload(:meditations)
  end

  @doc """
  Same as `get_meditation_set_with_ordered_meditations!/1` but raises
  `Ecto.NoResultsError` (rendered as a 404) when the set contains an
  archived meditation, so hidden sets cannot be reached by direct URL.
  """
  def get_visible_meditation_set_with_ordered_meditations!(id) do
    set = get_meditation_set_with_ordered_meditations!(id)

    if Enum.any?(set.meditations, & &1.archived_at) do
      raise Ecto.NoResultsError, queryable: MeditationSet
    end

    set
  end

  @doc """
  Returns a MapSet of ids of sets that are hidden from public surfaces
  because they contain at least one archived meditation.
  """
  def hidden_meditation_set_ids do
    hidden_set_ids_query()
    |> Repo.all()
    |> MapSet.new()
  end

  defp visible_meditation_sets_query do
    from ms in MeditationSet, where: ms.id not in subquery(hidden_set_ids_query())
  end

  defp hidden_set_ids_query do
    from msm in MeditationSetMeditation,
      join: m in Meditation,
      on: msm.meditation_id == m.id,
      where: not is_nil(m.archived_at),
      distinct: true,
      select: msm.meditation_set_id
  end

  def get_meditation_set!(id) do
    Repo.get!(MeditationSet, id)
    |> Repo.preload(meditations: from(m in Meditation, order_by: m.id))
  end

  def get_meditation_set_with_ordered_meditations!(id) do
    from(ms in MeditationSet,
      where: ms.id == ^id,
      left_join: msm in MeditationSetMeditation,
      on: msm.meditation_set_id == ms.id,
      left_join: m in Meditation,
      on: msm.meditation_id == m.id,
      left_join: my in Mystery,
      on: m.mystery_id == my.id,
      order_by: [asc: msm.order],
      select: %{
        set: ms,
        meditation: %Meditation{
          id: m.id,
          title: m.title,
          content: m.content,
          author: m.author,
          source: m.source,
          audio_url: m.audio_url,
          archived_at: m.archived_at,
          mystery_id: m.mystery_id,
          inserted_at: m.inserted_at,
          updated_at: m.updated_at,
          mystery: my
        }
      }
    )
    |> Repo.all()
    |> case do
      [] ->
        raise Ecto.NoResultsError, queryable: MeditationSet

      results ->
        set = hd(results).set
        meditations = Enum.map(results, & &1.meditation) |> Enum.reject(&is_nil(&1.id))
        %{set | meditations: meditations}
    end
  end

  def create_meditation_set(attrs \\ %{}) do
    %MeditationSet{}
    |> MeditationSet.changeset(attrs)
    |> Repo.insert()
  end

  def update_meditation_set(%MeditationSet{} = meditation_set, attrs) do
    meditation_set
    |> MeditationSet.changeset(attrs)
    |> Repo.update()
  end

  def change_meditation_set(%MeditationSet{} = meditation_set, attrs \\ %{}) do
    MeditationSet.changeset(meditation_set, attrs)
  end

  def delete_meditation_set(%MeditationSet{} = meditation_set) do
    Repo.delete(meditation_set)
  end

  ## Meditation Set Meditations (Join Table)

  def add_meditation_to_set(meditation_set_id, meditation_id, order) do
    %MeditationSetMeditation{}
    |> MeditationSetMeditation.changeset(%{
      meditation_set_id: meditation_set_id,
      meditation_id: meditation_id,
      order: order
    })
    |> Repo.insert()
  end

  def remove_meditation_from_set(meditation_set_id, meditation_id) do
    Repo.delete_all(
      from msm in MeditationSetMeditation,
        where: msm.meditation_set_id == ^meditation_set_id and msm.meditation_id == ^meditation_id
    )
  end

  ## Admin content statistics

  @doc """
  Counts archived meditations.
  """
  def count_archived_meditations do
    from(m in Meditation, where: not is_nil(m.archived_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Counts active (non-archived) meditations that have no audio file yet.
  """
  def count_active_meditations_missing_audio do
    from(m in Meditation,
      where: is_nil(m.archived_at) and (is_nil(m.audio_url) or m.audio_url == "")
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  Counts meditations that do not belong to any meditation set.
  """
  def count_meditations_not_in_any_set do
    from(m in Meditation,
      where: m.id not in subquery(from(msm in MeditationSetMeditation, select: msm.meditation_id))
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns a map of mystery_id => meditation count for every mystery that has
  at least one meditation.
  """
  def meditation_counts_by_mystery do
    from(m in Meditation, group_by: m.mystery_id, select: {m.mystery_id, count(m.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns a map of meditation_set_id => stats for every set that has at least
  one meditation. Stats: meditation_count, audio_count (meditations with an
  audio file), archived_count.
  """
  def meditation_set_stats do
    from(msm in MeditationSetMeditation,
      join: m in Meditation,
      on: msm.meditation_id == m.id,
      group_by: msm.meditation_set_id,
      select:
        {msm.meditation_set_id,
         %{
           meditation_count: count(m.id),
           audio_count: filter(count(m.id), not is_nil(m.audio_url) and m.audio_url != ""),
           archived_count: filter(count(m.id), not is_nil(m.archived_at))
         }}
    )
    |> Repo.all()
    |> Map.new()
  end

  ## Rosary Completions (Analytics)

  @doc """
  Records a rosary completion for analytics tracking.
  Called when a user reaches the 5th mystery in a meditation set.

  Optionally accepts an IP address to fetch and store location data.
  """
  def record_completion(meditation_set_id, ip_address \\ nil) do
    location_data =
      case ip_address do
        nil ->
          %{}

        ip ->
          # Always store the IP address
          base_data = %{ip_address: ip}

          # Try to fetch location data
          case LumenViae.Services.Geolocation.get_location(ip) do
            nil -> base_data
            location -> Map.merge(base_data, location)
          end
      end

    attrs =
      Map.merge(
        %{
          meditation_set_id: meditation_set_id,
          completed_at: DateTime.utc_now()
        },
        location_data
      )

    %RosaryCompletion{}
    |> RosaryCompletion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets the total count of rosary completions across all sets.
  """
  def count_total_completions do
    Repo.aggregate(RosaryCompletion, :count)
  end

  @doc """
  Gets completion statistics grouped by meditation set.
  Returns a list of %{set_id, set_name, category, count} maps.
  """
  def get_completions_by_set do
    from(rc in RosaryCompletion,
      join: ms in MeditationSet,
      on: rc.meditation_set_id == ms.id,
      group_by: [ms.id, ms.name, ms.category],
      select: %{
        set_id: ms.id,
        set_name: ms.name,
        category: ms.category,
        count: count(rc.id)
      },
      order_by: [desc: count(rc.id)]
    )
    |> Repo.all()
  end

  @doc """
  Gets recent completions for the dashboard.
  Returns the last N completions with set information and location data.
  """
  def get_recent_completions(limit \\ 10) do
    from(rc in RosaryCompletion,
      join: ms in MeditationSet,
      on: rc.meditation_set_id == ms.id,
      select: %{
        id: rc.id,
        set_name: ms.name,
        category: ms.category,
        completed_at: rc.completed_at,
        city: rc.city,
        region: rc.region,
        country: rc.country,
        country_code: rc.country_code
      },
      order_by: [desc: rc.completed_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets completion count for a specific date range.
  """
  def count_completions_in_range(start_date, end_date) do
    from(rc in RosaryCompletion,
      where: rc.completed_at >= ^start_date and rc.completed_at <= ^end_date
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets completion count for the trailing N days (including today).
  """
  def count_completions_last_days(days) when is_integer(days) and days > 0 do
    now = DateTime.utc_now()
    count_completions_in_range(DateTime.add(now, -days * 24 * 3600, :second), now)
  end

  @doc """
  Gets completion count for today.
  """
  def count_completions_today do
    today_start = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00])
    today_end = DateTime.utc_now()
    count_completions_in_range(today_start, today_end)
  end
end
