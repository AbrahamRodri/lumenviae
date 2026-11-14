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

  A prayer in neither keeps its English: it has no translation.
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

        true ->
          :ok
      end
    end
  end

  @doc """
  Every novena that has Spanish, in the book's order, each
  `%{id:, title:, list_title:, detail:, note:, origin:, search_words:,
  day_titles:, parts:}`, its parts `%{id:, title:, text:}` in the order the
  novena first says them.
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
        parts:
          for(
            day <- novena.days,
            part <- day.parts,
            words = parts[part.id],
            uniq: true,
            do: %{id: part.id, title: words["title"], text: words["text"]}
          )
      }
    end
  end

  @doc """
  Every prayer the book prints that has Spanish, in the book's order, each
  `%{id:, title:, text:}` plus `ai_translated: true` where part of it is
  the team's translation.
  """
  @spec prayers() :: [map]
  def prayers do
    rosary = Map.new(Content.prayers("es"), &{&1["id"], &1})

    for id <- @book_ids, spanish = spanish(id, rosary), do: spanish
  end

  defp spanish(id, rosary) do
    cond do
      prayer = Map.get(@file_prayers, id) ->
        shape(id, prayer["title"], prayer["text"], prayer["ai_translated"])

      # A Rosary prayer whose Spanish is still its English fallback has no
      # translation.
      (prayer = Map.get(rosary, id)) && prayer["text"]["es"] != prayer["text"]["en"] ->
        shape(
          id,
          prayer["title"]["es"],
          Enum.join(prayer["text"]["es"], "\n"),
          prayer["ai_translated"]
        )

      true ->
        nil
    end
  end

  defp shape(id, title, text, true), do: %{id: id, title: title, text: text, ai_translated: true}
  defp shape(id, title, text, _ai), do: %{id: id, title: title, text: text}

  @doc "When the Spanish last changed: the later of this file's date and the Rosary's Spanish."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: Enum.max([@updated_at, Content.updated_at("es")], DateTime)

  @doc "When `priv/library/es/prayer_book.json` last changed, for the test that pins it."
  @spec file_updated_at() :: DateTime.t()
  def file_updated_at, do: @updated_at

  @doc "A fingerprint of the file's words (`Content.version/1`), for the test that pins it."
  @spec file_version() :: String.t()
  def file_version do
    if @file_novenas == %{},
      do: Content.version(%{"prayers" => @file_prayers}),
      else: Content.version(%{"prayers" => @file_prayers, "novenas" => @file_novenas})
  end
end
