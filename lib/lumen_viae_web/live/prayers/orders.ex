defmodule LumenViaeWeb.Live.Prayers.Orders do
  @moduledoc """
  The orders of prayer as the pages read them, the iOS app's rules
  (`PrayerBook`'s orders, `PrayerBookSchedule`, `PrayerBookSearch`,
  `PrayerBookPainting.order` and `.hour`; the Android app's
  `PrayerOrders` line for line): which of the day's three orders the hour
  belongs to, the shortcuts, an order's name and prayers on a day (the
  Angelus is Queen of Heaven in Eastertide, Night Prayers close on the
  season's song to Mary), the lines the pages set around them, the
  paintings they hang and the search that finds them.

  Presentation only, over a `LumenViaeWeb.Live.Prayers.Book`: the orders
  themselves (their prayers, their Eastertide variant, whether they close
  on the song to Mary) are the domain's. Every rule takes the date or the
  hour it is asked about; `local_now/1` gives the visitor's.

  The app marks an order prayed today from what the device kept. The
  website keeps nothing about a visitor, so an order is never offered
  here: the Now card always says NOW and PRAY, never PRAYED.
  """

  alias LumenViae.LiturgicalCalendar
  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Prayers.Book

  @morning "morning"
  @angelus "angelus"
  @night "night"

  # The orders kept for an occasion with a shortcut of their own, after
  # the day's three (PrayerBookView.shortcutOccasionIDs). Saved, the
  # app's fourth tile, is not on the website.
  @shortcut_occasion_ids ~w(before_mass before_confession)

  # The hour the book's day begins (PrayerBook.dayBeginsAtHour).
  @day_begins 4

  # A browser's offset from UTC, in minutes, as Book.local_date/1 takes it.
  @max_offset 24 * 60

  ## Paths

  @doc "An order's page."
  def order_path(id), do: "/prayers/orders/#{id}"

  @doc """
  Praying an order: `step` counts its prayers from 1, or is `:amen` for
  its close; the language is carried. The defaults (the first prayer,
  English) are never written.
  """
  def pray_path(id, step \\ 1, language \\ "english") do
    query =
      [
        step:
          case step do
            :amen -> "amen"
            1 -> nil
            n -> n
          end,
        lang: if(language != "english", do: language)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    case query do
      [] -> order_path(id) <> "/pray"
      query -> order_path(id) <> "/pray?" <> URI.encode_query(query)
    end
  end

  ## The visitor's clock

  @doc """
  The visitor's local time from the offset the `UserTimezone` hook sends
  (minutes, positive west of UTC, as `Date.getTimezoneOffset()`), or
  `:error` for anything that is not one. Before it comes, the pages use
  the server's clock.
  """
  def local_now(offset) when is_integer(offset) and abs(offset) <= @max_offset,
    do: {:ok, NaiveDateTime.utc_now() |> NaiveDateTime.add(-offset * 60, :second)}

  def local_now(_offset), do: :error

  ## Which orders

  def order(%Book{orders: orders}, id), do: Enum.find(orders, &(&1.id == id))

  @doc "The three orders that keep the hours of an ordinary day (PrayerBook.dayOrders)."
  def day_orders(book), do: orders(book, [@morning, @angelus, @night])

  @doc """
  The shortcut tiles, as the app sets them two by two: the day's three,
  then Before Mass and Before Confession (Saved is the app's alone).
  """
  def shortcut_orders(book), do: day_orders(book) ++ orders(book, @shortcut_occasion_ids)

  @doc """
  The orders a topic holds, in the book's order, for its Pray together
  card (the app's `PrayerBookChapter.orders`; once For an Occasion).
  """
  def chapter_orders(%Book{orders: orders}, chapter_id),
    do: Enum.filter(orders, &(&1.chapter_id == chapter_id))

  defp orders(book, ids), do: ids |> Enum.map(&order(book, &1)) |> Enum.reject(&is_nil/1)

  @doc """
  Which of the day's three orders the hour belongs to (PrayerBook.dayOrder):
  the morning from four until eleven, the Angelus through the noon and
  evening bells until eight, and night after that.
  """
  def day_order_id(hour) when hour >= @day_begins and hour < 11, do: @morning
  def day_order_id(hour) when hour >= 11 and hour < 20, do: @angelus
  def day_order_id(_hour), do: @night

  @doc "The hour's order at `now`."
  def day_order(book, %NaiveDateTime{hour: hour}), do: order(book, day_order_id(hour))

  @doc """
  The name the Now card gives one of the day's orders (PrayerBook.hourName):
  Morning, Night, and the Angelus as Noon's bell until three, then the
  Evening's until the day turns at four.
  """
  def hour_name(@morning, _hour), do: "Morning"
  def hour_name(@night, _hour), do: "Night"
  def hour_name(_angelus, hour) when hour < @day_begins or hour >= 15, do: "Evening"
  def hour_name(_angelus, _hour), do: "Noon"

  ## An order on a day

  defp easter_variant(%{in_eastertide: %{} = variant}, date) do
    if LiturgicalCalendar.eastertide?(date), do: variant
  end

  defp easter_variant(_order, _date), do: nil

  @doc "The order's name on `date` (PrayerOrder.title(on:)): the Angelus is Queen of Heaven in Eastertide."
  def title(order, %Date{} = date) do
    case easter_variant(order, date) do
      %{title: title} -> title
      nil -> order.title
    end
  end

  @doc """
  The ids of its prayers on `date`: the Eastertide variant's while that
  season lasts, and the season's song to Mary at the close of an order
  that closes on it (Night Prayers).
  """
  def prayer_ids(book, order, %Date{} = date) do
    ids =
      case easter_variant(order, date) do
        %{prayer_ids: [_ | _] = ids} -> ids
        _none -> order.prayer_ids
      end

    antiphon = order.closes_with_marian_antiphon && Book.antiphon(book, date)
    if antiphon, do: ids ++ [antiphon.prayer_id], else: ids
  end

  @doc "Its prayers on `date`; an id the book does not carry is skipped."
  def prayers(book, order, date), do: Book.prayers(book, prayer_ids(book, order, date))

  @doc """
  One short line under one of the day's orders on the Now card
  (PrayerBook.daySummary); any other order is its own detail.
  """
  def day_summary(%{id: @morning}, _date), do: "Giving the day to God."

  def day_summary(%{id: @angelus}, date) do
    if LiturgicalCalendar.eastertide?(date),
      do: "The Easter prayer to Mary, said in place of the Angelus.",
      else: "A short prayer to Mary at 6 AM, noon and 6 PM."
  end

  def day_summary(%{id: @night}, _date), do: "A look back on the day, ending with a song to Mary."
  def day_summary(order, _date), do: order.detail

  @doc """
  Why the order holds what it holds on `date`, where the season decides
  (PrayerOrderView.seasonNote); nil for the rest.
  """
  def season_note(%{id: @angelus} = order, date) do
    if easter_variant(order, date), do: "Said in place of the Angelus until Pentecost."
  end

  def season_note(_order, _date), do: nil

  @doc """
  The head over the prayers being prayed (PrayAlongView.kicker): the
  order's name, or "Prayers" for an order of one prayer that bears it,
  so the head never says the title beneath it again.
  """
  def kicker(title, [prayer]) do
    if String.downcase(prayer.title) == String.downcase(title), do: "Prayers", else: title
  end

  def kicker(title, _prayers), do: title

  ## Paintings (PrayerBookPaintings.swift), `{name, focal x, focal y}`

  @doc """
  The painting over one of the day's orders on the Now card
  (PrayerBookPainting.hour): Morning's and Night's own, the Annunciation
  for the Angelus and the risen Christ with His Mother for Queen of Heaven.
  """
  def hour_painting(%{id: @morning}, _date),
    do: resolve({"hour_morning", 0.5, 0.2}, {"joyful_presentation", 0.5, 0.2})

  def hour_painting(%{id: @night}, _date), do: resolve({"hour_night", 0.5, 0.3})

  def hour_painting(_angelus, date) do
    if LiturgicalCalendar.eastertide?(date),
      do: resolve({"easter_appears_to_mary", 0.5, 0.55}),
      else: {"joyful_annunciation", 0.5, 0.18}
  end

  @doc """
  An order's painting on its shortcut, its topic's Pray together card and
  its search row (PrayerBookPainting.order); the day's three hang their
  hour's.
  """
  def painting(%{id: id}, _date) when id in ~w(before_mass after_mass),
    do: {"luminous_eucharist", 0.5, 0.35}

  def painting(%{id: "before_confession"}, _date), do: resolve({"saint_peter_tears", 0.5, 0.27})
  def painting(%{id: "after_confession"}, _date), do: resolve({"topic_confession", 0.3, 0.32})
  def painting(%{id: "visit"}, _date), do: resolve({"jesus_eucharist_saviour", 0.5, 0.3})
  def painting(%{id: "holy_souls"}, _date), do: resolve({"order_raising_of_lazarus", 0.4, 0.45})
  def painting(%{id: "trouble"}, _date), do: resolve({"jesus_good_shepherd", 0.4, 0.45})
  def painting(%{id: "table"}, _date), do: resolve({"prayer_supper_emmaus", 0.5, 0.35})
  def painting(order, date), do: hour_painting(order, date)

  @doc """
  The painting at the head of an order's page (PrayerOrderView.painting):
  its own, Night Prayers' hung from the top of the canvas.
  """
  def page_painting(%{id: @night} = order, date) do
    {name, x, _y} = painting(order, date)
    {name, x, 0.0}
  end

  def page_painting(order, date), do: painting(order, date)

  @doc """
  The painting behind the prayers being prayed (PrayAlongView.painting):
  the Angelus is read from its prayer, Queen of Heaven's risen Christ or
  the Hail Mary's Annunciation; any other order hangs its own.
  """
  def pray_painting(book, order, prayers, date) do
    case {order.id, prayers} do
      {_id, [%{id: "regina_caeli"}]} -> resolve({"easter_appears_to_mary", 0.5, 0.55})
      {@angelus, _prayers} -> Book.prayer_painting(book, "hail_mary")
      {_id, [%{id: "angelus"}]} -> Book.prayer_painting(book, "hail_mary")
      _other -> painting(order, date)
    end
  end

  # The asset itself where the website has it, else its fallback: iOS's
  # own where it names one (Morning's Presentation), else the Coronation,
  # which every page has.
  defp resolve({asset, _x, _y} = painting, fallback \\ {"glorious_coronation", 0.5, 0.12}) do
    if MysteryPainting.for_name(asset), do: painting, else: fallback
  end

  ## Search (PrayerBook.searchOrders, AppSearch.orderHits)

  @doc """
  The orders a search names, as the app's search finds them: every word
  searched begins a word of the order's title, Latin title, when it is
  said or the names it is looked for by ("blessed sacrament" finds
  Visiting Jesus in Church); then any whose name on `date` holds the
  search, which the names alone do not know ("queen of heaven" is the
  Angelus in Eastertide).
  """
  def search(%Book{orders: orders}, needle, %Date{} = date) do
    wanted = Book.search_terms(needle)

    named =
      if wanted == [] or String.length(Enum.join(wanted)) < 3 do
        []
      else
        Enum.filter(orders, fn order ->
          [order.title, order.latin_title, order.occasion | order.search_words]
          |> Enum.any?(&Book.name_answers?(wanted, &1))
        end)
      end

    phrase = needle |> Book.fold() |> String.trim()

    seasonal =
      if phrase == "" do
        []
      else
        Enum.filter(orders, fn order ->
          order not in named and String.contains?(Book.fold(title(order, date)), phrase)
        end)
      end

    named ++ seasonal
  end
end
