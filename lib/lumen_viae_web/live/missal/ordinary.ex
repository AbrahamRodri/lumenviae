defmodule LumenViaeWeb.Live.Missal.Ordinary do
  @moduledoc """
  The day's Mass with the Ordinary let into its places, the iOS app's
  `MissalOrderData.readerSections` rule for rule: the Whole Mass of the
  app's Contents choice ("With the Ordinary"), against Today's texts only.

  The propers keep the order Missale Meum serves them in; the Order of
  Mass's parts (`LumenViae.Office.fetch_order_of_mass/0`, the text the
  Order of Mass page reads) stand at their fixed places among them, both
  on one scale of stations, so a day that lacks a proper loses only that
  part. A section the tables do not know keeps the station of the one
  before it, so an unusual rite stays where Missale Meum put it.

  The parts that vary are decided by the day and by whether the Mass is
  sung, as iOS decides them:

    * the Asperges opens a sung Mass on a Sunday;
    * the Gloria falls away with violet, black or rose vestments;
    * the Credo belongs to Sundays and the greater feasts (class I and II);
    * the incensing belongs to the sung Mass, the Prayers after Mass
      (Leo XIII's) to the spoken one;
    * the Offertory's dialogue opens the day's Offertory verse, or stands
      alone where the day has none;
    * the Preface's dialogue stands before the day's own Preface and the
      Sanctus after it; a day with no Preface of its own reads the Common
      Preface.

  Only the Order of Mass's prayers are woven in: its rubrics (one-sided
  passages) and its "– Introit in today Mass –" placeholders are left to
  the Order of Mass page. With no Order of Mass to hand, the day's texts
  stand alone.

  Each entry is `{:proper, index, section}`, the day's section at its
  index in Missale Meum's list (an Offertory verse with the dialogue
  before its passages), or `{:ordinary, part}`, `%{latin:, name:,
  posture:, body:}`. Pure: no fetching here.
  """

  # {Order of Mass label, Latin name, plain name, posture, nil for every
  # Mass, true for the sung Mass only, false for the spoken Mass only}
  @asperges {"asperges", "Asperges", "Sprinkling with Holy Water", :stand, true}

  @fore_mass [
    {"prayers at the foot of the altar", "At the Foot of the Altar", "At the Foot of the Altar",
     :kneel, nil}
  ]

  @kyrie {"kyrie", "Kyrie", "Lord, Have Mercy", :stand, nil}
  @gloria {"gloria", "Gloria", "Glory to God", :stand, nil}
  @credo {"credo", "Credo", "The Creed", :stand, nil}

  @after_offertory [
    {"offertory prayers", "Offertory Prayers", "Offertory Prayers", :sit, nil},
    {"incensing", "Incensing", "Incensing", :sit, true},
    {"lavabo", "Lavabo", "Washing of the Hands", :sit, nil},
    {"prayer to the most holy trinity", "Súscipe, Sancta Trínitas", "Prayer to the Holy Trinity",
     :sit, nil},
    {"orate fratres", "Oráte, Fratres", "Pray, Brethren", :sit, nil}
  ]

  @canon {"canon", "Canon Missæ", "Eucharistic Prayer", :kneel, nil}

  @after_canon [
    {"fraction – breaking of the sacred host", "Fractio", "Breaking of the Host", :kneel, nil},
    {"agnus dei", "Agnus Dei", "Lamb of God", :kneel, nil},
    {"prayers for holy communion", "Prayers for Holy Communion", "Prayers for Holy Communion",
     :kneel, nil},
    {"communion of the priest", "Communion of the Priest", "Communion of the Priest", :kneel,
     nil},
    {"communion of the people", "Communion of the People", "Communion of the People", :kneel,
     nil},
    {"ablutions", "Ablutiones", "Cleansing of the Vessels", :sit, nil}
  ]

  @closing [
    {"conclusion", "Ite, Missa Est", "The Mass Is Ended", :stand, nil},
    {"the last gospel", "Ultimum Evangélium", "Closing Gospel", :stand, nil},
    {"prayers ordered by the pope leo xiii", "Preces Leoninæ", "Prayers after Mass", :kneel,
     false}
  ]

  # Where each part stands in the fixed order of the Mass.
  @station %{
    asperges: 10,
    fore_mass: 20,
    introit: 30,
    kyrie: 40,
    gloria: 50,
    collect: 60,
    epistle: 70,
    gradual: 80,
    gospel: 90,
    credo: 100,
    offertory_dialogue: 105,
    offertory: 110,
    offertory_prayers: 120,
    secret: 130,
    sursum_corda: 140,
    preface: 150,
    sanctus: 160,
    canon: 170,
    pater_noster: 180,
    fraction: 190,
    communion: 200,
    postcommunion: 210,
    closing: 220
  }

  # The station of each proper Missale Meum serves, by its Latin id.
  @proper_stations %{
    "introitus" => @station.introit,
    "oratio" => @station.collect,
    "commemoratio oratio" => @station.collect,
    "lectio" => @station.epistle,
    "epistola" => @station.epistle,
    "graduale" => @station.gradual,
    "tractus" => @station.gradual,
    "sequentia" => @station.gradual,
    "evangelium" => @station.gospel,
    "offertorium" => @station.offertory,
    "secreta" => @station.secret,
    "commemoratio secreta" => @station.secret,
    "prefatio" => @station.preface,
    "communio" => @station.communion,
    "postcommunio" => @station.postcommunion,
    "commemoratio postcommunio" => @station.postcommunion
  }

  @doc """
  The day's Mass as entries (see the moduledoc). `ordo` nil or empty
  leaves the propers alone; `opts` are `:date` (a Sunday decides the
  Asperges and the Credo) and `:sung?`.
  """
  def weave(propers, ordo, mass, opts \\ [])

  def weave(propers, ordo, _mass, _opts) when ordo in [nil, []],
    do: propers |> Enum.with_index() |> Enum.map(fn {s, i} -> {:proper, i, s} end)

  def weave(propers, ordo, mass, opts) do
    date = Keyword.fetch!(opts, :date)
    sung? = Keyword.get(opts, :sung?, false)
    keys = Enum.map(propers, &key/1)
    carried = MapSet.new(keys)
    preface = body(ordo, "preface")

    pending =
      [
        {@station.asperges, if(sung? and sunday?(date), do: [@asperges], else: [])},
        {@station.fore_mass, @fore_mass},
        {@station.kyrie, [@kyrie]},
        {@station.gloria, if(gloria?(mass), do: [@gloria], else: [])},
        {@station.credo, if(credo?(mass, date), do: [@credo], else: [])},
        {@station.offertory_prayers, @after_offertory},
        {@station.canon, [@canon]},
        {@station.fraction, @after_canon},
        {@station.closing, @closing}
      ]
      |> Enum.map(fn {station, parts} ->
        {station,
         for(part <- parts, belongs?(part, sung?), p = part(part, ordo), p != nil, do: p)}
      end)
      |> Kernel.++([
        {@station.offertory_dialogue,
         if(MapSet.member?(carried, "offertorium"),
           do: [],
           else: made("Offertorium", "Offertory Chant", :sit, body(ordo, "offertory"))
         )},
        {@station.sursum_corda,
         made("Sursum Corda", "Lift Up Your Hearts", :stand, Enum.take(preface, 1))},
        {@station.preface,
         if(MapSet.member?(carried, "prefatio") or length(preface) < 3,
           do: [],
           else:
             made(
               "Præfatio Communis",
               "Common Preface",
               :stand,
               preface |> Enum.drop(1) |> Enum.drop(-1)
             )
         )},
        {@station.sanctus,
         if(length(preface) >= 2,
           do: made("Sanctus", "Holy, Holy, Holy", :kneel, Enum.take(preface, -1)),
           else: []
         )},
        {@station.pater_noster,
         made(
           "Pater Noster",
           "Our Father",
           :kneel,
           body(ordo, "communion") ++ body(ordo, "pater noster")
         )}
      ])
      |> Enum.sort_by(&elem(&1, 0))

    offertory_prefix = body(ordo, "offertory")

    {entries, pending, _station} =
      propers
      |> Enum.zip(keys)
      |> Enum.with_index()
      |> Enum.reduce({[], pending, 0}, fn {{section, key}, index}, {entries, pending, station} ->
        station = Map.get(@proper_stations, key, station)
        {due, pending} = Enum.split_while(pending, fn {s, _parts} -> s < station end)

        section =
          if key == "offertorium",
            do: %{section | body: offertory_prefix ++ section.body},
            else: section

        {entries ++ ordinary(due) ++ [{:proper, index, section}], pending, station}
      end)

    entries ++ ordinary(pending)
  end

  @doc "Whether the day says the Gloria: not in violet, black or rose."
  def gloria?(mass) do
    case mass do
      %{colors: [first | _rest]} -> first not in ["v", "b", "p"]
      _no_colour -> true
    end
  end

  @doc "Whether the day says the Credo: a Sunday, or a feast of the first or second class."
  def credo?(mass, %Date{} = date) do
    sunday?(date) or match?(%{rank: rank} when is_integer(rank) and rank <= 2, mass)
  end

  defp sunday?(date), do: Date.day_of_week(date) == 7

  defp belongs?({_label, _latin, _name, _posture, nil}, _sung?), do: true
  defp belongs?({_label, _latin, _name, _posture, sung_only}, sung?), do: sung_only == sung?

  defp part({label, latin, name, posture, _when}, ordo) do
    case body(ordo, label) do
      [] -> nil
      passages -> %{latin: latin, name: name, posture: posture, body: passages}
    end
  end

  defp made(_latin, _name, _posture, []), do: []

  defp made(latin, name, posture, body),
    do: [%{latin: latin, name: name, posture: posture, body: body}]

  defp ordinary(due), do: for({_station, parts} <- due, part <- parts, do: {:ordinary, part})

  # The prayers of one part of the Order of Mass, by its label: its
  # rubrics and its placeholders left out.
  defp body(ordo, label) do
    case Enum.find(ordo, &(key_of(&1.label) == label)) do
      nil -> []
      section -> Enum.filter(section.body, &prayer?/1)
    end
  end

  defp prayer?([first, _second]) do
    first = String.trim(first)
    not (String.starts_with?(first, "–") and String.ends_with?(first, "–"))
  end

  defp prayer?(_one_side), do: false

  defp key(section), do: key_of(section.id || section.label)

  defp key_of(nil), do: ""
  defp key_of(name), do: name |> String.trim() |> String.downcase()
end
