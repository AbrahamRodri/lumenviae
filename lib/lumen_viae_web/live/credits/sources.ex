defmodule LumenViaeWeb.Live.Credits.Sources do
  @moduledoc """
  What the Sources & Credits page lists, shaped for it: the Prayer Book's
  prayers by their home chapter with their origins, the novenas' paintings
  and the mysteries' woodcuts with their credits and licences, the Chant
  Library's singers and every chant's source, and the books with their
  editions and recordings.

  Presentation only. The credits are the data's own (the Prayer Book's
  `origin` and novena `art.credit`, the woodcut manifest, the Chant
  Library's `source_url`, the Spiritual Reading catalogue, True Devotion's
  `about`), read through `LumenViae.Rosary` and the pages' own readers.
  """

  alias LumenViae.Rosary
  alias LumenViaeWeb.Components.WoodcutPlate
  alias LumenViaeWeb.Live.Chants.Library
  alias LumenViaeWeb.Live.Prayers.Book
  alias LumenViaeWeb.Live.SpiritualReading.Shelf

  @cc_by_sa %{label: "CC BY-SA 4.0", url: "https://creativecommons.org/licenses/by-sa/4.0/"}
  @cc0 %{label: "CC0", url: "https://creativecommons.org/publicdomain/zero/1.0/"}
  @public_domain %{label: "Public domain", url: nil}

  @doc """
  The Prayer Book's chapters in the book's order, each `%{chapter:,
  prayers:}` with the prayers whose home it is, in the chapter's order.
  A chapter that is home to none is left out. The novenas' prayers stand
  under the website's Novenas topic, last, as their pages' trail has it.
  """
  def prayer_chapters(%Book{chapters: chapters} = book) do
    for chapter <- chapters ++ List.wrap(Book.novenas_chapter(book)),
        prayers = home_prayers(book, chapter),
        prayers != [] do
      %{chapter: chapter, prayers: prayers}
    end
  end

  defp home_prayers(book, chapter) do
    book
    |> Book.prayers(Enum.uniq(chapter.prayer_ids))
    |> Enum.filter(&(Book.home_chapter(book, &1.id) == chapter))
  end

  @doc "A prayer's origin to print, or nil where it has none."
  def origin(%{origin: origin}) when is_binary(origin) and origin != "", do: origin
  def origin(_prayer), do: nil

  @doc """
  The novenas' paintings, in the order their prayers stand in the book,
  each `%{title:, prayer_id:, url:, credit:, licence:}`. A novena with no
  painting is left out.
  """
  def novena_paintings(%Book{novenas: novenas} = book) do
    order =
      book.chapters
      |> Enum.flat_map(& &1.prayer_ids)
      |> Enum.uniq()
      |> Enum.with_index()
      |> Map.new()

    novenas
    |> Map.values()
    |> Enum.filter(
      &match?(%{art: %{url: url, credit: credit}} when is_binary(url) and is_binary(credit), &1)
    )
    |> Enum.sort_by(&Map.get(order, &1.prayer_id, map_size(order)))
    |> Enum.map(fn novena ->
      %{
        title: novena.title,
        prayer_id: novena.prayer_id,
        url: novena.art.url,
        credit: credit_line(novena.art.credit),
        licence: licence(novena.art.credit)
      }
    end)
  end

  @doc """
  The licence a credit names, as the pill shows it: CC BY-SA 4.0 and CC0
  with their deeds, else public domain, else nil.
  """
  def licence(credit) when is_binary(credit) do
    cond do
      credit =~ ~r/CC BY-SA 4\.0/ -> @cc_by_sa
      credit =~ ~r/\bCC0\b/ -> @cc0
      credit =~ ~r/public domain|PD-old/i -> @public_domain
      true -> nil
    end
  end

  def licence(_credit), do: nil

  @doc """
  A painting's credit as the page prints it, ending at its source: the
  licence is the pill's, so it is not said again in the line (design,
  15 Nov 2026), and no raw licence URL is printed.
  """
  def credit_line(credit) when is_binary(credit) do
    credit
    |> String.replace(~r/, CC BY-SA 4\.0 \([^)]*\)/, "")
    |> String.replace(~r/\b(?:Public domain|CC0), via\b/, "Via")
    |> String.replace(~r/\s*Public domain\.$/, "")
  end

  @doc """
  The mysteries' woodcuts, one row per print (a print that hangs on two
  mysteries once), each `%{title:, src:, srcset:, credit:, source:,
  licence:}`.
  """
  def woodcuts do
    WoodcutPlate.keys()
    |> Enum.map(&WoodcutPlate.plate/1)
    |> Enum.uniq_by(& &1.file)
    |> Enum.map(fn plate ->
      %{
        title: plate.title,
        src: plate.src,
        srcset: srcset(plate.sources),
        credit: woodcut_credit(plate),
        source: plate.source,
        licence: licence(plate.licence)
      }
    end)
  end

  defp srcset([]), do: nil
  defp srcset(sources), do: Enum.map_join(sources, ", ", & &1.srcset)

  # "from the Small Passion", but a print that stands alone is "a
  # single-sheet engraving", not "from" one.
  defp series_phrase(nil), do: nil
  defp series_phrase("Single-sheet " <> rest), do: "a single-sheet " <> rest
  defp series_phrase("La " <> _ = series), do: "from " <> series
  defp series_phrase(series), do: "from the " <> series

  defp woodcut_credit(plate) do
    [plate.artist, plate.year, series_phrase(plate.series)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  @manifest Path.join([
              :code.priv_dir(:lumen_viae),
              "static",
              "images",
              "paintings",
              "manifest.json"
            ])
  @external_resource @manifest
  @site_paintings @manifest |> File.read!() |> Jason.decode!() |> Map.fetch!("paintings")

  @doc """
  Every painting the site hangs from `priv/static/images/paintings` (the
  mysteries, the Prayer Book and the Chant Library), by title, each
  `%{title:, src:, srcset:, credit:, source:, licence:}`: the credit is
  the artist, date and collection from the manifest.
  """
  def site_paintings do
    @site_paintings
    |> Enum.map(fn p ->
      %{
        title: p["title"],
        src: "/images/paintings/#{p["name"]}-480.webp",
        srcset:
          Enum.map_join(p["widths"] || [], ", ", fn [w, _h] ->
            "/images/paintings/#{p["name"]}-#{w}.webp #{w}w"
          end),
        credit:
          [p["artist"], p["date"], p["collection"]]
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.join(", "),
        source: p["source_page"],
        licence: licence(p["licence"])
      }
    end)
    |> Enum.sort_by(&String.downcase(String.replace_prefix(&1.title, "The ", "")))
  end

  @doc """
  The Chant Library's credit and every chant with its source page,
  `%{credit:, licence_note:, licence_url:, source_site:, chants:}`; nil
  when no chant names a source.
  """
  def chant(actor) do
    library = Library.load(actor)
    chants = Enum.filter(library.chants, &is_binary(&1.source_url))

    if chants != [] do
      %{
        credit: Library.library_credit(),
        licence_note: Library.licence_note(),
        licence_url: Library.licence_url(),
        source_site: Library.source_site(),
        chants: Enum.sort_by(chants, &{&1.latin_title, &1.setting || ""})
      }
    end
  end

  @doc "A chant's name on its row: its Latin title and, where it has one, its setting."
  def chant_name(%{latin_title: title, setting: setting}) when is_binary(setting),
    do: "#{title} · #{setting}"

  def chant_name(%{latin_title: title}), do: title

  @doc "The Spiritual Reading catalogue's books, in its order."
  def books(actor), do: Shelf.books(actor)

  defdelegate author_line(book), to: Shelf

  # The printed edition each shelf book's text was set from, by book id, so
  # the credit names the real book rather than the website that carries it
  # (reports/rig/copyright-review/inventory.md, "Item 19"). Imitation and
  # Confessions are inferred there (a matching introduction; Pusey's own
  # first edition); the others are stated in the transcribed text. A book
  # added to the catalogue needs a line here: credits_test checks it.
  @printed_editions %{
    "imitation-of-christ" => "Harvard Classics, P. F. Collier & Son, New York, 1909",
    "story-of-a-soul" => "Burns, Oates & Washbourne, London, 1912; 8th edition, 1922",
    "confessions-of-st-augustine" => "first published by J. H. Parker, Oxford, 1838",
    "glories-of-mary" => "second American edition, Edward Dunigan & Brother, New York, 1852",
    "practice-of-the-presence-of-god" => "Fleming H. Revell Company, New York, about 1895"
  }

  @doc """
  The printed edition a shelf book's text comes from, "Text: Burns, Oates &
  Washbourne, London, 1912; 8th edition, 1922.", or nil for a book with none
  recorded.
  """
  def printed_edition(%{id: id}) do
    case Map.fetch(@printed_editions, id) do
      {:ok, edition} -> "Text: #{edition}."
      :error -> nil
    end
  end

  @doc "\"Recording: LibriVox volunteers, audiobook #8021.\", or nil for a book with none."
  def librivox_credit(%{librivox_id: id}) when is_integer(id),
    do: "Recording: LibriVox volunteers, audiobook ##{id}."

  def librivox_credit(_book), do: nil

  @doc "The Internet Archive recording the apps play, `%{credit:, url:}`, or nil."
  def archive_recording(%{archive_recording: %{item: item, credit: credit}})
      when is_binary(item) and is_binary(credit),
      do: %{credit: credit, url: "https://archive.org/details/#{item}"}

  def archive_recording(_book), do: nil

  @licences [
    {"divinum-officium", "Divinum Officium", "The engine that assembles Hours of Prayer.", "MIT"},
    {"missale-meum", "Missale Meum", "The Daily Missal's texts, read from its API.", "MIT"},
    {"phosphor", "Phosphor Icons", "Icons in the iPhone and Android apps.", "MIT"},
    {"cinzel", "Cinzel", "The headings' typeface.", "SIL Open Font License 1.1"},
    {"eb-garamond", "EB Garamond", "The text typeface.", "SIL Open Font License 1.1"}
  ]

  for {file, _, _, _} <- @licences do
    @external_resource Path.join([:code.priv_dir(:lumen_viae), "licences", file <> ".txt"])
  end

  @licence_texts Map.new(@licences, fn {file, _, _, _} ->
                   {file,
                    [:code.priv_dir(:lumen_viae), "licences", file <> ".txt"]
                    |> Path.join()
                    |> File.read!()}
                 end)

  @doc """
  The software and fonts whose licences ask that their notice go with every
  copy (MIT, SIL OFL 1.1), each `%{id:, name:, use:, licence:, copyright:,
  text:}`: `copyright` is the notice's first line, `text` the whole licence
  as its project publishes it (`priv/licences/`).
  """
  def licences do
    Enum.map(@licences, fn {file, name, use, licence} ->
      text = Map.fetch!(@licence_texts, file)

      copyright =
        text |> String.split("\n") |> Enum.find(&String.starts_with?(&1, "Copyright"))

      %{id: file, name: name, use: use, licence: licence, copyright: copyright, text: text}
    end)
  end

  @doc "True Devotion's title, author, translator and edition."
  def true_devotion(actor), do: Rosary.get_true_devotion!(actor: actor, load: [:about]).about
end
