defmodule LumenViaeWeb.Live.Prayers.Index do
  @moduledoc """
  `/prayers`: the Prayer Book, as the iOS app's Prayers tab opens it. The
  heading and the number of prayers, the search, and the shelves in the
  app's order: Everyday Prayers, Prayers to Mary (the season's song
  first) and All Topics under the book's five parts.

  "Today", for the season's song, is the visitor's: the `UserTimezone`
  hook sends the browser's offset once connected (`set_timezone`); until
  then it is the server's date.

  The search rides in the link as `?q=`, so a reload, a shared link and
  the back button keep it; it is ranked as the app ranks it
  (`LumenViaeWeb.Live.Prayers.Book.search/2`), with the topics it names
  as cards above the prayers.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Index.Shelves
  import LumenViaeWeb.Live.Prayers.Index.Search

  @description "The Lumen Viae Prayer Book: the everyday prayers, the songs to Mary through the year and every topic, in English and Latin."

  @impl true
  def mount(_params, _session, socket) do
    book = Book.load(socket.assigns.current_admin)
    today = Date.utc_today()

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
     |> assign_today(today)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = if is_binary(params["q"]), do: String.trim(params["q"]), else: ""
    book = socket.assigns.book

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:hits, if(query == "", do: [], else: Book.search(book, query)))
     |> assign(:topics, if(query == "", do: [], else: book |> Book.topics(query) |> Enum.take(2)))}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) when is_binary(query) do
    {:noreply, push_patch(socket, to: path(query), replace: true)}
  end

  def handle_event("search", _params, socket), do: {:noreply, socket}

  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case Book.local_date(offset) do
      {:ok, date} -> {:noreply, assign_today(socket, date)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  defp assign_today(socket, today) do
    book = socket.assigns.book

    socket
    |> assign(:marian, Book.marian_shelf(book, today))
    |> assign(:seasonal_id, seasonal_id(book, today))
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
