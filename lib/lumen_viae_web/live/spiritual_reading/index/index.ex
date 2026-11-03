defmodule LumenViaeWeb.Live.SpiritualReading.Index do
  @moduledoc """
  `/spiritual-reading`: the Spiritual Reading shelf, as the iOS app's
  `SpiritualReadingView`: the open book over the shelf's name, what it
  is, Augustine's "Take up and read", then the five books in their own
  cloth, each opening its page, and the credit to the books' sources.
  A book with a reading under way in this browser wears the marker ribbon
  (the `SpiritualReadingPlace` hook). Instant: no book's text is fetched
  until a book is opened.

  True Devotion is not on it, as it is not on the app's shelf: the app
  reaches Montfort's book from Explore and the Consecration, and so does
  the site (`/true-devotion`).
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.SpiritualReading.Shelf
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.SpiritualReading.Cover

  @impl true
  def mount(_params, _session, socket) do
    books = Shelf.books(socket.assigns.current_admin)

    {:ok,
     socket
     |> PageMeta.put(Shelf.path(),
       title: "Spiritual Reading",
       description:
         "Classic Catholic books to read online, chapter by chapter: " <>
           Enum.map_join(books, ", ", &"#{&1.title} by #{&1.author}") <>
           ". Public-domain texts from Project Gutenberg.",
       trail: [{"Spiritual Reading", Shelf.path()}],
       json_ld: [shelf_data(books)]
     )
     |> assign(:books, books)}
  end

  @doc false
  def book_data(book) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Book",
      "name" => book.title,
      "author" => %{"@type" => "Person", "name" => book.author},
      "inLanguage" => "en",
      "isAccessibleForFree" => true,
      "url" => PageMeta.absolute_url(Shelf.book_path(book.id))
    }
    |> then(fn data ->
      if book.translator,
        do: Map.put(data, "translator", %{"@type" => "Person", "name" => book.translator}),
        else: data
    end)
  end

  defp shelf_data(books) do
    %{
      "@context" => "https://schema.org",
      "@type" => "ItemList",
      "name" => "Spiritual Reading",
      "itemListElement" =>
        books
        |> Enum.with_index(1)
        |> Enum.map(fn {book, position} ->
          %{"@type" => "ListItem", "position" => position, "item" => book_data(book)}
        end)
    }
  end
end
