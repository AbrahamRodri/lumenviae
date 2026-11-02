defmodule LumenViaeWeb.Live.Prayers.Index do
  @moduledoc """
  `/prayers`: the Prayer Book, as the iOS app's Prayers tab opens it. The
  heading and the number of prayers, the search, and the page in the
  app's order: the shortcuts (the day's three orders of prayer, Before
  Mass and Before Confession; the app's Saved is not on the website),
  Now (the order for the hour it is), Everyday Prayers, Prayers to Mary
  (the season's song first) and All Topics under the book's five parts.

  "Now", for the hour's order and the season's names and song, is the
  visitor's: the `UserTimezone` hook sends the browser's offset once
  connected (`set_timezone`). Until it does, the shortcuts and the songs
  go by the server's date, and the Now card is an empty frame of its
  size, so no visitor (or crawler) is shown the hour in UTC. While the
  page is open the card turns when the book's hour does
  (`Orders.next_turn_in/1`: four, eleven, three and eight o'clock on the
  visitor's clock).

  The search rides in the link as `?q=`, so a reload, a shared link and
  the back button keep it; it is ranked as the app ranks it
  (`LumenViaeWeb.Live.Prayers.Book.search/2`), with the topics it names
  as cards, then the orders of prayer it names
  (`LumenViaeWeb.Live.Prayers.Orders.search/3`), above the prayers.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Prayers.{Book, Orders}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Index.Shelves
  import LumenViaeWeb.Live.Prayers.Index.Search

  @description "The Lumen Viae Prayer Book: the everyday prayers, the songs to Mary through the year and every topic, in English and Latin."

  @impl true
  def mount(_params, _session, socket) do
    book = Book.load(socket.assigns.current_admin)

    {:ok,
     socket
     |> PageMeta.put("/prayers",
       title: "Prayers",
       description: @description,
       trail: [{"Prayers", "/prayers"}]
     )
     |> assign(:book, book)
     |> assign(:prayer_count, Book.prayer_count(book))
     |> assign(:everyday, everyday_rows(book))
     |> assign(:parts, Book.parts(book))
     |> assign(:query, "")
     |> assign(offset: nil, turn: nil)
     |> assign_now(NaiveDateTime.utc_now())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = if is_binary(params["q"]), do: String.trim(params["q"]), else: ""

    {:noreply, socket |> assign(:query, query) |> assign_search()}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) when is_binary(query) do
    {:noreply, push_patch(socket, to: path(query), replace: true)}
  end

  def handle_event("search", _params, socket), do: {:noreply, socket}

  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case Orders.local_now(offset) do
      {:ok, now} -> {:noreply, socket |> assign(:offset, offset) |> keep_time(now)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:turn, %{assigns: %{offset: offset}} = socket) when is_integer(offset) do
    {:ok, now} = Orders.local_now(offset)
    {:noreply, keep_time(socket, now)}
  end

  def handle_info(:turn, socket), do: {:noreply, socket}

  # The page at the visitor's `now`, and a wake for the hour's next turn
  # (PrayerBook.nextTurn), a second after it so the clock has passed it.
  defp keep_time(socket, now) do
    if socket.assigns.turn, do: Process.cancel_timer(socket.assigns.turn)
    turn = Process.send_after(self(), :turn, Orders.next_turn_in(now) + 1000)

    socket |> assign(:turn, turn) |> assign_now(now) |> assign_search()
  end

  # The page as it stands at the visitor's `now`: the shortcuts' names and
  # paintings, the hour's order, and the season's song to Mary.
  defp assign_now(socket, now) do
    book = socket.assigns.book
    today = NaiveDateTime.to_date(now)

    socket
    |> assign(:today, today)
    |> assign(:shortcuts, Orders.shortcut_orders(book))
    |> assign(:now_order, Orders.day_order(book, now))
    |> assign(:hour, now.hour)
    |> assign(:marian, Book.marian_shelf(book, today))
    |> assign(:seasonal_id, seasonal_id(book, today))
  end

  defp assign_search(socket) do
    %{book: book, query: query, today: today} = socket.assigns

    if query == "" do
      assign(socket, hits: [], topics: [], orders: [])
    else
      assign(socket,
        hits: Book.search(book, query),
        topics: book |> Book.topics(query) |> Enum.take(2),
        orders: book |> Orders.search(query, today) |> Enum.take(3)
      )
    end
  end

  # Each everyday prayer with its painting.
  defp everyday_rows(book) do
    for prayer <- Book.prayers(book, Book.everyday_ids()) do
      %{prayer: prayer, painting: Book.prayer_painting(book, prayer.id)}
    end
  end

  defp path(query) do
    case String.trim(query) do
      "" -> "/prayers"
      query -> "/prayers?" <> URI.encode_query(q: query)
    end
  end

  defp seasonal_id(book, today) do
    case Book.antiphon(book, today) do
      nil -> nil
      antiphon -> antiphon.prayer_id
    end
  end
end
