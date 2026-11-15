defmodule LumenViaeWeb.Live.Prayers.Prayer do
  @moduledoc """
  `/prayers/:prayer_id`: one prayer of the Prayer Book, as the app opens
  a prayer alone (`PrayAlongView`'s head): its second name as a small
  gold label over the title where the app shows one
  (`Book.second_title/1`), the title, the language (the app's ··· menu
  choice, made visible here as a chooser, only for a prayer with Latin),
  and the words in the book's grammar
  (`LumenViaeWeb.Live.Prayers.PrayerText`). A quiet link above leads back
  to the prayer's topic. Opened alone, the app does not step to other
  prayers, so neither does this page. An id the book does not have is a
  404.

  The language rides in the link as `?lang=latin` or `?lang=both`;
  English, the default, is never written. In Both the English leads and
  the Latin pairs with it line by line, as the app's Prayer Book sets it
  (English with Latin, the Latin in quiet italic): two columns on a wide
  screen, the Latin beneath each English line, stepped in, on a phone.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Prayers.{Book, Novena, PrayerText}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Prayer.Text
  import LumenViaeWeb.Live.Prayers.Prayer.Novena

  @language_labels [{"english", "English"}, {"latin", "Latin"}, {"both", "Both"}]

  @impl true
  def mount(%{"prayer_id" => id}, _session, socket) do
    book = Book.load(socket.assigns.current_admin, novenas: true)

    prayer =
      Book.prayer(book, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown prayer: #{id}"

    chapter = Book.home_chapter(book, id)

    {:ok,
     socket
     |> PageMeta.put(Book.prayer_path(id),
       title: prayer.title,
       description: description(prayer),
       trail: trail(prayer, chapter)
     )
     |> assign(:book, book)
     |> assign(:novena, Book.novena(book, id))
     |> assign(:prayer, prayer)
     |> assign(:origin_lines, Book.origin_lines(prayer))
     |> assign(:chapter, chapter)
     |> assign(:languages, @language_labels)}
  end

  @impl true
  def handle_params(params, _uri, %{assigns: %{novena: %{} = novena}} = socket) do
    day = Novena.day_number(novena, params["day"])

    {:noreply,
     socket
     |> assign(:language, "english")
     |> assign(:day, day)
     |> assign(:blocks, Novena.blocks(Novena.day(novena, day), socket.assigns.book))}
  end

  def handle_params(params, _uri, socket) do
    prayer = socket.assigns.prayer

    language =
      if prayer.latin, do: PrayerText.language(params["lang"]), else: "english"

    {:noreply,
     socket
     |> assign(:language, language)
     |> assign(:stanzas, PrayerText.stanzas(prayer.english, prayer.latin, language))}
  end

  @doc false
  def language_path(prayer_id, "english"), do: Book.prayer_path(prayer_id)
  def language_path(prayer_id, language), do: Book.prayer_path(prayer_id) <> "?lang=" <> language

  defp trail(prayer, nil),
    do: [{"Prayers", "/prayers"}, {prayer.title, Book.prayer_path(prayer.id)}]

  defp trail(prayer, chapter) do
    [
      {"Prayers", "/prayers"},
      {chapter.title, Book.chapter_path(chapter.id)},
      {prayer.title, Book.prayer_path(prayer.id)}
    ]
  end

  # The opening words, without the book's marks.
  defp description(prayer) do
    words =
      prayer.english
      |> String.split("\n", trim: true)
      |> Enum.reject(&PrayerText.rubric?/1)
      |> Enum.join(" ")
      |> String.replace(~r/[℣℟✠]\.?\s*/u, "")
      |> String.replace(" * ", " ")

    "#{prayer.title}: #{words}"
  end
end
