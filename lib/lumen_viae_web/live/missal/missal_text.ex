defmodule LumenViaeWeb.Live.Missal.MissalText do
  @moduledoc """
  The Missal's sections as the pages set them, the iOS app's
  `MissalReaderSection`, `MissalSectionsView` and `MissalOrderData`
  (and the Android app's `domain/MissalText.kt`) rule for rule.

  A day's part is named plainly ("Entrance Chant", "Prayer over the
  Gifts"), with its Latin name beside it small and dim so a reader can
  find it in a hand missal; the day's own texts (the propers) carry a
  gold diamond, and each part the posture the congregation keeps through
  it (Stand, Sit, Kneel). A part of the Order of Mass is named by its plain
  English name where the app has one ("Lord, Have Mercy" for the Kyrie),
  its own label otherwise.

  Every passage is an `[english, latin]` pair, read in the language
  chosen, as an hour of the Office is (`LumenViaeWeb.Live.Hours.OfficeText`
  cleans each line the same way):

    * `"english"` and `"latin"`: that side alone;
    * `"both"`: the Latin leading and the English with it, line for line
      where the two have as many lines, else as two blocks.

  A line wholly in asterisks ("*Ps 84:2*") is a citation, set apart; in
  Both it stands once where both sides carry it. A passage with one side
  only is a rubric of the Order of Mass (what the priest does), and the
  "– Introit in today Mass –" placeholders read as one too: each is set
  once, as a note, whatever the language.

  Pure: no fetching here.
  """

  alias LumenViaeWeb.Live.Hours.OfficeText
  alias LumenViaeWeb.Live.Prayers.PrayerText

  # The day's own parts named plainly, keyed by Missale Meum's Latin id,
  # with the posture kept through each and whether it is the day's own
  # (the Preface travels with the propers but is the Ordinary's).
  @parts %{
    "introitus" => {"Entrance Chant", :stand, true},
    "oratio" => {"Opening Prayer", :stand, true},
    "commemoratio oratio" => {"Opening Prayer · Also Remembered", :stand, true},
    "lectio" => {"First Reading", :sit, true},
    "epistola" => {"First Reading", :sit, true},
    "graduale" => {"Chant Between the Readings", :sit, true},
    "tractus" => {"Chant Between the Readings", :sit, true},
    "sequentia" => {"Feast Poem", :sit, true},
    "evangelium" => {"Gospel", :stand, true},
    "offertorium" => {"Offertory Chant", :sit, true},
    "secreta" => {"Prayer over the Gifts", :sit, true},
    "commemoratio secreta" => {"Prayer over the Gifts · Also Remembered", :sit, true},
    "prefatio" => {"Preface", :stand, false},
    "communio" => {"Communion Chant", :kneel, true},
    "postcommunio" => {"Prayer after Communion", :stand, true},
    "commemoratio postcommunio" => {"Prayer after Communion · Also Remembered", :stand, true}
  }

  # The Order of Mass's parts named plainly, keyed by its own labels.
  @ordinary %{
    "asperges" => "Sprinkling with Holy Water",
    "prayers at the foot of the altar" => "At the Foot of the Altar",
    "kyrie" => "Lord, Have Mercy",
    "gloria" => "Glory to God",
    "credo" => "The Creed",
    "offertory" => "Offertory Chant",
    "offertory prayers" => "Offertory Prayers",
    "incensing" => "Incensing",
    "lavabo" => "Washing of the Hands",
    "prayer to the most holy trinity" => "Prayer to the Holy Trinity",
    "orate fratres" => "Pray, Brethren",
    "preface" => "Preface",
    "sanctus" => "Holy, Holy, Holy",
    "canon" => "Eucharistic Prayer",
    "pater noster" => "Our Father",
    "fraction – breaking of the sacred host" => "Breaking of the Host",
    "agnus dei" => "Lamb of God",
    "prayers for holy communion" => "Prayers for Holy Communion",
    "communion of the priest" => "Communion of the Priest",
    "communion of the people" => "Communion of the People",
    "ablutions" => "Cleansing of the Vessels",
    "conclusion" => "The Mass Is Ended",
    "the last gospel" => "Closing Gospel",
    "prayers ordered by the pope leo xiii" => "Prayers after Mass"
  }

  @postures %{stand: "Stand", sit: "Sit", kneel: "Kneel"}

  @doc "The languages the Missal is read in, as the chooser lists them."
  def languages, do: OfficeText.languages()

  @doc "A language from the link: `latin` or `both`, anything else English."
  def language(value), do: OfficeText.language(value)

  @doc """
  A day's sections, each `%{id:, name:, latin:, rail_name:, proper?:,
  posture:, passages:}`, set for `language`. The first of the day's own
  parts opens on the gilt versal, as a printed missal's Introit does.
  """
  def day_sections(sections, language) do
    sections =
      sections
      |> Enum.with_index()
      |> Enum.map(fn {section, index} -> day_section(section, index, language) end)

    case Enum.find_index(sections, & &1.proper?) do
      nil -> sections
      index -> List.update_at(sections, index, &with_versal/1)
    end
  end

  @doc "The Order of Mass's sections, in the same shape, with no posture or diamond."
  def ordo_sections(sections, language) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      name = ordinary_name(section.label) || section.label || section.id || "Part"

      %{
        id: "ordo-#{index}-#{slug(name)}",
        name: name,
        latin: nil,
        rail_name: name,
        proper?: false,
        posture: nil,
        passages: Enum.map(section.body, &passage(&1, language))
      }
    end)
  end

  defp day_section(section, index, language) do
    key = key(section.id || section.label)
    {plain, posture, proper?} = part(key)
    english = plain || section.label || section.id || "Part"
    latin = section.id

    %{
      id: "missal-#{index}-#{slug(latin || english)}",
      name: english,
      latin: if(latin && String.downcase(latin) != String.downcase(english), do: latin),
      rail_name: english,
      proper?: proper?,
      posture: posture && @postures[posture],
      passages: Enum.map(section.body, &passage(&1, language))
    }
  end

  # A part by its key, or by the head of it: Missale Meum names a second
  # lesson "Lectio 2" and a seasonal variant "Graduale (Allelúja)". A part
  # the tables do not know reads as the day's own, with no posture.
  defp part(key) do
    head = key |> String.split(~r/[^\p{L} ]/u) |> List.first() |> String.trim()
    Map.get(@parts, key) || Map.get(@parts, head) || {nil, nil, true}
  end

  defp ordinary_name(nil), do: nil
  defp ordinary_name(label), do: Map.get(@ordinary, key(label))

  defp key(nil), do: ""
  defp key(name), do: name |> String.trim() |> String.downcase()

  # -- Passages -----------------------------------------------------------------

  @doc """
  One passage set for `language`: `{:note, text}` for a rubric, or
  `{:single, side, items}`, `{:paired, items}` or `{:blocks, latin_items,
  english_items}`. An item is `{:citation, text}` or `{:line, runs}`, and
  in a paired passage `{:pair, latin_runs, english_runs}`.
  """
  def passage([english, latin], language) do
    if rubric?(english, latin) do
      {:note, String.trim(english)}
    else
      body(lines(english, :english), lines(latin, :latin), language)
    end
  end

  def passage([text], _language),
    do: {:note, text |> String.trim() |> String.replace(~r/\s*\n\s*/u, " ")}

  # The Order of Mass's "– Introit in today Mass –", the same on both sides.
  defp rubric?(english, latin) do
    english = String.trim(english)

    english == String.trim(latin) and String.starts_with?(english, "–") and
      String.ends_with?(english, "–")
  end

  defp body(english, [], _language), do: {:single, :english, items(english)}
  defp body([], latin, _language), do: {:single, :latin, items(latin)}
  defp body(english, _latin, "english"), do: {:single, :english, items(english)}
  defp body(_english, latin, "latin"), do: {:single, :latin, items(latin)}

  defp body(english, latin, "both") when length(english) == length(latin) do
    {:paired,
     Enum.zip_with(latin, english, fn la, en ->
       case {citation(la), citation(en)} do
         {nil, _} -> {:pair, runs(la), runs(en)}
         {_, nil} -> {:pair, runs(la), runs(en)}
         {cited, _} -> {:citation, cited}
       end
     end)}
  end

  defp body(english, latin, "both"), do: {:blocks, items(latin), items(english)}

  defp items(lines) do
    Enum.map(lines, fn line ->
      case citation(line) do
        nil -> {:line, runs(line)}
        cited -> {:citation, cited}
      end
    end)
  end

  defp lines(text, side) do
    text
    |> String.split("\n")
    |> Enum.map(&(&1 |> String.trim() |> OfficeText.normalized(side)))
    |> Enum.reject(&(&1 == ""))
  end

  # A line wholly in asterisks: "*Ps 84:2*".
  defp citation(line) do
    if String.length(line) > 2 and String.starts_with?(line, "*") and
         String.ends_with?(line, "*"),
       do: line |> String.slice(1..-2//1) |> String.trim()
  end

  defp runs(line), do: PrayerText.runs(line)

  # The versal on the first line of the first passage that has one.
  defp with_versal(section) do
    {passages, _done} =
      Enum.map_reduce(section.passages, false, fn
        passage, true -> {passage, true}
        passage, false -> versal(passage)
      end)

    %{section | passages: passages}
  end

  defp versal({:single, side, items}) do
    {items, done} = versal_items(items)
    {{:single, side, items}, done}
  end

  defp versal({:paired, items}) do
    {items, done} = versal_items(items)
    {{:paired, items}, done}
  end

  defp versal({:blocks, latin, english}) do
    {latin, done} = versal_items(latin)
    {{:blocks, latin, english}, done}
  end

  defp versal(passage), do: {passage, false}

  defp versal_items(items) do
    Enum.map_reduce(items, false, fn
      {:line, runs}, false -> {{:versal, runs}, true}
      {:pair, la, en}, false -> {{:versal_pair, la, en}, true}
      item, done -> {item, done}
    end)
  end

  defp slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, "-")
    |> String.trim("-")
  end
end
