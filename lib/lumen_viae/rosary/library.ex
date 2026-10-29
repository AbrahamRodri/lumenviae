defmodule LumenViae.Rosary.Library do
  @moduledoc """
  The Prayer Book, the Chant Library, the Consecration, True Devotion, St.
  Carlo Acutis's page, the Marian Library and the Spiritual Reading
  catalogue: what `GET /api/v2/prayer-book`, `GET /api/v2/chant-library`,
  `GET /api/v2/consecration`, `GET /api/v2/true-devotion`,
  `GET /api/v2/carlo-acutis`, `GET /api/v2/marian-library` and
  `GET /api/v2/spiritual-reading` serve, and
  what the apps keep an offline copy of.

  A value module. The content is seven files in `priv/library/`, read when
  this module compiles, so a new or corrected prayer or chant is a deploy
  rather than an edit in the admin: no query, no state.

  `prayer_book.json` holds `prayers`, every prayer the book prints, each
  once (the Rosary's and the consecration's resolved, so a client needs
  nothing else), and `chapters`, in book order, each naming its prayers
  under its sub-headings (`sections`) and as their union (`prayer_ids`).
  A prayer's `english` and `latin` are written in the app's `PrayerText`
  grammar and pair line for line, blank lines included.

  `chant_library.json` holds `groups`, in the Parish Book of Chant's
  order, and `chants`, in the catalog's order (the app takes the first
  chant for a prayer, so the order matters). Each chant's recording and
  score pages are files in the public assets bucket, at URLs ending in
  their name and checksum (`chants/audio/<id>-<sha256 first 12>.m4a`,
  `chants/scores/<file>-<sha256 first 12>.lvscore`), so a changed file is
  a new URL. `mix lumen_viae.upload_chants` puts them there and writes
  their url, bytes and sha256 into the file. Beside them, as the iOS app
  holds them (`Data/ChantLibraryData.swift`): `feasts`, the days the
  library sings a chant for, each with its date rule; `months`, the
  months' dedications; and `occasions`, the sung sets (Benediction, a
  visit, a sung Rosary and the rest), each its chants in the order sung.

  `consecration.json` holds the 33-day Consecration as the iOS app
  bundles it: `phases`, each with its days' span and the prayers said on
  each of them; `days`, 1 to 34, each with its readings and journal
  prompt; `prayers`, the Consecration's own words for each prayer a phase
  names; and `feasts`, the feasts of Mary it may end on.

  `true_devotion.json` holds St. Louis de Montfort's True Devotion as the
  iOS app bundles it (`Resources/TrueDevotionBook.json`): `about`, the
  book's title, author, translator and source; `parts`, its two parts;
  `chapters`, in reading order, each with its paragraphs numbered from 0;
  and the summary page's `teaching` shelf and `ejaculatory_prayers`
  (`Data/TrueDevotionData.swift`, `Data/TrueDevotionPrayers.swift`).

  `carlo_acutis.json` holds St. Carlo's page as the iOS app holds it
  (`Data/CarloAcutisData.swift`): his `feast`, two `shelves` of readings
  (his life, his devotions), his `timeline` and `rule` of life, each
  naming a reading, his `sayings` and a `prayer`.

  `marian_library.json` holds the Marian Library as the iOS app holds it
  (`Data/MarianLibraryData.swift`): the `feasts` of Our Lady in the order
  of the year, each with its painting and reading, and six `shelves` of
  readings.

  `spiritual_reading.json` holds the Spiritual Reading shelf's catalogue
  as the iOS app holds it (`Data/LibraryCatalog.swift`): its `books`, each
  with its Gutenberg and LibriVox numbers, the rules that cut its edition
  into chapters (`parsing`), how its recording lines up with them
  (`track_mapping`), and its chapter titles and heading overrides. The
  books' text and recordings are not here: a device fetches them.

  The shapes are the contract in docs/JSON_API.md, "The Prayer Book and
  the Chant Library" and "The Consecration". The ids are stable forever:
  devices store them.

  ## Every file is dated

  Each file carries a top-level `updated_at`, an ISO 8601 UTC timestamp:
  the moment its content last changed. A document's `version` fingerprints
  its content (`LumenViae.Rosary.Content.version/1`), never the date.
  `test/lumen_viae/rosary/library_test.exs` keeps each file's history of
  dates and versions, so changing a file without dating it fails the build.

  A file that repeats an id, names one that does not exist, pairs English
  and Latin of different lengths, puts a chant's lines out of order or
  past its recording, or leaves a chant file without its url, bytes and
  sha256 fails the compile (`LumenViae.Rosary.Library.Check`), never a
  request.
  """

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.Library.Check
  alias LumenViae.Rosary.Library.Section

  @dir Path.join(:code.priv_dir(:lumen_viae), "library")

  @prayer_book_path Path.join(@dir, "prayer_book.json")
  @external_resource @prayer_book_path

  @chant_library_path Path.join(@dir, "chant_library.json")
  @external_resource @chant_library_path

  @consecration_path Path.join(@dir, "consecration.json")
  @external_resource @consecration_path

  @true_devotion_path Path.join(@dir, "true_devotion.json")
  @external_resource @true_devotion_path

  @carlo_acutis_path Path.join(@dir, "carlo_acutis.json")
  @external_resource @carlo_acutis_path

  @marian_library_path Path.join(@dir, "marian_library.json")
  @external_resource @marian_library_path

  @spiritual_reading_path Path.join(@dir, "spiritual_reading.json")
  @external_resource @spiritual_reading_path

  read = fn path, sections ->
    file = path |> File.read!() |> Jason.decode!()
    name = "priv/library/#{Path.basename(path)}"

    updated_at =
      case DateTime.from_iso8601(Map.get(file, "updated_at") || "") do
        {:ok, at, 0} ->
          DateTime.truncate(at, :second)

        _ ->
          raise CompileError,
            description: "#{name} needs a top-level \"updated_at\", an ISO 8601 UTC timestamp"
      end

    {Map.take(file, sections), updated_at}
  end

  check = fn path, errors ->
    if errors != [] do
      raise CompileError,
        description: "priv/library/#{Path.basename(path)}:\n  " <> Enum.join(errors, "\n  ")
    end
  end

  {prayer_book, prayer_book_updated_at} =
    read.(@prayer_book_path, ~w(prayers chapters orders marian_antiphons))

  check.(@prayer_book_path, Check.prayer_book_errors(prayer_book))

  {chant_library, chant_library_updated_at} =
    read.(@chant_library_path, ~w(groups chants feasts months occasions))

  # A chant's prayer_ids name the book's prayers.
  check.(
    @chant_library_path,
    Check.chant_library_errors(chant_library, Enum.map(prayer_book["prayers"], & &1["id"]))
  )

  {consecration, consecration_updated_at} =
    read.(@consecration_path, ~w(phases days prayers feasts))

  check.(@consecration_path, Check.consecration_errors(consecration))

  {true_devotion, true_devotion_updated_at} =
    read.(@true_devotion_path, ~w(about parts chapters teaching ejaculatory_prayers))

  check.(
    @true_devotion_path,
    Check.true_devotion_errors(true_devotion, Enum.map(prayer_book["prayers"], & &1["id"]))
  )

  {carlo_acutis, carlo_acutis_updated_at} =
    read.(@carlo_acutis_path, ~w(feast shelves timeline rule sayings prayer))

  # A door may name a Prayer Book prayer.
  check.(
    @carlo_acutis_path,
    Check.carlo_acutis_errors(carlo_acutis, Enum.map(prayer_book["prayers"], & &1["id"]))
  )

  {marian_library, marian_library_updated_at} = read.(@marian_library_path, ~w(feasts shelves))

  check.(
    @marian_library_path,
    Check.marian_library_errors(marian_library, Enum.map(prayer_book["prayers"], & &1["id"]))
  )

  {spiritual_reading, spiritual_reading_updated_at} = read.(@spiritual_reading_path, ~w(books))

  check.(@spiritual_reading_path, Check.spiritual_reading_errors(spiritual_reading))

  # Each section is cast to its type here, once, and served as cast; a
  # section the cast would change fails the compile (Section.cast/3).
  cast = fn path, document, sections ->
    Map.new(sections, fn {name, items} ->
      case Section.cast(document, name, items) do
        {:ok, cast} -> {name, cast}
        {:error, message} -> check.(path, [message])
      end
    end)
  end

  @served %{
    prayer_book: cast.(@prayer_book_path, :prayer_book, prayer_book),
    chant_library: cast.(@chant_library_path, :chant_library, chant_library),
    consecration: cast.(@consecration_path, :consecration, consecration),
    true_devotion: cast.(@true_devotion_path, :true_devotion, true_devotion),
    carlo_acutis: cast.(@carlo_acutis_path, :carlo_acutis, carlo_acutis),
    marian_library: cast.(@marian_library_path, :marian_library, marian_library),
    spiritual_reading: cast.(@spiritual_reading_path, :spiritual_reading, spiritual_reading)
  }

  @asset_base for(chant <- chant_library["chants"], do: chant["audio"]["url"])
              |> hd()
              |> String.split("/chants/")
              |> hd()

  @documents %{
    prayer_book: %{
      name: "prayer_book.json",
      sections: prayer_book,
      updated_at: prayer_book_updated_at,
      version: Content.version(prayer_book)
    },
    chant_library: %{
      name: "chant_library.json",
      sections: chant_library,
      updated_at: chant_library_updated_at,
      version: Content.version(chant_library)
    },
    consecration: %{
      name: "consecration.json",
      sections: consecration,
      updated_at: consecration_updated_at,
      version: Content.version(consecration)
    },
    true_devotion: %{
      name: "true_devotion.json",
      sections: true_devotion,
      updated_at: true_devotion_updated_at,
      version: Content.version(true_devotion)
    },
    carlo_acutis: %{
      name: "carlo_acutis.json",
      sections: carlo_acutis,
      updated_at: carlo_acutis_updated_at,
      version: Content.version(carlo_acutis)
    },
    marian_library: %{
      name: "marian_library.json",
      sections: marian_library,
      updated_at: marian_library_updated_at,
      version: Content.version(marian_library)
    },
    spiritual_reading: %{
      name: "spiritual_reading.json",
      sections: spiritual_reading,
      updated_at: spiritual_reading_updated_at,
      version: Content.version(spiritual_reading)
    }
  }

  @typedoc "One of the seven documents."
  @type document ::
          :prayer_book
          | :chant_library
          | :consecration
          | :true_devotion
          | :carlo_acutis
          | :marian_library
          | :spiritual_reading

  @doc "The seven documents' names."
  @spec documents() :: [document]
  def documents,
    do: [
      :prayer_book,
      :chant_library,
      :consecration,
      :true_devotion,
      :carlo_acutis,
      :marian_library,
      :spiritual_reading
    ]

  @doc """
  A document's sections, keyed by name (`"prayers"`, `"chapters"`;
  `"groups"`, `"chants"`, `"feasts"`, `"months"`, `"occasions"`; `"phases"`, `"days"`, `"prayers"`, `"feasts"`;
  `"about"`, `"parts"`, `"chapters"`, `"teaching"`, `"ejaculatory_prayers"`; `"feast"`, `"shelves"`, `"timeline"`,
  `"rule"`, `"sayings"`, `"prayer"`; `"feasts"`, `"shelves"`; `"books"`),
  string keys throughout, as the file holds them.
  """
  @spec sections(document) :: map
  def sections(document), do: @documents |> Map.fetch!(document) |> Map.fetch!(:sections)

  @doc """
  A section as the APIs serve it: the file's, cast to its type when this
  module compiled (`Types.BookPrayer`, `Types.PrayerBookChapter`,
  `Types.ChantGroup`, `Types.Chant`, `Types.ChantFeast`, `Types.ChantMonth`,
  `Types.ChantOccasion`, and the Consecration's
  `Types.ConsecrationPhase`, `Types.ConsecrationDay`,
  `Types.ConsecrationPrayer`, `Types.MarianFeast`, and True Devotion's
  `Types.TrueDevotionAbout`, `Types.TrueDevotionPart`,
  `Types.TrueDevotionChapter`, `Types.LibraryShelf`,
  `Types.TrueDevotionPrayer`; St. Carlo's `Types.LibraryFeast`,
  `Types.LibraryShelf`, `Types.CarloMoment`, `Types.CarloHabit`, strings;
  the Marian Library's `Types.LibraryFeast` and `Types.LibraryShelf`;
  the Spiritual Reading catalogue's `Types.SpiritualBook`).
  `"about"`, `"teaching"` and `"feast"` are one struct and `"prayer"` one string, not
  lists.
  """
  @spec served(document, String.t()) :: [struct] | struct | [String.t()] | String.t()
  def served(document, section), do: @served |> Map.fetch!(document) |> Map.fetch!(section)

  @doc """
  A document's `version` (a fingerprint of every section: it changes when,
  and only when, the content does) and `updated_at` (when it last changed).
  """
  @spec stamp(document) :: %{version: String.t(), updated_at: DateTime.t()}
  def stamp(document), do: @documents |> Map.fetch!(document) |> Map.take([:version, :updated_at])

  @doc """
  Each file in `priv/library/`: its name, its `updated_at` and its version,
  for the test that pins them.
  """
  @spec files() :: [%{name: String.t(), updated_at: DateTime.t(), version: String.t()}]
  def files do
    for document <- documents(),
        do: @documents |> Map.fetch!(document) |> Map.take([:name, :updated_at, :version])
  end

  @doc """
  Where every chant file is: the one base their URLs share, before
  `/chants/`. The compile requires one base; the test pins which, so
  moving the files is a reviewed change.
  """
  @spec asset_base() :: String.t()
  def asset_base, do: @asset_base

  @doc """
  The problems with a document's sections cast as they will be served,
  `[]` when none: the text a type would change, as the compile refuses it
  (`LumenViae.Rosary.Library.Section.cast/3`).
  """
  @spec cast_errors(document, map) :: [String.t()]
  def cast_errors(document, sections) do
    for {name, items} <- sections,
        {:error, message} <- [Section.cast(document, name, items)],
        do: message
  end

  @doc """
  The problems with a Chant Library document's sections, `[]` when none:
  its chants' `prayer_ids` checked against `prayer_ids`, and its files'
  URLs against `base`, each when given.
  """
  @spec chant_library_errors(map, [String.t()] | nil, String.t() | nil) :: [String.t()]
  defdelegate chant_library_errors(sections, prayer_ids \\ nil, base \\ nil), to: Check

  @doc "The ids of the Prayer Book's prayers, the ids a chant may name."
  @spec prayer_ids() :: [String.t()]
  def prayer_ids, do: Enum.map(sections(:prayer_book)["prayers"], & &1["id"])
end
