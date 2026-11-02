defmodule LumenViaeWeb.Live.Prayers.Chapter do
  @moduledoc """
  `/prayers/topics/:chapter_id`: one chapter of the Prayer Book, as the
  app's chapter page heads it (its numeral, title, Latin title and note),
  with its prayers under its own sub-headings and the chapters either side
  at its foot. An id the book does not have is a 404.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.PageMeta

  @impl true
  def mount(%{"chapter_id" => id}, _session, socket) do
    book = Book.load(socket.assigns.current_admin)

    chapter =
      Book.chapter(book, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown prayer book chapter: #{id}"

    seasonal = Book.antiphon(book, Date.utc_today())
    {previous, next} = Book.neighbours(book.chapters, chapter)

    {:ok,
     socket
     |> PageMeta.put(Book.chapter_path(id),
       title: chapter.topic,
       description: description(book, chapter),
       trail: [{"Prayers", "/prayers"}, {chapter.title, Book.chapter_path(id)}]
     )
     |> assign(:chapter, chapter)
     |> assign(:sections, sections(book, chapter))
     |> assign(
       :seasonal_id,
       chapter.id == Book.our_lady_chapter_id() && seasonal && seasonal.prayer_id
     )
     |> assign(:previous, previous)
     |> assign(:next, next)}
  end

  defp sections(book, chapter) do
    for section <- chapter.sections do
      %{title: section.title, prayers: Book.prayers(book, section.prayer_ids)}
    end
  end

  defp description(book, chapter) do
    names =
      book
      |> Book.prayers(chapter.prayer_ids)
      |> Enum.take(4)
      |> Enum.map_join(", ", &Book.list_name/1)

    "#{chapter.title} (#{chapter.latin_title}): #{Book.count_label(length(chapter.prayer_ids))} in English and Latin, among them #{names}."
  end
end
