defmodule LumenViaeWeb.Live.Chants.Occasions do
  @moduledoc """
  The Chant Library's sung sets as the Chant pages read them, as the iOS
  app's `ChantOccasion`, `ChantQueue.occasion` and `ChantSetPage` (and the
  Android app's `ChantOccasions` and `SungSet`) read them: Adoration and
  Blessing, a visit, a sung Rosary, Before Bed, Before Work or Study, For
  Those Who Have Died.

  Each is unrolled for a day, since Before Bed sings tonight's song to
  Mary: the season's antiphon by the visitor's date
  (`LumenViae.LiturgicalCalendar.marian_antiphon_season/1`), the first
  chant that sings it. A set's page lists each step once, a note in red
  over the chants it leads to and a chant numbered with how often it is
  sung; Play all sings every chant as often as it sounds, the decades'
  rounds unrolled.

  Presentation only: the sets are the domain's (`occasions` of
  `LumenViae.Rosary.get_chant_library!/1`), read through
  `LumenViaeWeb.Live.Chants.Library.load/1`.
  """

  alias LumenViae.LiturgicalCalendar
  alias LumenViaeWeb.Live.Chants.Library

  # The sets the Chant page's tiles open, in the grid's order around the
  # Mass of the Angels (ChantLibraryView.tileOccasionIDs): the first two
  # before it, the rest after.
  @tile_ids ~w(sung_rosary benediction before_bed)

  # The prayer each season's song to Mary sings, by where the season
  # begins (the Prayer Book's `marian_antiphons`; PrayerBook.antiphon(on:)).
  @antiphons %{
    advent_eve: "alma_redemptoris",
    february_2: "ave_regina_caelorum",
    easter: "regina_caeli",
    pentecost_saturday: "hail_holy_queen"
  }

  # How many of its chants a set's card lists before "and n more"
  # (ChantSetCard).
  @listed 4

  @doc "Sets of Chants."
  def sets_path, do: "/chant/sets"

  @doc "A sung set's page."
  def set_path(id), do: "/chant/sets/#{id}"

  def listed, do: @listed

  @doc "Every sung set, in the library's order."
  def all(%Library{occasions: occasions}), do: occasions

  @doc "A sung set by its id; nil for one the library does not have."
  def occasion(%Library{occasions: occasions}, id) when is_binary(id),
    do: Enum.find(occasions, &(&1.id == id))

  def occasion(_library, _id), do: nil

  @doc """
  The Chant page's tiles around the Mass of the Angels: `{before, after}`,
  the sung sets the app's grid places before its tile and after it.
  """
  def tiles(%Library{} = library) do
    sets = @tile_ids |> Enum.map(&occasion(library, &1)) |> Enum.reject(&is_nil/1)
    Enum.split(sets, 2)
  end

  @doc """
  Tonight's song to Mary on `date` (ChantCatalog.antiphonOfTheSeason): the
  first chant that sings the season's antiphon.
  """
  def antiphon_of_the_season(%Library{chants: chants}, %Date{} = date) do
    prayer = @antiphons[LiturgicalCalendar.marian_antiphon_season(date)]
    Enum.find(chants, &(prayer in &1.prayer_ids))
  end

  @doc "A step's chant on `date`: the one it names, or tonight's song to Mary; nil for one the site cannot sing."
  def resolve(%{kind: "chant", chant_id: id}, %Library{} = library, _date) when is_binary(id),
    do: Library.chant(library, id)

  def resolve(%{kind: "antiphon_of_the_season"}, %Library{} = library, date),
    do: antiphon_of_the_season(library, date)

  def resolve(_step, _library, _date), do: nil

  @doc """
  A sung set on `date`, as its page and its card lay it out
  (ChantSetPage.Content): its id, title, note and painting; `rows`, its
  order a step at a time (`%{kind: :rubric, text:}` or `%{kind: :chant,
  chant:, times:, origin:, number:, seconds:}`); `queue`, every chant in
  the order it sounds with the step it was unrolled from (`%{chant:,
  origin:}`); `chants`, the different chants in it; `seconds`, how long.

  A step's `origin` is its place among all the set's steps, counted from
  0 in the order the set writes them; `number` its place among the chant
  rows shown, from 1.
  """
  def unroll(occasion, %Library{} = library, %Date{} = date) do
    {blocks, _next} =
      Enum.map_reduce(occasion.blocks, 0, fn block, first ->
        steps =
          block.steps
          |> Enum.with_index(first)
          |> Enum.map(fn {step, origin} ->
            %{chant: resolve(step, library, date), times: max(step.times, 1), origin: origin}
          end)
          |> Enum.reject(&is_nil(&1.chant))

        {%{rubric: block.rubric, rounds: max(block.rounds, 1), steps: steps},
         first + length(block.steps)}
      end)

    queue =
      for block <- blocks,
          _round <- 1..block.rounds,
          step <- block.steps,
          _time <- 1..step.times,
          do: %{chant: step.chant, origin: step.origin}

    %{
      id: occasion.id,
      title: occasion.title,
      note: occasion.note,
      painting: painting(occasion),
      rows: rows(blocks),
      queue: queue,
      chants: queue |> Enum.map(& &1.chant) |> Enum.uniq_by(& &1.id),
      seconds: queue |> Enum.map(& &1.chant.duration) |> Enum.sum()
    }
  end

  defp rows(blocks) do
    {rows, _number} =
      Enum.flat_map_reduce(blocks, 1, fn block, number ->
        rubric = if block.rubric, do: [%{kind: :rubric, text: block.rubric}], else: []

        {chants, next} =
          Enum.map_reduce(block.steps, number, fn step, n ->
            row = %{
              kind: :chant,
              chant: step.chant,
              times: step.times,
              origin: step.origin,
              number: n,
              seconds: step.chant.duration * step.times
            }

            {row, n + 1}
          end)

        {rubric ++ chants, next}
      end)

    rows
  end

  @doc "\"7 chants · 53 min\": the different chants and how long it all sounds."
  def summary(%{chants: chants, seconds: seconds}), do: Library.summary(length(chants), seconds)

  @doc "The painting a set is shown in, by its name, with its focal point."
  def painting(%{painting: name}), do: Library.named_painting(name)

  @doc "How often a chant is sung, after its name: \"×10\"; nothing for once."
  def repeats(times) when times > 1, do: "×#{times}"
  def repeats(_times), do: nil

  @doc """
  The queue as the `ChantPlayer` hook reads it from the page: JSON, each
  entry `[chant id, recording, origin]`.
  """
  def entries_json(%{queue: queue}) do
    queue
    |> Enum.map(&[&1.chant.id, &1.chant.audio.url, &1.origin])
    |> Jason.encode!()
  end
end
