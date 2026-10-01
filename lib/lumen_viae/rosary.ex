defmodule LumenViae.Rosary do
  @moduledoc """
  The Rosary domain: the single public entry point to everything about
  mysteries, meditations, meditation sets, narrations, authors and
  completions.

  Everything outside the domain - LiveViews, controllers, mix tasks, the
  release module, the curation services, the GraphQL schema - talks to
  this module and only this module. It is an `Ash.Domain`, and its public
  functions are mostly the code interface defined in the `resources` block:
  one function per action, named for what it does rather than for the
  resource it runs on (`create_meditation/1`, `list_visible_meditation_sets!/0`).

  ## The resources

    * `LumenViae.Rosary.Mystery`
    * `LumenViae.Rosary.Meditation`
    * `LumenViae.Rosary.MeditationSet`
    * `LumenViae.Rosary.SetMembership`
    * `LumenViae.Rosary.Narration`
    * `LumenViae.Rosary.Author`
    * `LumenViae.Rosary.Completion`

  plus two with no table, `LumenViae.Rosary.NarrationVoice` and
  `LumenViae.Rosary.SpokenRosary`, which give the APIs the configured
  voices and the spoken Rosary.

  Nothing outside `lib/lumen_viae/rosary/` names a resource, calls `Ash`
  on one, or touches the Repo for Rosary data; `test/lumen_viae/rosary/context_rules_test.exs`
  fails the build if something does. The value modules (`Categories`,
  `Labels`, `Artwork`, `Voices`, `PrayerAudio`) hold vocabulary and pure
  calculation and may be called from any layer.

  ## What is a function here, and what is an action

  Reads are defined with their raising form only (`list_mysteries!/0`), so
  that they hand back the list itself; `get_*!/1` raises an error that
  renders as a 404. Writes keep both forms and return `{:ok, record}` or
  `{:error, %Ash.Error.Invalid{}}`. A page builds its form with
  `form_to_<function>`; a dry run asks for the changeset with
  `changeset_to_<function>`.

  The rules that span resources are expressions on the resources rather
  than code here:

    * **Visibility.** A set is hidden from public surfaces when any of its
      meditations is archived. That is `MeditationSet`'s `visible?`
      calculation and its `:visible` read.
    * **Prayer order.** A set's meditations are ordered by the join row, so
      `set_memberships` is sorted and `meditations` is read through it.
    * **Byline.** A set's byline is its own or the one its meditations agree
      on: the `derived_*` and `byline_*` calculations.
    * **Reporting.** Counts are aggregates and calculations on the sets and
      the completions; the dashboard's folds are the functions below.

  What stays as plain functions is the composition no action can express:
  signing narration URLs (`sign_meditation_narrations/1`, `fetch_meditation_audio/2`),
  the artwork a set actually shows (`artwork_record/1`), and the figures
  the admin dashboard draws.

  See `docs/ARCHITECTURE.md` for the rules this layout follows and
  `docs/ASH_MIGRATION.md` for how it got here.
  """
  use Ash.Domain,
    otp_app: :lumen_viae,
    extensions: [AshGraphql.Domain, AshPhoenix, AshAdmin.Domain]

  # The GraphQL API's Rosary queries. See docs/GRAPHQL.md.
  graphql do
    queries do
      list LumenViae.Rosary.NarrationVoice, :voices, :offered, paginate_with: nil
      list LumenViae.Rosary.NarrationVoice, :retired_voices, :retired, paginate_with: nil
      read_one LumenViae.Rosary.SpokenRosary, :rosary_audio, :for_voice, allow_nil?: false
      action LumenViae.Rosary.Meditation, :meditation_audio, :audio_for

      # The sets the public may see. Both read through :visible, so a set
      # hidden by an archived meditation is absent from the list and a
      # not-found error by id.
      list LumenViae.Rosary.MeditationSet, :visible_meditation_sets, :visible, paginate_with: nil

      get LumenViae.Rosary.MeditationSet, :meditation_set, :visible,
        hide_inputs: [:category],
        allow_nil?: false
    end

    # The one public write. LumenViaeWeb.GraphqlSchema puts the same guard
    # in front of it as POST /api/completions: a crawler check and a
    # per-address rate limit, on one budget shared with REST.
    mutations do
      create LumenViae.Rosary.Completion, :record_completion, :record_from_app
    end
  end

  # Browsable at /admin/data, behind the console's login: a generic view of
  # every resource for the cases the console has no screen for.
  admin do
    show?(true)
  end

  # A read is defined with its raising form only (`list_mysteries!/0`), so
  # that it hands back the list itself, as these functions always have. The
  # writes keep both forms and return `{:ok, record}` or
  # `{:error, %Ash.Error.Invalid{}}`.
  @read [:subject, :can, :can?, :action!]

  # What every listed set carries so that it can be shown as the app will
  # show it. The linked author, because a set with no painting of its own
  # still shows one when its author has a portrait (see `artwork_record/1`).
  # The derived byline, because a set with no `author` of its own still
  # prints one when its meditations agree.
  @set_context [:author_profile, :derived_author, :derived_source]

  # A set's meditations in the order it is prayed, each with what a page or
  # an API response renders beside it.
  @prayer_order [set_memberships: [meditation: [:mystery, :narrations]]]
  @visible_set_in_prayer_order @prayer_order ++ @set_context

  resources do
    resource LumenViae.Rosary.Mystery do
      define :list_mysteries, action: :in_prayer_order, functions: @read

      define :list_mysteries_by_category,
        action: :by_category,
        args: [:category],
        functions: @read

      define :get_mystery, action: :read, get_by: [:id]
      define :create_mystery, action: :create
      define :update_mystery, action: :update
      define :delete_mystery, action: :destroy, default_options: [return_destroyed?: true]
    end

    resource LumenViae.Rosary.Meditation do
      define :list_meditations, action: :detailed, functions: @read

      define :list_meditations_with_sets,
        action: :detailed,
        default_options: [load: [:meditation_sets]],
        functions: @read

      define :get_meditation, action: :detailed, get_by: [:id]
      define :create_meditation, action: :create
      define :update_meditation, action: :update
      define :delete_meditation, action: :destroy, default_options: [return_destroyed?: true]
      define :archive_meditation, action: :archive
      define :unarchive_meditation, action: :unarchive
    end

    resource LumenViae.Rosary.MeditationSet do
      define :list_meditation_sets,
        action: :catalogue,
        default_options: [load: @set_context],
        functions: @read

      define :list_visible_meditation_sets,
        action: :visible,
        default_options: [load: @set_context],
        functions: @read

      define :list_visible_meditation_sets_with_meditations,
        action: :visible,
        default_options: [load: [:meditations | @set_context]],
        functions: @read

      define :list_visible_meditation_sets_by_category,
        action: :visible,
        args: [:category],
        default_options: [load: [:meditations | @set_context]],
        functions: @read

      define :get_meditation_set,
        action: :read,
        get_by: [:id],
        default_options: [load: [:meditations]]

      define :create_meditation_set, action: :create
      define :update_meditation_set, action: :update

      define :delete_meditation_set,
        action: :destroy,
        default_options: [return_destroyed?: true]

      define :update_meditation_set_artwork, action: :record_artwork
      define :update_meditation_set_artwork_metadata, action: :update_artwork_metadata
    end

    resource LumenViae.Rosary.SetMembership do
      define :add_meditation_to_set,
        action: :create,
        args: [:meditation_set_id, :meditation_id, :order]
    end

    resource LumenViae.Rosary.Completion

    resource LumenViae.Rosary.Author do
      define :list_authors, action: :alphabetical, functions: @read
      define :get_author, action: :read, get_by: [:id]
      define :create_author, action: :create
      define :update_author, action: :update
      define :delete_author, action: :destroy, default_options: [return_destroyed?: true]
      define :update_author_artwork, action: :record_artwork
      define :update_author_artwork_metadata, action: :update_artwork_metadata
    end

    resource LumenViae.Rosary.Narration

    # No tables: GraphQL's view of the narration voices and the spoken
    # Rosary, both of which are configuration rather than data.
    resource LumenViae.Rosary.NarrationVoice
    resource LumenViae.Rosary.SpokenRosary
  end

  require Ash.Query

  alias LumenViae.Rosary.Artwork
  alias LumenViae.Rosary.Author
  alias LumenViae.CentralTime
  alias LumenViae.Rosary.Completion
  alias LumenViae.Rosary.MeditationSet
  alias LumenViae.Rosary.Meditation
  alias LumenViae.Rosary.Mystery
  alias LumenViae.Rosary.Narration
  alias LumenViae.Rosary.SetMembership
  alias LumenViae.Rosary.Voices
  alias LumenViae.Storage.S3

  ## Mysteries
  #
  # list_mysteries!/0, list_mysteries_by_category!/1, get_mystery!/1,
  # create_mystery/1, update_mystery/2 and delete_mystery/1 are the code
  # interface defined in the resources block above.

  def count_mysteries, do: Ash.count!(Mystery)

  ## Meditations
  #
  # list_meditations!/0 and list_meditations_with_sets!/0 (oldest first, each
  # with its mystery and narrations; the second with its sets too),
  # get_meditation/1 and get_meditation!/1, create_meditation/1,
  # update_meditation/2, delete_meditation/1, archive_meditation/1 and
  # unarchive_meditation/1 are the code interface defined in the resources
  # block above. To validate attributes without writing them, as the CSV
  # import's dry run does, ask for the changeset:
  # changeset_to_create_meditation/1, changeset_to_update_meditation/2.

  def count_meditations, do: Ash.count!(Meditation)

  def meditation_archived?(%{archived_at: archived_at}), do: not is_nil(archived_at)

  @doc """
  Returns whichever of the given audio filenames are already claimed by a
  meditation, so an import can warn before it overwrites their audio.
  """
  def list_taken_audio_urls([]), do: []

  def list_taken_audio_urls(audio_urls) do
    Meditation
    |> Ash.Query.for_read(:with_audio_filenames, %{audio_urls: audio_urls})
    |> Ash.Query.select([:audio_url])
    |> Ash.read!()
    |> Enum.map(& &1.audio_url)
  end

  @doc """
  The lines of an error from one of this domain's writes, as
  `"field: message; field: message"`, for the reports the import and the
  mix tasks print. Takes what a write returns in its `{:error, _}`, or a
  changeset from one of the `changeset_to_*` functions.

  `error_details/1` is the same reading as a map, for the API's envelope.
  """
  def error_summary(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.flat_map(&form_errors/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map_join("; ", fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
  end

  # The same reading of an error that an AshPhoenix form shows beside a
  # field, so a report and a form never describe one failure two ways. An
  # error with no field of its own (a record that was not found, say) is
  # reported under `base`.
  defp form_errors(error) do
    case AshPhoenix.FormData.Error.impl_for(error) &&
           AshPhoenix.FormData.Error.to_form_error(error) do
      empty when empty in [nil, false, []] ->
        [{:base, Exception.message(error)}]

      form_errors ->
        form_errors
        |> List.wrap()
        |> Enum.map(fn {field, message, vars} ->
          {field,
           Regex.replace(~r"%{(\w+)}", message, fn whole, key ->
             case Enum.find(vars, fn {name, _value} -> to_string(name) == key end) do
               {_name, value} -> to_string(value)
               nil -> whole
             end
           end)}
        end)
    end
  end

  ## Narration

  defdelegate list_voices(), to: Voices, as: :list
  defdelegate default_voice(), to: Voices, as: :default
  defdelegate fetch_voice(slug), to: Voices, as: :fetch

  @doc """
  How many meditations each voice has recorded, as `%{voice => count}`.
  """
  def narration_counts_by_voice do
    Narration
    |> Ash.Query.select([:voice])
    |> Ash.read!()
    |> Enum.frequencies_by(& &1.voice)
  end

  @doc """
  Meditation ids that have a recording in `voice_slug`.
  """
  def meditation_ids_with_narration(voice_slug) do
    Narration
    |> Ash.Query.for_read(:in_voice, %{voice: voice_slug})
    |> Ash.Query.select([:meditation_id])
    |> Ash.read!()
    |> Enum.map(& &1.meditation_id)
  end

  @doc """
  Records that `s3_key` now holds `voice`'s recording of the meditation.

  Called by the audio pipeline's callers once the upload has succeeded; a
  row here is a promise that the object exists. Returns the meditation with
  its narrations reloaded so the caller can go on rendering it.
  """
  def record_narration(%{id: meditation_id} = meditation, voice_slug, s3_key)
      when is_binary(voice_slug) and is_binary(s3_key) do
    with {:ok, _voice} <- Voices.fetch(voice_slug),
         {:ok, _narration} <-
           Narration
           |> Ash.Changeset.for_create(:record, %{
             meditation_id: meditation_id,
             voice: voice_slug,
             s3_key: s3_key
           })
           |> Ash.create() do
      {:ok, %{meditation | narrations: narrations_of(meditation_id)}}
    end
  end

  defp narrations_of(meditation_id) do
    Narration
    |> Ash.Query.for_read(:for_meditation, %{meditation_id: meditation_id})
    |> Ash.read!()
  end

  @doc """
  The voices a meditation can be heard in, default first, each with the S3
  key of its recording: `[%{voice: %Voice{}, s3_key: key}]`.

  Only configured voices count. A row for a voice that has since been
  removed from config is a file nobody can be offered, so it is left out
  rather than rendered as a voice the app has no name for. Uses the
  loaded relationship when the meditation carries one, and asks the
  table otherwise.
  """
  def meditation_narrations(%{id: meditation_id} = meditation) do
    rows =
      case Map.get(meditation, :narrations) do
        narrations when is_list(narrations) -> narrations
        _not_loaded -> narrations_of(meditation_id)
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
  is exact, since a client asking for the male voice has made a choice. A
  retired (hidden) voice's slug is served by its successor
  (`Voices.resolve/1`).

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
    with {:ok, voice} <- Voices.resolve(voice_slug) do
      meditation
      |> meditation_narrations()
      |> Enum.find(&(&1.voice.slug == voice.slug))
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
  #
  # list_authors!/0, get_author!/1, create_author/1, update_author/2,
  # delete_author/1, update_author_artwork/2 (a completed upload) and
  # update_author_artwork_metadata/2 (what the curator typed) are the code
  # interface defined in the resources block above.

  ## Meditation sets
  #
  # create_meditation_set/1, update_meditation_set/2, delete_meditation_set/1,
  # update_meditation_set_artwork/2 (a completed upload) and
  # update_meditation_set_artwork_metadata/2 (what the curator typed) are
  # the code interface defined in the resources block above, as are the
  # reads:
  #
  #   * list_meditation_sets!/0 - every set, by category and then creation
  #     order, each with its linked author and its derived byline. The
  #     admin's list.
  #   * get_meditation_set!/1 - one set with its meditations, oldest first.
  #     Prefer get_meditation_set_with_ordered_meditations!/1 when the order
  #     the set is prayed in matters.
  #
  # The visible reads are further down.

  def count_meditation_sets, do: Ash.count!(MeditationSet)

  @doc """
  Number of meditations a set of the given category is expected to hold. The
  Seven Sorrows are prayed as seven; every other category is a five-decade
  Rosary.
  """
  def expected_meditation_count("seven_sorrows"), do: 7
  def expected_meditation_count(_category), do: 5

  @doc """
  The set with this name, or nil.

  Names repeat across categories - the four Liguori sets are all
  "St. Alphonsus Liguori" - so a category narrows the search when the
  caller has one. Without a category the name must be unique: several
  matches answer nil rather than one of them at random, since anything
  that then appended to "the" set would land in whichever came first.
  """
  def get_meditation_set_by_name(name, category \\ nil)

  def get_meditation_set_by_name(name, nil) do
    case named_sets(name, nil) |> Ash.Query.limit(2) |> Ash.read!() do
      [set] -> set
      _none_or_several -> nil
    end
  end

  def get_meditation_set_by_name(name, category) do
    name |> named_sets(category) |> Ash.read_one!()
  end

  @doc """
  How many sets carry this name, across every category.
  """
  def count_meditation_sets_by_name(name) do
    name |> named_sets(nil) |> Ash.count!()
  end

  defp named_sets(name, category) do
    Ash.Query.for_read(MeditationSet, :named, %{name: name, category: category})
  end

  @doc """
  Ids of the sets still waiting for a painting, for the admin dashboard.

  Id-shaped rather than a count because the dashboard only reports on sets
  the public can reach.
  """
  def meditation_set_ids_missing_artwork do
    MeditationSet
    |> Ash.Query.for_read(:missing_artwork)
    |> Ash.Query.select([:id])
    |> Ash.read!()
    |> Enum.map(& &1.id)
  end

  @doc """
  Returns `%{author_id => set count}` for every author with at least one set
  linked to them, so the authors list can say what each portrait is covering.
  """
  def meditation_set_counts_by_author do
    Author
    |> Ash.Query.select([:id])
    |> Ash.Query.load(:meditation_set_count)
    |> Ash.read!()
    |> Enum.reject(&(&1.meditation_set_count == 0))
    |> Map.new(&{&1.id, &1.meditation_set_count})
  end

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

  The linked author must be loaded for the fallback to apply; the list and
  visible-set reads load it. Where it is not loaded the set behaves as if
  it had no author.
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
  Fetches a set with its meditations in the order the set is prayed, which
  lives on the join row rather than on the meditations themselves. Hidden
  sets included: this is the admin's read.

  Raises an error that renders as a 404 when the set does not exist.
  """
  def get_meditation_set_with_ordered_meditations!(id) do
    MeditationSet |> Ash.get!(id, load: @prayer_order) |> in_prayer_order()
  end

  @doc """
  A set's meditations in the order the set is prayed, with mysteries and
  narrations loaded.
  """
  def list_meditations_in_set(set_id) do
    SetMembership
    |> Ash.Query.for_read(:in_set, %{meditation_set_id: set_id})
    |> Ash.Query.load(meditation: [:mystery, :narrations])
    |> Ash.read!()
    |> Enum.map(& &1.meditation)
  end

  # The many-to-many cannot be sorted by its join row, so prayer order is
  # read from the memberships and written over `meditations`, which is the
  # field every page and JSON view reads.
  defp in_prayer_order(%{set_memberships: memberships} = set) when is_list(memberships) do
    %{set | meditations: Enum.map(memberships, & &1.meditation)}
  end

  ## Visible meditation sets (public surfaces)
  #
  # A set is "visible" when none of its meditations are archived. Archiving a
  # single meditation therefore hides every set that contains it from the
  # public site and the iOS API, while the admin functions above keep
  # returning everything. The rule is MeditationSet's `visible?`
  # calculation, and these all go through its `:visible` read:
  #
  #   * list_visible_meditation_sets!/0
  #   * list_visible_meditation_sets_with_meditations!/0
  #   * list_visible_meditation_sets_by_category!/1 (with meditations)
  #
  # Each set comes with its linked author and its derived byline.

  @doc """
  Same as `get_meditation_set_with_ordered_meditations!/1` but raises its
  404 when the set contains an archived meditation too, so hidden sets
  cannot be reached by direct URL.
  """
  def get_visible_meditation_set_with_ordered_meditations!(id) do
    MeditationSet
    |> Ash.get!(id, action: :visible, load: @visible_set_in_prayer_order)
    |> in_prayer_order()
  end

  # The id column is a bigint, and a number outside its range is rejected by
  # the driver as an encoding error rather than as a missing row - which
  # reached a client as a 500 with a stacktrace for what is only a nonsense
  # URL.
  @id_range 1..9_223_372_036_854_775_807

  @doc """
  Result-shaped sibling of
  `get_visible_meditation_set_with_ordered_meditations!/1`.

  Returns `{:ok, set}`, or `{:error, :not_found}` for a set that does not
  exist, is not an id at all, is a number no id could ever be, or is hidden
  because one of its meditations is archived. The bang version stays for
  the pages, where a 404 by exception is the right answer; the API wants
  the error in hand so it goes through the fallback controller and comes
  back in the same envelope as every other error.
  """
  def fetch_visible_meditation_set(id) do
    with {:ok, id} <- set_id(id),
         {:ok, set} <-
           Ash.get(MeditationSet, id, action: :visible, load: @visible_set_in_prayer_order) do
      {:ok, in_prayer_order(set)}
    else
      :error ->
        {:error, :not_found}

      # Only a missing or hidden set is "not found". Anything else is a
      # fault, and answering 404 for it would hide the fault.
      {:error, %Ash.Error.Invalid{errors: errors} = error} ->
        if Enum.any?(errors, &is_struct(&1, Ash.Error.Query.NotFound)),
          do: {:error, :not_found},
          else: raise(error)

      {:error, error} ->
        raise error
    end
  end

  defp set_id(id) when is_integer(id), do: if(id in @id_range, do: {:ok, id}, else: :error)

  defp set_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> set_id(id)
      _not_an_id -> :error
    end
  end

  defp set_id(_id), do: :error

  @doc """
  Returns a MapSet of ids of sets that are hidden from public surfaces
  because they contain at least one archived meditation.
  """
  def hidden_meditation_set_ids do
    MeditationSet
    |> Ash.Query.filter(not visible?)
    |> Ash.Query.select([:id])
    |> Ash.read!()
    |> MapSet.new(& &1.id)
  end

  ## Set membership
  #
  # add_meditation_to_set/3 (set id, meditation id, order) is the code
  # interface defined in the resources block above.

  @doc """
  Takes a meditation out of a set. Removing one that is not in the set is
  not an error.
  """
  def remove_meditation_from_set(set_id, meditation_id) do
    SetMembership
    |> Ash.Query.for_read(:in_set, %{meditation_set_id: set_id})
    |> Ash.Query.filter(meditation_id == ^meditation_id)
    |> Ash.bulk_destroy!(:destroy, %{})

    :ok
  end

  @doc """
  The order an appended meditation should take in a set: one past the
  highest order currently used.
  """
  def next_order_in_set(set_id) do
    highest =
      SetMembership
      |> Ash.Query.for_read(:in_set, %{meditation_set_id: set_id})
      |> Ash.max!(:order)

    (highest || 0) + 1
  end

  ## Admin content statistics

  def count_archived_meditations do
    Meditation |> Ash.Query.for_read(:archived) |> Ash.count!()
  end

  @doc """
  Returns a map of mystery_id => meditation count for every mystery that has
  at least one meditation.
  """
  def meditation_counts_by_mystery, do: mystery_counts(:meditation_count)

  @doc """
  The same map as `meditation_counts_by_mystery/0`, counting only active
  meditations.
  """
  def active_meditation_counts_by_mystery, do: mystery_counts(:active_meditation_count)

  defp mystery_counts(aggregate) do
    Mystery
    |> Ash.Query.select([:id])
    |> Ash.Query.load(aggregate)
    |> Ash.read!()
    |> Enum.reject(&(Map.fetch!(&1, aggregate) == 0))
    |> Map.new(&{&1.id, Map.fetch!(&1, aggregate)})
  end

  @doc """
  Counts active meditations that do not belong to any meditation set.

  Archived ones are left out: a meditation deliberately taken out of
  circulation and out of its sets is finished, not unfinished.
  """
  def count_meditations_not_in_any_set do
    Meditation |> Ash.Query.for_read(:active_in_no_set) |> Ash.count!()
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
    Meditation |> Ash.Query.for_read(:public_missing_audio) |> meditation_ids()
  end

  @doc """
  Ids of active meditations that have an audio filename but lack a recording
  in at least one configured voice - an import whose generation failed
  partway, or a set imported before a voice was added. Each is one
  `regenerate_audio --only-missing` away from being whole.
  """
  def meditation_ids_missing_a_voice do
    voices = Enum.map(Voices.list(), & &1.slug)

    Meditation
    |> Ash.Query.for_read(:missing_a_voice, %{voices: voices})
    |> meditation_ids()
  end

  defp meditation_ids(query) do
    query |> Ash.Query.select([:id]) |> Ash.read!() |> Enum.map(& &1.id)
  end

  @doc """
  Returns a map of meditation_set_id => stats for every set that has at least
  one meditation. Stats: meditation_count, audio_count (meditations with an
  audio file), archived_count.
  """
  def meditation_set_stats do
    MeditationSet
    |> Ash.Query.select([:id])
    |> Ash.Query.load([:meditation_count, :audio_count, :archived_count])
    |> Ash.read!()
    |> Enum.reject(&(&1.meditation_count == 0))
    |> Map.new(
      &{&1.id,
       %{
         meditation_count: &1.meditation_count,
         audio_count: &1.audio_count,
         archived_count: &1.archived_count
       }}
    )
  end

  ## Rosary completions (analytics)
  #
  # A completion is recorded when someone presses the button at the end of
  # the last mystery, never by arriving at it. Reaching the final screen is
  # something a crawler does for free; pressing the button is not, and the
  # numbers below are only worth reading if they mean a Rosary was prayed.

  def count_total_completions, do: Ash.count!(Completion)

  def count_completions_in_range(start_at, end_at) do
    start_at |> completions_between(end_at) |> Ash.count!()
  end

  defp completions_between(start_at, end_at) do
    Ash.Query.for_read(Completion, :in_range, %{since: start_at, until: end_at})
  end

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
    * `:prayed_aloud` - whether the spoken Rosary was on

  The address travels as the action's context rather than as one of its
  inputs, and the place is filled in afterwards by a background task; see
  `LumenViae.Rosary.Completion.Stamp` for why, on both counts.

  Returns `{:ok, completion}` or `{:error, %Ash.Error.Invalid{}}`.
  """
  def record_completion(meditation_set_id, context \\ %{}) when is_map(context) do
    Completion
    |> Ash.Changeset.for_create(
      :record,
      %{
        meditation_set_id: meditation_set_id,
        source: context[:source],
        time_zone: context[:time_zone],
        locale: context[:locale],
        prayed_aloud: context[:prayed_aloud]
      },
      context: %{client_ip: context[:ip]}
    )
    |> Ash.create()
  end

  @doc """
  The field-by-field messages of an error from one of this domain's writes,
  as `%{field => [message]}`: what the API's error envelope carries as
  `details`.
  """
  def error_details(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.flat_map(&form_errors/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @doc """
  Gets completion statistics grouped by meditation set.

  Returns a list of %{set_id, set_name, category, count} maps, most
  completed first.

  ## Options

    * `:days` - only count completions from the trailing N days, so the
      dashboard can show what is being prayed *now* rather than a ranking
      dominated by whichever set has existed longest
  """
  def get_completions_by_set(opts \\ []) do
    range =
      case opts[:days] do
        nil -> %{}
        days -> %{since: days_ago(days), until: DateTime.utc_now()}
      end

    MeditationSet
    |> Ash.Query.select([:id, :name, :category])
    |> Ash.Query.load(completion_count: range)
    |> Ash.read!()
    |> Enum.reject(&(&1.completion_count == 0))
    |> Enum.sort_by(&{-&1.completion_count, &1.id})
    |> Enum.map(
      &%{set_id: &1.id, set_name: &1.name, category: &1.category, count: &1.completion_count}
    )
  end

  @doc """
  Gets recent completions for the dashboard.
  Returns the last N completions with set information and location data.
  """
  def get_recent_completions(limit \\ 10) do
    Completion
    |> Ash.Query.for_read(:recent, %{limit: limit})
    |> Ash.Query.load(meditation_set: Ash.Query.select(MeditationSet, [:name, :category]))
    |> Ash.read!()
    |> Enum.map(fn completion ->
      %{
        id: completion.id,
        set_name: completion.meditation_set.name,
        category: completion.meditation_set.category,
        completed_at: completion.completed_at,
        city: completion.city,
        region: completion.region,
        country: completion.country,
        country_code: completion.country_code,
        source: completion.source
      }
    end)
  end

  @doc """
  Where the last `days` of Rosaries were prayed from, and on what.

  Returns `%{countries:, cities:, sources:, prayed_aloud:, located:, total:}`.

  `located` and `total` are both here on purpose. A place is attached by a
  best-effort lookup that can be switched off, rate limited, or simply
  wrong about an address, so the country list is drawn from a subset of the
  rows and the reader needs to know how large that subset is. A ranking
  covering a tenth of the completions and one covering all of them look
  identical otherwise.

  One read of the period's rows, six small columns each, folded here.
  """
  def completion_locations(days) when is_integer(days) and days > 0 do
    rows =
      days_ago(days)
      |> completions_between(DateTime.utc_now())
      |> Ash.Query.select([:city, :region, :country, :country_code, :source, :prayed_aloud])
      |> Ash.read!()

    %{
      # Rows whose lookup never produced a country are left out rather than
      # grouped under a blank heading.
      countries:
        rows
        |> Enum.reject(&is_nil(&1.country))
        |> ranked(&{&1.country, &1.country_code})
        |> Enum.map(fn {{country, code}, count} ->
          %{country: country, country_code: code, count: count}
        end),
      # Grouped by city *and* region, because a city name on its own is not
      # a place: there is a Paris in Texas, and several dozen Springfields.
      cities:
        rows
        |> Enum.reject(&is_nil(&1.city))
        |> ranked(&{&1.city, &1.region, &1.country_code})
        |> Enum.map(fn {{city, region, code}, count} ->
          %{city: city, region: region, country_code: code, count: count}
        end),
      # Completions recorded before a source was stored answer to `nil`.
      sources: Enum.frequencies_by(rows, & &1.source),
      # true, false, or nil for not reported either way.
      prayed_aloud: Enum.frequencies_by(rows, & &1.prayed_aloud),
      located: Enum.count(rows, &(not is_nil(&1.country_code))),
      total: length(rows)
    }
  end

  # Most frequent first, then by name, so two places prayed from equally
  # often always come out in the same order.
  defp ranked(rows, key) do
    rows
    |> Enum.frequencies_by(key)
    |> Enum.sort_by(fn {group, count} -> {-count, elem(group, 0)} end)
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
      active_sets_30: count_sets_completed_in_range(days_ago(30), now)
    }
  end

  # How many distinct sets have been completed at least once in the range.
  defp count_sets_completed_in_range(start_at, end_at) do
    start_at
    |> completions_between(end_at)
    |> Ash.Query.select([:meditation_set_id])
    |> Ash.read!()
    |> Enum.uniq_by(& &1.meditation_set_id)
    |> length()
  end

  @doc """
  A dense daily series for the trailing N days, oldest first, as
  `[%{date: %Date{}, count: integer}]`.

  Days with no completions are filled in with zero: a chart that silently
  drops empty days draws a flat line through a week nobody prayed.

  The day each completion belongs to is Completion's `local_day`
  calculation, worked out by Postgres in the reporting zone.
  """
  def completions_by_day(days) when is_integer(days) and days > 0 do
    today = CentralTime.today()
    first = Date.add(today, -(days - 1))

    counted =
      first
      |> CentralTime.day_start()
      |> completions_between(DateTime.utc_now())
      |> Ash.Query.select([:id])
      |> Ash.Query.load(local_day: %{time_zone: reporting_time_zone()})
      |> Ash.read!()
      |> Enum.frequencies_by(& &1.local_day)

    Enum.map(0..(days - 1), fn offset ->
      date = Date.add(first, offset)
      %{date: date, count: Map.get(counted, date, 0)}
    end)
  end

  defp days_ago(days), do: DateTime.add(DateTime.utc_now(), -days * 24 * 3600, :second)
end
