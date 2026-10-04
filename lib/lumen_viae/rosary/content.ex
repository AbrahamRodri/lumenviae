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

  `learn.json` is the iOS app's How to Pray course and `guided_rosary.json`
  its "Your First Rosary", the Rosary a step at a time for each of the
  four sets, both word for word. Every prayer id either names is one
  `prayers.json` holds, and every door of a reading leads to a target in
  `door_targets/0`; a file that breaks either fails the compile. Their
  shapes are `Types.RosaryLearn` and `Types.GuidedRosary`, documented in
  docs/JSON_API.md, "The How to Pray course".

  ## Every file is dated

  Each file carries a top-level `updated_at`, an ISO 8601 UTC timestamp:
  the moment its content last changed. `updated_at/0` is the latest of
  them. `version/1` fingerprints the content itself, never the dates, so it
  cannot drift from what is served; the date says when.
  `test/lumen_viae/rosary/content_test.exs` keeps each file's history of
  dates and versions, so changing a file without dating it fails the build:
  bump the file's `updated_at` and add its new version to that history.

  ## The companion sections

  Beside the prayers, four files hold what the app keeps around the
  Rosary, each a section of the document: `quotes.json` (`quotes`: the
  daily quotation and how one is chosen), `milestones.json` (`milestones`:
  the streak's named devotional milestones), `reminders.json`
  (`reminders`: the daily reminders' messages in their groups, what each
  intention draws from, and the selection rule) and `forms.json` (`forms`:
  the Rosary's forms, the Audio and Counting choices and what each form's
  page offers). The words are the app's, copied verbatim; the rules they
  go with are in docs/JSON_API.md, "The content document". A fifth
  section, `labels`, is code (`LumenViae.Rosary.RosaryContent.Labels`),
  dated and pinned there.

  A file that is missing a field, holds an unknown group, repeats an id,
  pairs languages of different lengths, names a prayer, place or style
  that does not exist, or carries no valid date fails the compile, never
  a request.
  """

  alias LumenViae.Rosary.Categories
  alias LumenViae.Rosary.Content.ScriptCheck

  @dir Path.join(:code.priv_dir(:lumen_viae), "rosary_content")

  @prayers_path Path.join(@dir, "prayers.json")
  @external_resource @prayers_path

  @learn_path Path.join(@dir, "learn.json")
  @external_resource @learn_path

  @guided_rosary_path Path.join(@dir, "guided_rosary.json")
  @external_resource @guided_rosary_path

  @quotes_path Path.join(@dir, "quotes.json")
  @external_resource @quotes_path
  @milestones_path Path.join(@dir, "milestones.json")
  @external_resource @milestones_path
  @reminders_path Path.join(@dir, "reminders.json")
  @external_resource @reminders_path
  @forms_path Path.join(@dir, "forms.json")
  @external_resource @forms_path

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

  @script Map.get(script_file, "script")

  # Every part of the file a Rosary or the document needs: see ScriptCheck.
  case ScriptCheck.errors(@script, @prayer_ids, Categories.slugs()) do
    [] ->
      :ok

    errors ->
      raise CompileError,
        description: "priv/rosary_content/script.json:\n  " <> Enum.join(errors, "\n  ")
  end

  # learn.json and guided_rosary.json: the How to Pray course and "Your
  # First Rosary". Their shapes are checked by casting them to their types
  # (Types.RosaryLearn, Types.GuidedRosary) when the sections are served
  # and in the test; what a type cannot say, every prayer id and door
  # target naming something there is, is checked here.

  {learn_file, learn_updated_at} = read.(@learn_path)
  {guided_rosary_file, guided_rosary_updated_at} = read.(@guided_rosary_path)

  @learn Map.fetch!(learn_file, "learn")
  @guided_rosary Map.fetch!(guided_rosary_file, "guided_rosary")

  check_prayers = fn file, ids ->
    for id <- ids, id not in @prayer_ids do
      raise CompileError,
        description:
          "priv/rosary_content/#{file} names the prayer #{inspect(id)}, which prayers.json does not hold"
    end
  end

  check_prayers.(
    "learn.json",
    Enum.flat_map(@learn["steps"], & &1["prayer_ids"]) ++
      Enum.map(@learn["prayer_counts"], & &1["prayer_id"]) ++
      Enum.flat_map(@learn["lessons"], fn lesson ->
        Enum.flat_map(lesson["sections"], &(&1["prayer_ids"] || []))
      end)
  )

  @reading_ids for shelf <- @learn["shelves"], reading <- shelf["readings"], do: reading["id"]

  if Enum.uniq(@reading_ids) != @reading_ids do
    raise CompileError, description: "priv/rosary_content/learn.json repeats a reading id"
  end

  # Where a reading's door may lead. Every target resolves inside the
  # document but a `library` door's: a reading the iOS app holds that this
  # document does not serve (the Marian Library's), listed so a typo still
  # fails the compile.
  @door_targets %{
    "act" => ~w(todays_rosary),
    "reading" => @reading_ids,
    "library" => ~w(montfort cana),
    "prayer" => @prayer_ids,
    "page" => ~w(mysteries_in_scripture)
  }

  for shelf <- @learn["shelves"],
      reading <- shelf["readings"],
      %{"kind" => kind, "target" => target} <- reading["doors"],
      target not in Map.get(@door_targets, kind, []) do
    raise CompileError,
      description:
        "priv/rosary_content/learn.json: #{reading["id"]} has a door #{kind}:#{target}, which is not in Content.door_targets/0"
  end

  @guided_parts @guided_rosary["parts"]

  if Enum.uniq(@guided_parts) != @guided_parts do
    raise CompileError, description: "priv/rosary_content/guided_rosary.json repeats a part"
  end

  for %{"category" => category, "steps" => steps} <- @guided_rosary["rosaries"],
      step <- steps do
    check_prayers.("guided_rosary.json", step["prayer_ids"])

    if step["part"] not in @guided_parts do
      raise CompileError,
        description:
          "priv/rosary_content/guided_rosary.json: a #{category} step is on #{inspect(step["part"])}, which is not one of its parts"
    end
  end

  for anatomy <- @guided_rosary["anatomy"], part <- anatomy["parts"], part not in @guided_parts do
    raise CompileError,
      description:
        "priv/rosary_content/guided_rosary.json: the anatomy's #{anatomy["id"]} names #{inspect(part)}, which is not one of its parts"
  end

  # The companion files are read as prayers.json is, and each is checked
  # for the shape its section is served in.
  invalid = fn file, message ->
    raise CompileError, description: "priv/rosary_content/#{file}: #{message}"
  end

  text? = fn value -> is_binary(value) and String.trim(value) != "" end
  text_or_nil? = fn value -> is_nil(value) or (is_binary(value) and String.trim(value) != "") end

  {quotes_file, quotes_updated_at} = read.(@quotes_path)
  @quotes Map.fetch!(quotes_file, "quotes")

  with %{"rotation" => %{"home_offset" => home, "after_prayer_offset_divisor" => divisor}} <-
         @quotes,
       true <- is_integer(home) and is_integer(divisor) and divisor > 0 do
    :ok
  else
    _ ->
      invalid.(
        "quotes.json",
        "quotes needs a rotation with a home_offset and a positive after_prayer_offset_divisor"
      )
  end

  if @quotes["items"] == [] or not is_list(@quotes["items"]) or
       not Enum.all?(@quotes["items"], fn
         %{"text" => text, "author" => author, "source" => source} ->
           text?.(text) and text?.(author) and text_or_nil?.(source)

         _other ->
           false
       end) do
    invalid.("quotes.json", "every quote needs a text and an author, and a source or null")
  end

  {milestones_file, milestones_updated_at} = read.(@milestones_path)
  @milestones Map.fetch!(milestones_file, "milestones")

  if @milestones == [] or not is_list(@milestones) or
       not Enum.all?(@milestones, fn
         %{"days" => days, "meaning" => meaning, "icon" => icon, "blessing" => blessing} ->
           is_integer(days) and days > 0 and text_or_nil?.(meaning) and text?.(icon) and
             text?.(blessing)

         _other ->
           false
       end) do
    invalid.(
      "milestones.json",
      "every milestone needs days, a meaning or null, an icon and a blessing"
    )
  end

  milestone_days = Enum.map(@milestones, & &1["days"])

  if milestone_days != Enum.sort(Enum.uniq(milestone_days)) do
    invalid.("milestones.json", "the milestones are in ascending order of days, each once")
  end

  {reminders_file, reminders_updated_at} = read.(@reminders_path)
  @reminders Map.fetch!(reminders_file, "reminders")

  %{
    "groups" => reminder_groups,
    "intentions" => reminder_intentions,
    "fallback_group" => reminder_fallback,
    "week_length" => reminder_week
  } = @reminders

  reminder_group_ids = Enum.map(reminder_groups, & &1["id"])

  if Enum.uniq(reminder_group_ids) != reminder_group_ids or reminder_group_ids == [] do
    invalid.("reminders.json", "every group needs its own id")
  end

  if not Enum.all?(reminder_groups, fn %{"messages" => messages} ->
       messages != [] and
         Enum.all?(messages, fn
           %{"title" => title, "body" => body} -> text?.(title) and text?.(body)
           _other -> false
         end)
     end) do
    invalid.("reminders.json", "every group needs messages, each with a title and a body")
  end

  # A message is shown as it is written: nothing in it is filled in.
  if Enum.any?(reminder_groups, fn %{"messages" => messages} ->
       Enum.any?(messages, &(&1["title"] =~ ~r/[{}%]/ or &1["body"] =~ ~r/[{}%]/))
     end) do
    invalid.("reminders.json", "a message holds a placeholder; none does, and the docs say so")
  end

  intention_ids = Enum.map(reminder_intentions, & &1["id"])

  if Enum.uniq(intention_ids) != intention_ids or
       not Enum.all?(reminder_intentions, fn intention ->
         text?.(intention["raw_value"]) and text?.(intention["name"]) and
           text?.(intention["detail"]) and intention["groups"] != [] and
           Enum.all?(intention["groups"], &(&1 in reminder_group_ids))
       end) do
    invalid.(
      "reminders.json",
      "every intention needs its own id, its words and groups that exist"
    )
  end

  if reminder_fallback not in reminder_group_ids or not is_integer(reminder_week) or
       reminder_week < 1 do
    invalid.(
      "reminders.json",
      "the fallback group must exist and the week must be a number of days"
    )
  end

  {forms_file, forms_updated_at} = read.(@forms_path)
  @forms Map.fetch!(forms_file, "forms")

  form_ids = Enum.map(@forms["forms"], & &1["id"])
  choice_ids = Enum.map(@forms["choices"], & &1["id"])
  row_ids = Enum.map(@forms["row_titles"], & &1["id"])

  if Enum.uniq(form_ids) != form_ids or
       not Enum.all?(@forms["forms"], fn form ->
         Enum.all?(~w(name recorded_as kicker subtitle detail about), &text?.(form[&1]))
       end) do
    invalid.(
      "forms.json",
      "every form needs its own id, a name, recorded_as, kicker, subtitle, detail and about"
    )
  end

  all_form_ids = Enum.uniq(["meditation" | form_ids])

  if not Enum.all?(@forms["choices"], fn choice ->
       text?.(choice["title"]) and text?.(choice["icon"]) and
         choice["options"] != [] and
         Enum.all?(choice["options"], fn option ->
           option["form"] in ["any" | all_form_ids] and is_boolean(option["value"]) and
             text?.(option["name"]) and text?.(option["note"])
         end)
     end) do
    invalid.(
      "forms.json",
      "every choice needs a title, an icon and options with a form, a value, a name and a note"
    )
  end

  for {key, ids} <- [{"offered", choice_ids}, {"rows", row_ids}],
      rule <- @forms[key] do
    if rule["form"] not in all_form_ids or
         not Enum.all?(rule["when_aloud"] ++ rule["when_silent"], &(&1 in ids)) do
      invalid.("forms.json", "#{key} names a form or an id that does not exist: #{inspect(rule)}")
    end
  end

  if not text?.(@forms["holy_audio_value"]) do
    invalid.(
      "forms.json",
      "holy_audio_value is the words under the Rosary Said Aloud's audio row"
    )
  end

  # One entry per file. A new file is read and checked as prayers.json is
  # above, and listed here; its sections join the document.
  @files [
    %{name: "prayers.json", content: prayers_file, updated_at: prayers_updated_at},
    %{name: "script.json", content: script_file, updated_at: script_updated_at},
    %{name: "learn.json", content: learn_file, updated_at: learn_updated_at},
    %{
      name: "guided_rosary.json",
      content: guided_rosary_file,
      updated_at: guided_rosary_updated_at
    },
    %{name: "quotes.json", content: quotes_file, updated_at: quotes_updated_at},
    %{name: "milestones.json", content: milestones_file, updated_at: milestones_updated_at},
    %{name: "reminders.json", content: reminders_file, updated_at: reminders_updated_at},
    %{name: "forms.json", content: forms_file, updated_at: forms_updated_at}
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

  @doc """
  The daily quotations and how one is chosen: `%{"rotation" => ..., "items"
  => [...]}`.
  """
  @spec quotes() :: map
  def quotes, do: @quotes

  @doc "The streak milestones, by days ascending."
  @spec milestones() :: [map]
  def milestones, do: @milestones

  @doc """
  The reminders: `%{"groups" => ..., "intentions" => ..., "fallback_group"
  => ..., "week_length" => ...}`.
  """
  @spec reminders() :: map
  def reminders, do: @reminders

  @doc """
  The Rosary's forms, its two choices and what each form's page offers.
  """
  @spec forms() :: map
  def forms, do: @forms

  @doc "One prayer by its id, or `nil`."
  @spec prayer(String.t()) :: map | nil
  def prayer(id), do: Enum.find(@prayers, &(&1["id"] == id))

  @doc """
  The How to Pray course: the `learn` section, string keys throughout, as
  `priv/rosary_content/learn.json` holds it. See `Types.RosaryLearn`.
  """
  @spec learn() :: map
  def learn, do: @learn

  @doc """
  "Your First Rosary": the `guided_rosary` section, as
  `priv/rosary_content/guided_rosary.json` holds it. See
  `Types.GuidedRosary`.
  """
  @spec guided_rosary() :: map
  def guided_rosary, do: @guided_rosary

  @doc """
  Where a reading's door may lead: each `kind` with the targets it may
  name. See `Types.ReadingDoor`.
  """
  @spec door_targets() :: %{String.t() => [String.t()]}
  def door_targets, do: @door_targets

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
