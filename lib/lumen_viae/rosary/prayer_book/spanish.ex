defmodule LumenViae.Rosary.PrayerBook.Spanish do
  @moduledoc """
  The Prayer Book's prayers in Spanish: what
  `GET /api/v2/prayer-book?lang=es` serves in its `translations` section.

  Two sources, one each per prayer:

  - `priv/library/es/prayer_book.json`, keyed by prayer id, each a Spanish
    `title` and `text` in the book's `PrayerText` grammar: copied from a
    Church source or a good unofficial version, or else the team's own
    translation, marked `ai_translated` (`priv/library/es/SOURCES.md`
    says which, and every change made);
  - the Rosary's prayers the book also prints, whose Spanish is
    `LumenViae.Rosary.Content.prayers("es")`'s, so the two documents never
    disagree. The file may not hold those ids.

  A prayer in neither keeps its English: it has no translation. The file
  also holds the chapters' Spanish names (`chapters/0`) and the novenas'.
  Nothing here is narrated: the spoken Prayer Book says the English.

  The file is dated and pinned in
  `test/lumen_viae/rosary/prayer_book/spanish_test.exs`.
  """

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Library

  @path Path.join([:code.priv_dir(:lumen_viae), "library", "es", "prayer_book.json"])
  @external_resource @path

  file = @path |> File.read!() |> Jason.decode!()

  @updated_at (case DateTime.from_iso8601(file["updated_at"] || "") do
                 {:ok, at, 0} ->
                   DateTime.truncate(at, :second)

                 _ ->
                   raise CompileError,
                     description:
                       "priv/library/es/prayer_book.json needs a top-level \"updated_at\", an ISO 8601 UTC timestamp"
               end)

  @book_ids Enum.map(Library.served(:prayer_book, "prayers"), & &1.id)
  @rosary_ids Content.prayer_ids()

  @file_prayers Map.fetch!(file, "prayers")

  # Where the Rosary's own prayers' Spanish comes from, by Rosary prayer
  # id. Their words are priv/rosary_content/es/prayers.json's and stay
  # there untouched; only this line is the book's.
  @rosary_origins Map.get(file, "rosary_origins", %{})

  for {id, origin} <- @rosary_origins do
    (id in @rosary_ids and is_binary(origin) and String.trim(origin) != "") ||
      raise CompileError,
        description:
          "priv/library/es/prayer_book.json: rosary_origins holds #{inspect(id)}; it holds only Rosary prayer ids, each with a line of text"
  end

  # A short credit for a Rosary prayer whose Spanish origin above runs
  # over 100 characters, as `short_credit` is for the file's own prayers.
  @rosary_short_credits Map.get(file, "rosary_short_credits", %{})

  for {id, origin} <- @rosary_origins do
    Map.has_key?(@rosary_short_credits, id) == String.length(origin) > 100 ||
      raise CompileError,
        description:
          "priv/library/es/prayer_book.json: the Rosary prayer #{id} has a rosary_short_credits line exactly when its rosary_origins line runs over 100 characters"
  end

  for {id, credit} <- @rosary_short_credits do
    (Map.has_key?(@rosary_origins, id) and is_binary(credit) and String.trim(credit) != "") ||
      raise CompileError,
        description:
          "priv/library/es/prayer_book.json: rosary_short_credits holds #{inspect(id)}; it holds only ids in rosary_origins, each with a line of text"
  end

  for {id, prayer} <- @file_prayers do
    cond do
      id not in @book_ids ->
        raise CompileError,
          description:
            "priv/library/es/prayer_book.json holds #{inspect(id)}, which the book does not print"

      id in @rosary_ids ->
        raise CompileError,
          description:
            "priv/library/es/prayer_book.json holds #{inspect(id)}, a Rosary prayer: its Spanish is priv/rosary_content/es/prayers.json's"

      not match?(
        %{"title" => t, "text" => x} when is_binary(t) and is_binary(x) and x != "",
        prayer
      ) or
          Map.get(prayer, "ai_translated", true) != true ->
        raise CompileError,
          description:
            "priv/library/es/prayer_book.json: #{id} needs a title and a text, and \"ai_translated\" is either true or left out"

      Map.keys(prayer) -- ["title", "text", "ai_translated", "origin", "short_credit"] != [] or
          not match?(o when is_nil(o) or (is_binary(o) and o != ""), prayer["origin"]) ->
        raise CompileError,
          description:
            "priv/library/es/prayer_book.json: #{id} holds a title, a text, \"ai_translated\", an \"origin\" (where it comes from, in Spanish) and a \"short_credit\" only"

      # As in English: a short credit names the prayer's author, for under
      # the title, and is shorter than the origin it stands for.
      Map.has_key?(prayer, "short_credit") and
          (not match?(c when is_binary(c) and c != "", prayer["short_credit"]) or
             String.length(prayer["short_credit"]) >= String.length(prayer["origin"] || "")) ->
        raise CompileError,
          description:
            "priv/library/es/prayer_book.json: #{id} has a \"short_credit\" with no origin, or one no shorter than its origin"

      true ->
        :ok
    end
  end

  # The novenas' Spanish, keyed by novena id: its titles, card sentence,
  # day titles and the words of its own parts by part id. Every part's
  # Spanish stands in the Spanish twin word for word, as the English does in
  # the English twin, so the two never drift.
  @file_novenas Map.get(file, "novenas", %{})
  @book_novenas Library.served(:prayer_book, "novenas")

  for {id, spanish} <- @file_novenas do
    novena = Enum.find(@book_novenas, &(&1.id == id))

    fail =
      &raise(CompileError,
        description: "priv/library/es/prayer_book.json, the novena #{id}: #{&1}"
      )

    if is_nil(novena), do: fail.("the book has no such novena")

    twin = get_in(@file_prayers, [novena.prayer_id, "text"])
    if is_nil(twin), do: fail.("its twin #{novena.prayer_id} has no Spanish here")

    unless match?(%{"title" => t, "detail" => d} when is_binary(t) and is_binary(d), spanish),
      do: fail.("it needs a title and a detail")

    unless is_list(spanish["search_words"]), do: fail.("it needs its search_words")

    unless Map.get(spanish, "ai_translated", false) in [true, false],
      do: fail.("its \"ai_translated\" is true, false or left out")

    day_titles = spanish["day_titles"]

    unless is_list(day_titles) and length(day_titles) == novena.length and
             Enum.all?(day_titles, &(is_binary(&1) and &1 != "")),
           do: fail.("its day_titles are one per day, #{novena.length}")

    part_ids =
      for day <- novena.days, part <- day.parts, is_binary(part.id), uniq: true, do: part.id

    for {part_id, part} <- spanish["parts"] || %{} do
      cond do
        part_id not in part_ids ->
          fail.("it has no part #{part_id}")

        not match?(%{"text" => text} when is_binary(text) and text != "", part) ->
          fail.("the part #{part_id} needs its text")

        not String.contains?(twin, part["text"]) ->
          fail.("the words of #{part_id} are not in the Spanish twin, word for word")

        Map.get(part, "ai_translated", false) not in [true, false] ->
          fail.("the part #{part_id}'s \"ai_translated\" is true, false or left out")

        true ->
          :ok
      end
    end
  end

  # The chapters' Spanish (the Prayers tab's topics), keyed by chapter id:
  # its title, topic, note where the English has one, one title per section
  # in the English order, and the words a Spanish search finds it by.
  @file_chapters Map.get(file, "chapters", %{})
  @book_chapters Library.served(:prayer_book, "chapters")

  for {id, spanish} <- @file_chapters do
    chapter = Enum.find(@book_chapters, &(&1.id == id))

    fail =
      &raise(CompileError,
        description: "priv/library/es/prayer_book.json, the chapter #{id}: #{&1}"
      )

    if is_nil(chapter), do: fail.("the book has no such chapter")

    unless Map.keys(spanish) -- ~w(title topic note section_titles search_words) == [],
      do: fail.("it holds a title, topic, note, section_titles and search_words only")

    unless match?(%{"title" => t, "topic" => p} when is_binary(t) and is_binary(p), spanish),
      do: fail.("it needs a title and a topic")

    unless is_nil(spanish["note"]) == is_nil(chapter.note) and
             (is_nil(spanish["note"]) or is_binary(spanish["note"])),
           do: fail.("it has a note exactly when the English has one")

    titles = spanish["section_titles"]

    unless is_list(titles) and length(titles) == length(chapter.sections) and
             Enum.all?(titles, &(is_binary(&1) and &1 != "")),
           do: fail.("its section_titles are one per section, #{length(chapter.sections)}")

    unless is_list(spanish["search_words"]) and Enum.all?(spanish["search_words"], &is_binary/1),
      do: fail.("it needs its search_words")
  end

  @doc """
  Every chapter that has Spanish, in the book's order, each `%{id:, title:,
  topic:, note:, section_titles:, search_words:}`, `section_titles` one per
  section in the order of the chapter's `sections`.
  """
  @spec chapters() :: [map]
  def chapters do
    for chapter <- @book_chapters, spanish = @file_chapters[chapter.id] do
      %{
        id: chapter.id,
        title: spanish["title"],
        topic: spanish["topic"],
        note: spanish["note"],
        section_titles: spanish["section_titles"],
        search_words: spanish["search_words"]
      }
    end
  end

  @doc """
  Every novena that has Spanish, in the book's order, each
  `%{id:, title:, list_title:, detail:, note:, origin:, search_words:,
  day_titles:, ai_translated:, parts:}`, its parts `%{id:, title:, text:,
  ai_translated:}` in the order the novena first says them. A novena or a
  part is `ai_translated` only where the file marks it `true`.
  """
  @spec novenas() :: [map]
  def novenas do
    for novena <- @book_novenas, spanish = @file_novenas[novena.id] do
      parts = spanish["parts"] || %{}

      %{
        id: novena.id,
        title: spanish["title"],
        list_title: spanish["list_title"],
        detail: spanish["detail"],
        note: spanish["note"],
        origin: spanish["origin"],
        search_words: spanish["search_words"],
        day_titles: spanish["day_titles"],
        ai_translated: spanish["ai_translated"] == true,
        parts:
          for(
            day <- novena.days,
            part <- day.parts,
            words = parts[part.id],
            uniq: true,
            do: %{
              id: part.id,
              title: words["title"],
              text: words["text"],
              ai_translated: words["ai_translated"] == true
            }
          )
      }
    end
  end

  @doc """
  Every prayer the book prints that has Spanish, in the book's order, each
  `%{id:, title:, text:}` plus `ai_translated: true` where part of it is
  the team's translation, `origin:` where the file says in Spanish
  where it comes from, and `short_credit:` where the origin names an author.
  """
  @spec prayers() :: [map]
  def prayers do
    rosary = Map.new(Content.prayers("es"), &{&1["id"], &1})

    for id <- @book_ids, spanish = spanish(id, rosary), do: spanish
  end

  defp spanish(id, rosary) do
    cond do
      prayer = Map.get(@file_prayers, id) ->
        id
        |> shape(prayer["title"], prayer["text"], prayer["ai_translated"])
        |> put_origin(prayer["origin"])
        |> put_short_credit(prayer["short_credit"])

      # A Rosary prayer whose Spanish is still its English fallback has no
      # translation.
      (prayer = Map.get(rosary, id)) && prayer["text"]["es"] != prayer["text"]["en"] ->
        id
        |> shape(
          prayer["title"]["es"],
          Enum.join(prayer["text"]["es"], "\n"),
          prayer["ai_translated"]
        )
        |> put_origin(@rosary_origins[id])
        |> put_short_credit(@rosary_short_credits[id])

      true ->
        nil
    end
  end

  defp shape(id, title, text, true), do: %{id: id, title: title, text: text, ai_translated: true}
  defp shape(id, title, text, _ai), do: %{id: id, title: title, text: text}

  defp put_origin(prayer, origin) when is_binary(origin), do: Map.put(prayer, :origin, origin)
  defp put_origin(prayer, _none), do: prayer

  defp put_short_credit(prayer, credit) when is_binary(credit),
    do: Map.put(prayer, :short_credit, credit)

  defp put_short_credit(prayer, _none), do: prayer

  @doc "When the Spanish last changed: the later of this file's date and the Rosary's Spanish."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: Enum.max([@updated_at, Content.updated_at("es")], DateTime)

  @doc "When `priv/library/es/prayer_book.json` last changed, for the test that pins it."
  @spec file_updated_at() :: DateTime.t()
  def file_updated_at, do: @updated_at

  @doc "A fingerprint of the file's words (`Content.version/1`), for the test that pins it."
  @spec file_version() :: String.t()
  def file_version do
    words =
      %{"prayers" => @file_prayers}
      |> then(&if(@file_novenas == %{}, do: &1, else: Map.put(&1, "novenas", @file_novenas)))
      |> then(
        &if(@rosary_origins == %{}, do: &1, else: Map.put(&1, "rosary_origins", @rosary_origins))
      )
      |> then(&if(@file_chapters == %{}, do: &1, else: Map.put(&1, "chapters", @file_chapters)))
      |> then(
        &if(@rosary_short_credits == %{},
          do: &1,
          else: Map.put(&1, "rosary_short_credits", @rosary_short_credits)
        )
      )

    Content.version(words)
  end
end
