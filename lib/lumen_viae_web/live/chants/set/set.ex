defmodule LumenViaeWeb.Live.Chants.Set do
  @moduledoc """
  `/chant/sets/:occasion_id`: one sung set on a page of its own, as the
  app's `ChantSetPage` draws a set of the library's: its painting across
  the top, the name, one line and "7 chants · 53 min" on its foot, one
  outlined PLAY ALL, then its chants in the order they are sung, numbered,
  each with how often it is sung and how long, the notes in red over the
  chants they lead to.

  Play all sings the whole set in this page (`ChantPlayer`), the decades'
  rounds and repeats unrolled, and lights the row sounding; it pauses and
  resumes once under way. A row's Play from Here sings the set from that
  chant. Pause Between Chants, which the app keeps in the set's ··· menu,
  is a switch on the page, kept nowhere: with it on, the next chant waits
  at its start until Play next is pressed. Leaving the page stops it,
  since the website has no player at the foot of every page yet.

  The app's bookmark, which keeps a sung set as the reader's own, is left
  out: the website keeps nothing. Share is the reader's own sets' alone
  in the app, so it is not here either.

  Before Bed sings tonight's song to Mary by the visitor's date: the
  server's until the `UserTimezone` hook says the browser's. An id the
  library does not have is a 404.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Chants.Occasions
  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Chants.Parts
  import LumenViaeWeb.Live.Prayers.Painting

  @impl true
  def mount(%{"occasion_id" => id}, _session, socket) do
    library = Library.load(socket.assigns.current_admin)

    occasion =
      Occasions.occasion(library, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown sung set: #{inspect(id)}"

    set = Occasions.unroll(occasion, library, Date.utc_today())

    {:ok,
     socket
     |> PageMeta.put(Occasions.set_path(id),
       title: "#{occasion.title}, Chant",
       description: description(set),
       image: PageMeta.named_image(set.painting),
       trail: [
         {"Chant", "/chant"},
         {"Sets of Chants", Occasions.sets_path()},
         {occasion.title, Occasions.set_path(id)}
       ]
     )
     |> assign(:library, library)
     |> assign(:occasion, occasion)
     |> assign(:set, set)}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case Book.local_date(offset) do
      {:ok, date} ->
        %{occasion: occasion, library: library} = socket.assigns
        {:noreply, assign(socket, :set, Occasions.unroll(occasion, library, date))}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  defp description(set) do
    names = set.chants |> Enum.take(4) |> Enum.map_join(", ", & &1.latin_title)

    "#{set.title} in Gregorian chant: #{set.note}. #{Occasions.summary(set)}, among them #{names}."
  end
end
