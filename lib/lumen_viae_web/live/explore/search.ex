defmodule LumenViaeWeb.Live.Explore.Search do
  @moduledoc """
  The one search, as the iOS app's `AppSearch` runs it from Explore
  (`AppSearch.swift`; Android's `domain/AppSearch.kt`): the mysteries, the
  site's doors found by name (Pages), the Prayer Book's topics, orders of
  prayer and prayers, the chants and the meditation sets, gathered, put in
  Explore's order and the best match picked.

  The finding is each area's own, as the app's is: the Prayers page's
  (`LumenViaeWeb.Live.Prayers.Book.search/2` and `topics/2`,
  `LumenViaeWeb.Live.Prayers.Orders.search/3`) and the Chant Library's
  (`LumenViaeWeb.Live.Chants.Library.search/3`). This module only finds
  the mysteries, the doors and the sets itself, orders the sections and
  picks the best. Every word is folded as the app folds it (case, accents
  and the Latin ligatures aside, `Book.fold/1`), so "salve" finds the
  Salve Regina and "pater" the Pater Noster.

  Presentation only: it is handed what the page loaded and never queries.
  The app's Readings kind is not here, as its shelves are How to Pray's,
  which the website does not have.
  """

  alias LumenViae.LiturgicalCalendar
  alias LumenViae.Rosary.{Categories, Labels}
  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Prayers.{Book, Orders}

  defstruct best: nil, sections: [], date: nil

  @typedoc """
  One thing found: `{:mysteries, slug}` (a devotion), `{:mystery, mystery}`,
  `{:page, page}`, `{:topic, chapter}`, `{:order, order}`,
  `{:prayer, prayer}`, `{:chant, chant}` or `{:set, set}`.
  """
  @type hit :: {atom(), term()}

  @type t :: %__MODULE__{
          best: hit() | nil,
          sections: [%{kind: atom(), hits: [hit()]}],
          date: Date.t() | nil
        }

  # The kinds in Explore's order, the order the sections take
  # (AppSearch.Kind.allCases), the app's Readings left out.
  @kinds [:mysteries, :pages, :prayers, :chants, :meditations]

  @titles %{
    mysteries: "Rosary Mysteries",
    pages: "Pages",
    prayers: "Prayers",
    chants: "Chants",
    meditations: "Meditations"
  }

  # The site's doors the search knows by name and words, as Explore's
  # library entries (ExploreView.allLibraryEntries): those the website has,
  # in the app's order. `:today` opens the day's mysteries' page, where the
  # Rosary's ways to pray stand. The Consecration is iOS's tab and no entry
  # of its search; it is found here as Android's search finds it
  # (AppSearch.kt's PAGES), by its name and its words.
  @pages [
    %{
      id: "consecration",
      title: "Consecration to Mary",
      words: "33 days total consecration de montfort",
      icon: "hero-sparkles",
      path: "/consecration"
    },
    %{
      id: "office",
      title: "Hours of Prayer",
      words:
        "divine office breviary hours of prayer matins lauds prime terce sext none vespers compline",
      icon: "hero-clock",
      path: "/hours"
    },
    %{
      id: "trueDevotion",
      title: "True Devotion",
      words: "true devotion to mary montfort book",
      icon: "hero-bookmark",
      path: "/true-devotion"
    },
    %{
      id: "scripturalRosary",
      title: "The Scriptural Rosary",
      words: "scriptural rosary verse every bead gospel douay rheims bible",
      icon: "hero-book-open",
      path: :today
    },
    %{
      id: "rosaryAloud",
      title: "The Audio Rosary",
      words:
        "audio rosary holy rosary aloud said spoken listen voice hear prayers learn by ear no meditation",
      icon: "hero-speaker-wave",
      path: :today
    },
    %{
      id: "scripture",
      title: "In Scripture",
      words: "mysteries in scripture bible verses",
      icon: "hero-bookmark-square",
      path: "/mysteries"
    },
    %{
      id: "prayerBook",
      title: "Prayers",
      words:
        "prayer book prayers enchiridion morning night angelus grace confession examination conscience mass communion litany litanies marian our lady latin novena",
      icon: "hero-hand-raised",
      path: "/prayers"
    },
    %{
      id: "chantLibrary",
      title: "The Chant Library",
      words:
        "chant chants gregorian sung song songs hymn hymns latin score scores sheet music antiphon sing",
      icon: "hero-musical-note",
      path: "/chant"
    }
  ]

  @doc "The kinds, in the order their sections stand."
  def kinds, do: @kinds

  @doc "A section's heading (AppSearch.Kind.title)."
  def title(kind), do: Map.fetch!(@titles, kind)

  @doc "A chip's word, where the heading is too long for one (AppSearch.Kind.chipTitle)."
  def chip_title(:mysteries), do: "Mysteries"
  def chip_title(kind), do: title(kind)

  @doc """
  The site's doors as the search knows them, each with the path it opens
  on `date`: the Scriptural Rosary and the Audio Rosary open the day's
  mysteries on the traditional schedule.
  """
  def pages(%Date{} = date) do
    today = "/mysteries/#{LiturgicalCalendar.recommended_mysteries(date, :traditional)}"
    Enum.map(@pages, fn page -> if page.path == :today, do: %{page | path: today}, else: page end)
  end

  @doc "The words searched for, as the app reads them: folded and trimmed (SearchText.needle)."
  def needle(query) when is_binary(query), do: query |> Book.fold() |> String.trim()

  @doc """
  Everything the words find. `sources` holds what the page loaded:
  `:book` (`Book`), `:library` (`Library`), `:prayer_names`
  (`Library.prayer_names/1`), `:mysteries` (the domain's), `:sets` (the
  visible sets' summaries) and `:pages` (`pages/1`). `date` is the day
  whose names the orders go by (Queen of Heaven in Eastertide).
  """
  def results(query, sources, %Date{} = date) do
    needle = needle(query)

    if needle == "" do
      %__MODULE__{date: date}
    else
      %{book: book, library: library} = sources

      found = %{
        mysteries: mystery_hits(needle, Map.get(sources, :mysteries, [])),
        pages: page_hits(needle, Map.get(sources, :pages, [])),
        # A topic the words name, then an order of prayer, then the
        # prayers, as the Prayers page sets its own search
        prayers:
          Enum.map(Enum.take(Book.topics(book, query), 2), &{:topic, &1}) ++
            Enum.map(Enum.take(Orders.search(book, query, date), 3), &{:order, &1}) ++
            Enum.map(Book.search(book, query), &{:prayer, &1}),
        chants:
          Enum.map(
            Library.search(library, query, Map.get(sources, :prayer_names, %{})),
            &{:chant, &1}
          ),
        meditations:
          for(set <- Map.get(sources, :sets, []), set_matches?(set, needle), do: {:set, set})
      }

      shape(found, needle, date)
    end
  end

  @doc """
  Orders what was found: picks the best, and leaves it out of its own
  section. Split from the finding so it can be tested with hits of one's
  own (AppSearch.shape).
  """
  def shape(found, needle, %Date{} = date) do
    best = best_match(found, needle, date)

    sections =
      for kind <- @kinds,
          hits = Enum.reject(Map.get(found, kind, []), &(best && id(&1) == id(best))),
          hits != [],
          do: %{kind: kind, hits: hits}

    %__MODULE__{best: best, sections: sections, date: date}
  end

  @doc "Nothing searched for, or nothing found."
  def empty?(%__MODULE__{best: nil, sections: []}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  The kinds that found something, in the page's order: the chips. The best
  match's kind stands first, as its card does (AppSearch.Results.kinds).
  """
  def found_kinds(%__MODULE__{best: best, sections: sections}) do
    kinds = Enum.map(sections, & &1.kind)

    case best do
      nil -> kinds
      best -> [kind(best) | List.delete(kinds, kind(best))]
    end
  end

  @doc """
  Where a chip leads: the best match's kind to the best card, as the app's
  chip scrolls there (its own section may not be drawn when the best was
  its only hit); every other kind to its section.
  """
  def chip_target(%__MODULE__{best: best}, kind) do
    if best && kind(best) == kind, do: "#explore-best", else: "#explore-#{kind}"
  end

  @doc "How many of a kind were found, the best match included."
  def count(%__MODULE__{best: best, sections: sections}, kind) do
    in_section =
      case Enum.find(sections, &(&1.kind == kind)) do
        nil -> 0
        section -> length(section.hits)
      end

    in_section + if(best && kind(best) == kind, do: 1, else: 0)
  end

  @doc "The kind a hit is listed under."
  def kind({type, _}) when type in [:mysteries, :mystery], do: :mysteries
  def kind({:page, _}), do: :pages
  def kind({type, _}) when type in [:topic, :order, :prayer], do: :prayers
  def kind({:chant, _}), do: :chants
  def kind({:set, _}), do: :meditations

  @doc "A hit's id, unique across kinds."
  def id({:mysteries, slug}), do: "mysteries:#{slug}"
  def id({:mystery, m}), do: "mystery:#{m.category}:#{m.order}"
  def id({:page, page}), do: "page:#{page.id}"
  def id({:topic, chapter}), do: "topic:#{chapter.id}"
  def id({:order, order}), do: "order:#{order.id}"
  def id({:prayer, prayer}), do: "prayer:#{prayer.id}"
  def id({:chant, chant}), do: "chant:#{chant.id}"
  def id({:set, set}), do: "set:#{set.id}"

  @doc """
  The names a hit goes by on `date`, for judging how well it answers: an
  order of prayer by its day's name (AppSearch.Hit.names).
  """
  def names({:mysteries, slug}, _date), do: [Categories.devotion_title(slug)]
  def names({:mystery, mystery}, _date), do: [mystery.name]
  def names({:page, page}, _date), do: [page.title]
  def names({:topic, chapter}, _date), do: [chapter.topic, chapter.title]

  def names({:order, order}, date),
    do: Enum.reject([Orders.title(order, date), order.latin_title], &is_nil/1)

  def names({:prayer, prayer}, _date),
    do: Enum.reject([Book.list_name(prayer), prayer.title, prayer.latin_title], &is_nil/1)

  def names({:chant, chant}, _date), do: [chant.latin_title, chant.english_title]
  def names({:set, set}, _date), do: [set.name]

  ## The best match

  @closeness [:none, :within, :word_start, :start, :exact]

  @doc """
  How well a name answers the words: `:exact` (the name is the words),
  `:start` (the name begins with them), `:word_start` (a word of the name
  does), `:within` or `:none` (AppSearch.closeness).
  """
  def closeness(name, needle) do
    name = Book.fold(name)
    needle = Book.fold(needle)

    cond do
      needle == "" -> :none
      name == needle -> :exact
      String.starts_with?(name, needle) -> :start
      name |> word_list() |> Enum.any?(&String.starts_with?(&1, needle)) -> :word_start
      String.contains?(name, needle) -> :within
      true -> :none
    end
  end

  defp word_list(text), do: String.split(text, ~r/[^\p{L}\p{N}]+/u, trim: true)

  defp rank(closeness), do: Enum.find_index(@closeness, &(&1 == closeness))

  # The closest name of every kind, a tie going to the kind and then the
  # hit that stands first. A hit found only by its words or other names is
  # never the best: a card says "this is what you meant" (AppSearch.bestMatch).
  defp best_match(found, needle, date) do
    {best, _rank} =
      Enum.reduce(@kinds, {nil, 0}, fn kind, best ->
        Enum.reduce(Map.get(found, kind, []), best, fn hit, {_, best_rank} = acc ->
          rank =
            hit
            |> names(date)
            |> Enum.map(&rank(closeness(&1, needle)))
            |> Enum.max(fn -> 0 end)

          if rank > best_rank, do: {hit, rank}, else: acc
        end)
      end)

    best
  end

  ## The kinds Explore finds itself

  @doc """
  A devotion by its name or what it is about, then a single mystery by
  its name; a devotion found by name stands before its mysteries
  (AppSearch.mysteryHits). Only the mysteries a devotion counts are
  searched, in prayer order.
  """
  def mystery_hits(needle, mysteries) do
    categories =
      for slug <- Categories.slugs(),
          String.contains?(Book.fold(Categories.devotion_title(slug)), needle) or
            String.contains?(Book.fold(Categories.subtitle(slug)), needle),
          do: {:mysteries, slug}

    named =
      mysteries
      |> Enum.filter(fn m ->
        m.category in Categories.slugs() and m.order in 1..Categories.mystery_count(m.category) and
          String.contains?(Book.fold(m.name), needle)
      end)
      |> Enum.sort_by(&{Categories.position(&1.category), &1.order})
      |> Enum.map(&{:mystery, &1})

    categories ++ named
  end

  @doc "The doors whose name or words hold the search."
  def page_hits(needle, pages) do
    for page <- pages,
        String.contains?(Book.fold("#{page.title} #{page.words}"), needle),
        do: {:page, page}
  end

  @doc """
  Whether a meditation set answers: by its name, author, source, labels
  (the word the shelf shows as well as the one stored) or devotion
  (AppSearch.matches).
  """
  def set_matches?(set, needle) do
    labels = Enum.flat_map(set.labels || [], &[&1, Labels.display_name(&1)])

    [set.name, set_author(set), set.source, devotion_title(set.category) | labels]
    |> Enum.reject(&is_nil/1)
    |> Enum.any?(&String.contains?(Book.fold(&1), needle))
  end

  @doc "A set's author, as the site shows one."
  def set_author(set), do: LumenViaeWeb.PageMeta.set_author(set)

  @doc """
  A set's line: its author and devotion, or the devotion alone where the
  set is named for its author (AppSearchResultsView.note(for:)).
  """
  def set_note(set) do
    devotion = devotion_title(set.category) || set.category

    case set_author(set) do
      nil -> devotion
      author when author == set.name -> devotion
      author -> "#{author} · #{devotion}"
    end
  end

  defp devotion_title(category) do
    if category in Categories.slugs(), do: Categories.devotion_title(category)
  end
end
