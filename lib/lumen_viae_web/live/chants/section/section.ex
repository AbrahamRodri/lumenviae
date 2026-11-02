defmodule LumenViaeWeb.Live.Chants.Section do
  @moduledoc """
  `/chant/sections/:section_id`: a shelf of the Chant Library, as the
  app's `ChantShelf` draws one: a section of the book (`hymns`,
  `ourLady`) or the Mass of the Angels (`mass_of_the_angels`, the
  Ordinary's first Mass). Its painting hung across the top, the name,
  when it is sung, how many chants and how long, an outlined PLAY ALL,
  the strip of its parts where it has them (the Masses, the seasons), and
  its chants in order: a row with its own painting where they hang
  paintings of their own, numbered where every chant shares the shelf's.

  Play all sings the shelf's chants one after another in this page
  (`ChantPlayer`); leaving the page stops it, since the website has no
  player at the foot of every page yet. An id the library does not have
  is a 404.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Chants.Parts
  import LumenViaeWeb.Live.Prayers.Painting

  @impl true
  def mount(%{"section_id" => id}, _session, socket) do
    library = Library.load(socket.assigns.current_admin)

    shelf =
      Library.shelf(library, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown chant section: #{inspect(id)}"

    chants = Library.shelf_chants(shelf)

    {:ok,
     socket
     |> PageMeta.put(Library.section_path(shelf.id),
       title: "#{shelf.title}, Chant",
       description: description(shelf, chants),
       trail: [{"Chant", "/chant"}, {shelf.title, Library.section_path(shelf.id)}]
     )
     |> assign(:shelf, shelf)
     |> assign(:chants, chants)
     |> assign(:numbered?, Library.numbers_its_chants?(chants))
     |> assign(:strip?, Enum.any?(shelf.parts, & &1.title))}
  end

  defp description(shelf, chants) do
    names = chants |> Enum.take(4) |> Enum.map_join(", ", & &1.latin_title)
    lead = if shelf.note, do: "#{shelf.note}. ", else: ""
    "#{shelf.title} in Gregorian chant: #{Library.summary(chants)}. #{lead}Among them #{names}."
  end
end
