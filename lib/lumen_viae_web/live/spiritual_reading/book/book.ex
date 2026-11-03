defmodule LumenViaeWeb.Live.SpiritualReading.Book do
  @moduledoc """
  `/spiritual-reading/:book_id`: one book of the shelf, as the iOS app's
  `LibraryBookView`: its cloth beside the title, the author and the one
  gold act (Begin reading, or "Continue · III.V" where this browser left
  off), then the contents, "Contents · 115 chapters", each part's name
  pinned over its chapters with how many it holds, each row the chapter's
  numeral and title, and the parts' numerals down the edge to go to one.
  The list opens at the reader's place: the chapter being read is lit,
  the ones read are dimmed, and the chapters more than two before it fold
  into "39 earlier chapters", Show. The credit names the Gutenberg
  edition.

  The book's text is fetched from Project Gutenberg by the server
  (`Shelf.read/3`). A book this machine already holds is drawn whole at
  once, for a crawler too; one it has not fetched yet shows "Fetching the
  text from Project Gutenberg" and fetches it once the page connects
  (`start_async`); a book that cannot be reached says so with Try again,
  and an edition that no longer cuts into chapters says so without one,
  as the app does. The place is this browser's (`SpiritualReadingPlace`).
  An unknown book is a 404.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.SpiritualReading.Index
  alias LumenViaeWeb.Live.SpiritualReading.Shelf
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.SpiritualReading.Cover
  import LumenViaeWeb.Live.SpiritualReading.States

  @impl true
  def mount(%{"book_id" => id}, _session, socket) do
    book =
      Shelf.book(socket.assigns.current_admin, id) ||
        raise LumenViaeWeb.NotFoundError,
          message: "unknown Spiritual Reading book: #{inspect(id)}"

    {:ok,
     socket
     |> PageMeta.put(Shelf.book_path(book.id),
       title: book.title,
       description: "#{book.title} by #{Shelf.author_line(book)}, to read online. #{book.blurb}",
       trail: [{"Spiritual Reading", Shelf.path()}, {book.title, Shelf.book_path(book.id)}],
       json_ld: [Index.book_data(book)]
     )
     |> assign(:book, book)
     |> assign(:failure, nil)
     |> assign_text(Shelf.read(socket.assigns.current_admin, book.id, cached_only: true))}
  end

  @impl true
  def handle_event("retry", _params, socket), do: {:noreply, fetch(socket)}

  @impl true
  def handle_async(:text, {:ok, text}, socket), do: {:noreply, assign_text(socket, text)}

  def handle_async(:text, {:exit, _reason}, socket),
    do: {:noreply, assign(socket, state: :failed, failure: :unreachable)}

  defp assign_text(socket, %{status: :ok} = text) do
    runs = Shelf.runs(text.contents)

    assign(socket,
      state: :ready,
      edition: text.fingerprint,
      chapters: text.contents,
      runs: runs,
      parts?: Shelf.parts?(runs),
      numbered?: Shelf.numbers_chapters?(text.contents)
    )
  end

  defp assign_text(socket, %{status: :cold}), do: fetch(socket)

  defp assign_text(socket, %{status: reason}),
    do: assign(socket, state: :failed, failure: reason)

  defp fetch(socket) do
    socket = assign(socket, state: :loading, failure: nil)

    if connected?(socket) do
      %{book: book, current_admin: actor} = socket.assigns

      socket
      |> cancel_async(:text)
      |> start_async(:text, fn -> Shelf.read(actor, book.id) end)
    else
      socket
    end
  end

  attr :chapter, :map, required: true
  attr :book, :map, required: true
  attr :runs, :list, required: true
  attr :numbered?, :boolean, required: true

  # One row (LibraryChapterRow's page row): the numeral in a column of its
  # own, the title. The hook lights the chapter being read (with a dot by
  # its numeral) and dims the ones read.
  defp chapter_row(assigns) do
    numeral = Shelf.numeral(assigns.chapter.heading)
    assigns = assign(assigns, :numeral, numeral)

    ~H"""
    <.link
      navigate={Shelf.chapter_path(@book.id, @chapter.id)}
      class="sr-row"
      data-role="chapter-row"
      data-chapter={@chapter.id}
      data-short={Shelf.short_name(@chapter, @runs)}
      data-spoken={Shelf.spoken(@chapter)}
      aria-label={Shelf.spoken(@chapter)}
    >
      <span :if={@numeral || @numbered?} class="sr-row__num" aria-hidden="true">
        {@numeral}<span class="sr-row__here"></span>
      </span>
      <span class="sr-row__title">{Shelf.row_title(@chapter)}</span>
    </.link>
    """
  end
end
