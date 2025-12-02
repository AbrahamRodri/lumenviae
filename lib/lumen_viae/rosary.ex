defmodule LumenViae.Rosary do
  @moduledoc """
  The Rosary context.
  """

  import Ecto.Query, warn: false
  alias LumenViae.Repo

  alias LumenViae.Rosary.{Mystery, Meditation, MeditationSet, MeditationSetMeditation, RosaryCompletion}

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

  def list_meditation_sets do
    Repo.all(MeditationSet)
  end

  def list_meditation_sets_by_category(category) do
    Repo.all(from ms in MeditationSet, where: ms.category == ^category)
    |> Repo.preload(:meditations)
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
        meditation:
          %Meditation{
            id: m.id,
            title: m.title,
            content: m.content,
            author: m.author,
            source: m.source,
            audio_url: m.audio_url,
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
      Map.merge(%{
        meditation_set_id: meditation_set_id,
        completed_at: DateTime.utc_now()
      }, location_data)

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
  Gets completion count for today.
  """
  def count_completions_today do
    today_start = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00])
    today_end = DateTime.utc_now()
    count_completions_in_range(today_start, today_end)
  end
end
