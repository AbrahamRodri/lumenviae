defmodule LumenViaeWeb.Live.Hours.DayRank do
  @moduledoc """
  A day's class, read off the engine's own wording ("I. classis",
  "III. classis", none for a feria) and said in plain words, as the iOS
  app's `OfficeRank` and `DayRank` say it: Great Feast, Feast, Lesser
  Feast, Weekday (Advent Weekday, Lenten Weekday). The engine answers in
  Latin, and Latin belongs in the prayer text, not in the chrome above it.

  The app reads the plain words off the Missal's English title ("Saturday
  of the Third Week of Lent", "Holy Thursday"); the site has only the
  Office's Latin title, so the same rules are kept in both tongues: a day
  is a weekday by "Feria", "Sabbato" or "Quattuor Temporum" as by
  "Saturday" or "Ember", and Lent is "Quadragesima" (the calendar shortens
  it to "in Quadr"), "Passionis", "Cineres" and "Hebdomadæ Sanctæ". The
  day's season line (the calendar's detail, the hour's tempora) is read
  with the title. The Triduum, the vigils and the days within an octave
  are named by weekday too, and are not weekdays; a day the engine ranks
  "Dies Octavæ" has no class to say, as on the app.

  Also the mark the month's calendar gives a day: brighter for the
  greater feasts, none at all on a feria.
  """

  # Named by weekday, but not weekdays: the octaves, the Triduum and the
  # vigils, in the Missal's English and the Office's Latin.
  @not_weekdays [
    "octave",
    "infra octav",
    "in albis",
    "supper",
    "cena domini",
    "good friday",
    "passione et morte",
    "parasceve",
    "holy saturday",
    "sabbato sancto",
    "vigil"
  ]

  @doc """
  1 to 4 from the engine's rank, nil for a feria or no rank. The Missal's
  class is already a number (Missale Meum's `rank`), and is taken as it is.
  """
  def class(rank) when is_integer(rank) and rank in 1..4, do: rank

  def class(rank) when is_binary(rank) do
    text = rank |> String.trim() |> String.upcase()

    Enum.find_value([{"IV", 4}, {"III", 3}, {"II", 2}, {"I", 1}], fn {numeral, number} ->
      if text == numeral or String.starts_with?(text, [numeral <> ".", numeral <> " "]),
        do: number
    end)
  end

  def class(_rank), do: nil

  @doc """
  The day's class in plain words, or nil when there is none to say.
  `title` is the celebration's, `season` any further text naming the
  season.
  """
  def plain(rank, title, season \\ nil) do
    number = class(rank)
    title = if number, do: title, else: "Feria #{title}"
    words = String.downcase("#{title} #{season}")

    cond do
      weekday?(title, rank) -> weekday(words)
      number == 1 -> "Great Feast"
      number == 2 -> "Feast"
      number == 3 -> "Lesser Feast"
      number == 4 -> weekday(words)
      true -> nil
    end
  end

  @doc """
  The Missal's day in plain words, as iOS's `DayRank.plainLabel` reads
  Missale Meum's number: a weekday by its title whatever its class, else
  the class; nil for a day Missale Meum sends with no class, unless its
  title names a weekday.
  """
  def plain_missal(rank, title, season \\ nil)

  def plain_missal(rank, title, season) when is_integer(rank), do: plain(rank, title, season)

  def plain_missal(_no_rank, title, season) do
    if weekday?(title, nil), do: weekday(String.downcase("#{title} #{season}"))
  end

  @doc "A day's plain class from an Office day or hour map."
  def plain_for(%{celebration: %{title: title, rank: rank}} = day),
    do: plain(rank, title, season(day))

  def plain_for(_day), do: nil

  defp season(%{tempora: tempora}) when is_binary(tempora), do: tempora
  defp season(%{detail: %{text: text}}) when is_binary(text), do: text
  defp season(_day), do: nil

  @doc "The month grid's mark for a day: `:first`, `:second`, `:third`, `:fourth` or nil."
  def mark(rank) do
    case class(rank) do
      1 -> :first
      2 -> :second
      3 -> :third
      4 -> :fourth
      nil -> nil
    end
  end

  # A feria by its title, or a weekday named for its week; the days of an
  # octave and of the Triduum are named by weekday too, and are not weekdays.
  defp weekday?(title, rank) do
    t = String.downcase(title || "")

    cond do
      Enum.any?(@not_weekdays, &String.contains?(t, &1)) -> false
      in_octave?(rank) -> false
      String.contains?(t, ["feria", "ember ", "quattuor temporum"]) -> true
      String.starts_with?(t, "ash wednesday") -> true
      Regex.match?(~r/^(monday|tuesday|wednesday|thursday|friday|saturday|sabbato)\b/u, t) -> true
      true -> false
    end
  end

  # "Dies Octavæ I. classis": a day within the octaves of Easter and
  # Pentecost, whatever its title says.
  defp in_octave?(rank) when is_binary(rank),
    do: rank |> String.downcase() |> String.contains?("octav")

  defp in_octave?(_rank), do: false

  defp weekday(words) do
    cond do
      String.contains?(words, "advent") ->
        "Advent Weekday"

      String.contains?(words, ["holy week", "hebdomadæ sanctæ", "hebdomada sancta"]) ->
        "Lenten Weekday"

      String.contains?(words, ["ash wednesday", "cinerum", "cineres"]) ->
        "Lenten Weekday"

      # "Lent" as a word, so a Valentine is not Lenten; the Latin says
      # "Quadragesimæ", or "in Quadr" in the calendar, and "Passionis".
      Regex.match?(~r/\blent\b|\bquadr\b/u, words) or
          String.contains?(words, ["quadrages", "passion"]) ->
        "Lenten Weekday"

      true ->
        "Weekday"
    end
  end
end
