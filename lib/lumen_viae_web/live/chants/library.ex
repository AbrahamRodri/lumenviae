defmodule LumenViaeWeb.Live.Chants.Library do
  @moduledoc """
  The Chant Library as the Chant pages read it, as the iOS app's
  `ChantCatalog`, `ChantLibraryData` and `ChantBrowseScope` (and the
  Android app's `ChantLibraryIndex`) read it: chants by id and by section,
  the shelves the Chant page opens on, the painting each section and
  chant hangs, the rows' second lines and the search.

  Presentation only. The chants, their recordings and their timed lines
  are the domain's (`LumenViae.Rosary.get_chant_library!/1`, from
  `priv/library/chant_library.json`); how the apps arrange them is the
  apps', and this is the website's copy of it. It never queries beyond
  `load/1`.
  """

  alias LumenViae.Rosary
  alias LumenViaeWeb.Components.MysteryPainting
  alias LumenViaeWeb.Live.Prayers.Book

  defstruct groups: [], chants: [], occasions: [], by_id: %{}

  @type t :: %__MODULE__{
          groups: [map()],
          chants: [map()],
          occasions: [map()],
          by_id: %{String.t() => map()}
        }

  # The Chant page's shelf of songs to Mary, in its own order
  # (ChantLibraryData.songsToMary).
  @songs_to_mary ~w(
    salve_regina_simple salve_regina_solemn alma_redemptoris_simple alma_redemptoris
    ave_regina_simple ave_regina_solemn regina_caeli_simple regina_caeli_solemn sub_tuum
    ave_maris_stella_feasts ave_maris_stella quem_terra omni_die concordi_laetitia
    magnificat tota_pulchra flos_carmeli stabat_mater litany_loreto memorare
    ave_maria_antiphon salve_mater inviolata o_gloriosa te_matrem
  )

  # The scene, saint or feast a chant sings (ChantLibraryData.paintings);
  # a chant not named takes its section's.
  @chant_paintings %{
    "salve_regina_simple" => "glorious_coronation",
    "salve_regina_solemn" => "glorious_coronation",
    "alma_redemptoris" => "joyful_nativity",
    "alma_redemptoris_simple" => "joyful_nativity",
    "ave_regina_simple" => "glorious_assumption",
    "ave_regina_solemn" => "glorious_assumption",
    "regina_caeli_simple" => "easter_appears_to_mary",
    "regina_caeli_solemn" => "easter_appears_to_mary",
    "sub_tuum" => "mary_mother_of_mercy",
    "salve_mater" => "mary_mother_of_mercy",
    "ave_maris_stella_feasts" => "feast_annunciation",
    "quem_terra" => "feast_annunciation",
    "ave_maria_antiphon" => "feast_annunciation",
    "tota_pulchra" => "mary_immaculate_conception",
    "inviolata" => "mary_immaculate_conception",
    "flos_carmeli" => "mary_mount_carmel",
    "stabat_mater" => "seven_sorrows_calvary",
    "litany_loreto" => "feast_our_lady_of_the_rosary",
    "memorare" => "glorious_assumption",
    "angelus" => "joyful_annunciation",
    "concordi_laetitia" => "easter_appears_to_mary",
    "in_nomine_patris" => "devotion_holy_trinity",
    "credo_in_deum" => "glorious_pentecost",
    "pater_noster" => "luminous_proclamation",
    "ave_maria" => "joyful_annunciation",
    "gloria_patri" => "devotion_holy_trinity",
    "o_mi_jesu" => "feast_our_lady_of_the_rosary",
    "adoro_te" => "jesus_eucharist_saviour",
    "ave_verum" => "jesus_eucharist_saviour",
    "o_sacrum_convivium" => "jesus_eucharist_saviour",
    "panis_angelicus" => "jesus_eucharist_saviour",
    "ecce_panis" => "jesus_eucharist_saviour",
    "lauda_sion" => "topic_blessed_sacrament",
    "ubi_caritas" => "luminous_eucharist",
    "adoramus_te" => "sorrowful_crucifixion",
    "anima_christi" => "jesus_anima_christi",
    "litany_sacred_heart" => "topic_our_lord",
    "cor_jesu" => "topic_our_lord",
    "litany_holy_name" => "jesus_holy_name",
    "jesu_dulcis_memoria" => "jesus_holy_name",
    "salvete_christi_vulnera" => "jesus_precious_blood",
    "christus_vincit" => "feast_christ_the_king",
    "te_saeculorum" => "feast_christ_the_king",
    "te_deum_simple" => "feast_all_saints",
    "te_deum" => "feast_all_saints",
    "litany_saints" => "feast_all_saints",
    "lucis_creator" => "devotion_holy_trinity",
    "da_pacem" => "topic_for_the_living",
    "veni_creator" => "glorious_pentecost",
    "veni_sancte_spiritus" => "glorious_pentecost",
    "veni_sancte_reple" => "glorious_pentecost",
    "sancte_michael" => "saint_michael",
    "ut_queant_laxis" => "saint_john_baptist_birth",
    "litany_st_joseph" => "devotion_st_joseph",
    "te_joseph" => "devotion_st_joseph",
    "rorate_caeli" => "advent_isaiah",
    "puer_natus" => "joyful_nativity",
    "jesu_redemptor" => "joyful_nativity",
    "adeste_fideles" => "christmas_shepherds",
    "attende_domine" => "season_lent",
    "parce_domine" => "season_lent",
    "media_vita" => "season_lent",
    "audi_benigne" => "season_lent",
    "miserere" => "psalm_king_david",
    "vexilla_regis" => "sorrowful_crucifixion",
    "o_vos_omnes" => "sorrowful_crucifixion",
    "victimae_paschali" => "easter_noli_me_tangere",
    "o_filii" => "easter_saint_thomas",
    "vidi_aquam" => "glorious_resurrection",
    "salve_festa_dies" => "easter_holy_women",
    "aurora_caelum" => "easter_holy_women",
    "ad_regias" => "mass_lamb_of_god",
    "jesu_nostra_redemptio" => "glorious_ascension",
    "dies_irae" => "last_judgment"
  }

  # Each section's painting beside a chant of it not named above
  # (ChantLibraryData.groupPaintings).
  @group_paintings %{
    "asperges" => "psalm_king_david",
    "mass" => "mass_lamb_of_god",
    "creed" => "topic_holy_trinity",
    "sequences" => "glorious_pentecost",
    "requiem" => "devotion_holy_souls",
    "hymns" => "jesus_eucharist_saviour",
    "ourLady" => "mary_sistine_madonna",
    "seasons" => "advent_isaiah",
    "canticles" => "topic_thanksgiving",
    "litanies" => "feast_all_saints",
    "benediction" => "topic_blessed_sacrament",
    "rosary" => "feast_our_lady_of_the_rosary"
  }

  # A section's own painting on its card and at the head of its shelf
  # (ChantGroup.painting): a neighbour of the Mass or of Our Lady takes a
  # painting of its own subject, so no two cards hang the same one.
  @section_paintings %{
    "asperges" => "luminous_baptism",
    "creed" => "devotion_holy_trinity",
    "canticles" => "joyful_visitation",
    "litanies" => "feast_all_saints"
  }

  # Where a painting is cut when its middle would lose its subject, 0 to 1
  # across and down (ChantLibraryData.focalPoints); any other is cut about
  # its middle.
  @focal_points %{
    "devotion_holy_trinity" => {0.5, 0.25},
    "mary_immaculate_conception" => {0.5, 0.25},
    "mary_sistine_madonna" => {0.5, 0.25},
    "mary_mother_of_mercy" => {0.5, 0.3},
    "mary_mount_carmel" => {0.5, 0.25},
    "feast_annunciation" => {0.7, 0.5},
    "jesus_holy_name" => {0.5, 0.2},
    "jesus_precious_blood" => {0.5, 0.35},
    "jesus_anima_christi" => {0.5, 0.3},
    "jesus_eucharist_saviour" => {0.5, 0.3},
    "season_lent" => {0.75, 0.45},
    "psalm_king_david" => {0.5, 0.25},
    "easter_noli_me_tangere" => {0.6, 0.4},
    "easter_saint_thomas" => {0.4, 0.4},
    "easter_holy_women" => {0.5, 0.45},
    "easter_appears_to_mary" => {0.5, 0.55},
    "mass_lamb_of_god" => {0.5, 0.3},
    "advent_isaiah" => {0.55, 0.25},
    "christmas_shepherds" => {0.5, 0.55},
    "saint_john_baptist_birth" => {0.65, 0.6},
    "saint_michael" => {0.5, 0.3},
    "last_judgment" => {0.5, 0.3}
  }

  # What kind of chant each is, in one word for the best match's kicker
  # in Explore's search (ChantLibraryData.forms, ChantForm.singular): a
  # short chant, a feast poem, a litany, a psalm or an everyday prayer;
  # every chant not named is a hymn, as the app's default is.
  @short_chants ~w(
    salve_regina_simple salve_regina_solemn alma_redemptoris alma_redemptoris_simple
    ave_regina_simple ave_regina_solemn regina_caeli_simple regina_caeli_solemn sub_tuum
    tota_pulchra ave_maria_antiphon o_sacrum_convivium cor_jesu rorate_caeli parce_domine
    adoremus christus_vincit vidi_aquam o_vos_omnes o_sapientia_magnificat
    o_adonai_magnificat o_radix_magnificat o_clavis_magnificat o_oriens_magnificat
    o_rex_magnificat o_emmanuel_magnificat adoramus_te da_pacem asperges_me media_vita
  )
  @feast_poems ~w(
    victimae_paschali veni_sancte_spiritus lauda_sion ecce_panis stabat_mater dies_irae
    flos_carmeli
  )
  @litanies ~w(litany_loreto litany_sacred_heart litany_holy_name litany_st_joseph litany_saints)
  @psalms ~w(magnificat miserere te_deum te_deum_simple te_matrem)
  @everyday_prayers ~w(
    in_nomine_patris credo_in_deum pater_noster ave_maria gloria_patri o_mi_jesu angelus
    sancte_michael memorare anima_christi divine_praises veni_sancte_reple kyrie_de_angelis
    gloria_de_angelis sanctus_de_angelis agnus_de_angelis credo_iii kyrie_orbis_factor
    gloria_orbis_factor sanctus_orbis_factor agnus_orbis_factor
  )
  @forms Map.new(
           Enum.map(@short_chants, &{&1, "Short chant"}) ++
             Enum.map(@feast_poems, &{&1, "Feast poem"}) ++
             Enum.map(@litanies, &{&1, "Litany"}) ++
             Enum.map(@psalms, &{&1, "Psalm"}) ++
             Enum.map(@everyday_prayers, &{&1, "Prayer"})
         )

  @fallback "mary_sistine_madonna"

  # The Mass of the Angels' tile and shelf (ChantBrowseScope.massOfTheAngels).
  @mass_of_the_angels "mass_of_the_angels"
  @mass_setting "Mass of the Angels"
  @mass_tile_painting "sorrowful_crucifixion"

  @credit "Recordings and sheet music by Verbum Gloriae"
  @library_credit "Recordings and scores by Verbum Gloriae"
  @licence_note "Shared under Verbum Gloriae's free licence, a copyleft licence. Our copies are compressed and recoloured, and they carry the same licence."
  @source_site "https://www.verbumgloriae.es"
  @licence_url "https://www.verbumgloriae.es/licencia-copyleft/"

  # Fewer letters than this find no words: every chant sings "a".
  @min_word_letters 3

  @doc "The whole library, read through the domain as `actor`."
  def load(actor) do
    Rosary.get_chant_library!(actor: actor, load: [:groups, :chants, :occasions])
    |> new()
  end

  @doc "The index over a library the domain served; its sung sets where it was read with them."
  def new(%{groups: groups, chants: chants} = library) do
    occasions =
      case Map.get(library, :occasions) do
        occasions when is_list(occasions) -> occasions
        _ -> []
      end

    %__MODULE__{
      groups: groups,
      chants: chants,
      occasions: occasions,
      by_id: Map.new(chants, &{&1.id, &1})
    }
  end

  def credit, do: @credit
  def library_credit, do: @library_credit
  def licence_note, do: @licence_note
  def source_site, do: @source_site
  def licence_url, do: @licence_url
  def mass_of_the_angels_id, do: @mass_of_the_angels

  @doc "A chant's page."
  def chant_path(id), do: "/chant/#{id}"

  @doc """
  Where the site serves a page of a chant's score, by the bucket's own
  file name: the bucket sends no CORS headers, so the full score's hook
  reads it from the site (`LumenViaeWeb.ChantScoreController`).
  """
  def score_page_path(%{url: url}), do: "/chant/scores/" <> Rosary.chant_score_page_name(url)

  @doc "A section's shelf, or the Mass of the Angels'."
  def section_path(id), do: "/chant/sections/#{id}"

  def count(%__MODULE__{chants: chants}), do: length(chants)

  def chant(%__MODULE__{by_id: by_id}, id), do: Map.get(by_id, id)

  def group(%__MODULE__{groups: groups}, id), do: Enum.find(groups, &(&1.id == id))

  @doc "The chants with these ids, in order; an id the library does not carry is skipped."
  def chants(%__MODULE__{by_id: by_id}, ids),
    do: ids |> Enum.map(&by_id[&1]) |> Enum.reject(&is_nil/1)

  @doc "A section's chants in its own order, part after part."
  def group_chants(%__MODULE__{} = library, group),
    do: Enum.flat_map(group.parts, &chants(library, &1.chant_ids))

  @doc "The Chant page's songs to Mary, in the app's order."
  def songs_to_mary(%__MODULE__{} = library), do: chants(library, @songs_to_mary)

  @doc """
  A shelf: a section by its id, or the Mass of the Angels (the Ordinary's
  first Mass). Its title, the line under it, its painting and its parts,
  each with its chants; nil for an id that is neither.
  """
  def shelf(%__MODULE__{} = library, @mass_of_the_angels) do
    with %{parts: [part | _]} <- group(library, "mass") do
      %{
        id: @mass_of_the_angels,
        title: @mass_setting,
        note: part.note && without_title(part.note),
        painting: section_painting("mass"),
        parts: [%{title: nil, note: nil, chants: chants(library, part.chant_ids)}]
      }
    end
  end

  def shelf(%__MODULE__{} = library, id) when is_binary(id) do
    case group(library, id) do
      nil ->
        nil

      group ->
        %{
          id: id,
          title: card_title(group),
          note: group.note,
          painting: section_painting(id),
          parts:
            for part <- group.parts do
              %{title: part.title, note: part.note, chants: chants(library, part.chant_ids)}
            end
        }
    end
  end

  def shelf(_library, _id), do: nil

  @doc "Every chant a shelf holds, part after part."
  def shelf_chants(%{parts: parts}), do: Enum.flat_map(parts, & &1.chants)

  @doc """
  A section's name on its card and its shelf (ChantBrowseScope.cardTitle):
  the book's own title, but Our Lady's fifty letters and Benediction's
  thirty-six take the names they are known by.
  """
  def card_title(%{id: "ourLady"}), do: "Hymns to Our Lady"
  def card_title(%{id: "benediction"}), do: "Benediction"
  def card_title(%{title: title}), do: title

  ## Paintings

  @doc "A chant's painting, `{name, focal x, focal y}`: its own, else its section's."
  def painting(%{id: id, group_id: group_id}),
    do: framed(@chant_paintings[id] || @group_paintings[group_id] || @fallback)

  @doc """
  A section's painting on its card and at the head of its shelf, cut where
  the curation says; Durer's All Saints low, so its arched top leaves no
  pale corners.
  """
  def section_painting(group_id) do
    name = @section_paintings[group_id] || @group_paintings[group_id] || @fallback

    case framed(name) do
      {"feast_all_saints", _x, _y} -> {"feast_all_saints", 0.5, 0.85}
      painting -> painting
    end
  end

  @doc """
  A painting hung across the head of a wide page: cut nearer its top
  than a square is, since a band across a desktop screen shows only a
  slice of a tall painting and the faces stand high in it.
  """
  def hero(painting)
  def hero({"feast_all_saints", _x, _y} = painting), do: painting
  def hero({name, x, y}), do: {name, x, min(y, 0.3)}

  @doc "A painting by its name with its focal point; one the site does not have hangs the fallback."
  def named_painting(name), do: framed(name)

  @doc "The Mass of the Angels' tile."
  def mass_tile_painting, do: framed(@mass_tile_painting)

  @doc "The chant paintings the site serves, for the tests: every one the rules can name."
  def painting_names do
    Enum.uniq(
      Map.values(@chant_paintings) ++
        Map.values(@group_paintings) ++
        Map.values(@section_paintings) ++ [@fallback, @mass_tile_painting]
    )
  end

  # The painting with its focal point; one the site does not have hangs
  # the fallback, so a card is never bare.
  defp framed(name) do
    name = if MysteryPainting.for_name(name), do: name, else: @fallback
    {x, y} = Map.get(@focal_points, name, {0.5, 0.5})
    {name, x, y}
  end

  @doc """
  Whether a shelf numbers its chants rather than hang a painting on each:
  every one would hang the same.
  """
  def numbers_its_chants?(chants),
    do: chants |> Enum.map(&painting/1) |> Enum.uniq() |> length() <= 1

  ## Words under a name

  @doc """
  The kind of chant it is, in the app's word for one of them ("Short
  chant", "Hymn", "Feast poem"), for the kicker over Explore's best match.
  """
  def form_name(%{id: id}), do: Map.get(@forms, id, "Hymn")

  @doc "\"1 chant\", \"8 chants\"."
  def chant_count(1), do: "1 chant"
  def chant_count(n), do: "#{n} chants"

  @doc "\"6 chants · 9 min\": the length of the recordings, never under a minute."
  def summary(chants) do
    summary(length(chants), chants |> Enum.map(& &1.duration) |> Enum.sum())
  end

  @doc "\"7 chants · 53 min\": so many chants, so many seconds, never under a minute."
  def summary(count, seconds), do: "#{chant_count(count)} · #{max(1, round(seconds / 60))} min"

  @doc "\"4:08\", rounded: a recording's length."
  def duration_label(seconds) do
    whole = round(max(seconds, 0))
    "#{div(whole, 60)}:#{whole |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end

  @doc """
  A note that opens on the shelf's own name, said without it: "The Mass of
  the Angels: for feasts, and any Sunday" reads "For feasts, and any
  Sunday".
  """
  def without_title(note) do
    with [head, rest] <- String.split(note, ": ", parts: 2),
         true <- String.contains?(String.downcase(head), String.downcase(@mass_setting)) do
      {first, tail} = String.split_at(rest, 1)
      String.upcase(first) <> tail
    else
      _ -> note
    end
  end

  @doc "The setting, where neither title already says it."
  def distinct_setting(%{setting: setting} = chant) when is_binary(setting) do
    wanted = String.downcase(setting)

    if String.contains?(String.downcase(chant.english_title), wanted) or
         String.contains?(String.downcase(chant.latin_title), wanted),
       do: nil,
       else: setting
  end

  def distinct_setting(_chant), do: nil

  @doc """
  The distinct setting after a "·": "simple melody", but a name keeps its
  capitals ("Mass of the Angels").
  """
  def setting_mid_line(chant) do
    case distinct_setting(chant) do
      nil ->
        nil

      setting ->
        named? =
          setting
          |> String.split(" ")
          |> Enum.drop(1)
          |> Enum.any?(&(&1 != "" and String.upcase(String.first(&1)) == String.first(&1)))

        if named?, do: setting, else: String.downcase(setting)
    end
  end

  @doc "\"Hail, Holy Queen · simple melody\", or the English title alone."
  def subtitle(chant, shows_setting? \\ true) do
    case shows_setting? && setting_mid_line(chant) do
      setting when is_binary(setting) -> "#{chant.english_title} · #{setting}"
      _ -> chant.english_title
    end
  end

  @doc """
  Whether a shelf's row names its chant's setting: not where a heading on
  the page already says it; a setting no heading names stays.
  """
  def says_setting?(chant, headings) do
    case setting_mid_line(chant) do
      nil ->
        false

      setting ->
        wanted = String.downcase(setting)

        headings
        |> Enum.reject(&is_nil/1)
        |> Enum.all?(&(not String.contains?(String.downcase(&1), wanted)))
    end
  end

  @doc "The other settings of the prayer a chant sings, the solemn beside the simple."
  def other_settings(%__MODULE__{}, %{prayer_ids: []}), do: []

  def other_settings(%__MODULE__{chants: chants}, chant) do
    Enum.filter(chants, fn other ->
      other.id != chant.id and Enum.any?(other.prayer_ids, &(&1 in chant.prayer_ids))
    end)
  end

  ## Search (AppSearch.chantHits, ChantCatalog.search, ChantSearch)

  @doc """
  The chants a search finds, as the app's search lists them from the Chant
  tab: by their titles, Latin or English; then by the prayer they sing,
  by its names in the Prayer Book (`prayer_names` maps a prayer's id to
  them), the settings of one work together; then by a line of what they
  sing, from three letters. Case, accents and the ligatures aside
  (`LumenViaeWeb.Live.Prayers.Book.fold/1`), each chant once.
  """
  def search(%__MODULE__{chants: chants}, query, prayer_names \\ %{}) do
    needle = query |> Book.fold() |> String.trim()

    if needle == "" do
      []
    else
      by_name =
        Enum.filter(chants, fn chant ->
          String.contains?(Book.fold(chant.latin_title), needle) or
            String.contains?(Book.fold(chant.english_title), needle)
        end)

      by_prayer =
        chants
        |> Enum.filter(fn chant ->
          Enum.any?(chant.prayer_ids, fn id ->
            prayer_names |> Map.get(id, []) |> Enum.any?(&String.contains?(Book.fold(&1), needle))
          end)
        end)
        |> by_work()

      by_words =
        if String.length(needle) >= @min_word_letters do
          Enum.filter(chants, fn chant ->
            Enum.any?(chant.lines, fn line ->
              String.contains?(Book.fold(line.latin), needle) or
                String.contains?(Book.fold(line.english), needle)
            end)
          end)
        else
          []
        end

      Enum.uniq_by(by_name ++ by_prayer ++ by_words, & &1.id)
    end
  end

  @doc "The names the search knows each prayer by: its title and its Latin title."
  def prayer_names(%Book{prayers: prayers}) do
    Map.new(prayers, fn {id, prayer} ->
      {id, Enum.reject([prayer.title, prayer.latin_title], &is_nil/1)}
    end)
  end

  # The settings of one work stand together, in the order the first of
  # each was found.
  defp by_work(chants) do
    chants
    |> Enum.group_by(&work_key/1)
    |> then(fn groups ->
      chants
      |> Enum.map(&work_key/1)
      |> Enum.uniq()
      |> Enum.flat_map(&groups[&1])
    end)
  end

  @doc "Chants of one work share this: the simple and the solemn Salve Regina."
  def work_key(chant),
    do: "#{chant.latin_title}|#{chant.prayer_ids |> Enum.sort() |> Enum.join(",")}"
end
