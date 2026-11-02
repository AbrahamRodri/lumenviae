defmodule LumenViaeWeb.Live.Prayers.Chapter do
  @moduledoc """
  `/prayers/topics/:chapter_id`: one topic of the Prayer Book, as the
  app's topic page draws it (`PrayerBookChapterView`): its painting at the
  head with the title and the topic's line over its foot, then its
  prayers, a row each with a small arched painting and the prayer's
  title, under the book's sub-headings only where it has more than one.
  At the foot the next topic as a painted card and a quiet line back to
  the one before. An id the book does not have is a 404.

  Our Lady's song for the season is marked on her topic; "today" is the
  visitor's once the `UserTimezone` hook has sent the offset.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Painting

  @impl true
  def mount(%{"chapter_id" => id}, _session, socket) do
    book = Book.load(socket.assigns.current_admin)

    chapter =
      Book.chapter(book, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown prayer book chapter: #{id}"

    {previous, next} = Book.neighbours(book.chapters, chapter)

    {:ok,
     socket
     |> PageMeta.put(Book.chapter_path(id),
       title: chapter.topic,
       description: description(book, chapter),
       trail: [{"Prayers", "/prayers"}, {chapter.title, Book.chapter_path(id)}]
     )
     |> assign(:book, book)
     |> assign(:chapter, chapter)
     |> assign(:painting, Book.topic_painting(chapter.id))
     |> assign(:sections, sections(book, chapter))
     |> assign(:headed?, length(chapter.sections) > 1)
     |> assign(:previous, previous)
     |> assign(:next, next)
     |> assign_today(Date.utc_today())}
  end

  @impl true
  def handle_event("set_timezone", %{"offset" => offset}, socket) do
    case Book.local_date(offset) do
      {:ok, date} -> {:noreply, assign_today(socket, date)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_timezone", _params, socket), do: {:noreply, socket}

  defp assign_today(socket, today) do
    %{book: book, chapter: chapter} = socket.assigns
    seasonal = chapter.id == Book.our_lady_chapter_id() && Book.antiphon(book, today)
    assign(socket, :seasonal_id, seasonal && seasonal.prayer_id)
  end

  defp sections(book, chapter) do
    for section <- chapter.sections do
      %{
        title: section.title,
        rows:
          for prayer <- Book.prayers(book, section.prayer_ids) do
            %{prayer: prayer, painting: Book.prayer_painting(book, prayer.id)}
          end
      }
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
