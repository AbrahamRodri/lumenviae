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
    * `LumenViae.Rosary.Authors`
    * `LumenViae.Rosary.Narrations`

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
    * **Narration.** A meditation's recordings come from `Narrations`, the
      voices they are in from the `Voices` value module, and the presigned
      URLs a client plays are assembled here, default voice first.

  See `docs/ARCHITECTURE.md` for the rules this layout follows.
  """

  alias LumenViae.Rosary.Artwork
  alias LumenViae.CentralTime
  alias LumenViae.Rosary.Authors
  alias LumenViae.Rosary.Completions
  alias LumenViae.Rosary.MeditationSets
  alias LumenViae.Rosary.Meditations
  alias LumenViae.Rosary.Mysteries
  alias LumenViae.Rosary.Narrations
  alias LumenViae.Rosary.SetMemberships
  alias LumenViae.Rosary.Voices
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

  ## Narration

  defdelegate list_voices(), to: Voices, as: :list
  defdelegate default_voice(), to: Voices, as: :default
  defdelegate fetch_voice(slug), to: Voices, as: :fetch
  defdelegate narration_counts_by_voice(), to: Narrations, as: :count_by_voice

  defdelegate meditation_ids_with_narration(voice_slug),
    to: Narrations,
    as: :list_meditation_ids_with_voice

  @doc """
  Records that `s3_key` now holds `voice`'s recording of the meditation.

  Called by the audio pipeline's callers once the upload has succeeded; a
  row here is a promise that the object exists. Returns the meditation with
  its narrations reloaded so the caller can go on rendering it.
  """
  def record_narration(%{id: meditation_id} = meditation, voice_slug, s3_key)
      when is_binary(voice_slug) and is_binary(s3_key) do
    with {:ok, _voice} <- Voices.fetch(voice_slug),
         {:ok, _narration} <- Narrations.upsert(meditation_id, voice_slug, s3_key) do
      {:ok, Meditations.reload_narrations(meditation)}
    end
  end

  @doc """
  The voices a meditation can be heard in, default first, each with the S3
  key of its recording: `[%{voice: %Voice{}, s3_key: key}]`.

  Only configured voices count. A row for a voice that has since been
  removed from config is a file nobody can be offered, so it is left out
  rather than rendered as a voice the app has no name for. Uses the
  preloaded association when the meditation carries one, and asks the
  table otherwise.
  """
  def meditation_narrations(%{id: meditation_id} = meditation) do
    rows =
      case Map.get(meditation, :narrations) do
        narrations when is_list(narrations) -> narrations
        _not_loaded -> Narrations.list_for_meditation(meditation_id)
      end

    by_voice = Map.new(rows, &{&1.voice, &1.s3_key})

    Voices.list()
    |> Enum.flat_map(fn voice ->
      case Map.fetch(by_voice, voice.slug) do
        {:ok, s3_key} -> [%{voice: voice, s3_key: s3_key}]
        :error -> []
      end
    end)
  end

  @doc """
  Every narration of a meditation as a presigned URL, default voice first:
  `[%{voice: %Voice{}, url: url}]`. A narration whose URL could not be
  signed is left out rather than rendered as a link that will fail.
  """
  def sign_meditation_narrations(meditation) do
    ttl = audio_url_ttl()

    meditation
    |> meditation_narrations()
    |> Enum.flat_map(fn %{voice: voice, s3_key: s3_key} ->
      case S3.generate_presigned_url(s3_key, expires_in: ttl) do
        {:ok, url} -> [%{voice: voice, url: url}]
        {:error, _reason} -> []
      end
    end)
  end

  @doc """
  Generates a pre-signed URL for a meditation's narration in the default
  voice - or, when the default voice has not recorded it yet, in the first
  voice that has. This is what the website plays and what the legacy single
  `audio_url` field carries.

  Returns nil when the meditation has no narration or the URL could not be
  signed.

  ## Examples

      iex> get_meditation_audio_url(%Meditation{narrations: [...]})
      "https://lumenviae-audio.s3.us-east-2.amazonaws.com/voices/female/meditation1.mp3?..."

      iex> get_meditation_audio_url(%Meditation{narrations: []})
      nil
  """
  def get_meditation_audio_url(meditation) do
    case fetch_meditation_audio(meditation) do
      {:ok, %{url: url}} -> url
      _none -> nil
    end
  end

  @doc """
  A meditation's narration in one voice as a URL, with the voice and the
  moment that URL stops working.

  The plain `get_meditation_audio_url/1` above cannot say when what it
  returned expires, so a client that caches the URL has no way to know it
  has gone stale except by being refused. This returns both, which is what
  a client storing audio for offline use actually needs.

  `voice_slug` is nil for the default voice, falling back to whichever
  voice has recorded the meditation when the default has not; a named voice
  is exact, since a client asking for the male voice has made a choice.

  Returns `{:ok, %{voice: %Voice{}, url: url, expires_at: %DateTime{}}}`,
  `{:error, :unknown_voice}` for a slug that is not configured, or `:error`
  when the meditation has no such narration or the URL could not be signed.
  """
  def fetch_meditation_audio(meditation, voice_slug \\ nil)

  def fetch_meditation_audio(meditation, nil) do
    case meditation_narrations(meditation) do
      [] -> :error
      [first | _] -> sign_narration(first)
    end
  end

  def fetch_meditation_audio(meditation, voice_slug) when is_binary(voice_slug) do
    with {:ok, _voice} <- Voices.fetch(voice_slug) do
      meditation
      |> meditation_narrations()
      |> Enum.find(&(&1.voice.slug == voice_slug))
      |> case do
        nil -> :error
        narration -> sign_narration(narration)
      end
    end
  end

  defp sign_narration(%{voice: voice, s3_key: s3_key}) do
    ttl = audio_url_ttl()

    case S3.generate_presigned_url(s3_key, expires_in: ttl) do
      {:ok, url} ->
        expires_at =
          DateTime.utc_now() |> DateTime.add(ttl, :second) |> DateTime.truncate(:second)

        {:ok, %{voice: voice, url: url, expires_at: expires_at}}

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

  ## Authors

  defdelegate list_authors(), to: Authors, as: :list
  defdelegate get_author!(id), to: Authors, as: :get!
  defdelegate create_author(attrs \\ %{}), to: Authors, as: :create
  defdelegate update_author(author, attrs), to: Authors, as: :update
  defdelegate change_author(author, attrs \\ %{}), to: Authors, as: :change
  defdelegate change_new_author(attrs \\ %{}), to: Authors, as: :change_new
  defdelegate delete_author(author), to: Authors, as: :delete
  defdelegate update_author_artwork(author, attrs), to: Authors, as: :update_artwork

  defdelegate update_author_artwork_metadata(author, attrs),
    to: Authors,
    as: :update_artwork_metadata

  defdelegate change_author_artwork(author, attrs \\ %{}),
    to: Authors,
    as: :change_artwork

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

  defdelegate update_meditation_set_artwork(set, attrs),
    to: MeditationSets,
    as: :update_artwork

  defdelegate update_meditation_set_artwork_metadata(set, attrs),
    to: MeditationSets,
    as: :update_artwork_metadata

  defdelegate change_meditation_set_artwork(set, attrs \\ %{}),
    to: MeditationSets,
    as: :change_artwork

  defdelegate meditation_set_ids_missing_artwork(),
    to: MeditationSets,
    as: :list_ids_missing_artwork

  defdelegate meditation_set_counts_by_author(), to: MeditationSets, as: :count_by_author

  @doc """
  Stable public URL for a set's or a meditation's artwork, or nil.

  Unlike the audio URLs above this signs nothing and never expires: artwork
  lives in the public assets bucket precisely so a client can cache it and
  still show it during offline prayer. Building it is pure string work with
  no I/O, so callers may do it per row without thinking about cost.
  """
  def artwork_url(%{image_key: key}), do: S3.public_url(key)
  def artwork_url(_record), do: nil

  @doc """
  The record whose artwork a set displays: the set itself when its own
  artwork is publishable, otherwise its linked author, otherwise nil.

  The same shape as the byline derivation: what the set carries always
  wins, the author only fills a gap. The clients cannot tell the two
  apart - both render through the same image fields - which is what lets a
  portrait uploaded once cover every set under that author with no API or
  app change.

  The author association must be preloaded for the fallback to apply; the
  visible-set reads preload it. Where it is not loaded the set behaves as
  if it had no author.
  """
  def artwork_record(set) do
    author = Map.get(set, :author_profile)

    cond do
      Artwork.publishable?(set) -> set
      Artwork.publishable?(author) -> author
      true -> nil
    end
  end

  @doc """
  Every set, admin order, with the linked author preloaded and the byline
  resolved.

  Both come along because the admin's job is to show what the app will
  actually do with each set. Artwork: a set with no painting of its own
  still shows one when its author has a portrait (see `artwork_record/1`),
  so the health check needs the author loaded or it reports paintings
  missing that are not. Byline: a set with no `author` of its own still
  prints one when its meditations agree, so a column reading it raw would
  be a column of dashes.

  Three extra queries over a table of a few dozen rows, for a list that is
  not quietly wrong about either.
  """
  def list_meditation_sets do
    MeditationSets.list()
    |> MeditationSets.preload_author_profile()
    |> resolve_attribution()
  end

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
    |> MeditationSets.preload_author_profile()
    |> resolve_attribution()
  end

  def list_visible_meditation_sets_with_meditations do
    list_visible_meditation_sets() |> MeditationSets.preload_meditations()
  end

  def list_visible_meditation_sets_by_category(category) do
    MeditationSets.list(category: category, exclude_ids: hidden_meditation_set_ids())
    |> MeditationSets.preload_meditations()
    |> MeditationSets.preload_author_profile()
    |> resolve_attribution()
  end

  @doc """
  Fills in each set's derived byline.

  An explicit `author` or `source` on the set always wins. Otherwise it is
  derived from the set's meditations, and only when every meditation agrees:
  a set of four Emmerich passages and one Liguori gets nil rather than a
  name that is true of most of it.

  Writes only the virtual `derived_author` and `derived_source`. Writing the
  derivation into the persisted columns would mean any later save of that
  struct - an admin form prefilled from a public read, a re-save - promoted
  a guess to an explicit override, which is exactly the staleness having a
  derivation is meant to avoid.

  Two queries, whether it is given one set or all of them.
  """
  def resolve_attribution(sets) when is_list(sets) do
    ids_by_set = SetMemberships.list_meditation_ids_by_set()

    attribution =
      sets
      |> Enum.flat_map(&Map.get(ids_by_set, &1.id, []))
      |> Enum.uniq()
      |> Meditations.list_attribution_by_ids()

    Enum.map(sets, fn set ->
      rows =
        ids_by_set
        |> Map.get(set.id, [])
        |> Enum.map(&Map.get(attribution, &1))
        |> Enum.reject(&is_nil/1)

      %{
        set
        | derived_author: unanimous(rows, :author),
          derived_source: unanimous(rows, :source)
      }
    end)
  end

  def resolve_attribution(set), do: set |> List.wrap() |> resolve_attribution() |> hd()

  defp unanimous([], _key), do: nil

  defp unanimous(rows, key) do
    case rows |> Enum.map(&blank_to_nil(Map.fetch!(&1, key))) |> Enum.uniq() do
      [value] when is_binary(value) -> value
      _disagreement_or_nothing -> nil
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
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

    resolve_attribution(set)
  end

  @doc """
  Result-shaped sibling of
  `get_visible_meditation_set_with_ordered_meditations!/1`.

  Returns `{:ok, set}`, or `{:error, :not_found}` for a set that does not
  exist, is not an id at all, or is hidden because one of its meditations is
  archived. The bang version stays for the admin surfaces, where a 404 by
  exception is the right answer; the API wants the error in hand so it goes
  through the fallback controller and comes back in the same envelope as
  every other error.
  """
  def fetch_visible_meditation_set(id) do
    with set when not is_nil(set) <- MeditationSets.get(id),
         set = MeditationSets.preload_author_profile(set),
         set = %{set | meditations: list_meditations_in_set(set.id)},
         false <- Enum.any?(set.meditations, &Meditations.archived?/1) do
      {:ok, resolve_attribution(set)}
    else
      _missing_or_hidden -> {:error, :not_found}
    end
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
  defdelegate meditation_counts_by_mystery(), to: Meditations, as: :count_by_mystery

  defdelegate active_meditation_counts_by_mystery(),
    to: Meditations,
    as: :count_active_by_mystery

  @doc """
  Counts active meditations that do not belong to any meditation set.

  Archived ones are left out: a meditation deliberately taken out of
  circulation and out of its sets is finished, not unfinished.
  """
  def count_meditations_not_in_any_set do
    SetMemberships.list_member_meditation_ids()
    |> Meditations.count_active_excluding_ids()
  end

  @doc """
  Ids of active meditations with no narration that someone can actually
  reach today: they belong to at least one set that is not hidden.

  The dashboard reports on what the app and the site are serving, so a
  meditation sitting in no set, or only in sets hidden by an archived
  sibling, is not counted as missing audio. It shows up under its own
  heading instead.
  """
  def public_meditation_ids_missing_audio do
    hidden = hidden_meditation_set_ids()

    reachable =
      SetMemberships.list_meditation_ids_by_set()
      |> Enum.reject(fn {set_id, _ids} -> MapSet.member?(hidden, set_id) end)
      |> Enum.flat_map(fn {_set_id, ids} -> ids end)
      |> MapSet.new()

    Meditations.list_active_ids_missing_audio()
    |> Enum.filter(&MapSet.member?(reachable, &1))
  end

  @doc """
  Ids of active meditations that have an audio filename but lack a recording
  in at least one configured voice - an import whose generation failed
  partway, or a set imported before a voice was added. Each is one
  `regenerate_audio --only-missing` away from being whole.
  """
  def meditation_ids_missing_a_voice do
    expected = Meditations.list_active_ids_with_audio()

    complete =
      Voices.list()
      |> Enum.map(&MapSet.new(Narrations.list_meditation_ids_with_voice(&1.slug)))
      |> Enum.reduce(MapSet.new(expected), &MapSet.intersection(&2, &1))

    Enum.reject(expected, &MapSet.member?(complete, &1))
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
  #
  # A completion is recorded when someone presses the button at the end of
  # the last mystery, never by arriving at it. Reaching the final screen is
  # something a crawler does for free; pressing the button is not, and the
  # numbers below are only worth reading if they mean a Rosary was prayed.

  defdelegate count_total_completions(), to: Completions, as: :count
  defdelegate count_completions_in_range(start_at, end_at), to: Completions, as: :count_in_range

  @doc """
  The zone the admin analytics are reported in. Days start and end here, not
  in UTC. See `LumenViae.CentralTime`.
  """
  def reporting_time_zone, do: CentralTime.zone_name()

  @doc """
  Records that somebody finished praying a set.

  `context` describes where the completion came from and is entirely
  optional - a completion with an empty context is still a completion, and
  every field below can be missing:

    * `:ip` - the caller's address, used to look up a rough place and then
      truncated before it is stored. Never written down in full.
    * `:source` - `"web"` or `"ios"`
    * `:time_zone` - an IANA zone name reported by the client
    * `:locale` - a locale reported by the client

  ## Why the place is filled in afterwards

  The row is written first and the geolocation lookup runs in a background
  task that updates it. Doing the lookup inline would put a third-party
  HTTP call between somebody pressing Complete and the page moving on, so a
  slow provider would be felt as a slow Rosary - and a provider that was
  down would fail the completion entirely. A place is worth having and is
  not worth that.

  The consequence, which is the honest trade: a row is briefly placeless
  after it is written, and stays that way for good if the lookup fails.
  """
  def record_completion(meditation_set_id, context \\ %{}) when is_map(context) do
    ip = context[:ip]

    attrs = %{
      meditation_set_id: meditation_set_id,
      completed_at: DateTime.utc_now(),
      ip_prefix: Geolocation.anonymize(ip),
      source: context[:source],
      time_zone: context[:time_zone],
      locale: context[:locale]
    }

    case Completions.create(attrs) do
      {:ok, completion} ->
        locate_later(completion.id, ip)
        {:ok, completion}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Nothing is scheduled when a lookup could not produce an answer anyway:
  # geolocation switched off, no address, or an address on a private range.
  # A task that starts only to return `nil` is noise in the supervisor.
  defp locate_later(completion_id, ip) do
    if is_binary(ip) and Geolocation.enabled?() and Geolocation.routable?(ip) do
      Task.Supervisor.start_child(LumenViae.TaskSupervisor, fn ->
        case Geolocation.locate(ip) do
          nil -> :ok
          location -> Completions.update_location(completion_id, location)
        end
      end)
    end

    :ok
  end

  @doc """
  Gets completion statistics grouped by meditation set.

  Returns a list of %{set_id, set_name, category, count} maps, most
  completed first. Completions whose set has since been deleted are omitted.

  ## Options

    * `:days` - only count completions from the trailing N days, so the
      dashboard can show what is being prayed *now* rather than a ranking
      dominated by whichever set has existed longest
  """
  def get_completions_by_set(opts \\ []) do
    counts =
      case opts[:days] do
        nil -> Completions.count_by_set()
        days -> Completions.count_by_set_in_range(days_ago(days), DateTime.utc_now())
      end

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
              country_code: completion.country_code,
              source: completion.source
            }
          ]

        :error ->
          []
      end
    end)
  end

  @doc """
  Where the last `days` of Rosaries were prayed from, and on what.

  Returns `%{countries:, cities:, sources:, located:, total:}`.

  `located` and `total` are both here on purpose. A place is attached by a
  best-effort lookup that can be switched off, rate limited, or simply
  wrong about an address, so the country list is drawn from a subset of the
  rows and the reader needs to know how large that subset is. A ranking
  covering a tenth of the completions and one covering all of them look
  identical otherwise.
  """
  def completion_locations(days) when is_integer(days) and days > 0 do
    start_at = days_ago(days)
    end_at = DateTime.utc_now()

    %{
      countries:
        start_at
        |> Completions.count_by_country(end_at)
        |> Enum.map(fn {country, code, count} ->
          %{country: country, country_code: code, count: count}
        end),
      cities:
        start_at
        |> Completions.count_by_city(end_at)
        |> Enum.map(fn {city, region, code, count} ->
          %{city: city, region: region, country_code: code, count: count}
        end),
      sources: Completions.count_by_source(start_at, end_at),
      located: Completions.count_located_in_range(start_at, end_at),
      total: Completions.count_in_range(start_at, end_at)
    }
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
    count_completions_in_range(days_ago(days), DateTime.utc_now())
  end

  @doc """
  Gets completion count for today, where today ends at midnight in the
  reporting zone rather than at midnight UTC - which, for a Central-time
  reader, used to roll the day over at six in the evening.
  """
  def count_completions_today do
    count_completions_in_range(CentralTime.day_start(CentralTime.today()), DateTime.utc_now())
  end

  @doc """
  Headline completion figures, each trailing window paired with the window
  immediately before it so the dashboard can show movement rather than a
  number with nothing to compare it to.

  Returns `%{total:, today:, last_7:, previous_7:, last_30:, previous_30:,
  active_sets_30:}`.
  """
  def completion_summary do
    now = DateTime.utc_now()

    %{
      total: count_total_completions(),
      today: count_completions_today(),
      last_7: count_completions_in_range(days_ago(7), now),
      previous_7: count_completions_in_range(days_ago(14), days_ago(7)),
      last_30: count_completions_in_range(days_ago(30), now),
      previous_30: count_completions_in_range(days_ago(60), days_ago(30)),
      active_sets_30: Completions.count_distinct_sets_in_range(days_ago(30), now)
    }
  end

  @doc """
  A dense daily series for the trailing N days, oldest first, as
  `[%{date: %Date{}, count: integer}]`.

  Days with no completions are filled in with zero: a chart that silently
  drops empty days draws a flat line through a week nobody prayed.
  """
  def completions_by_day(days) when is_integer(days) and days > 0 do
    today = CentralTime.today()
    first = Date.add(today, -(days - 1))

    counted =
      Completions.count_by_day(
        CentralTime.day_start(first),
        DateTime.utc_now(),
        reporting_time_zone()
      )
      |> Map.new()

    Enum.map(0..(days - 1), fn offset ->
      date = Date.add(first, offset)
      %{date: date, count: Map.get(counted, date, 0)}
    end)
  end

  defp days_ago(days), do: DateTime.add(DateTime.utc_now(), -days * 24 * 3600, :second)
end
