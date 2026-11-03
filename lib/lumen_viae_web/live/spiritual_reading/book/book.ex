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
  text from Project Gutenberg" and, once the page connects, waits
  (`start_async`) on the download the server runs in a process of its own,
  so leaving the page never aborts it; a book that cannot be reached says so with Try again,
  and an edition that no longer cuts into chapters says so without one,
  as the app does. The place is this browser's (`SpiritualReadingPlace`).
  An unknown book is a 404.

  Where the book has a LibriVox recording, each row a track opens on wears
  its listen chip (the app's `LibraryChapterRow.listenChip`): the track's
  length, which starts the voice and opens the chapter, Pause while it
  sounds, and "31:05 in" where this browser left the voice mid-reading.
  The track list is fetched by the server once the text is held
  (`Shelf.recording/3`); one that cannot be had says "The recording
  couldn't be reached." with Try again, as the app does. The recording
  plays in the browser (`Player`, the `BookPlayer` hook), and the credit
  names LibriVox's volunteers.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.SpiritualReading.Index
  alias LumenViaeWeb.Live.SpiritualReading.Shelf
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.SpiritualReading.Cover
  import LumenViaeWeb.Live.SpiritualReading.Player
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
     |> assign(failure: nil, recording: nil, recording_failed?: false)
     |> assign_text(Shelf.read(socket.assigns.current_admin, book.id, cached_only: true))}
  end

  @impl true
  # Only a failed page tries again: a client sending retry while the text
  # is on the way (or there) asks Gutenberg for nothing more.
  def handle_event("retry", _params, %{assigns: %{state: :failed}} = socket),
    do: {:noreply, fetch(socket)}

  def handle_event("retry", _params, socket), do: {:noreply, socket}

  # Likewise for the recording: only once its track list failed.
  def handle_event("retry_recording", _params, %{assigns: %{recording_failed?: true}} = socket),
    do: {:noreply, socket |> assign(:recording_failed?, false) |> fetch_recording()}

  def handle_event("retry_recording", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_async(:text, {:ok, text}, socket), do: {:noreply, assign_text(socket, text)}

  def handle_async(:text, {:exit, _reason}, socket),
    do: {:noreply, assign(socket, state: :failed, failure: :unreachable)}

  def handle_async(:recording, {:ok, %{status: :ok} = recording}, socket),
    do: {:noreply, assign(socket, :recording, recording)}

  def handle_async(:recording, _failed, socket),
    do: {:noreply, assign(socket, :recording_failed?, true)}

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
    |> load_recording()
  end

  defp assign_text(socket, %{status: :cold}), do: fetch(socket)

  defp assign_text(socket, %{status: reason}),
    do: assign(socket, state: :failed, failure: reason)

  # The track list, once the text is held: from this machine at once, or
  # fetched after the page connects.
  defp load_recording(%{assigns: %{book: %{librivox_id: nil}}} = socket), do: socket
  defp load_recording(%{assigns: %{recording: %{status: :ok}}} = socket), do: socket

  defp load_recording(socket) do
    %{book: book, current_admin: actor} = socket.assigns

    case Shelf.recording(actor, book.id, cached_only: true) do
      %{status: :ok} = recording -> assign(socket, :recording, recording)
      %{status: :cold} -> fetch_recording(socket)
      _unavailable -> assign(socket, :recording_failed?, true)
    end
  end

  defp fetch_recording(socket) do
    if connected?(socket) do
      %{book: book, current_admin: actor} = socket.assigns
      start_async(socket, :recording, fn -> Shelf.recording(actor, book.id) end)
    else
      socket
    end
  end

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

  attr :book, :map, required: true

  # The app's credit: the text's (linked to Gutenberg's page for the
  # book), the recording's where it has one, and the public domain.
  defp credit(assigns) do
    ~H"""
    <a href={Shelf.gutenberg_url(@book)} class="sr-credit__link">{Shelf.credit(@book)}</a>
    <span :if={Shelf.recording_credit(@book)} data-role="recording-credit">
      {Shelf.recording_credit(@book)}
    </span>
    Public domain.
    """
  end

  attr :chapter, :map, required: true
  attr :book, :map, required: true
  attr :recording, :map, default: nil

  # The listen chip where a track opens on this chapter
  # (`LibraryChapterRow.listenChip`): the track's length, which starts the
  # voice and opens the chapter. The hook fills "31:05 in" where the voice
  # was left mid-reading, and marks the chip sounding.
  defp listen_chip(assigns) do
    assigns = assign(assigns, :track, Shelf.opening(assigns.recording, assigns.chapter.id))

    ~H"""
    <span :if={@track} class="sr-listen-wrap">
      <span class="sr-listen__resting" data-role="resting" data-track={@track.index} hidden></span>
      <button
        type="button"
        class="sr-listen"
        data-act="listen"
        data-track={@track.index}
        data-chapter={@chapter.id}
        data-label={"Hear #{Shelf.display_title(@chapter)} read"}
        data-pause-label={"Pause the reading of #{Shelf.display_title(@chapter)}"}
        aria-label={"Hear #{Shelf.display_title(@chapter)} read"}
      >
        <span class="hero-play-solid size-3" data-icon="play" aria-hidden="true" />
        <span class="hero-pause-solid size-3" data-icon="pause" aria-hidden="true" hidden />
        <span :if={@track.seconds}>{Shelf.chip_minutes(@track.seconds)}</span>
      </button>
    </span>
    """
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
