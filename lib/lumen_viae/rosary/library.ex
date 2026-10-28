defmodule LumenViae.Rosary.Library do
  @moduledoc """
  The Prayer Book, the Chant Library, the Consecration and True Devotion:
  what `GET /api/v2/prayer-book`, `GET /api/v2/chant-library`,
  `GET /api/v2/consecration` and `GET /api/v2/true-devotion` serve, and
  what the apps keep an offline copy of.

  A value module. The content is four files in `priv/library/`, read when
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
  their url, bytes and sha256 into the file.

  `consecration.json` holds the 33-day Consecration as the iOS app
  bundles it: `phases`, each with its days' span and the prayers said on
  each of them; `days`, 1 to 34, each with its readings and journal
  prompt; `prayers`, the Consecration's own words for each prayer a phase
  names; and `feasts`, the feasts of Mary it may end on.

  `true_devotion.json` holds St. Louis de Montfort's True Devotion as the
  iOS app bundles it (`Resources/TrueDevotionBook.json`): `about`, the
  book's title, author, translator and source; `parts`, its two parts;
  and `chapters`, in reading order, each with its paragraphs numbered
  from 0.

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

  {prayer_book, prayer_book_updated_at} = read.(@prayer_book_path, ~w(prayers chapters))
  check.(@prayer_book_path, Check.prayer_book_errors(prayer_book))

  {chant_library, chant_library_updated_at} = read.(@chant_library_path, ~w(groups chants))
  # A chant's prayer_ids name the book's prayers.
  check.(
    @chant_library_path,
    Check.chant_library_errors(chant_library, Enum.map(prayer_book["prayers"], & &1["id"]))
  )

  {consecration, consecration_updated_at} =
    read.(@consecration_path, ~w(phases days prayers feasts))

  check.(@consecration_path, Check.consecration_errors(consecration))

  {true_devotion, true_devotion_updated_at} =
    read.(@true_devotion_path, ~w(about parts chapters))

  check.(@true_devotion_path, Check.true_devotion_errors(true_devotion))

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
    true_devotion: cast.(@true_devotion_path, :true_devotion, true_devotion)
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
    }
  }

  @typedoc "One of the four documents."
  @type document :: :prayer_book | :chant_library | :consecration | :true_devotion

  @doc "The four documents' names."
  @spec documents() :: [document]
  def documents, do: [:prayer_book, :chant_library, :consecration, :true_devotion]

  @doc """
  A document's sections, keyed by name (`"prayers"`, `"chapters"`;
  `"groups"`, `"chants"`; `"phases"`, `"days"`, `"prayers"`, `"feasts"`;
  `"about"`, `"parts"`, `"chapters"`),
  string keys throughout, as the file holds them.
  """
  @spec sections(document) :: map
  def sections(document), do: @documents |> Map.fetch!(document) |> Map.fetch!(:sections)

  @doc """
  A section as the APIs serve it: the file's, cast to its type when this
  module compiled (`Types.BookPrayer`, `Types.PrayerBookChapter`,
  `Types.ChantGroup`, `Types.Chant`, and the Consecration's
  `Types.ConsecrationPhase`, `Types.ConsecrationDay`,
  `Types.ConsecrationPrayer`, `Types.MarianFeast`, and True Devotion's
  `Types.TrueDevotionAbout`, `Types.TrueDevotionPart`,
  `Types.TrueDevotionChapter`). `"about"` is one struct, not a list.
  """
  @spec served(document, String.t()) :: [struct] | struct
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
