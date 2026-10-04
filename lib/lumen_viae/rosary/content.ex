defmodule LumenViae.Rosary.Content do
  @moduledoc """
  The Rosary's fixed words: what `GET /api/v2/rosary-content` serves and the
  spoken Rosary says.

  A value module. The content is files in `priv/rosary_content/`, read when
  this module compiles, so it is a deploy rather than an edit in the
  admin: no query, no state.

  ## The words are the server's

  Since 3 October 2026 the server holds the Rosary's words, and the iOS
  app's bundle is its offline copy. `prayers.json` holds the twelve
  prayers the Rosary and the Seven Sorrows chaplet say, in the order they
  are said, each in English and Latin. The English is exactly what
  `LumenViae.Rosary.PrayerAudio` sends the narrator (it reads it from
  here), so a word changed in that file is a clip to record again: see
  docs/SPOKEN_ROSARY.md before touching it.

  Each prayer is `id` (the app's prayer id), `group` (`rosary`, the
  Rosary's eight; `chaplet`, the Seven Sorrows chaplet's two; `after`, the
  optional prayers after the Rosary), `title` and `text`, each in `en` and
  `la`. A text is a list of lines, broken where the app breaks them on
  screen, and the two languages have the same number of lines so a
  two-language view can pair them; a `[bracketed]` line is a rubric, shown
  and not said as written.

  `script.json` holds the order a Rosary is said in, as templates the
  spoken Rosary and a client both expand (`script/0`, docs/SPOKEN_ROSARY.md).
  Its captions, pauses, beads and pendant places are shown and timed but
  never spoken, so a change to them records nothing.

  ## Every file is dated

  Each file carries a top-level `updated_at`, an ISO 8601 UTC timestamp:
  the moment its content last changed. `updated_at/0` is the latest of
  them. `version/1` fingerprints the content itself, never the dates, so it
  cannot drift from what is served; the date says when.
  `test/lumen_viae/rosary/content_test.exs` keeps each file's history of
  dates and versions, so changing a file without dating it fails the build:
  bump the file's `updated_at` and add its new version to that history.

  A file that is missing a field, holds an unknown group, repeats an id,
  pairs languages of different lengths, names a prayer, place or style
  that does not exist, or carries no valid date fails the compile, never
  a request.
  """

  alias LumenViae.Rosary.Categories

  @dir Path.join(:code.priv_dir(:lumen_viae), "rosary_content")

  @prayers_path Path.join(@dir, "prayers.json")
  @external_resource @prayers_path

  @groups ~w(rosary chaplet after)

  read = fn path ->
    file = path |> File.read!() |> Jason.decode!()

    updated_at =
      case DateTime.from_iso8601(Map.get(file, "updated_at") || "") do
        {:ok, at, 0} ->
          DateTime.truncate(at, :second)

        _ ->
          raise CompileError,
            description:
              "priv/rosary_content/#{Path.basename(path)} needs a top-level \"updated_at\", an ISO 8601 UTC timestamp"
      end

    {Map.delete(file, "updated_at"), updated_at}
  end

  {prayers_file, prayers_updated_at} = read.(@prayers_path)

  @prayers Map.fetch!(prayers_file, "prayers")

  for prayer <- @prayers do
    with %{
           "id" => id,
           "group" => group,
           "title" => %{"en" => en_title, "la" => la_title},
           "text" => %{"en" => [_ | _] = en, "la" => [_ | _] = la}
         }
         when is_binary(id) and is_binary(en_title) and is_binary(la_title) <- prayer,
         true <- Enum.all?(en ++ la, &is_binary/1) do
      if group not in @groups do
        raise CompileError,
          description:
            "priv/rosary_content/prayers.json: #{id}'s group #{inspect(group)} is not one of #{inspect(@groups)}"
      end

      if length(en) != length(la) do
        raise CompileError,
          description:
            "priv/rosary_content/prayers.json: #{id} has #{length(en)} English lines and #{length(la)} Latin; a two-language view pairs them line for line"
      end
    else
      _ ->
        raise CompileError,
          description:
            "priv/rosary_content/prayers.json: every prayer needs an id, a group, a title in en and la, and text in en and la as non-empty lists of lines: #{inspect(prayer)}"
    end
  end

  @prayer_ids Enum.map(@prayers, & &1["id"])

  if Enum.uniq(@prayer_ids) != @prayer_ids do
    raise CompileError, description: "priv/rosary_content/prayers.json repeats a prayer id"
  end

  @script_path Path.join(@dir, "script.json")
  @external_resource @script_path

  {script_file, script_updated_at} = read.(@script_path)

  @script Map.fetch!(script_file, "script")

  @step_kinds ~w(prayer announcement meditation verse)

  # The templates may name only the prayers above, the places on the
  # pendant and the styles the file declares, and only a decade repeats a
  # run of steps for each Hail Mary.
  script_steps =
    for form <- ["rosary", "chaplet"],
        part <- ["opening", "decade", "closing", "final"],
        step <- @script[form][part],
        do: {"#{form}.#{part}", step}

  extra_steps =
    for %{"id" => id, "steps" => steps} <- @script["closing_extras"],
        step <- steps,
        do: {"closing_extras.#{id}", step}

  places = Enum.map(@script["pendant"], & &1["place"])

  for {where, step} <- script_steps ++ extra_steps do
    %{"kind" => kind, "prayer_id" => prayer_id, "caption" => caption, "bead" => bead} = step

    valid? =
      kind in @step_kinds and is_binary(caption) and
        kind == "prayer" == prayer_id in @prayer_ids and
        step["place"] in [nil | places] and
        step["style"] in [nil | @script["styles"]] and
        is_integer(step["pause_ms"]) and step["pause_ms"] >= 0 and
        if(step["per_bead"],
          do: bead == nil and String.ends_with?(where, ".decade"),
          else: is_integer(bead)
        )

    if not valid? do
      raise CompileError,
        description:
          "priv/rosary_content/script.json: #{where} has a step it cannot say: #{inspect(step)}"
    end
  end

  for form <- ["rosary", "chaplet"] do
    runs =
      @script[form]["decade"]
      |> Enum.chunk_by(& &1["per_bead"])
      |> Enum.count(&hd(&1)["per_bead"])

    if runs != 1 do
      raise CompileError,
        description:
          "priv/rosary_content/script.json: #{form}'s decade needs one run of steps said on each Hail Mary, not #{runs}"
    end
  end

  if Enum.sort(@script["rosary"]["categories"] ++ @script["chaplet"]["categories"]) !=
       Enum.sort(Categories.slugs()) do
    raise CompileError,
      description: "priv/rosary_content/script.json: every category belongs to exactly one form"
  end

  # One entry per file. A new file is read and checked as prayers.json is
  # above, and listed here; its sections join the document.
  @files [
    %{name: "prayers.json", content: prayers_file, updated_at: prayers_updated_at},
    %{name: "script.json", content: script_file, updated_at: script_updated_at}
  ]

  @document Enum.reduce(@files, %{}, &Map.merge(&2, &1.content))

  @updated_at @files |> Enum.map(& &1.updated_at) |> Enum.max(DateTime)

  @doc """
  Everything served, keyed by section (`"prayers"`, `"script"`), string
  keys throughout, as the files hold it.
  """
  @spec document() :: map
  def document, do: @document

  @doc """
  The twelve prayers in the order they are said. See the moduledoc for
  their shape.
  """
  @spec prayers() :: [map]
  def prayers, do: @prayers

  @doc """
  The order a Rosary is said in, as templates: the Rosary's and the
  chaplet's opening, decade, closing and final steps, the optional
  prayers after the Rosary, the bead rules, the pendant's places and the
  styles. `LumenViae.Rosary.PrayerAudio.script/3` expands them, and a
  client can do the same offline. See docs/SPOKEN_ROSARY.md.
  """
  @spec script() :: map
  def script, do: @script

  @doc "The prayer ids, in the order they are said."
  @spec prayer_ids() :: [String.t()]
  def prayer_ids, do: @prayer_ids

  @doc "One prayer by its id, or `nil`."
  @spec prayer(String.t()) :: map | nil
  def prayer(id), do: Enum.find(@prayers, &(&1["id"] == id))

  @doc "The groups a prayer may belong to."
  @spec groups() :: [String.t()]
  def groups, do: @groups

  @doc """
  Each file in `priv/rosary_content/`: its name, its `updated_at` and the
  version of its own content (`version/1`), so a change can be traced to
  the file it was made in.
  """
  @spec files() :: [%{name: String.t(), updated_at: DateTime.t(), version: String.t()}]
  def files do
    for %{name: name, content: content, updated_at: updated_at} <- @files,
        do: %{name: name, updated_at: updated_at, version: version(content)}
  end

  @doc """
  When the content last changed: the latest `updated_at` of the files.
  """
  @spec updated_at() :: DateTime.t()
  def updated_at, do: @updated_at

  @doc """
  A short fingerprint of `document` (the served content by default): the
  same content always gives the same version, and any change to a word,
  a line break, an order or a field gives another. Maps are encoded with
  their keys sorted, so the version does not depend on how a map happens
  to be laid out in memory.
  """
  @spec version(map) :: String.t()
  def version(document \\ @document) do
    :crypto.hash(:sha256, document |> canonical() |> Jason.encode!())
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp canonical(map) when is_map(map) and not is_struct(map) do
    map
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Jason.OrderedObject.new()
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(value), do: value
end
