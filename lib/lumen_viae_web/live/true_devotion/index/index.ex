defmodule LumenViaeWeb.Live.TrueDevotion.Index do
  @moduledoc """
  `/true-devotion`: St. Louis de Montfort's True Devotion, the book's own
  title page as the iOS app sets it (`TrueDevotionReaderView`): the
  binding over its halo, the one gold act (Begin Reading, the first
  chapter; or Continue Reading, the chapter left off, with a thread for
  how far into it), the contents (the Introduction, then each part folding
  open on its chapters, the part being read open), and the translator and
  the edition at the foot. From 1024px the binding and the act stand
  beside the contents.

  The page is drawn for someone who has not begun; the reader's place,
  the chapters read and the bookmarks are this browser's
  (`localStorage`), and the `TrueDevotionPlace` hook turns the act, lights
  the row and opens the part from them after the page loads. Nothing is
  sent to the server.

  The app's summary page (the teaching, the short prayers, his sayings) is
  archived on iOS and is not here; nor are the day's reading goal and the
  reader's notes, which the site does not keep.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.TrueDevotion.Book
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.TrueDevotion.Cover

  @impl true
  def mount(_params, _session, socket) do
    book = Book.load(socket.assigns.current_admin)
    {free, parts} = Book.contents(book)
    first = hd(book.chapters)

    {:ok,
     socket
     |> PageMeta.put(Book.path(),
       title: book.about.title,
       description:
         "#{book.about.title} by #{book.about.author}, the whole book to read chapter by chapter. #{book.about.translator}.",
       trail: [{"True Devotion", Book.path()}],
       json_ld: [book_data(book)]
     )
     |> assign(:book, book)
     |> assign(:free, free)
     |> assign(:parts, parts)
     |> assign(:first, first)}
  end

  attr :chapter, :map, required: true

  # A chapter in the contents: its title, then the place's dot or a caret.
  # The hook marks the row read (a gilt rule in the gutter), where you are
  # (the dot) and how many bookmarks it holds, as the app's ledger does.
  defp chapter_row(assigns) do
    ~H"""
    <.link
      navigate={Book.chapter_path(@chapter.id)}
      class="td-row"
      data-chapter={@chapter.id}
      data-title={@chapter.title}
      data-paragraphs={Book.paragraph_count(@chapter)}
      data-role="chapter-row"
    >
      <span class="td-row__title">{@chapter.title}</span>
      <span class="td-row__marks" data-role="row-marks" hidden>
        <span class="td-ribbon" aria-hidden="true"></span><span data-role="row-marks-count"></span>
      </span>
      <span class="td-row__here" aria-hidden="true"></span>
      <span class="hero-chevron-right size-3.5 row-chevron td-row__caret" aria-hidden="true" />
    </.link>
    """
  end

  @doc false
  def book_data(book) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Book",
      "name" => book.about.title,
      "author" => %{"@type" => "Person", "name" => book.about.author},
      "translator" => %{
        "@type" => "Person",
        "name" =>
          book.about.translator
          |> String.replace_prefix("Translated by ", "")
          |> String.split(",")
          |> hd()
      },
      "inLanguage" => "en",
      "isAccessibleForFree" => true,
      "url" => PageMeta.absolute_url(Book.path())
    }
  end
end
