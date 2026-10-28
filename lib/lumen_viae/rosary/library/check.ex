defmodule LumenViae.Rosary.Library.Check do
  @moduledoc """
  What `priv/library/prayer_book.json`, `priv/library/chant_library.json`,
  `priv/library/consecration.json`, `priv/library/true_devotion.json`,
  `priv/library/carlo_acutis.json` and `priv/library/marian_library.json`
  must hold, checked as `LumenViae.Rosary.Library` compiles and again by
  `LumenViae.Curation.ChantUpload` before it rewrites a file.

  Each function takes a file's sections (string keys, as decoded) and
  returns the problems as sentences, `[]` when there are none. What a
  type cannot say is checked here: every id once, every id named exists,
  a prayer's English and Latin pairing line for line, a chant's lines in
  order within its recording, and every chant file carrying its URL, size
  and checksum, the URL content-addressed by that checksum, all on one
  base. An id or a score's file name goes into a device's storage, a
  local path and a bucket key, so it holds only letters, digits, `_` and
  `-`.
  """

  @sha256 ~r/\A[0-9a-f]{64}\z/

  # What a library reading's door may open, beyond its own document's
  # readings, a Prayer Book prayer and a category's mysteries: the acts
  # and the pages both apps have. docs/JSON_API.md, "Reading doors".
  @door_acts ~w(todays_rosary mass consecration)
  @door_pages ~w(marian_library carlo_acutis true_devotion true_devotion_book how_to_pray
                 mysteries_in_scripture)
  @name ~r/\A[A-Za-z0-9_-]+\z/

  @doc "The problems with a Prayer Book document's sections."
  @spec prayer_book_errors(map) :: [String.t()]
  def prayer_book_errors(%{"prayers" => prayers, "chapters" => chapters} = book)
      when is_list(prayers) and is_list(chapters) do
    prayer_ids = Enum.map(prayers, &id/1)

    chapter_ids = Enum.map(chapters, &id/1)

    Enum.flat_map(prayers, &prayer_errors/1) ++
      repeated("prayer", prayer_ids) ++
      unnamed("prayer id", prayer_ids) ++
      Enum.flat_map(chapters, &chapter_errors(&1, MapSet.new(prayer_ids))) ++
      repeated("chapter", chapter_ids) ++
      unnamed("chapter id", chapter_ids) ++
      orders_errors(list(book["orders"]), MapSet.new(prayer_ids), MapSet.new(chapter_ids)) ++
      antiphons_errors(list(book["marian_antiphons"]), MapSet.new(prayer_ids))
  end

  def prayer_book_errors(_document), do: ["the document needs a list of prayers and of chapters"]

  @doc """
  The problems with a Consecration document's sections: phases that run
  from day 1 without a gap, every day once and in order within its
  phase, every prayer a phase names and every prayer named, and feasts
  on dates that exist, in calendar order.
  """
  @spec consecration_errors(map) :: [String.t()]
  def consecration_errors(%{
        "phases" => phases,
        "days" => days,
        "prayers" => prayers,
        "feasts" => feasts
      })
      when is_list(phases) and is_list(days) and is_list(prayers) and is_list(feasts) do
    phase_ids = Enum.map(phases, &id/1)
    prayer_ids = Enum.map(prayers, &id/1)
    feast_ids = Enum.map(feasts, &id/1)
    # The rules across phases read only the phases that are maps; the
    # others are refused one by one, as "a phase needs an id".
    mapped = Enum.filter(phases, &is_map/1)
    named = for phase <- mapped, id <- list(phase["prayer_ids"]), do: id

    Enum.flat_map(phases, &phase_errors(&1, MapSet.new(prayer_ids))) ++
      repeated("phase", phase_ids) ++
      unnamed("phase id", phase_ids) ++
      phase_span_errors(mapped) ++
      days_errors(days, mapped) ++
      Enum.flat_map(prayers, &consecration_prayer_errors/1) ++
      repeated("prayer", prayer_ids) ++
      unnamed("prayer id", prayer_ids) ++
      for(id <- prayer_ids, is_binary(id), id not in named, do: "the prayer #{id} is in no phase") ++
      Enum.flat_map(feasts, &feast_errors/1) ++
      feast_order_errors(feasts) ++
      repeated("feast", feast_ids) ++
      unnamed("feast id", feast_ids)
  end

  def consecration_errors(_document),
    do: ["the document needs a list of phases, of days, of prayers and of feasts"]

  @doc """
  The problems with a True Devotion document's sections: its parts
  numbered 1, 2 and on, every chapter once and in a part there is (or 0,
  the Introduction's), and each chapter's paragraphs numbered from 0 in
  order, each `text` or a `subheading`. A device keeps a reader's place
  by chapter id and paragraph id, so neither may move. The summary page's
  `teaching` is checked as a library shelf (`prayer_ids` are the Prayer
  Book's), and each ejaculatory prayer's English and Latin pair line for
  line.
  """
  @spec true_devotion_errors(map, [String.t()]) :: [String.t()]
  def true_devotion_errors(
        %{
          "about" => about,
          "parts" => parts,
          "chapters" => chapters,
          "teaching" => teaching,
          "ejaculatory_prayers" => prayers
        },
        prayer_ids
      )
      when is_map(about) and is_list(parts) and is_list(chapters) and is_map(teaching) and
             is_list(prayers) do
    numbers = for %{"number" => number} <- parts, do: number
    chapter_ids = Enum.map(chapters, &id/1)

    required(about, ~w(title author translator source_note)) ++
      if(numbers == Enum.to_list(1..length(parts)//1),
        do: [],
        else: ["the parts are numbered 1, 2 and on, in order"]
      ) ++
      Enum.flat_map(chapters, &true_devotion_chapter_errors(&1, [0 | numbers])) ++
      repeated("chapter", chapter_ids) ++
      unnamed("chapter id", chapter_ids) ++
      library_shelves_errors([teaching], prayer_ids) ++
      for(
        prayer <- prayers,
        error <-
          required(prayer, ~w(title english latin)) ++
            pairing_errors(Map.put(prayer, "id", prayer["title"])),
        do: "ejaculatory prayer #{inspect(prayer["title"])}: #{error}"
      )
  end

  def true_devotion_errors(_document, _prayer_ids),
    do: [
      "the document needs an about, a teaching shelf, and a list of parts, of chapters and of ejaculatory prayers"
    ]

  @doc """
  The problems with St. Carlo Acutis's page: its feast on a real date,
  its shelves' readings each once with every door opening something
  there is (`prayer_ids` are the Prayer Book's), and every moment of the
  timeline and habit of the rule naming a reading of the page, a habit's
  act being one an act door may name.
  """
  @spec carlo_acutis_errors(map, [String.t()]) :: [String.t()]
  def carlo_acutis_errors(
        %{
          "feast" => feast,
          "shelves" => shelves,
          "timeline" => timeline,
          "rule" => rule,
          "sayings" => sayings,
          "prayer" => prayer
        },
        prayer_ids
      )
      when is_map(feast) and is_list(shelves) and is_list(timeline) and is_list(rule) and
             is_list(sayings) and is_binary(prayer) do
    reading_ids = for shelf <- shelves, reading <- list(shelf["readings"]), do: id(reading)

    library_feast_errors(feast) ++
      library_shelves_errors(shelves, prayer_ids) ++
      for(
        %{"reading_id" => reading_id} = item <- timeline ++ rule,
        reading_id not in reading_ids,
        do:
          "#{item["title"] || item["name"]} names the reading #{inspect(reading_id)}, which is not on a shelf"
      ) ++
      for(
        %{"act" => act} = habit <- rule,
        act != nil and act not in @door_acts,
        do: "the habit #{habit["name"]} has the act #{inspect(act)}, which no door may name"
      ) ++
      for(saying <- sayings, not is_binary(saying) or saying == "", do: "a saying is empty")
  end

  def carlo_acutis_errors(_document, _prayer_ids),
    do: [
      "the document needs a feast, a list of shelves, of timeline moments, of rule habits and of sayings, and a prayer"
    ]

  @doc """
  The problems with the Marian Library: its shelves as St. Carlo's are
  checked, and its feasts on real dates in the order of the year, each
  with a painting and naming, where it names one, a reading on its shelves.
  """
  @spec marian_library_errors(map, [String.t()]) :: [String.t()]
  def marian_library_errors(%{"feasts" => feasts, "shelves" => shelves}, prayer_ids)
      when is_list(feasts) and is_list(shelves) do
    reading_ids = for shelf <- shelves, reading <- list(shelf["readings"]), do: id(reading)

    library_shelves_errors(shelves, prayer_ids) ++
      Enum.flat_map(feasts, &library_feast_errors/1) ++
      feast_order_errors(feasts) ++
      for(
        feast <- feasts,
        error <- required(feast, ~w(name painting)),
        do: "#{feast["name"]}: #{error}"
      ) ++
      for(
        %{"reading_id" => reading_id} = feast <- feasts,
        reading_id != nil and reading_id not in reading_ids,
        do:
          "the feast #{feast["name"]} names the reading #{inspect(reading_id)}, which is not on a shelf"
      )
  end

  def marian_library_errors(_document, _prayer_ids),
    do: ["the document needs a list of feasts and of shelves"]

  # Shelves of library readings: each shelf and reading id once and safe
  # to store, every door opening something there is, every feast a date.
  defp library_shelves_errors(shelves, prayer_ids) do
    readings = for shelf <- shelves, reading <- list(shelf["readings"]), do: reading
    shelf_ids = Enum.map(shelves, &id/1)
    reading_ids = Enum.map(readings, &id/1)

    targets = %{
      "act" => @door_acts,
      "page" => @door_pages,
      "reading" => reading_ids,
      "prayer" => prayer_ids,
      "mysteries" => LumenViae.Rosary.Categories.slugs()
    }

    for(
      shelf <- shelves,
      list(shelf["readings"]) == [],
      do: "the shelf #{id(shelf)} has no readings"
    ) ++
      repeated("shelf", shelf_ids) ++
      unnamed("shelf id", shelf_ids) ++
      repeated("reading", reading_ids) ++
      unnamed("reading id", reading_ids) ++
      for(
        reading <- readings,
        %{"kind" => kind, "target" => target} <- list(reading["doors"]),
        target not in Map.get(targets, kind, []),
        do:
          "the reading #{id(reading)} has a door #{kind}:#{target}, which opens nothing there is"
      ) ++
      for(
        reading <- readings,
        is_map(reading["feast"]),
        error <- library_feast_errors(reading["feast"]),
        do: "the reading #{id(reading)}: #{error}"
      )
  end

  defp library_feast_errors(%{"month" => month, "day" => day} = feast)
       when is_integer(month) and is_integer(day) do
    # A leap year, so 29 February is a date.
    if match?({:ok, _date}, Date.new(2024, month, day)),
      do: [],
      else: ["the feast #{feast["name"]} on #{month}/#{day} is not a date"]
  end

  defp library_feast_errors(feast), do: ["the feast #{inspect(feast)} needs a month and a day"]

  @doc """
  The problems with a Chant Library document's sections. `prayer_ids`,
  when given, are the ids a chant's `prayer_ids` may name, and `base`,
  when given, is where every chant file must be (the public assets
  bucket's URL); without it, every file must at least share one base.
  """
  @spec chant_library_errors(map, [String.t()] | nil, String.t() | nil) :: [String.t()]
  def chant_library_errors(document, prayer_ids \\ nil, base \\ nil)

  def chant_library_errors(%{"groups" => groups, "chants" => chants}, prayer_ids, base)
      when is_list(groups) and is_list(chants) do
    group_ids = Enum.map(groups, &id/1)
    chant_ids = Enum.map(chants, &id/1)
    known_chants = MapSet.new(chant_ids)
    known_prayers = prayer_ids && MapSet.new(prayer_ids)

    placed =
      for group <- groups, part <- list(group["parts"]), id <- list(part["chant_ids"]), do: id

    Enum.flat_map(groups, &group_errors(&1, known_chants)) ++
      repeated("group", group_ids) ++
      Enum.flat_map(chants, &chant_errors(&1, MapSet.new(group_ids), known_prayers)) ++
      repeated("chant", chant_ids) ++
      unnamed("group id", group_ids) ++
      unnamed("chant id", chant_ids) ++
      unnamed("score file", for(chant <- chants, part <- list(chant["score"]), do: part["file"])) ++
      for(id <- chant_ids, id not in placed, do: "the chant #{id} is in no group's parts") ++
      base_errors(chants, base)
  end

  def chant_library_errors(_document, _prayer_ids, _base),
    do: ["the document needs a list of groups and of chants"]

  # The Prayer Book

  defp prayer_errors(%{"id" => id} = prayer) when is_binary(id) do
    errors =
      required(prayer, ~w(title english)) ++
        optional(prayer, ~w(latin_title origin note latin list_title english_name)) ++
        words(prayer, "search_words")

    Enum.map(errors, &"the prayer #{id}: #{&1}") ++ pairing_errors(prayer)
  end

  defp prayer_errors(prayer), do: ["a prayer needs an id: #{inspect(prayer)}"]

  defp chapter_errors(%{"id" => id} = chapter, prayer_ids) when is_binary(id) do
    errors =
      required(chapter, ~w(numeral title latin_title)) ++
        optional(chapter, ~w(note topic)) ++
        words(chapter, "search_words") ++
        words(chapter, "prayer_ids") ++
        unknown("prayer", list(chapter["prayer_ids"]), prayer_ids) ++
        repeated("prayer", list(chapter["prayer_ids"])) ++
        sections_errors(chapter, prayer_ids)

    Enum.map(errors, &"the chapter #{id}: #{&1}")
  end

  defp chapter_errors(chapter, _prayer_ids), do: ["a chapter needs an id: #{inspect(chapter)}"]

  # An order names only the book's prayers and chapters, each order once.
  # Only the ids are checked here; the type checks the rest.
  defp orders_errors(orders, prayer_ids, chapter_ids) do
    ids = Enum.map(orders, &id/1)

    Enum.flat_map(orders, &order_errors(&1, prayer_ids, chapter_ids)) ++
      repeated("order", ids) ++
      unnamed("order id", ids)
  end

  defp order_errors(%{"id" => id} = order, prayer_ids, chapter_ids) when is_binary(id) do
    eastertide = order["in_eastertide"] || %{}
    chapter = order["chapter_id"]

    errors =
      words(order, "prayer_ids") ++
        unknown("prayer", list(order["prayer_ids"]), prayer_ids) ++
        unknown("prayer", list(eastertide["prayer_ids"]), prayer_ids) ++
        if(is_nil(chapter), do: [], else: unknown("chapter", [chapter], chapter_ids))

    Enum.map(errors, &"the order #{id}: #{&1}")
  end

  defp order_errors(order, _prayer_ids, _chapter_ids),
    do: ["an order needs an id: #{inspect(order)}"]

  # The four songs, each a prayer of the book, each season once.
  defp antiphons_errors(antiphons, prayer_ids) do
    named = for %{"prayer_id" => id} <- antiphons, do: id
    seasons = for %{"begins" => begins} <- antiphons, do: begins

    unknown("prayer", named, prayer_ids) ++
      repeated("song to Mary", named) ++
      for {begins, count} <- Enum.frequencies(seasons),
          count > 1,
          do: "two songs to Mary begin on #{begins}"
  end

  # A chapter's sub-headings, in order. A prayer may stand under two, and
  # the chapter's own prayer_ids is their union, each prayer once, in the
  # order it first stands.
  defp sections_errors(%{"sections" => []}, _prayer_ids), do: ["it needs at least one section"]

  defp sections_errors(%{"sections" => sections} = chapter, prayer_ids) when is_list(sections) do
    errors =
      Enum.flat_map(sections, fn
        %{"title" => title, "prayer_ids" => ids} when is_binary(title) and is_list(ids) ->
          if title == "" or not Enum.all?(ids, &is_binary/1) or ids == [] do
            ["the section #{inspect(title)} needs a title and prayer ids"]
          else
            unknown("prayer", ids, prayer_ids)
          end

        section ->
          ["a section needs a title and prayer ids: #{inspect(section)}"]
      end)

    union =
      sections
      |> Enum.flat_map(&list(&1["prayer_ids"]))
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    cond do
      errors != [] -> errors
      union == chapter["prayer_ids"] -> []
      true -> ["its prayer_ids are not its sections' prayers, each once, in order"]
    end
  end

  defp sections_errors(_chapter, _prayer_ids), do: ["it needs a list of sections"]

  # The Chant Library

  defp group_errors(%{"id" => id} = group, chant_ids) when is_binary(id) do
    errors =
      required(group, ~w(title)) ++
        optional(group, ~w(note)) ++
        case group["parts"] do
          [_ | _] = parts ->
            Enum.flat_map(parts, fn
              %{"chant_ids" => [_ | _] = ids} = part ->
                optional(part, ~w(title note)) ++ unknown("chant", ids, chant_ids)

              part ->
                ["a part needs chant ids: #{inspect(part)}"]
            end)

          _other ->
            ["it needs parts"]
        end

    Enum.map(errors, &"the group #{id}: #{&1}")
  end

  defp group_errors(group, _chant_ids), do: ["a group needs an id: #{inspect(group)}"]

  defp chant_errors(%{"id" => id} = chant, group_ids, prayer_ids) when is_binary(id) do
    errors =
      required(chant, ~w(group_id latin_title english_title detail source_url)) ++
        optional(chant, ~w(setting)) ++
        words(chant, "prayer_ids") ++
        unknown("group", List.wrap(chant["group_id"]), group_ids) ++
        if(prayer_ids, do: unknown("prayer", list(chant["prayer_ids"]), prayer_ids), else: []) ++
        duration_errors(chant) ++
        audio_errors(chant) ++
        score_errors(chant) ++
        lines_errors(chant)

    Enum.map(errors, &"the chant #{id}: #{&1}")
  end

  defp chant_errors(chant, _group_ids, _prayer_ids),
    do: ["a chant needs an id: #{inspect(chant)}"]

  defp duration_errors(%{"duration" => duration}) when is_number(duration) and duration > 0,
    do: []

  defp duration_errors(_chant), do: ["its duration is a number of seconds above zero"]

  defp audio_errors(%{"id" => id, "audio" => audio}) when is_map(audio),
    do: file_errors("its audio", audio, "chants/audio/#{id}", ".m4a")

  defp audio_errors(_chant), do: ["it needs its audio: a url, bytes and a sha256"]

  defp score_errors(%{"score" => score}) when is_list(score) do
    Enum.flat_map(score, fn
      %{"file" => file, "caption" => caption, "aspect_ratio" => ratio} = part
      when is_binary(file) and is_binary(caption) and is_number(ratio) and ratio > 0 ->
        file_errors("its score #{file}", part, "chants/scores/#{file}", ".lvscore")

      part ->
        ["a score part needs a file, a caption and an aspect ratio above zero: #{inspect(part)}"]
    end)
  end

  defp score_errors(_chant), do: ["it needs a list of score parts"]

  # A chant file is content-addressed: its URL ends in its name and the
  # first twelve characters of its checksum, so a changed file is a new
  # URL and a client caches by URL.
  defp file_errors(what, %{"url" => url, "bytes" => bytes, "sha256" => sha256}, stem, extension)
       when is_binary(url) and is_integer(bytes) and bytes > 0 and is_binary(sha256) do
    cond do
      not Regex.match?(@sha256, sha256) ->
        ["#{what}'s sha256 is 64 lowercase hex characters"]

      not String.starts_with?(url, "https://") ->
        ["#{what}'s url is https"]

      not String.ends_with?(url, "/#{stem}-#{binary_part(sha256, 0, 12)}#{extension}") ->
        ["#{what}'s url does not end in #{stem}-<first 12 of its sha256>#{extension}"]

      true ->
        []
    end
  end

  defp file_errors(what, _file, _stem, _extension),
    do: ["#{what} needs a url, bytes above zero and a sha256"]

  defp lines_errors(%{"lines" => lines, "duration" => duration} = chant)
       when is_list(lines) and is_number(duration) do
    score = chant["score"]

    shaped =
      Enum.all?(lines, fn
        %{"latin" => latin, "english" => english, "start" => start, "end" => finish} = line ->
          is_binary(latin) and is_binary(english) and is_number(start) and is_number(finish) and
            (is_nil(line["part"]) or is_integer(line["part"]))

        _line ->
          false
      end)

    cond do
      not shaped ->
        ["every line needs its latin, english, start, end and a part or null"]

      Enum.any?(lines, &(&1["start"] < 0 or &1["start"] > &1["end"] or &1["end"] > duration)) ->
        ["every line starts before it ends, within the recording"]

      Enum.map(lines, & &1["start"]) != Enum.sort(Enum.map(lines, & &1["start"])) ->
        ["its lines are in the order they are sung"]

      # A line's part is the score page it is sung from, counting from 0.
      Enum.any?(lines, &(&1["part"] && &1["part"] not in 0..(length(list(score)) - 1)//1)) ->
        ["a line's part is one of its score pages, counting from 0"]

      true ->
        []
    end
  end

  defp lines_errors(%{"lines" => lines}) when is_list(lines), do: []
  defp lines_errors(_chant), do: ["it needs a list of lines"]

  # Every chant file's URL, without its `/chants/...` path: one base for
  # all, and `base` when given.
  defp base_errors(chants, base) do
    urls =
      for chant <- chants,
          file <- [chant["audio"] | list(chant["score"])],
          is_map(file) and is_binary(file["url"]),
          do: file["url"]

    bases = urls |> Enum.map(&(String.split(&1, "/chants/") |> hd())) |> Enum.uniq()

    cond do
      base && bases not in [[], [base]] ->
        ["every chant file's url starts with #{base}/chants/; found #{Enum.join(bases, ", ")}"]

      length(bases) > 1 ->
        ["every chant file is on one base; found #{Enum.join(bases, ", ")}"]

      true ->
        []
    end
  end

  # The Consecration

  defp phase_errors(%{"id" => id} = phase, prayer_ids) when is_binary(id) do
    errors =
      required(phase, ~w(name subtitle painting)) ++
        words(phase, "prayer_ids") ++
        unknown("prayer", list(phase["prayer_ids"]), prayer_ids) ++
        phase_prayers_errors(phase) ++
        phase_days_errors(phase)

    Enum.map(errors, &"the phase #{id}: #{&1}")
  end

  defp phase_errors(phase, _prayer_ids), do: ["a phase needs an id: #{inspect(phase)}"]

  defp phase_prayers_errors(%{"prayer_ids" => [_ | _]}), do: []
  defp phase_prayers_errors(_phase), do: ["it needs prayers"]

  defp phase_days_errors(%{"first_day" => first, "last_day" => last})
       when is_integer(first) and is_integer(last) and first <= last,
       do: []

  defp phase_days_errors(_phase),
    do: ["its first_day and last_day are whole numbers, the first no later than the last"]

  # The phases run from day 1, each starting the day after the last ends.
  defp phase_span_errors(phases) do
    starts = Enum.map(phases, & &1["first_day"])

    after_each =
      Enum.map(Enum.drop(phases, -1), &(is_integer(&1["last_day"]) and &1["last_day"] + 1))

    if starts == [1 | after_each],
      do: [],
      else: ["the phases run from day 1 without a gap or an overlap, in order"]
  end

  defp days_errors(days, phases) do
    ranges = Map.new(phases, &{&1["id"], {&1["first_day"], &1["last_day"]}})

    last =
      case List.last(phases) do
        %{"last_day" => last} when is_integer(last) -> last
        _other -> 0
      end

    numbers =
      if Enum.map(days, &(is_map(&1) && &1["number"])) == Enum.to_list(1..last//1),
        do: [],
        else: ["the days are numbered 1 to the last phase's last day, each once, in order"]

    numbers ++ Enum.flat_map(days, &day_errors(&1, ranges))
  end

  defp day_errors(%{"number" => number} = day, ranges) when is_integer(number) do
    errors =
      required(day, ~w(title journal_prompt)) ++
        case Map.fetch(ranges, day["phase_id"]) do
          {:ok, {first, last}} when is_integer(first) and is_integer(last) ->
            if number in first..last//1,
              do: [],
              else: ["it falls outside its phase #{day["phase_id"]}"]

          _other ->
            ["names the phase #{inspect(day["phase_id"])}, which does not exist"]
        end ++ readings_errors(day["readings"])

    Enum.map(errors, &"the day #{number}: #{&1}")
  end

  defp day_errors(day, _ranges), do: ["a day needs a number: #{inspect(day)}"]

  defp readings_errors([_ | _] = readings) do
    orders = Enum.map(readings, &(is_map(&1) && &1["order"]))

    Enum.flat_map(readings, fn
      reading when is_map(reading) ->
        required(reading, ~w(title text)) ++ optional(reading, ~w(source))

      reading ->
        ["a reading is a map: #{inspect(reading)}"]
    end) ++
      if orders == Enum.to_list(1..length(readings)),
        do: [],
        else: ["its readings are in order, numbered from 1"]
  end

  defp readings_errors(_readings), do: ["it needs readings"]

  defp consecration_prayer_errors(%{"id" => id} = prayer) when is_binary(id) do
    errors = required(prayer, ~w(title english)) ++ optional(prayer, ~w(latin_title latin))

    Enum.map(errors, &"the prayer #{id}: #{&1}") ++ pairing_errors(prayer)
  end

  defp consecration_prayer_errors(prayer), do: ["a prayer needs an id: #{inspect(prayer)}"]

  defp feast_errors(%{"id" => id} = feast) when is_binary(id) do
    errors =
      required(feast, ~w(name description)) ++
        case feast do
          # A leap year, so 29 February is a date.
          %{"month" => month, "day" => day} when is_integer(month) and is_integer(day) ->
            if match?({:ok, _date}, Date.new(2024, month, day)),
              do: [],
              else: ["#{month}/#{day} is not a date"]

          _other ->
            ["it needs a month and a day"]
        end

    Enum.map(errors, &"the feast #{id}: #{&1}")
  end

  defp feast_errors(feast), do: ["a feast needs an id: #{inspect(feast)}"]

  # A chooser lists the feasts in the order they fall in the year.
  defp feast_order_errors(feasts) do
    dates = for %{"month" => month, "day" => day} <- feasts, do: {month, day}

    if dates == Enum.sort(dates),
      do: [],
      else: ["the feasts are in calendar order"]
  end

  # Shared

  # A prayer's English and Latin pair line for line, blank lines included.
  defp pairing_errors(%{"id" => id, "english" => english, "latin" => latin})
       when is_binary(english) and is_binary(latin) do
    english_lines = english |> String.split("\n") |> length()
    latin_lines = latin |> String.split("\n") |> length()

    if english_lines == latin_lines,
      do: [],
      else: [
        "the prayer #{id} has #{english_lines} English lines and #{latin_lines} Latin; the two pair line for line, blank lines included"
      ]
  end

  defp pairing_errors(_prayer), do: []

  defp true_devotion_chapter_errors(%{"id" => id} = chapter, parts) when is_binary(id) do
    paragraphs = list(chapter["paragraphs"])

    errors =
      required(chapter, ~w(title)) ++
        if(chapter["part"] in parts, do: [], else: ["its part is not one of the parts"]) ++
        if(paragraphs == [], do: ["it has no paragraphs"], else: []) ++
        if(Enum.map(paragraphs, &id/1) == Enum.to_list(0..(length(paragraphs) - 1)//1),
          do: [],
          else: ["its paragraphs are numbered 0, 1, 2 and on, in order"]
        ) ++
        for(
          paragraph <- paragraphs,
          paragraph["kind"] not in ~w(text subheading),
          do: "paragraph #{inspect(id(paragraph))} is neither text nor a subheading"
        ) ++
        for(
          paragraph <- paragraphs,
          error <- required(paragraph, ~w(text)),
          do: "paragraph #{inspect(id(paragraph))}: #{error}"
        )

    for error <- errors, do: "chapter #{id}: #{error}"
  end

  defp true_devotion_chapter_errors(chapter, _parts),
    do: ["a chapter needs an id: #{inspect(chapter, limit: 3)}"]

  defp id(%{"id" => id}), do: id
  defp id(_other), do: nil

  defp list(value) when is_list(value), do: value
  defp list(_value), do: []

  defp required(map, keys) do
    for key <- keys,
        not (is_binary(map[key]) and String.trim(map[key]) != ""),
        do: "#{key} is required text"
  end

  defp optional(map, keys) do
    for key <- keys,
        not Map.has_key?(map, key) or not (is_nil(map[key]) or is_binary(map[key])),
        do: "#{key} is text or null"
  end

  defp words(map, key) do
    case map[key] do
      words when is_list(words) ->
        if Enum.all?(words, &(is_binary(&1) and &1 != "")), do: [], else: ["#{key} holds text"]

      _other ->
        ["#{key} is a list"]
    end
  end

  defp unknown(kind, ids, known) do
    for id <- ids,
        not MapSet.member?(known, id),
        do: "names the #{kind} #{inspect(id)}, which does not exist"
  end

  defp unnamed(kind, names) do
    for name <- names,
        is_binary(name),
        not Regex.match?(@name, name),
        do: "the #{kind} #{inspect(name)} may hold only letters, digits, _ and -"
  end

  defp repeated(kind, ids) do
    for {id, count} <- Enum.frequencies(ids),
        count > 1,
        do: "the #{kind} id #{inspect(id)} is repeated"
  end
end
