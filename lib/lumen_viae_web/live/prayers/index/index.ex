defmodule LumenViaeWeb.Live.Prayers.Index do
  @moduledoc """
  `/prayers`: the Prayer Book, as the iOS app's Prayers tab opens it. The
  heading and the number of prayers, the search, and the shelves in the
  app's order: Everyday Prayers, Prayers to Mary (the season's song
  first) and All Topics.

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

  @description "The Lumen Viae Prayer Book: the everyday prayers, the songs to Mary through the year and every topic, in English and Latin, with a note on when each is said."

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
     |> assign(:everyday, Book.prayers(book, Book.everyday_ids()))
     |> assign(:marian, Book.marian_shelf(book, today))
     |> assign(:seasonal_id, seasonal_id(book, today))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params |> Map.get("q", "") |> to_string() |> String.trim()
    book = socket.assigns.book

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:hits, if(query == "", do: [], else: Book.search(book, query)))
     |> assign(:topics, if(query == "", do: [], else: book |> Book.topics(query) |> Enum.take(2)))}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: path(query), replace: true)}
  end

  def handle_event("search", _params, socket), do: {:noreply, socket}

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
