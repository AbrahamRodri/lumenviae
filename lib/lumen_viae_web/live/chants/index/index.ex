defmodule LumenViaeWeb.Live.Chants.Index do
  @moduledoc """
  `/chant`: the Chant Library, as the iOS app's Chant tab opens it
  (`ChantLibraryView`): the name over the number of recordings and the
  search; the tiles, A Sung Rosary and Adoration and Blessing, the Mass
  of the Angels, Before Bed; Songs to Mary as square cards, each with its
  length and its own play; Sets of chants, the six sung sets as cards
  whose disc sings the whole set, the shelf's name opening Sets of
  Chants; and All Chants, the book's twelve sections as painted cards,
  each opening its shelf; the singers' credit at the foot.

  The app's other tiles and shelves open what the phone keeps (the chant
  last sung, Learned, Your favourites, Played lately, the reader's own
  sets and Make your own set); the website keeps nothing of what a
  visitor played, so they are not here.

  The sets are unrolled for the visitor's day, since Before Bed sings
  tonight's song to Mary: the server's date until the `UserTimezone` hook
  says the browser's.

  The search rides in the link as `?q=` and lists the chants it finds as
  the app's search lists them from the Chant tab
  (`LumenViaeWeb.Live.Chants.Library.search/3`): by title, by the prayer
  they sing, by a line of their words.

  A disc plays its chant where it stands, through the `ChantPlayer` hook;
  leaving the page stops it.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Chants.Occasions
  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Chants.Parts

  @description "The Lumen Viae Chant Library: the Church's own songs in Gregorian chant, each recording with its Latin and English words line by line, the Mass of the Angels and the songs to Mary among them."

  @impl true
  def mount(_params, _session, socket) do
    library = Library.load(socket.assigns.current_admin)

    {:ok,
     socket
     |> PageMeta.put("/chant",
       title: "Chant",
       description: @description,
       trail: [{"Chant", "/chant"}]
     )
     |> assign(:library, library)
     |> assign(:count, Library.count(library))
     |> assign(:songs, Library.songs_to_mary(library))
     |> assign(:sections, sections(library))
     |> assign_day(Date.utc_today())
     |> assign(:prayer_names, nil)
     |> assign(:query, "")
     |> assign(:hits, [])}
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
    case Book.local_date(offset) do
      {:ok, date} -> {:noreply, assign_day(socket, date)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  defp assign_day(socket, date) do
    library = socket.assigns.library
    {before_mass, after_mass} = Occasions.tiles(library)

    socket
    |> assign(:tiles_before, before_mass)
    |> assign(:tiles_after, after_mass)
    |> assign(:sets, Enum.map(Occasions.all(library), &Occasions.unroll(&1, library, date)))
  end

  defp assign_search(%{assigns: %{query: ""}} = socket), do: assign(socket, :hits, [])

  defp assign_search(socket) do
    # The Prayer Book's names for the prayers the chants sing, read the
    # first time anything is searched.
    socket =
      if socket.assigns.prayer_names,
        do: socket,
        else:
          assign(
            socket,
            :prayer_names,
            Library.prayer_names(Book.load(socket.assigns.current_admin))
          )

    %{library: library, query: query, prayer_names: names} = socket.assigns
    assign(socket, :hits, Library.search(library, query, names))
  end

  defp sections(library) do
    for group <- library.groups do
      %{
        id: group.id,
        title: Library.card_title(group),
        note: Library.chant_count(length(Library.group_chants(library, group))),
        painting: Library.section_painting(group.id)
      }
    end
  end

  defp path(query) do
    case String.trim(query) do
      "" -> "/chant"
      query -> "/chant?" <> URI.encode_query(q: query)
    end
  end
end
