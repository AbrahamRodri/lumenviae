defmodule LumenViaeWeb.Live.Chants.Sets do
  @moduledoc """
  `/chant/sets`: Sets of Chants, as the app's `ChantSetsPage` lists them:
  "Chants sung one after another, for a time of prayer.", then the
  library's six sung sets as wide painted cards, each with what it is for
  and how many chants and how long, opening its page.

  The app goes on to the reader's own sets and Make your own set, which
  the phone keeps; the website keeps nothing, so they are not here.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Chants.Occasions
  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Chants.Parts

  @description "Sets of Gregorian chants sung one after another for a time of prayer: Adoration and Blessing, a visit to Jesus in church, a sung Rosary, before bed, before work or study, and for those who have died."

  @impl true
  def mount(_params, _session, socket) do
    library = Library.load(socket.assigns.current_admin)

    {:ok,
     socket
     |> PageMeta.put(Occasions.sets_path(),
       title: "Sets of Chants",
       description: @description,
       trail: [{"Chant", "/chant"}, {"Sets of Chants", Occasions.sets_path()}]
     )
     |> assign(:library, library)
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

  # Before Bed's length is tonight's song to Mary's.
  defp assign_day(socket, date) do
    library = socket.assigns.library
    assign(socket, :sets, Enum.map(Occasions.all(library), &Occasions.unroll(&1, library, date)))
  end
end
