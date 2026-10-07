defmodule LumenViaeWeb.Live.Pray.Sequence do
  @moduledoc """
  The whole Rosary as the prayer page shows it, built from the same
  script the spoken Rosary plays (`LumenViae.Rosary.PrayerAudio.script/3`)
  so what is on the screen and what is heard are one order.

  A sequence is a list of pages: the opening prayers, one page per decade,
  and the closing prayers. Each page is a list of screens, one per bead
  counted on the screen. A Scriptural Rosary's verse and the Hail Mary it
  goes before are one screen, so a bead is one tap.

  Presentation only: it reads the value modules and the records the
  LiveView already loaded, and never queries.
  """

  alias LumenViae.Rosary.{Categories, Content, PrayerAudio}

  defmodule Decade do
    @moduledoc "One decade's mystery as the page shows it."
    defstruct [
      :index,
      :key,
      :order,
      :label,
      :name,
      :fruit,
      :scripture_reference,
      :description,
      :meditation
    ]
  end

  defmodule Screen do
    @moduledoc "One bead, or one prayer, of the sequence."
    defstruct [
      :index,
      :page,
      :step,
      :kind,
      :prayer_id,
      :caption,
      :decade,
      :bead,
      :place,
      :verse
    ]
  end

  defmodule Page do
    @moduledoc "The opening, one decade, or the closing."
    defstruct [:index, :kind, :decade, :screens]
  end

  defstruct [:category, :form, :extras, :decades, :pages, :steps, :hail_marys, :chaplet?]

  @styles %{"meditation" => :meditation, "scriptural" => :scriptural, "holy" => :plain}

  @doc """
  The sequence for `category` prayed in `form` (`"meditation"`,
  `"scriptural"` or `"holy"`), with the optional closing prayers `extras`.
  `decades` are the `Decade` structs in prayer order.
  """
  def build(category, form, extras, decades) do
    orders = Enum.map(decades, & &1.order)

    steps =
      PrayerAudio.script(category, orders, style: Map.fetch!(@styles, form), closing: extras)

    verses = Map.new(PrayerAudio.verses(), &{&1.name, &1})
    last_page = length(decades) + 1

    {screens, step_screens} = fold_screens(steps, verses, last_page)

    pages =
      screens
      |> Enum.group_by(& &1.page)
      |> Enum.map(fn {page, screens} ->
        %Page{
          index: page,
          kind: page_kind(page, last_page),
          decade: if(page in 1..length(decades)//1, do: Enum.at(decades, page - 1)),
          screens: screens
        }
      end)
      |> Enum.sort_by(& &1.index)

    %__MODULE__{
      category: category,
      form: form,
      extras: extras,
      decades: decades,
      pages: pages,
      steps: Enum.zip(steps, step_screens),
      hail_marys: Categories.hail_marys(category),
      chaplet?: category == "seven_sorrows"
    }
  end

  # Each script step becomes a screen, except a verse, which waits for the
  # Hail Mary that follows it and is shown on that Hail Mary's screen. The
  # second list is, for every script step, the screen it is shown on.
  defp fold_screens(steps, verses, last_page) do
    {screens, step_screens, _pending} =
      Enum.reduce(steps, {[], [], nil}, fn step, {screens, step_screens, pending} ->
        case step.kind do
          :verse ->
            {screens, [length(screens) | step_screens], verses[step.name]}

          _kind ->
            page = page_of(step, last_page)
            index = length(screens)
            step_in_page = Enum.count(screens, &(&1.page == page))

            screen = %Screen{
              index: index,
              page: page,
              step: step_in_page,
              kind: step.kind,
              prayer_id: if(step.kind == :prayer, do: step.name),
              caption: step.caption,
              decade: step.decade,
              bead: step.bead,
              place: step.place,
              verse: pending && %{text: pending.text, reference: pending.reference}
            }

            {[screen | screens], [index | step_screens], nil}
        end
      end)

    {Enum.reverse(screens), Enum.reverse(step_screens)}
  end

  defp page_of(%{phase: :opening}, _last), do: 0
  defp page_of(%{phase: :decade, decade: decade}, _last), do: decade + 1
  defp page_of(%{phase: :closing}, last), do: last

  defp page_kind(0, _last), do: :opening
  defp page_kind(last, last), do: :closing
  defp page_kind(_page, _last), do: :decade

  @doc "The pages' count: the opening, the decades and the closing."
  def page_count(%__MODULE__{pages: pages}), do: length(pages)

  def last_page(sequence), do: page_count(sequence) - 1

  def page(%__MODULE__{pages: pages}, index), do: Enum.at(pages, index)

  def screen(sequence, page, step) do
    case page(sequence, page) do
      nil -> nil
      %Page{screens: screens} -> Enum.at(screens, step)
    end
  end

  def screen_at(%__MODULE__{pages: pages}, index) do
    Enum.find_value(pages, fn page -> Enum.find(page.screens, &(&1.index == index)) end)
  end

  def step_count(sequence, page) do
    case page(sequence, page) do
      nil -> 0
      %Page{screens: screens} -> length(screens)
    end
  end

  @doc "The page and step one bead on, or `nil` at the very end."
  def next(sequence, page, step) do
    cond do
      step + 1 < step_count(sequence, page) -> {page, step + 1}
      page < last_page(sequence) -> {page + 1, 0}
      true -> nil
    end
  end

  @doc "The page and step one bead back, or `nil` at the very start."
  def previous(sequence, page, step) do
    cond do
      step > 0 -> {page, step - 1}
      page > 0 -> {page - 1, step_count(sequence, page - 1) - 1}
      true -> nil
    end
  end

  @doc """
  The page's screens with a run of the same prayer said several times in a
  row (three Hail Marys) gathered into one block, for a page read whole.
  """
  def blocks(%Page{screens: screens}) do
    screens
    |> Enum.chunk_while(
      [],
      fn screen, acc ->
        case acc do
          [%Screen{kind: :prayer, prayer_id: id} | _] when screen.prayer_id == id ->
            {:cont, [screen | acc]}

          [] ->
            {:cont, [screen]}

          acc ->
            {:cont, Enum.reverse(acc), [screen]}
        end
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
  end

  ## Words

  @languages ~w(en la)

  @doc """
  The languages the prayers can be set in, as the app offers them on the
  Rosary: English, the default, or Latin. The app's two bilingual settings
  set the Rosary in English, so the page has no third choice. Only the
  prayers change: captions, announcements, verses and meditations stay in
  English.
  """
  def languages, do: @languages

  def default_language, do: "en"

  @doc "A prayer's title as the app sets it, in `language`."
  def prayer_title(id, language \\ "en") do
    case Content.prayer(id) do
      %{"title" => title} -> title[language] || title["en"]
      nil -> nil
    end
  end

  @doc """
  A prayer's lines in `language`, each `{:rubric, text}` for a
  `[bracketed]` direction or `{:line, text}` for words said.
  """
  def prayer_lines(id, language \\ "en") do
    case Content.prayer(id) do
      %{"text" => text} ->
        Enum.map(text[language] || text["en"], fn line ->
          case Regex.run(~r/^\[(.*)\]$/, String.trim(line)) do
            [_, rubric] -> {:rubric, rubric}
            nil -> {:line, line}
          end
        end)

      nil ->
        []
    end
  end

  @doc """
  The optional prayers after the Rosary, as the app offers them:
  `%{id, title, detail}`, in the order they are said.
  """
  def closing_extras do
    for extra <- Content.script()["closing_extras"] do
      %{id: extra["id"], title: extra["title"], detail: extra["detail"]}
    end
  end

  def extra_ids, do: Enum.map(closing_extras(), & &1.id)

  ## Decades

  @doc "The decades of a meditation set: one per meditation, in prayer order."
  def set_decades(set) do
    set.meditations
    |> Enum.with_index()
    |> Enum.map(fn {meditation, index} ->
      decade(set.category, meditation.mystery, index, meditation)
    end)
  end

  @doc """
  The decades of a category prayed without a set: every mystery of it, in
  order, from the mysteries loaded (`mysteries`), or from the spoken
  Rosary's announcements where a mystery is not in the database.
  """
  def category_decades(category, mysteries) do
    by_order = Map.new(mysteries, &{&1.order, &1})

    for order <- 1..Categories.mystery_count(category) do
      mystery =
        Map.get(by_order, order) ||
          %{name: announced_name(category, order), order: order}

      decade(category, mystery, order - 1, nil)
    end
  end

  defp decade(category, mystery, index, meditation) do
    order = mystery.order
    key = "#{category}_#{order}"

    %Decade{
      index: index,
      key: key,
      order: order,
      label: mystery_label(category, order, index),
      name: mystery.name,
      fruit: Map.get(mystery, :fruit),
      scripture_reference: Map.get(mystery, :scripture_reference),
      description: Map.get(mystery, :description),
      meditation: meditation
    }
  end

  defp mystery_label(category, order, _index) when order in 1..7,
    do: Categories.mystery_label(category, order)

  defp mystery_label(category, _order, index) when index in 0..6,
    do: Categories.mystery_label(category, index + 1)

  defp mystery_label(_category, _order, _index), do: nil

  defp announced_name(category, order) do
    key = "#{category}_#{order}"

    case Enum.find(PrayerAudio.announcements(), &(&1.mystery == key)) do
      %{text: text} -> text |> String.split(": ", parts: 2) |> List.last()
      nil -> Categories.mystery_label(category, order)
    end
  end

  ## The streak

  @doc """
  The streak's devotional milestones, by days ascending, as the app's
  `StreakMilestone` names them: `%{days, name, blessing}`. The completion
  screen shows one only on the day it is reached.
  """
  def milestones do
    for milestone <- Content.milestones() do
      %{
        days: milestone["days"],
        name: "#{milestone["days"]} days",
        blessing: milestone["blessing"]
      }
    end
  end

  ## Quotes

  @doc """
  The line shown after a Rosary: the app's `RosaryQuotes.afterPraying`,
  by day of the year, half the list on from the home screen's.
  """
  def quote_after_praying(date \\ Date.utc_today()) do
    %{"items" => items, "rotation" => rotation} = Content.quotes()
    divisor = rotation["after_prayer_offset_divisor"] || 2
    offset = div(length(items), divisor)
    Enum.at(items, rem(Date.day_of_year(date) + offset, length(items)))
  end
end
