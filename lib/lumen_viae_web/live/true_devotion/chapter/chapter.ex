defmodule LumenViaeWeb.Live.TrueDevotion.Chapter do
  @moduledoc """
  `/true-devotion/:chapter_id`: one chapter of True Devotion read in
  place, as the iOS app's chapter reader sets it
  (`TrueDevotionChapterReaderView`): the hairline that says where the
  chapter stands in the book, the part over the title and "3 of 13", the
  ornament, the text on night at the reading size with the app's versal
  on a long opening paragraph and its sub-headings in gold, and at the
  foot the chapters either side, or The End after the last.

  Each text paragraph carries its number in the chapter in the margin
  (`LumenViaeWeb.Live.TrueDevotion.Book.blocks/1`) and its anchor,
  `#p-3`. The number, or a tap on the paragraph, chooses it, and the
  bar that rises offers Bookmark and Share (the Web Share API where the
  browser has one, else the link copied), as the app's passage bar does.
  The contents are a rail beside the text from 1024px and a list that
  opens above it on a phone, with the reader's bookmarks at their head.

  The place, the chapters read and the bookmarks are this browser's
  (`localStorage`, the `TrueDevotionPlace` hook): the paragraph at the
  top of the screen is kept as the place once the reader scrolls, and
  reaching the foot or stepping on marks the chapter read. Nothing is
  sent to the server. An unknown chapter is a 404.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.TrueDevotion.Book
  alias LumenViaeWeb.Live.TrueDevotion.Index
  alias LumenViaeWeb.PageMeta

  @impl true
  def mount(%{"chapter_id" => id}, _session, socket) do
    book = Book.load(socket.assigns.current_admin)

    chapter =
      Book.chapter(book, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown True Devotion chapter: #{inspect(id)}"

    {previous, next} = Book.neighbours(book, chapter)
    {free, parts} = Book.contents(book)
    index = Book.index(book, chapter)

    {:ok,
     socket
     |> PageMeta.put(Book.chapter_path(chapter.id),
       title: "#{chapter.title}, True Devotion",
       description: Book.description(book, chapter),
       trail: [{"True Devotion", Book.path()}, {chapter.title, Book.chapter_path(chapter.id)}],
       json_ld: [chapter_data(book, chapter)]
     )
     |> assign(:book, book)
     |> assign(:chapter, chapter)
     |> assign(:blocks, Book.blocks(chapter))
     |> assign(:kicker, Book.kicker(book, chapter))
     |> assign(:index, index)
     |> assign(:count, length(book.chapters))
     |> assign(:free, free)
     |> assign(:parts, parts)
     |> assign(:previous, previous)
     |> assign(:next, next)
     |> assign(:citation, Book.citation(book, chapter))}
  end

  defp chapter_data(book, chapter) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Chapter",
      "name" => chapter.title,
      "url" => PageMeta.absolute_url(Book.chapter_path(chapter.id)),
      "isPartOf" => Index.book_data(book)
    }
  end

  attr :id, :string, required: true
  attr :book, :map, required: true
  attr :chapter, :map, required: true
  attr :free, :list, required: true
  attr :parts, :list, required: true

  # The whole book from inside a chapter, as the app's contents sheet: the
  # reader's bookmarks at its head (drawn by the hook from this browser's
  # storage), then the chapters under their parts, this one marked Here.
  defp contents(assigns) do
    ~H"""
    <div class="td-contents">
      <div
        id={"#{@id}-marks"}
        class="td-marks"
        data-role="marks"
        phx-update="ignore"
        hidden
      >
      </div>
      <ul id={"#{@id}-free"} phx-update="ignore">
        <li :for={chapter <- @free}>
          <.contents_row chapter={chapter} current={@chapter} />
        </li>
      </ul>
      <div :for={%{part: part, chapters: chapters} <- @parts}>
        <p class="td-contents__part">{part.title}</p>
        <ul id={"#{@id}-part-#{part.number}"} phx-update="ignore">
          <li :for={chapter <- chapters}>
            <.contents_row chapter={chapter} current={@chapter} />
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :chapter, :map, required: true
  attr :current, :map, required: true

  defp contents_row(assigns) do
    ~H"""
    <.link
      navigate={Book.chapter_path(@chapter.id)}
      class="td-contents__link"
      data-chapter={@chapter.id}
      aria-current={if(@chapter.id == @current.id, do: "page")}
    >
      <span class="flex-1 min-w-0">{@chapter.title}</span>
      <span :if={@chapter.id == @current.id} class="td-contents__here">Here</span>
    </.link>
    """
  end
end
