defmodule LumenViaeWeb.Live.Prayers.Prayer do
  @moduledoc """
  `/prayers/:prayer_id`: one prayer of the Prayer Book, as the app's
  prayer page sets it. Its chapter above it, its title and its Latin or
  English name, where it comes from, the language chooser (only for a
  prayer with Latin), the words in the book's grammar
  (`LumenViaeWeb.Live.Prayers.PrayerText`), when it is said, and the
  prayers either side of it in its chapter. An id the book does not have
  is a 404.

  The language rides in the link as `?lang=latin` or `?lang=both`;
  English, the default, is never written. In Both the Latin leads and the
  English pairs with it line by line: two columns on a wide screen, the
  English beneath each Latin line on a phone.
  """
  use LumenViaeWeb, :live_view

  alias LumenViaeWeb.Live.Prayers.{Book, PrayerText}
  alias LumenViaeWeb.PageMeta

  import LumenViaeWeb.Live.Prayers.Prayer.Text

  @language_labels [{"english", "English"}, {"latin", "Latin"}, {"both", "Both"}]

  @impl true
  def mount(%{"prayer_id" => id}, _session, socket) do
    book = Book.load(socket.assigns.current_admin)

    prayer =
      Book.prayer(book, id) ||
        raise LumenViaeWeb.NotFoundError, message: "unknown prayer: #{id}"

    chapter = Book.home_chapter(book, id)

    {previous, next} =
      if chapter,
        do: Book.neighbours(Book.prayers(book, chapter.prayer_ids), prayer),
        else: {nil, nil}

    {:ok,
     socket
     |> PageMeta.put(Book.prayer_path(id),
       title: prayer.title,
       description: description(prayer),
       trail: trail(prayer, chapter)
     )
     |> assign(:prayer, prayer)
     |> assign(:chapter, chapter)
     |> assign(:previous, previous)
     |> assign(:next, next)
     |> assign(:languages, @language_labels)}
  end

  @impl true
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
