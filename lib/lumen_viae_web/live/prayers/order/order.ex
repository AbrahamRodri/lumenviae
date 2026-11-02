defmodule LumenViaeWeb.Live.Prayers.Order do
  @moduledoc """
  `/prayers/orders/:order_id`: an order of prayer's own page, as the app's
  `PrayerOrderView` draws it. The order's painting at the head, dissolving
  into the page; when it is prayed and its name for the day over the
  painting's foot; its prayers as a quiet numbered list, each beginning
  the order there; in Eastertide, a line saying Queen of Heaven stands in
  the Angelus's place; and at the foot Pray, the page's one gold act,
  which prays it in silence at `/prayers/orders/:order_id/pray`. An id
  the book does not have is a 404.

  The day is the visitor's: the server's until the `UserTimezone` hook
  sends the browser's offset, then the local one, so the Angelus is Queen
  of Heaven from Easter to Pentecost and Night Prayers close on the song
  to Mary the visitor's day sings. The app's PRAYED TODAY is left out:
  the website keeps nothing of what a visitor prayed.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Prayers.{Book, Orders}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Painting

  @impl true
  def mount(%{"order_id" => id}, _session, socket) do
    book = Book.load(socket.assigns.current_admin)

    order =
      Orders.order(book, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown order of prayer: #{id}"

    chapter = order.chapter_id && Book.chapter(book, order.chapter_id)
    # The day's name (Queen of Heaven in Eastertide), on the server's date.
    title = Orders.title(order, Date.utc_today())

    {:ok,
     socket
     |> PageMeta.put(Orders.order_path(id),
       title: title,
       description: "#{title} (#{order.latin_title}), #{lower(order.occasion)}: #{order.detail}",
       trail: trail(order, chapter, title)
     )
     |> assign(:book, book)
     |> assign(:order, order)
     |> assign_day(Date.utc_today())}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case Book.local_date(offset) do
      {:ok, date} -> {:noreply, assign_day(socket, date)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  defp assign_day(socket, date) do
    %{book: book, order: order} = socket.assigns

    socket
    |> assign(:title, Orders.title(order, date))
    |> assign(:prayers, Orders.prayers(book, order, date))
    |> assign(:season_note, Orders.season_note(order, date))
    |> assign(:painting, Orders.page_painting(order, date))
  end

  defp trail(order, nil, title),
    do: [{"Prayers", "/prayers"}, {title, Orders.order_path(order.id)}]

  defp trail(order, chapter, title) do
    [
      {"Prayers", "/prayers"},
      {chapter.title, Book.chapter_path(chapter.id)},
      {title, Orders.order_path(order.id)}
    ]
  end

  defp lower(<<first::utf8, rest::binary>>), do: String.downcase(<<first::utf8>>) <> rest
end
