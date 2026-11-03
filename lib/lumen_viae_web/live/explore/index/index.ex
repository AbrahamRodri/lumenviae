defmodule LumenViaeWeb.Live.Explore.Index do
  @moduledoc """
  `/explore`: Explore, as the iOS app opens it from Home's search glass
  (`ExploreView`): one page that can reach everything. Empty, it is a
  directory of the site (`LumenViaeWeb.Live.Explore.Index.Browse`);
  typed into, it searches the mysteries, the site's doors (the Daily
  Missal, the Spiritual Reading shelf and each of its books among them),
  the Prayer Book's topics, orders and prayers, the chants and every meditation set
  (`LumenViaeWeb.Live.Explore.Search`), drawn as the app draws what it
  found (`LumenViaeWeb.Live.Explore.Index.Results`).

  The search rides in the link as `?q=`, so a reload, a shared link and
  the back button keep it; the field is a plain GET form, so it works
  before the page connects, and once it has, every keystroke patches the
  link in place. A `q` that is not a string is no search. The search runs
  on the server over what the page loaded; nothing about it is kept.

  The mysteries, the meditation sets and the Prayer Book's names for the
  prayers the chants sing are read the first time anything is searched,
  as the app fetches the sets on the first typed word, never on arrival.

  The orders of prayer go by the visitor's day (Queen of Heaven for the
  Angelus in Eastertide): the server's date until the `UserTimezone` hook
  says the browser's. A chant's disc, and the best card's Listen, play it
  where it stands through the `ChantPlayer` hook; leaving the page leaves it
  singing, with the mini player at the foot of the site (`ChantMiniPlayer`).
  The Spiritual Reading shelf's covers wear the marker ribbon where this
  browser has a reading under way (the `SpiritualReadingPlace` hook).
  """
  use LumenViaeWeb, :live_view

  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Explore.Search
  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.Live.SpiritualReading.Shelf
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Explore.Index.Browse
  import LumenViaeWeb.Live.Explore.Index.Results

  @max_query 100

  @description "Explore Lumen Viae: search the mysteries of the Rosary, the Prayer Book, the Chant Library and every meditation set at once, or browse them."

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_admin
    book = Book.load(actor)
    library = Library.load(actor)

    {:ok,
     socket
     |> PageMeta.put("/explore",
       title: "Explore",
       description: @description,
       trail: [{"Explore", "/explore"}]
     )
     |> assign(:book, book)
     |> assign(:library, library)
     |> assign(:occasions, occasion_orders(book))
     |> assign(:chant_count, Library.count(library))
     |> assign(:books, Shelf.books(actor))
     |> assign(:loaded, nil)
     |> assign(:query, "")
     |> assign_date(Date.utc_today())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = if is_binary(params["q"]), do: params["q"] |> clip() |> String.trim(), else: ""

    {:noreply, socket |> assign(:query, query) |> assign_search()}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) when is_binary(query) do
    {:noreply, push_patch(socket, to: path(query), replace: true)}
  end

  def handle_event("search", _params, socket), do: {:noreply, socket}

  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case Book.local_date(offset) do
      {:ok, date} -> {:noreply, socket |> assign_date(date) |> assign_search()}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  defp assign_date(socket, date) do
    socket
    |> assign(:date, date)
    |> assign(:pages, Search.pages(date, socket.assigns.books))
  end

  defp assign_search(%{assigns: %{query: ""}} = socket) do
    assign(socket, :results, %Search{date: socket.assigns.date})
  end

  defp assign_search(socket) do
    socket = load_sources(socket)
    %{query: query, loaded: loaded, date: date} = socket.assigns

    sources =
      Map.merge(loaded, %{
        book: socket.assigns.book,
        library: socket.assigns.library,
        pages: socket.assigns.pages
      })

    assign(socket, :results, Search.results(query, sources, date))
  end

  # What only a search needs, read the first time anything is searched.
  defp load_sources(%{assigns: %{loaded: %{}}} = socket), do: socket

  defp load_sources(socket) do
    actor = socket.assigns.current_admin

    assign(socket, :loaded, %{
      prayer_names: Library.prayer_names(socket.assigns.book),
      mysteries: Rosary.list_mysteries!(actor: actor),
      # By name, as the app's Explore lists them (ExploreView).
      sets:
        Rosary.list_visible_meditation_set_summaries!(actor: actor)
        |> Enum.sort_by(& &1.name)
    })
  end

  # A search is at most @max_query characters: the field stops there, and
  # a longer one from a link or the socket is cut, so no visitor can make
  # every prayer fold against a page of text.
  defp clip(query), do: String.slice(query, 0, @max_query)

  defp path(query) do
    case query |> clip() |> String.trim() do
      "" -> "/explore"
      query -> "/explore?" <> URI.encode_query(q: query)
    end
  end
end
