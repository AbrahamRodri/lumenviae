defmodule LumenViae.Rosary do
  @moduledoc """
  The Rosary Primary Context: the single public entry point to the domain.

  Everything outside the domain - LiveViews, controllers, mix tasks, the
  release module, the curation services - talks to this module and only this
  module. Behind it sit one Secondary Context per resource, each owning all
  database access for its own table:

    * `LumenViae.Rosary.Mysteries`
    * `LumenViae.Rosary.Meditations`
    * `LumenViae.Rosary.MeditationSets`
    * `LumenViae.Rosary.SetMemberships`
    * `LumenViae.Rosary.Completions`

  Simple, single-resource operations pass straight through. The work this
  module does itself is composition across resources, because a Secondary
  Context never queries another resource's table:

    * **Visibility.** A set is hidden from public surfaces when any of its
      meditations is archived. `Meditations` reports which meditations are
      archived, `SetMemberships` maps those to set ids, and `MeditationSets`
      excludes them.
    * **Prayer order.** A set's meditations are ordered by the join row, so
      `SetMemberships` supplies the ordered ids and `Meditations` fetches
      the records.
    * **Reporting.** Completion and set statistics come back keyed by id
      from each context and are folded together here.

  See `docs/ARCHITECTURE.md` for the rules this layout follows.
  """

  alias LumenViae.Rosary.Completions
  alias LumenViae.Rosary.MeditationSets
  alias LumenViae.Rosary.Meditations
  alias LumenViae.Rosary.Mysteries
  alias LumenViae.Rosary.SetMemberships
  alias LumenViae.Services.Geolocation
  alias LumenViae.Storage.S3

  ## Mysteries

  defdelegate count_mysteries(), to: Mysteries, as: :count
  defdelegate list_mysteries(), to: Mysteries, as: :list
  defdelegate list_mysteries_by_category(category), to: Mysteries, as: :list_by_category
  defdelegate get_mystery!(id), to: Mysteries, as: :get!
  defdelegate create_mystery(attrs \\ %{}), to: Mysteries, as: :create
  defdelegate update_mystery(mystery, attrs), to: Mysteries, as: :update
  defdelegate change_mystery(mystery, attrs \\ %{}), to: Mysteries, as: :change
  defdelegate delete_mystery(mystery), to: Mysteries, as: :delete

  ## Meditations

  defdelegate count_meditations(), to: Meditations, as: :count
  defdelegate list_meditations(), to: Meditations, as: :list
  defdelegate list_meditations_with_sets(), to: Meditations, as: :list_with_sets
  defdelegate get_meditation(id), to: Meditations, as: :get
  defdelegate get_meditation!(id), to: Meditations, as: :get!
  defdelegate create_meditation(attrs \\ %{}), to: Meditations, as: :create
  defdelegate update_meditation(meditation, attrs), to: Meditations, as: :update
  defdelegate change_meditation(meditation, attrs \\ %{}), to: Meditations, as: :change
  defdelegate change_new_meditation(attrs \\ %{}), to: Meditations, as: :change_new
  defdelegate delete_meditation(meditation), to: Meditations, as: :delete
  defdelegate meditation_archived?(meditation), to: Meditations, as: :archived?
  defdelegate archive_meditation(meditation), to: Meditations, as: :archive
  defdelegate unarchive_meditation(meditation), to: Meditations, as: :unarchive
  defdelegate list_taken_audio_urls(audio_urls), to: Meditations

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
  def get_meditation_audio_url(%{audio_url: audio_url}) when audio_url in [nil, ""], do: nil

  def get_meditation_audio_url(%{audio_url: s3_key}) when is_binary(s3_key) do
    S3.generate_presigned_url!(s3_key, expires_in: audio_url_ttl())
  end

  @doc """
  A meditation's audio as a URL and the moment that URL stops working.

  The plain `get_meditation_audio_url/1` above cannot say when what it
  returned expires, so a client that caches the URL has no way to know it
  has gone stale except by being refused. This returns both, which is what
  a client storing audio for offline use actually needs.

  Returns `{:ok, %{url: url, expires_at: %DateTime{}}}`, or `:error` when
  the meditation has no audio or the URL could not be signed.
  """
  def fetch_meditation_audio(%{audio_url: audio_url}) when audio_url in [nil, ""], do: :error

  def fetch_meditation_audio(%{audio_url: s3_key}) when is_binary(s3_key) do
    ttl = audio_url_ttl()

    case S3.generate_presigned_url(s3_key, expires_in: ttl) do
      {:ok, url} ->
        expires_at = DateTime.utc_now() |> DateTime.add(ttl, :second) |> DateTime.truncate(:second)
        {:ok, %{url: url, expires_at: expires_at}}

      {:error, _reason} ->
        :error
    end
  end

  @doc """
  How many seconds a presigned audio URL stays valid.

  Read at call time rather than compiled in: every other AWS setting is
  resolved in `runtime.exs`, and a `compile_env` read of a runtime key
  raises at boot.
  """
  def audio_url_ttl do
    Application.get_env(:lumen_viae, :audio_url_ttl_seconds, 3600)
  end

  ## Meditation sets

  defdelegate count_meditation_sets(), to: MeditationSets, as: :count
  defdelegate get_meditation_set!(id), to: MeditationSets, as: :get_with_meditations!
  defdelegate get_meditation_set_by_name(name), to: MeditationSets, as: :get_by_name
  defdelegate create_meditation_set(attrs \\ %{}), to: MeditationSets, as: :create
  defdelegate update_meditation_set(set, attrs), to: MeditationSets, as: :update
  defdelegate change_meditation_set(set, attrs \\ %{}), to: MeditationSets, as: :change
  defdelegate change_new_meditation_set(attrs \\ %{}), to: MeditationSets, as: :change_new
  defdelegate delete_meditation_set(set), to: MeditationSets, as: :delete
  defdelegate expected_meditation_count(category), to: MeditationSets

  def list_meditation_sets, do: MeditationSets.list()

  @doc """
  Fetches a set with its meditations in the order the set is prayed, which
  lives on the join row rather than on the meditations themselves.

  Raises `Ecto.NoResultsError` when the set does not exist.
  """
  def get_meditation_set_with_ordered_meditations!(id) do
    set = MeditationSets.get!(id)
    %{set | meditations: list_meditations_in_set(set.id)}
  end

  @doc """
  A set's meditations in the order the set is prayed, with mysteries
  preloaded.
  """
  def list_meditations_in_set(set_id) do
    set_id
    |> SetMemberships.list_meditation_ids_in_set()
    |> Meditations.list_by_ids()
  end

  ## Visible meditation sets (public surfaces)
  #
  # A set is "visible" when none of its meditations are archived. Archiving a
  # single meditation therefore hides every set that contains it from the
  # public site and the iOS API, while the admin functions above keep
  # returning everything.

  def list_visible_meditation_sets do
    MeditationSets.list(exclude_ids: hidden_meditation_set_ids())
  end

  def list_visible_meditation_sets_with_meditations do
    list_visible_meditation_sets() |> MeditationSets.preload_meditations()
  end

  def list_visible_meditation_sets_by_category(category) do
    MeditationSets.list(category: category, exclude_ids: hidden_meditation_set_ids())
    |> MeditationSets.preload_meditations()
  end

  @doc """
  Same as `get_meditation_set_with_ordered_meditations!/1` but raises
  `Ecto.NoResultsError` (rendered as a 404) when the set contains an
  archived meditation, so hidden sets cannot be reached by direct URL.
  """
  def get_visible_meditation_set_with_ordered_meditations!(id) do
    set = get_meditation_set_with_ordered_meditations!(id)

    if Enum.any?(set.meditations, &Meditations.archived?/1) do
      MeditationSets.raise_not_found!()
    end

    set
  end

  @doc """
  Returns a MapSet of ids of sets that are hidden from public surfaces
  because they contain at least one archived meditation.
  """
  def hidden_meditation_set_ids do
    Meditations.list_archived_ids()
    |> SetMemberships.list_set_ids_containing()
    |> MapSet.new()
  end

  ## Set membership

  defdelegate add_meditation_to_set(set_id, meditation_id, order), to: SetMemberships, as: :add
  defdelegate remove_meditation_from_set(set_id, meditation_id), to: SetMemberships, as: :remove

  @doc """
  The order an appended meditation should take in a set: one past the
  highest order currently used.
  """
  def next_order_in_set(set_id) do
    SetMemberships.max_order_in_set(set_id) + 1
  end

  ## Admin content statistics

  defdelegate count_archived_meditations(), to: Meditations, as: :count_archived

  defdelegate count_active_meditations_missing_audio(),
    to: Meditations,
    as: :count_active_missing_audio

  defdelegate meditation_counts_by_mystery(), to: Meditations, as: :count_by_mystery

  @doc """
  Counts meditations that do not belong to any meditation set.
  """
  def count_meditations_not_in_any_set do
    SetMemberships.list_member_meditation_ids()
    |> Meditations.count_excluding_ids()
  end

  @doc """
  Returns a map of meditation_set_id => stats for every set that has at least
  one meditation. Stats: meditation_count, audio_count (meditations with an
  audio file), archived_count.
  """
  def meditation_set_stats do
    flags = Meditations.list_audio_and_archive_flags()

    SetMemberships.list_meditation_ids_by_set()
    |> Map.new(fn {set_id, meditation_ids} ->
      members = Enum.map(meditation_ids, &Map.get(flags, &1, %{audio?: false, archived?: false}))

      {set_id,
       %{
         meditation_count: length(members),
         audio_count: Enum.count(members, & &1.audio?),
         archived_count: Enum.count(members, & &1.archived?)
       }}
    end)
  end

  ## Rosary completions (analytics)

  defdelegate count_total_completions(), to: Completions, as: :count
  defdelegate count_completions_in_range(start_at, end_at), to: Completions, as: :count_in_range

  @doc """
  Records a rosary completion for analytics tracking.
  Called when a user reaches the last mystery in a meditation set.

  Optionally accepts an IP address to fetch and store location data.
  """
  def record_completion(meditation_set_id, ip_address \\ nil) do
    attrs =
      %{meditation_set_id: meditation_set_id, completed_at: DateTime.utc_now()}
      |> Map.merge(location_data(ip_address))

    Completions.create(attrs)
  end

  defp location_data(nil), do: %{}

  defp location_data(ip) do
    # The IP is always stored; the lookup that turns it into a place is
    # best-effort and may be unavailable.
    case Geolocation.get_location(ip) do
      nil -> %{ip_address: ip}
      location -> Map.merge(%{ip_address: ip}, location)
    end
  end

  @doc """
  Gets completion statistics grouped by meditation set.
  Returns a list of %{set_id, set_name, category, count} maps, most
  completed first. Completions whose set has since been deleted are omitted.
  """
  def get_completions_by_set do
    counts = Completions.count_by_set()
    sets = counts |> Enum.map(&elem(&1, 0)) |> sets_by_id()

    Enum.flat_map(counts, fn {set_id, count} ->
      case Map.fetch(sets, set_id) do
        {:ok, set} ->
          [%{set_id: set.id, set_name: set.name, category: set.category, count: count}]

        :error ->
          []
      end
    end)
  end

  @doc """
  Gets recent completions for the dashboard.
  Returns the last N completions with set information and location data.
  Completions whose set has since been deleted are omitted.
  """
  def get_recent_completions(limit \\ 10) do
    completions = Completions.list_recent(limit)
    sets = completions |> Enum.map(& &1.meditation_set_id) |> sets_by_id()

    Enum.flat_map(completions, fn completion ->
      case Map.fetch(sets, completion.meditation_set_id) do
        {:ok, set} ->
          [
            %{
              id: completion.id,
              set_name: set.name,
              category: set.category,
              completed_at: completion.completed_at,
              city: completion.city,
              region: completion.region,
              country: completion.country,
              country_code: completion.country_code
            }
          ]

        :error ->
          []
      end
    end)
  end

  defp sets_by_id(set_ids) do
    set_ids
    |> Enum.uniq()
    |> MeditationSets.list_by_ids()
    |> Map.new(&{&1.id, &1})
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
    count_completions_in_range(today_start, DateTime.utc_now())
  end
end
