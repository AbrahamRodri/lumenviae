defmodule LumenViae.Rosary.Library.Check do
  @moduledoc """
  What `priv/library/prayer_book.json` and `priv/library/chant_library.json`
  must hold, checked as `LumenViae.Rosary.Library` compiles and again by
  `LumenViae.Curation.ChantUpload` before it rewrites a file.

  Each function takes a file's sections (string keys, as decoded) and
  returns the problems as sentences, `[]` when there are none. What a
  type cannot say is checked here: every id once, every id named exists,
  a prayer's English and Latin pairing line for line, a chant's lines in
  order within its recording, and every chant file carrying its URL, size
  and checksum, the URL content-addressed by that checksum.
  """

  @sha256 ~r/\A[0-9a-f]{64}\z/

  @doc "The problems with a Prayer Book document's sections."
  @spec prayer_book_errors(map) :: [String.t()]
  def prayer_book_errors(%{"prayers" => prayers, "chapters" => chapters})
      when is_list(prayers) and is_list(chapters) do
    prayer_ids = Enum.map(prayers, &id/1)

    Enum.flat_map(prayers, &prayer_errors/1) ++
      repeated("prayer", prayer_ids) ++
      Enum.flat_map(chapters, &chapter_errors(&1, MapSet.new(prayer_ids))) ++
      repeated("chapter", Enum.map(chapters, &id/1))
  end

  def prayer_book_errors(_document), do: ["the document needs a list of prayers and of chapters"]

  @doc """
  The problems with a Chant Library document's sections. `prayer_ids`,
  when given, are the ids a chant's `prayer_ids` may name.
  """
  @spec chant_library_errors(map, [String.t()] | nil) :: [String.t()]
  def chant_library_errors(document, prayer_ids \\ nil)

  def chant_library_errors(%{"groups" => groups, "chants" => chants}, prayer_ids)
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
      for(id <- chant_ids, id not in placed, do: "the chant #{id} is in no group's parts")
  end

  def chant_library_errors(_document, _prayer_ids),
    do: ["the document needs a list of groups and of chants"]

  # The Prayer Book

  defp prayer_errors(%{"id" => id} = prayer) when is_binary(id) do
    errors =
      required(prayer, ~w(title english)) ++
        optional(prayer, ~w(latin_title origin note latin list_title english_name)) ++
        words(prayer, "search_words")

    errors = Enum.map(errors, &"the prayer #{id}: #{&1}")

    case prayer do
      %{"english" => english, "latin" => latin} when is_binary(english) and is_binary(latin) ->
        english_lines = english |> String.split("\n") |> length()
        latin_lines = latin |> String.split("\n") |> length()

        if english_lines == latin_lines,
          do: errors,
          else:
            errors ++
              [
                "the prayer #{id} has #{english_lines} English lines and #{latin_lines} Latin; the two pair line for line, blank lines included"
              ]

      _other ->
        errors
    end
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

  # A chapter's sub-headings, in order. A prayer may stand under two, and
  # the chapter's own prayer_ids is their union, each prayer once, in the
  # order it first stands.
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
      sections == [] -> []
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

  # Shared

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

  defp repeated(kind, ids) do
    for {id, count} <- Enum.frequencies(ids),
        count > 1,
        do: "the #{kind} id #{inspect(id)} is repeated"
  end
end
