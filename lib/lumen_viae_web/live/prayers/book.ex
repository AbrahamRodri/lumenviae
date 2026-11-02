defmodule LumenViaeWeb.Live.Prayers.Book do
  @moduledoc """
  The Prayer Book as the Prayers pages read it, as the iOS app's
  `PrayerBook` (and the Android app's `PrayerBookIndex`) reads it: prayers
  by id, the chapter a prayer belongs to, the search, the lists the
  Prayers page opens on and the painting each card shows.

  Presentation only. The words are the domain's
  (`LumenViae.Rosary.get_prayer_book!/1`); how the apps arrange them, which
  prayers open the page and which paintings hang beside them, is the
  apps', and this is the website's copy of it. It never queries beyond
  `load/1`.
  """

  alias LumenViae.LiturgicalCalendar
  alias LumenViae.Rosary

  defstruct chapters: [], prayers: %{}, antiphons: []

  @type t :: %__MODULE__{chapters: [map()], prayers: %{String.t() => map()}, antiphons: [map()]}

  # The first prayers, a row each under Everyday Prayers.
  @everyday_ids ~w(our_father hail_mary glory_be apostles_creed)

  # Her best-known prayers, on the shelf after the season's song to Mary.
  @best_known_marian_ids ~w(hail_mary memorare litany_loreto)

  # A line under a prayer to Mary on the shelf where the book gives none.
  @marian_notes %{"litany_loreto" => "Holy Mary, pray for us"}

  # The line under a topic on All Topics (PrayerBook.chapterNotes).
  @chapter_notes %{
    "sacrament" => "Jesus present in the Host",
    "litanies" => "Short petitions, each with the same response"
  }

  @first_chapter "first"
  @our_lady_chapter "our_lady"

  @search_stop ~w(a an and of the to o for in on at)
  @topic_stop ~w(a an and at for in of on the to with pray prayer prayers)

  @doc "The whole book, read through the domain as `actor`."
  def load(actor) do
    Rosary.get_prayer_book!(actor: actor, load: [:chapters, :prayers, :marian_antiphons])
    |> new()
  end

  @doc "The index over a book the domain served."
  def new(%{chapters: chapters, prayers: prayers, marian_antiphons: antiphons}) do
    %__MODULE__{
      chapters: chapters,
      prayers: Map.new(prayers, &{&1.id, &1}),
      antiphons: antiphons
    }
  end

  def everyday_ids, do: @everyday_ids
  def first_chapter_id, do: @first_chapter
  def our_lady_chapter_id, do: @our_lady_chapter

  @doc "A prayer's page."
  def prayer_path(id), do: "/prayers/#{id}"

  @doc "A chapter's page."
  def chapter_path(id), do: "/prayers/topics/#{id}"

  @doc "\"1 prayer\", \"5 prayers\"."
  def count_label(1), do: "1 prayer"
  def count_label(n), do: "#{n} prayers"

  @doc "How many prayers the book prints."
  def prayer_count(%__MODULE__{prayers: prayers}), do: map_size(prayers)

  def prayer(%__MODULE__{prayers: prayers}, id), do: Map.get(prayers, id)

  def chapter(%__MODULE__{chapters: chapters}, id), do: Enum.find(chapters, &(&1.id == id))

  @doc "The prayers with these ids, in order; an id the book does not carry is skipped."
  def prayers(%__MODULE__{prayers: prayers}, ids),
    do: ids |> Enum.map(&prayers[&1]) |> Enum.reject(&is_nil/1)

  @doc "The first chapter that lists the prayer: the one its page belongs to."
  def home_chapter(%__MODULE__{chapters: chapters}, prayer_id),
    do: Enum.find(chapters, &(prayer_id in &1.prayer_ids))

  @doc "The chapters either side of this one, each nil at an end."
  def neighbours(list, item) do
    case Enum.find_index(list, &(&1 == item)) do
      nil -> {nil, nil}
      0 -> {nil, Enum.at(list, 1)}
      i -> {Enum.at(list, i - 1), Enum.at(list, i + 1)}
    end
  end

  @doc "The line under a topic on All Topics, where the app gives one."
  def chapter_note(%{id: id}), do: @chapter_notes[id]

  @doc "The prayer's name in a list, as most people say it (\"Hail Mary\")."
  def list_name(%{list_title: list_title, title: title}), do: list_title || title

  @doc """
  The line set small beneath its name: its English for a prayer known by
  its Latin name ("Memorare"), else its Latin, never the name said twice.
  """
  def second_title(%{english_name: english}) when is_binary(english), do: english
  def second_title(%{latin_title: nil}), do: nil

  def second_title(%{latin_title: latin, title: title}) do
    if same_name?(latin, title), do: nil, else: latin
  end

  ## The season's song to Mary

  @doc "The song to Mary the Church sings on `date`, from the book's `marian_antiphons`."
  def antiphon(%__MODULE__{antiphons: antiphons}, %Date{} = date) do
    begins = date |> LiturgicalCalendar.marian_antiphon_season() |> Atom.to_string()
    Enum.find(antiphons, &(&1.begins == begins))
  end

  @doc """
  The Prayers to Mary shelf: the season's song first, then her best-known
  prayers, leaving out the song and any already under Everyday Prayers.
  Each `%{prayer:, note:, painting:, seasonal?:}`.
  """
  def marian_shelf(%__MODULE__{} = book, %Date{} = date) do
    antiphon = antiphon(book, date)
    seasonal_id = antiphon && antiphon.prayer_id
    our_lady = chapter(book, @our_lady_chapter)

    seasonal =
      case seasonal_id && prayer(book, seasonal_id) do
        nil ->
          []

        prayer ->
          [
            %{
              prayer: prayer,
              note: "This season's song to Mary",
              painting: antiphon_painting(antiphon.begins),
              seasonal?: true
            }
          ]
      end

    known =
      for id <- @best_known_marian_ids,
          id != seasonal_id,
          id not in @everyday_ids,
          prayer = prayer(book, id) do
        %{
          prayer: prayer,
          note: prayer.english_name || @marian_notes[id] || (our_lady && our_lady.title),
          painting: prayer_painting(id),
          seasonal?: false
        }
      end

    seasonal ++ known
  end

  ## Paintings (PrayerBookPaintings.swift)

  # The iOS asset each card wants, with the stand-in this site has: the
  # Holy Trinity and Our Lady of the Rosary are not among the paintings in
  # priv/static/images/paintings, so they hang what the Android app hangs.
  @doc "A prayer's painting on the Prayers page: `{painting name, focal y}`."
  def prayer_painting("our_father"), do: {"luminous_proclamation", 0.3}
  def prayer_painting("hail_mary"), do: {"joyful_annunciation", 0.18}
  # iOS: devotion_holy_trinity; the Baptism shows the Trinity.
  def prayer_painting("glory_be"), do: {"luminous_baptism", 0.3}
  def prayer_painting("apostles_creed"), do: {"glorious_pentecost", 0.3}
  def prayer_painting("memorare"), do: {"glorious_assumption", 0.3}
  # iOS: feast_our_lady_of_the_rosary.
  def prayer_painting("litany_loreto"), do: {"glorious_coronation", 0.2}
  def prayer_painting(_id), do: {"glorious_coronation", 0.2}

  @doc "The painting over a season's song to Mary, by the day its season begins."
  def antiphon_painting("advent_eve"), do: {"joyful_nativity", 0.35}
  def antiphon_painting("easter"), do: {"glorious_resurrection", 0.2}
  def antiphon_painting(_begins), do: {"glorious_coronation", 0.12}

  ## Search (PrayerBook.search, PrayerBook.topics(matching:))

  @doc """
  Prayers a search finds. A name answers when every word searched begins
  one of its words ("St Joseph", "loreto", "hail ma"): the title, the list
  title, the Latin title and the names it is looked for by, with "st" and
  "saint" one word. Prayers whose English or Latin holds the whole search
  (four letters or more) come after the names. Each prayer once, in book
  order.
  """
  def search(%__MODULE__{} = book, needle) do
    wanted = search_words(needle, false)

    if wanted == [] do
      []
    else
      phrase = needle |> fold() |> String.trim()

      {named, worded, _seen} =
        for chapter <- book.chapters,
            prayer <- prayers(book, chapter.prayer_ids),
            reduce: {[], [], MapSet.new()} do
          {named, worded, seen} = acc ->
            cond do
              MapSet.member?(seen, prayer.id) ->
                acc

              Enum.any?(names(prayer), &name_answers?(wanted, &1)) ->
                {[prayer | named], worded, MapSet.put(seen, prayer.id)}

              String.length(phrase) >= 4 and words_hold?(prayer, phrase) ->
                {named, [prayer | worded], MapSet.put(seen, prayer.id)}

              true ->
                acc
            end
        end

      Enum.reverse(named) ++ Enum.reverse(worded)
    end
  end

  @doc """
  The chapters a search names as topics: "mary" finds the Blessed
  Virgin's. Every word searched must begin a word of the chapter's title,
  topic, Latin title or search words; "prayer" and the small words count
  for nothing, or every topic would answer "pra".
  """
  def topics(%__MODULE__{chapters: chapters}, needle) do
    wanted = topic_words(needle)

    cond do
      wanted == [] -> []
      String.length(Enum.join(wanted)) < 3 -> []
      String.length(List.last(wanted)) < 2 -> []
      true -> Enum.filter(chapters, &topic_answers?(&1, wanted))
    end
  end

  defp topic_answers?(chapter, wanted) do
    [chapter.title, chapter.topic, chapter.latin_title | chapter.search_words]
    |> Enum.reject(&is_nil/1)
    |> Enum.any?(fn name ->
      words = topic_words(name)

      words != [] and
        Enum.all?(wanted, fn want -> Enum.any?(words, &String.starts_with?(&1, want)) end)
    end)
  end

  defp names(prayer) do
    Enum.reject([prayer.title, prayer.list_title, prayer.latin_title], &is_nil/1) ++
      prayer.search_words
  end

  defp words_hold?(prayer, phrase) do
    String.contains?(fold(prayer.english), phrase) or
      String.contains?(fold(prayer.latin || ""), phrase)
  end

  defp name_answers?(wanted, name) do
    words = search_words(name, true)

    words != [] and
      Enum.all?(wanted, fn want ->
        Enum.any?(words, &(String.starts_with?(&1, want) or (want == "st" and &1 == "saint")))
      end)
  end

  # In a name, "st" reads as "saint"; searched, it stays as typed. Small
  # words go unless they are all there is.
  defp search_words(text, as_name?) do
    all = text |> words() |> Enum.map(&if(as_name? and &1 == "st", do: "saint", else: &1))

    case Enum.reject(all, &(&1 in @search_stop)) do
      [] -> all
      kept -> kept
    end
  end

  defp topic_words(text), do: text |> words() |> Enum.reject(&(&1 in @topic_stop))

  defp words(text), do: text |> fold() |> String.split(~r/[^\p{L}]+/u, trim: true)

  @doc """
  Text as the searches read it: case and accents let go, and the
  ligatures the Latin is printed with written out, so "regina caeli" finds
  the Regina Cæli, and the older "coel" read as "cael", so "coeli" finds it
  too (SearchText.fold).
  """
  def fold(text) do
    text
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{M}+/u, "")
    |> String.downcase()
    |> String.replace("æ", "ae")
    |> String.replace("œ", "oe")
    |> String.replace("coel", "cael")
  end

  @doc "Whether two names are one, whatever their case, accents or leading article."
  def same_name?(one, other), do: bare(one) == bare(other)

  defp bare(name) do
    case fold(name) do
      "the " <> rest -> rest
      folded -> folded
    end
  end
end
