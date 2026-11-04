defmodule LumenViae.Rosary.Consecration.Spanish do
  @moduledoc """
  The Consecration in Spanish: what `GET /api/v2/consecration?lang=es`
  serves in its `translations` section.

  Two sources:

  - `priv/library/es/consecration.json`: the phases, days (each day's
    title, journal question and readings, by reading `order`), feasts and
    the prayers the Prayer Book does not print. A reading is copied from
    a public-domain Spanish edition (Torres Amat's Bible, Nieremberg's
    Imitation of Christ) or else is the team's translation, marked
    `ai_translated`; `priv/library/es/SOURCES.md` says which, and every
    change made;
  - the prayers the Prayer Book also prints, whose Spanish is
    `LumenViae.Rosary.PrayerBook.Spanish.prayers/0`'s, so the two
    documents never disagree. The file may not hold those ids.

  A part in neither keeps its English: it has no translation. Nothing
  here is narrated.

  The file is dated and pinned in
  `test/lumen_viae/rosary/consecration/spanish_test.exs`.
  """

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Library
  alias LumenViae.Rosary.PrayerBook

  @path Path.join([:code.priv_dir(:lumen_viae), "library", "es", "consecration.json"])
  @external_resource @path

  file = @path |> File.read!() |> Jason.decode!()

  @updated_at (case DateTime.from_iso8601(file["updated_at"] || "") do
                 {:ok, at, 0} ->
                   DateTime.truncate(at, :second)

                 _ ->
                   raise CompileError,
                     description:
                       "priv/library/es/consecration.json needs a top-level \"updated_at\", an ISO 8601 UTC timestamp"
               end)

  @phase_ids Enum.map(Library.served(:consecration, "phases"), & &1.id)
  @feast_ids Enum.map(Library.served(:consecration, "feasts"), & &1.id)
  @prayer_ids Enum.map(Library.served(:consecration, "prayers"), & &1.id)
  @readings Map.new(Library.served(:consecration, "days"), fn day ->
              {day.number, Enum.map(day.readings, & &1.order)}
            end)
  book_ids = Enum.map(Library.served(:prayer_book, "prayers"), & &1.id)

  @phases Map.get(file, "phases", %{})
  @days Map.get(file, "days", %{})
  @prayers Map.get(file, "prayers", %{})
  @feasts Map.get(file, "feasts", %{})

  fail = fn message ->
    raise CompileError, description: "priv/library/es/consecration.json: " <> message
  end

  strings? = fn entry, keys ->
    is_map(entry) and Enum.all?(keys, &(is_binary(entry[&1]) and entry[&1] != "")) and
      Map.get(entry, "ai_translated", true) == true
  end

  for {id, phase} <- @phases do
    id in @phase_ids || fail.("phases holds #{inspect(id)}, which the Consecration does not have")

    strings?.(phase, ["name", "subtitle"]) ||
      fail.(
        "phase #{id} needs a name and a subtitle, and \"ai_translated\" is either true or left out"
      )
  end

  for {id, feast} <- @feasts do
    id in @feast_ids || fail.("feasts holds #{inspect(id)}, which the Consecration does not have")

    strings?.(feast, ["name", "description"]) ||
      fail.(
        "feast #{id} needs a name and a description, and \"ai_translated\" is either true or left out"
      )
  end

  for {id, prayer} <- @prayers do
    id in @prayer_ids ||
      fail.("prayers holds #{inspect(id)}, which the Consecration does not have")

    id in book_ids &&
      fail.(
        "prayers holds #{inspect(id)}, a Prayer Book prayer: its Spanish is priv/library/es/prayer_book.json's"
      )

    strings?.(prayer, ["title", "text"]) ||
      fail.(
        "prayer #{id} needs a title and a text, and \"ai_translated\" is either true or left out"
      )
  end

  for {key, day} <- @days do
    orders =
      Map.get(@readings, String.to_integer(key)) ||
        fail.("days holds #{inspect(key)}, which the Consecration does not have")

    strings?.(day, ["title", "journal_prompt"]) ||
      fail.(
        "day #{key} needs a title and a journal_prompt, and \"ai_translated\" is either true or left out"
      )

    for {order, reading} <- Map.get(day, "readings", %{}) do
      String.to_integer(order) in orders ||
        fail.("day #{key} holds reading #{inspect(order)}, which that day does not have")

      strings?.(reading, ["title", "text", "source"]) ||
        fail.(
          "day #{key} reading #{order} needs a title, a text and a source, and \"ai_translated\" is either true or left out"
        )
    end
  end

  @doc """
  The Spanish, as the `translations` section serves it: `phases`, `days`,
  `prayers` and `feasts`, each listing only the parts that have Spanish, in
  the English sections' order, as plain maps so that `ai_translated` is
  there only when true.
  """
  @spec translation() :: map
  def translation do
    book = Map.new(PrayerBook.Spanish.prayers(), &{&1.id, &1})

    %{
      phases:
        for(
          id <- @phase_ids,
          phase = @phases[id],
          do: mark(%{id: id, name: phase["name"], subtitle: phase["subtitle"]}, phase)
        ),
      days:
        for(
          number <- Enum.sort(Map.keys(@readings)),
          day = @days["#{number}"],
          do: day(number, day)
        ),
      prayers: for(id <- @prayer_ids, prayer = prayer(id, book), do: prayer),
      feasts:
        for(
          id <- @feast_ids,
          feast = @feasts[id],
          do: mark(%{id: id, name: feast["name"], description: feast["description"]}, feast)
        )
    }
  end

  defp day(number, day) do
    readings = Map.get(day, "readings", %{})

    %{number: number, title: day["title"], journal_prompt: day["journal_prompt"]}
    |> mark(day)
    |> Map.put(
      :readings,
      for order <- Map.fetch!(@readings, number), reading = readings["#{order}"] do
        mark(
          %{
            order: order,
            title: reading["title"],
            text: reading["text"],
            source: reading["source"]
          },
          reading
        )
      end
    )
  end

  defp prayer(id, book) do
    cond do
      prayer = @prayers[id] ->
        mark(%{id: id, title: prayer["title"], text: prayer["text"]}, prayer)

      prayer = book[id] ->
        prayer

      true ->
        nil
    end
  end

  defp mark(map, %{"ai_translated" => true}), do: Map.put(map, :ai_translated, true)
  defp mark(map, _entry), do: map

  @doc "When the Spanish last changed: the later of this file's date and the Prayer Book's Spanish."
  @spec updated_at() :: DateTime.t()
  def updated_at, do: Enum.max([@updated_at, PrayerBook.Spanish.updated_at()], DateTime)

  @doc "When `priv/library/es/consecration.json` last changed, for the test that pins it."
  @spec file_updated_at() :: DateTime.t()
  def file_updated_at, do: @updated_at

  @doc "A fingerprint of the file's words (`Content.version/1`), for the test that pins it."
  @spec file_version() :: String.t()
  def file_version,
    do:
      Content.version(%{
        "phases" => @phases,
        "days" => @days,
        "prayers" => @prayers,
        "feasts" => @feasts
      })
end
