defmodule LumenViaeWeb.Live.SpiritualReading.Chapter do
  @moduledoc """
  `/spiritual-reading/:book_id/:chapter`: one chapter of a book read in
  place, as the iOS app's `LibraryChapterReaderView` sets it: the hairline
  that says where the chapter stands in the book, the part and heading
  over the title with "8 of 115", the ornament, the text on night at the
  reading size with the app's versal on a long opening paragraph, each of
  the edition's footnote markers a small gold link to its note, the notes
  set apart at the foot under NOTES, and the chapters either side by their
  headings. The contents (the app's sheet) are a rail beside the text from
  1024px and a list that opens above it on a phone, this chapter marked
  Here.

  `:chapter` counts from 1. The text is fetched and cut by the server as
  on the book's page (`Shelf.read/3`): drawn at once when this machine
  holds the book, fetched after the page connects when it does not, with
  the same words while it comes and when it cannot. A chapter the book
  does not have is a 404 (or, found only after a fetch, says so).

  The place is this browser's (`SpiritualReadingPlace`): opening the
  chapter makes it the place, the paragraph at the top of the screen is
  kept as the reader scrolls and resumed when the chapter is opened again,
  and reaching the foot or stepping on marks the chapter read. Nothing is
  sent to the server.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.SpiritualReading.Index
  alias LumenViaeWeb.Live.SpiritualReading.Shelf
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.SpiritualReading.States

  @impl true
  def mount(%{"book_id" => id, "chapter" => param}, _session, socket) do
    actor = socket.assigns.current_admin

    book =
      Shelf.book(actor, id) ||
        raise LumenViaeWeb.NotFoundError,
          message: "unknown Spiritual Reading book: #{inspect(id)}"

    index =
      case Shelf.parse_chapter(param) do
        {:ok, index} -> index
        :error -> raise LumenViaeWeb.NotFoundError, message: "no chapter #{inspect(param)}"
      end

    text = Shelf.read(actor, book.id, chapter: index, cached_only: true)

    if text.status == :not_found,
      do: raise(LumenViaeWeb.NotFoundError, message: "#{book.id} has no chapter #{index + 1}")

    {:ok,
     socket
     |> assign(book: book, index: index, failure: nil)
     |> put_meta(text)
     |> assign_text(text)}
  end

  @impl true
  def handle_event("retry", _params, socket), do: {:noreply, fetch(socket)}

  @impl true
  def handle_async(:text, {:ok, text}, socket), do: {:noreply, assign_text(socket, text)}

  def handle_async(:text, {:exit, _reason}, socket),
    do: {:noreply, assign(socket, state: :failed, failure: :unreachable)}

  # The title names the chapter where the server already holds it, and
  # its number otherwise, as the meta is written with the first response.
  defp put_meta(socket, text) do
    %{book: book, index: index} = socket.assigns
    path = Shelf.chapter_path(book.id, index)

    {name, description} =
      case text do
        %{status: :ok, chapter: chapter} ->
          {Shelf.display_title(chapter), Shelf.description(book, chapter)}

        _not_yet ->
          {"Chapter #{index + 1}",
           "Chapter #{index + 1} of #{book.title} by #{book.author}, to read online."}
      end

    PageMeta.put(socket, path,
      title: "#{name}, #{book.title}",
      description: description,
      trail: [
        {"Spiritual Reading", Shelf.path()},
        {book.title, Shelf.book_path(book.id)},
        {name, path}
      ],
      json_ld: [
        %{
          "@context" => "https://schema.org",
          "@type" => "Chapter",
          "name" => name,
          "url" => PageMeta.absolute_url(path),
          "isPartOf" => Index.book_data(book)
        }
      ]
    )
  end

  defp assign_text(socket, %{status: :ok} = text) do
    %{book: book, index: index} = socket.assigns
    chapter = text.chapter
    notes = Shelf.notes(chapter)
    runs = Shelf.runs(text.contents)

    assign(socket,
      state: :ready,
      edition: text.fingerprint,
      chapter: chapter,
      count: length(text.contents),
      runs: runs,
      kicker: Shelf.kicker(book, chapter),
      paragraphs: Shelf.paragraphs(chapter, book.parsing.note_pattern),
      notes: notes,
      note_text: Map.new(notes, &{&1.number, &1.text}),
      previous: index > 0 && Enum.at(text.contents, index - 1),
      next: Enum.at(text.contents, index + 1)
    )
  end

  defp assign_text(socket, %{status: :cold}), do: fetch(socket)

  defp assign_text(socket, %{status: :not_found}),
    do: assign(socket, state: :missing, failure: nil)

  defp assign_text(socket, %{status: reason}),
    do: assign(socket, state: :failed, failure: reason)

  defp fetch(socket) do
    socket = assign(socket, state: :loading, failure: nil)

    if connected?(socket) do
      %{book: book, index: index, current_admin: actor} = socket.assigns

      socket
      |> cancel_async(:text)
      |> start_async(:text, fn -> Shelf.read(actor, book.id, chapter: index) end)
    else
      socket
    end
  end

  # A paragraph's words with each footnote marker set small and gold,
  # linked to its note (its words in the link's title for a pointer to
  # read). Built as one run of markup: a template's line breaks between
  # the pieces would put a space before every marker.
  defp prose(pieces, note_text) do
    pieces
    |> Enum.map(fn
      {:text, words} ->
        Phoenix.HTML.html_escape(words)

      {:note, marker, number} ->
        title = Phoenix.HTML.html_escape(note_text[number] || "Note #{number}")

        [
          ~s(<sup class="sr-mark"><a href="#note-#{number}" title="),
          Phoenix.HTML.safe_to_string(title),
          ~s(" aria-label="Note #{number}">),
          Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(marker)),
          "</a></sup>"
        ]
        |> then(&{:safe, &1})
    end)
    |> Enum.map(&Phoenix.HTML.safe_to_string/1)
    |> Phoenix.HTML.raw()
  end

  attr :id, :string, required: true
  attr :book, :map, required: true
  attr :runs, :list, required: true
  attr :index, :integer, required: true

  # The whole book from inside a chapter, as the app's contents sheet: the
  # chapters under their parts, each its title with its heading beneath
  # where the edition prints a distinct one, this one marked Here. The
  # hook marks the chapters read.
  defp contents(assigns) do
    ~H"""
    <div class="td-contents" id={@id} phx-update="ignore">
      <div :for={run <- @runs}>
        <p :if={run.title} class="td-contents__part">{run.title}</p>
        <ul>
          <li :for={chapter <- run.chapters}>
            <.link
              navigate={Shelf.chapter_path(@book.id, chapter.id)}
              class="td-contents__link"
              data-chapter={chapter.id}
              aria-current={if(chapter.id == @index, do: "page")}
            >
              <span class="flex-1 min-w-0">
                <span class="block">{Shelf.display_title(chapter)}</span>
                <span :if={Shelf.distinct_title?(chapter)} class="sr-contents__heading">
                  {chapter.heading}
                </span>
              </span>
              <span :if={chapter.id == @index} class="td-contents__here">Here</span>
            </.link>
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
