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
  alias LumenViaeWeb.Components.MysteryPainting

  defstruct chapters: [], prayers: %{}, antiphons: [], orders: []

  @type t :: %__MODULE__{
          chapters: [map()],
          prayers: %{String.t() => map()},
          antiphons: [map()],
          orders: [map()]
        }

  # The first prayers, a row each under Everyday Prayers.
  @everyday_ids ~w(our_father hail_mary glory_be apostles_creed)

  # Her best-known prayers, on the shelf after the season's song to Mary.
  @best_known_marian_ids ~w(hail_mary memorare litany_loreto)

  # The prayers that go by their Latin name, whose Latin is set beneath
  # (or, on a prayer's page, above) the English title
  # (PrayerBook.latinNamesKnown). Any other Latin title only translates the
  # English one and is not drawn.
  @latin_names_known MapSet.new(~w(
    our_father hail_mary glory_be hail_holy_queen
    angele_dei visita_quaesumus in_manus_tuas nunc_dimittis benedictus
    magnificat te_deum confiteor requiem_aeternam de_profundis
    beati_quorum miserere domine_non_sum_dignus anima_christi suscipe
    adoro_te o_sacrum_convivium ave_verum o_salutaris tantum_ergo
    veni_creator veni_sancte_spiritus sub_tuum ave_maris_stella
    alma_redemptoris ave_regina_caelorum regina_caeli inviolata salve_mater
    tota_pulchra flos_carmeli stabat_mater totus_tuus ad_te_beate_ioseph
    actiones_nostras da_pacem
  ))

  # Prayers printed in more than one topic whose home is not the first of
  # them (PrayerBook.homes): without these the Hail, Holy Queen would be
  # headed Holy Mass and Communion.
  @homes %{
    "angele_dei" => "saints",
    "angelus" => "our_lady",
    "regina_caeli" => "our_lady",
    "miraculous_medal" => "our_lady",
    "mary_after_communion" => "our_lady",
    "hail_holy_queen" => "our_lady",
    "requiem_aeternam" => "departed",
    "st_gertrude" => "departed",
    "come_holy_ghost" => "holy_ghost",
    "spiritual_communion" => "sacrament",
    "anima_christi" => "our_lord",
    "en_ego" => "our_lord",
    "suscipe" => "our_lord",
    "st_michael_prayer" => "saints",
    "st_patrick_breastplate" => "saints",
    "st_francis_before_crucifix" => "saints",
    "rosary_closing_prayer" => "church",
    "te_deum" => "thanks"
  }

  # The five parts of the book the topics are gathered into, each a shelf
  # under All Topics (PrayerBookPart, and each chapter's part in
  # PrayerBook's layouts). A topic not named here stands in the last.
  @parts [
    {"Every Day", ~w(first day short)},
    {"The Sacraments", ~w(mass penance sacrament)},
    {"God, Our Lady and the Saints", ~w(holy_ghost our_lord our_lady st_joseph saints)},
    {"Through the Year", ~w(seasons thanks litanies)},
    {"For Others, and in Need", ~w(church sick departed needs)}
  ]

  @first_chapter "first"
  @our_lady_chapter "our_lady"

  @search_stop ~w(a an and of the to o for in on at)
  @topic_stop ~w(a an and at for in of on the to with pray prayer prayers)

  @doc "The whole book, read through the domain as `actor`."
  def load(actor) do
    Rosary.get_prayer_book!(actor: actor, load: [:chapters, :prayers, :marian_antiphons, :orders])
    |> new()
  end

  @doc "The index over a book the domain served; its orders of prayer when loaded."
  def new(%{chapters: chapters, prayers: prayers, marian_antiphons: antiphons} = book) do
    %__MODULE__{
      chapters: chapters,
      prayers: Map.new(prayers, &{&1.id, &1}),
      antiphons: antiphons,
      orders: if(is_list(Map.get(book, :orders)), do: book.orders, else: [])
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

  @doc """
  The prayer's home topic: the one `PrayerBook.homes` names for it, where
  that topic prints it, else the first topic that does.
  """
  def home_chapter(%__MODULE__{chapters: chapters} = book, prayer_id) do
    named = @homes[prayer_id] && chapter(book, @homes[prayer_id])

    if named && prayer_id in named.prayer_ids,
      do: named,
      else: Enum.find(chapters, &(prayer_id in &1.prayer_ids))
  end

  @doc """
  The book's five parts, each `%{title:, chapters:}` with its topics in
  the book's order, as All Topics shelves them.
  """
  def parts(%__MODULE__{chapters: chapters}) do
    named = @parts |> Enum.flat_map(&elem(&1, 1)) |> MapSet.new()
    last = length(@parts) - 1

    @parts
    |> Enum.with_index()
    |> Enum.map(fn {{title, ids}, i} ->
      %{
        title: title,
        chapters: Enum.filter(chapters, &(&1.id in ids or (i == last and &1.id not in named)))
      }
    end)
  end

  @doc "The chapters either side of this one, each nil at an end."
  def neighbours(list, item) do
    case Enum.find_index(list, &(&1 == item)) do
      nil -> {nil, nil}
      0 -> {nil, Enum.at(list, 1)}
      i -> {Enum.at(list, i - 1), Enum.at(list, i + 1)}
    end
  end

  @doc "The prayer's name in a list, as most people say it (\"Hail Mary\")."
  def list_name(%{list_title: list_title, title: title}), do: list_title || title

  @doc """
  The prayer's second name (BookPrayer.secondTitle): its English for the
  one titled in Latin ("Memorare"), else its Latin only where the prayer
  goes by that name (`PrayerBook.latinNamesKnown`), never the name said
  twice. Everywhere else, nil.
  """
  def second_title(%{english_name: english}) when is_binary(english), do: english

  def second_title(%{id: id, latin_title: latin, title: title}) when is_binary(latin) do
    if MapSet.member?(@latin_names_known, id) and not same_name?(latin, title),
      do: latin,
      else: nil
  end

  def second_title(_prayer), do: nil

  @doc "Whether the second name is the Latin one, for its `lang`."
  def second_title_latin?(%{english_name: english}), do: not is_binary(english)

  ## The season's song to Mary

  @doc """
  The visitor's date from the offset the `UserTimezone` hook sends
  (minutes, positive west of UTC, as `Date.getTimezoneOffset()`), or
  `:error` for anything that is not one. Before it comes, the pages use
  the server's date.
  """
  def local_date(offset) when is_integer(offset) and abs(offset) <= 24 * 60 do
    {:ok, DateTime.utc_now() |> DateTime.add(-offset * 60, :second) |> DateTime.to_date()}
  end

  def local_date(_offset), do: :error

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

    seasonal =
      case seasonal_id && prayer(book, seasonal_id) do
        nil ->
          []

        prayer ->
          [
            %{
              prayer: prayer,
              note: "This season",
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
          note: prayer.english_name,
          painting: prayer_painting(book, id),
          seasonal?: false
        }
      end

    seasonal ++ known
  end

  ## Paintings (PrayerBookPaintings.swift)

  # Every painting is `{name, focal x, focal y}`: the iOS asset and where
  # its subject sits, served from priv/static/images/paintings as the app
  # bundles it. A scene the website lacks hangs its topic's painting, as
  # iOS hangs a topic's painting on a prayer with no scene of its own.

  # A topic's painting, on its card in All Topics and at the head of its page.
  @topics %{
    "first" => {"topic_first_prayers", 0.5, 0.3},
    "day" => {"topic_daily_prayers", 0.5, 0.45},
    "short" => {"topic_short_prayers", 0.5, 0.3},
    "mass" => {"topic_holy_mass", 0.5, 0.5},
    "penance" => {"topic_confession", 0.5, 0.35},
    "sacrament" => {"topic_blessed_sacrament", 0.5, 0.45},
    "holy_ghost" => {"topic_holy_trinity", 0.5, 0.2},
    "our_lord" => {"topic_our_lord", 0.5, 0.25},
    "our_lady" => {"season_advent", 0.5, 0.25},
    "st_joseph" => {"devotion_st_joseph", 0.5, 0.2},
    "saints" => {"devotion_guardian_angels", 0.5, 0.3},
    "seasons" => {"topic_feasts_seasons", 0.5, 0.4},
    "thanks" => {"topic_thanksgiving", 0.5, 0.3},
    "litanies" => {"feast_all_saints", 0.5, 0.3},
    "church" => {"topic_for_the_living", 0.5, 0.6},
    "sick" => {"topic_sick_dying", 0.5, 0.55},
    "departed" => {"devotion_holy_souls", 0.5, 0.4},
    "needs" => {"topic_needs", 0.5, 0.35}
  }

  # Over a prayer with no topic, as iOS hangs Our Lady at prayer.
  @saved {"glorious_assumption", 0.5, 0.3}

  # Each prayer's scene (PrayerBookPainting.scenes), as iOS names them.
  @scenes (
            trinity = {"devotion_holy_trinity", 0.5, 0.3}
            nicene = {"topic_holy_trinity", 0.5, 0.2}
            pentecost = {"glorious_pentecost", 0.5, 0.3}
            rosary = {"feast_our_lady_of_the_rosary", 0.5, 0.3}
            prodigal = {"topic_confession", 0.5, 0.35}
            immaculate = {"mary_immaculate_conception", 0.5, 0.25}
            at_prayer = {"mary_virgin_in_prayer", 0.5, 0.35}
            mercy = {"mary_mother_of_mercy", 0.5, 0.3}
            carmel = {"mary_mount_carmel", 0.5, 0.25}
            sorrows = {"mary_mater_dolorosa", 0.45, 0.35}
            holy_name = {"jesus_holy_name", 0.5, 0.2}
            sacred_heart = {"topic_our_lord", 0.5, 0.25}
            blood = {"jesus_precious_blood", 0.5, 0.35}
            host = {"jesus_eucharist_saviour", 0.5, 0.3}
            joseph = {"devotion_st_joseph", 0.5, 0.2}
            carpenter = {"saint_joseph_carpenter", 0.5, 0.4}
            happy_death = {"topic_sick_dying", 0.5, 0.55}
            family = {"prayer_holy_family", 0.6, 0.4}
            aquinas = {"saint_thomas_aquinas", 0.5, 0.3}
            david = {"psalm_king_david", 0.5, 0.25}
            night = {"hour_night", 0.5, 0.4}
            blind = {"jesus_healing_blind", 0.5, 0.4}
            angel = {"devotion_guardian_angels", 0.5, 0.3}
            baptism = {"luminous_baptism", 0.5, 0.3}
            teresa = {"saint_teresa_purgatory", 0.5, 0.35}
            mond = {"crucifixion_mond", 0.5, 0.3}
            francis = {"saint_francis_desert", 0.6, 0.6}
            ignatius = {"saint_ignatius", 0.5, 0.3}
            emmaus = {"prayer_supper_emmaus", 0.5, 0.35}
            healing = {"prayer_healing_sick", 0.45, 0.4}
            all_saints = {"feast_all_saints", 0.5, 0.3}
            annunciation = {"joyful_annunciation", 0.5, 0.18}
            good_shepherd = {"jesus_good_shepherd", 0.4, 0.45}
            washing = {"jesus_washing_feet", 0.5, 0.4}
            bernard = {"jesus_anima_christi", 0.5, 0.3}
            crucified = {"sorrowful_crucifixion", 0.5, 0.3}
            visitation = {"joyful_visitation", 0.5, 0.3}
            calvary = {"seven_sorrows_calvary", 0.5, 0.35}
            disputation = {"topic_blessed_sacrament", 0.5, 0.45}
            bolsena = {"topic_holy_mass", 0.5, 0.5}
            last_supper = {"luminous_eucharist", 0.5, 0.35}
            feast_annunciation = {"feast_annunciation", 0.7, 0.5}
            sistine = {"mary_sistine_madonna", 0.5, 0.25}
            maino = {"pentecost_maino", 0.5, 0.3}

            %{
              # The First Prayers
              "sign_of_cross" => trinity,
              "our_father" => {"luminous_proclamation", 0.5, 0.3},
              "hail_mary" => annunciation,
              "glory_be" => trinity,
              "fatima_prayer" => rosary,
              "apostles_creed" => pentecost,
              "nicene_creed" => nicene,
              "act_of_contrition" => prodigal,
              # Daily Prayers
              "morning_offering" => {"hour_morning", 0.5, 0.35},
              "benedictus" => {"saint_john_baptist_birth", 0.65, 0.6},
              "grace_before" => emmaus,
              "grace_after" => last_supper,
              "actiones_nostras" => carpenter,
              "aquinas_before_study" => aquinas,
              "examen" => night,
              "in_manus_tuas" => night,
              "nunc_dimittis" => {"joyful_presentation", 0.5, 0.3},
              "visita_quaesumus" => family,
              # Short Prayers
              "sweet_heart" => sacred_heart,
              "sacred_heart_trust" => good_shepherd,
              "jesus_meek" => washing,
              "my_lord_and_my_god" => {"easter_saint_thomas", 0.4, 0.4},
              "o_sacrament_most_holy" => host,
              "blessed_be_conception" => {"season_advent", 0.5, 0.25},
              "totus_tuus" => at_prayer,
              "st_joseph_pray" => joseph,
              "jmj" => family,
              "jmj_heart_and_soul" => happy_death,
              "holy_spirit_enlighten" => pentecost,
              # Holy Mass and Communion
              "aquinas_before_mass" => aquinas,
              "domine_non_sum_dignus" => host,
              "aquinas_after_mass" => aquinas,
              # Confession
              "miserere" => david,
              "beati_quorum" => david,
              # The Blessed Sacrament
              "adoro_te" => disputation,
              "spiritual_communion" => {"communion_of_apostles", 0.5, 0.5},
              "o_sacrum_convivium" => {"last_supper_juanes", 0.5, 0.35},
              "ave_verum" => {"mass_lamb_of_god", 0.5, 0.3},
              # The Holy Spirit
              "come_holy_ghost" => pentecost,
              "veni_creator" => maino,
              "veni_sancte_spiritus" => pentecost,
              # Our Lord
              "litany_holy_name" => holy_name,
              "jesus_prayer" => blind,
              "golden_arrow" => holy_name,
              "infant_of_prague" => good_shepherd,
              "litany_sacred_heart" => sacred_heart,
              "consecration_sacred_heart" => {"jesus_light_of_the_world", 0.5, 0.3},
              "reparation_sacred_heart" => {"sorrowful_crowning", 0.5, 0.3},
              "efficacious_novena" => sacred_heart,
              "litany_precious_blood" => blood,
              "precious_blood_offering" => mond,
              "en_ego" => crucified,
              "st_bridget_twelve_years" => blood,
              "christ_the_king" => {"feast_christ_the_king", 0.5, 0.3},
              "anima_christi" => bernard,
              # Our Lady
              "hail_holy_queen" => {"glorious_coronation", 0.5, 0.12},
              "litany_loreto" => sistine,
              "alma_redemptoris" => {"joyful_nativity", 0.5, 0.35},
              "ave_regina_caelorum" => {"glorious_assumption", 0.5, 0.3},
              "regina_caeli" => {"easter_appears_to_mary", 0.5, 0.55},
              "magnificat" => {"topic_thanksgiving", 0.5, 0.3},
              "ave_maris_stella" => feast_annunciation,
              "inviolata" => immaculate,
              "salve_mater" => mercy,
              "tota_pulchra" => immaculate,
              "flos_carmeli" => carmel,
              "angelus" => annunciation,
              "sub_tuum" => mercy,
              "memorare" => {"glorious_assumption", 0.5, 0.3},
              "o_domina_mea" => at_prayer,
              "three_hail_marys" => feast_annunciation,
              "miraculous_medal" => immaculate,
              "mary_after_communion" => visitation,
              "perpetual_help" => mercy,
              "our_lady_of_good_counsel" => sistine,
              "our_lady_of_lourdes" => immaculate,
              "immaculate_heart" => at_prayer,
              "mary_help_of_christians" => mercy,
              "our_lady_of_mount_carmel" => carmel,
              "stabat_mater" => calvary,
              "our_lady_of_sorrows" => sorrows,
              "litany_seven_sorrows" => {"seven_sorrows_pieta", 0.5, 0.35},
              "sorrows_closing_prayer" => calvary,
              # St Joseph
              "ad_te_beate_ioseph" => joseph,
              "memorare_st_joseph" => family,
              "litany_st_joseph" => joseph,
              "st_joseph_workers" => carpenter,
              "st_joseph_happy_death" => happy_death,
              # Angels and Saints
              "angele_dei" => angel,
              "st_michael_prayer" => {"saint_michael", 0.5, 0.3},
              "litany_of_the_saints" => all_saints,
              "st_anne" => {"topic_first_prayers", 0.5, 0.3},
              "st_anthony" => {"saint_anthony", 0.5, 0.35},
              "st_peregrine" => crucified,
              "st_dominic_o_lumen" => rosary,
              "st_francis_before_crucifix" => {"topic_short_prayers", 0.5, 0.3},
              # Thanksgiving
              "te_deum" => all_saints,
              # For the Church and the Living
              "prayer_for_priests" => bolsena,
              "conversion_of_sinners" => {"saint_paul_conversion", 0.5, 0.6},
              "rosary_closing_prayer" => rosary,
              "prayer_for_family" => family,
              "parents_for_children" => {"children_blessed", 0.5, 0.4},
              # The Sick and the Dying
              "prayer_for_the_sick" => healing,
              "happy_death" => night,
              # In Time of Need
              "prayer_for_travel" => {"prayer_tobias_angel", 0.5, 0.3},
              # The rest, each its own scene
              "act_of_faith" => {"virtue_faith_isaac", 0.45, 0.3},
              "act_of_hope" => {"virtue_hope_dove", 0.5, 0.2},
              "act_of_charity" => {"virtue_charity_samaritan", 0.5, 0.5},
              "after_confession" => healing,
              "angels_prayer_fatima" => angel,
              "pardon_prayer" => angel,
              "before_confession" => {"saint_peter_tears", 0.5, 0.3},
              "examination_of_conscience" => night,
              "the_confession" => {"christ_and_the_adulteress", 0.4, 0.4},
              "confiteor" => {"saint_jerome_penitent", 0.5, 0.3},
              "breathe_in_me" => baptism,
              "seven_gifts" => nicene,
              "secret_of_sanctity" => maino,
              "litany_holy_ghost" => baptism,
              "st_patrick_breastplate" => nicene,
              "da_pacem" => {"shepherds_annunciation", 0.5, 0.25},
              "de_profundis" => david,
              "requiem_aeternam" => {"last_judgment", 0.5, 0.3},
              "fidelium_deus" => teresa,
              "deceased_parents" => {"devotion_holy_souls", 0.5, 0.4},
              "st_gertrude" => {"saint_gertrude", 0.5, 0.35},
              "divine_mercy_chaplet" => mond,
              "jesus_i_trust_in_thee" => {"topic_needs", 0.5, 0.35},
              "my_jesus_mercy" => blind,
              "my_jesus_i_love_thee" => bernard,
              "my_god_and_my_all" => francis,
              "peace_prayer" => francis,
              "divine_praises" => disputation,
              "litany_blessed_sacrament" => host,
              "st_alphonsus_visit" => host,
              "o_salutaris" => bolsena,
              "tantum_ergo" => last_supper,
              "lead_kindly_light" => {"topic_feasts_seasons", 0.5, 0.4},
              "newman_definite_service" => {"saint_matthew_calling", 0.3, 0.45},
              "litany_of_humility" => washing,
              "nada_te_turbe" => teresa,
              "abandonment_foucauld" => {"sorrowful_agony", 0.5, 0.3},
              "generosity_ignatius" => ignatius,
              "suscipe" => ignatius,
              "o_jesus_living_in_mary" => visitation,
              "radiating_christ" => {"luminous_transfiguration", 0.5, 0.25},
              "st_richard" => {"apostles_calling_duccio", 0.5, 0.45},
              "prayer_for_our_country" => {"tribute_money", 0.5, 0.35},
              "prayer_for_the_pope" => {"topic_for_the_living", 0.5, 0.6},
              "st_jude" => {"saint_jude", 0.5, 0.3},
              "st_benedict_medal" => {"saint_benedict", 0.4, 0.35},
              "st_ambrose_before_mass" => {"saint_ambrose", 0.5, 0.3},
              "transfige" => {"saint_bonaventure", 0.5, 0.4}
            }
          )

  @doc "A topic's painting, `{painting name, focal x, focal y}`, by the topic's id."
  def topic_painting(chapter_id),
    do: resolve(@topics[chapter_id] || @topics[@first_chapter])

  @doc """
  A prayer's painting on a row, a shelf or its page: its scene where the
  website has it, else its topic's painting.
  """
  def prayer_painting(%__MODULE__{} = book, prayer_id) do
    with scene when not is_nil(scene) <- @scenes[prayer_id],
         painting when not is_nil(painting) <- resolve(scene) do
      painting
    else
      _ ->
        case home_chapter(book, prayer_id) do
          nil -> @saved
          chapter -> topic_painting(chapter.id)
        end
    end
  end

  @doc "The painting over a season's song to Mary, by the day its season begins."
  def antiphon_painting("advent_eve"), do: {"joyful_nativity", 0.5, 0.35}
  def antiphon_painting("february_2"), do: {"glorious_assumption", 0.5, 0.3}
  def antiphon_painting("easter"), do: resolve({"easter_appears_to_mary", 0.5, 0.55})
  def antiphon_painting(_begins), do: {"glorious_coronation", 0.5, 0.12}

  # The asset itself where the website has it, else nil.
  defp resolve({asset, _x, _y} = painting) do
    if MysteryPainting.for_name(asset), do: painting
  end

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

  @doc """
  The words a search asks for, as `search/2` reads them: folded, the
  small words let go unless they are all there is.
  """
  def search_terms(needle), do: search_words(needle, false)

  @doc """
  Whether a name answers the words searched (`search_terms/1`): every word
  begins one of the name's words, "st" and "saint" one word.
  """
  def name_answers?(wanted, name) do
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
