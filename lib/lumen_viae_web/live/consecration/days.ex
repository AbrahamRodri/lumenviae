defmodule LumenViaeWeb.Live.Consecration.Days do
  @moduledoc """
  The 33-day Consecration as the website's pages read it, over
  `LumenViae.Rosary.get_consecration!/1` (`priv/library/consecration.json`):
  its phases, its 34 days, the prayers each phase says and the feasts of
  Mary it may end on, arranged by the iOS app's rules
  (`ConsecrationPhase`, `ConsecrationDay`, `ConsecrationDayFlowView`,
  `ConsecrationDayOverviewView`): a day's steps are its phase's prayers
  then its readings; a day's badge, line and ordinal; each phase's tint and
  its accent on the journey; and the chant a prayer is sung to, the first
  of the Chant Library's settings of it in the library's order.

  Presentation only: it never queries beyond `load/1`.
  """

  alias LumenViae.Rosary
  alias LumenViaeWeb.Live.Chants.Library

  defstruct [:phases, :days, :prayers, :feasts, :chants]

  @ordinals ~w(First Second Third Fourth Fifth Sixth Seventh Eighth Ninth Tenth
    Eleventh Twelfth Thirteenth Fourteenth Fifteenth Sixteenth Seventeenth
    Eighteenth Nineteenth Twentieth Twenty-First Twenty-Second Twenty-Third
    Twenty-Fourth Twenty-Fifth Twenty-Sixth Twenty-Seventh Twenty-Eighth
    Twenty-Ninth Thirtieth Thirty-First Thirty-Second Thirty-Third
    Thirty-Fourth)

  # The phases' tints laid over the page (ConsecrationPhase.gradientColors
  # on iOS): penitential violet-navy, deep navy, Marian blue, then warming
  # toward gold as the consecration nears.
  @tints %{
    "preparatory" => {"#1D1832", "#100D1F"},
    "knowledge_of_self" => {"#141E38", "#0C1222"},
    "knowledge_of_mary" => {"#16264D", "#0D142A"},
    "knowledge_of_jesus" => {"#2A2318", "#14101E"},
    "consecration_day" => {"#3D3522", "#1A1408"}
  }

  # Each phase's accent on the journey (ConsecrationPhase.accentColor): the
  # app's gold, quietly brightening as the 33 days advance.
  @accents %{
    "preparatory" => 0.6,
    "knowledge_of_self" => 0.75,
    "knowledge_of_mary" => 0.9,
    "knowledge_of_jesus" => 1.0,
    "consecration_day" => :light
  }

  @doc """
  The Consecration, read through the domain as `actor`; with `chants:
  true`, the Chant Library's settings of its prayers too.
  """
  def load(actor, opts \\ []) do
    doc = Rosary.get_consecration!(actor: actor, load: [:phases, :days, :prayers, :feasts])

    %__MODULE__{
      phases: doc.phases,
      days: doc.days,
      prayers: Map.new(doc.prayers, &{&1.id, &1}),
      feasts: doc.feasts,
      chants: if(opts[:chants], do: chants_by_prayer(actor), else: %{})
    }
  end

  defp chants_by_prayer(actor) do
    library = Library.load(actor)

    Enum.reduce(Enum.reverse(library.chants), %{}, fn chant, acc ->
      Enum.reduce(Enum.uniq(chant.prayer_ids || []), acc, &Map.put(&2, &1, chant))
    end)
  end

  # ---- Paths

  @doc "The Consecration's page."
  def path, do: "/consecration"

  @doc "The completion: the Act made."
  def act_path, do: "/consecration/act"

  @doc "A day's page."
  def day_path(n), do: "/consecration/days/#{n}"

  @doc "A step of a day's flow, from 1; the language rides along, English never written."
  def step_path(n, step, language \\ "english") do
    query = [{"step", step}] ++ if(language in ~w(latin both), do: [{"lang", language}], else: [])
    day_path(n) <> "?" <> URI.encode_query(query)
  end

  @doc "A day's page in a language, English never written."
  def day_path(n, language) when language in ~w(latin both),
    do: day_path(n) <> "?lang=" <> language

  def day_path(n, _language), do: day_path(n)

  @doc "True Devotion's title page, from PR #149 (a 404 until it is merged)."
  def book_path, do: "/true-devotion"

  @doc "True Devotion's chapter on the Act of Consecration (PR #149)."
  def book_act_path, do: "/true-devotion/formula"

  # ---- The days

  @doc "Day `n`, or nil."
  def day(%__MODULE__{days: days}, n) when is_integer(n), do: Enum.find(days, &(&1.number == n))
  def day(_doc, _n), do: nil

  @doc """
  A day number from the URL: a whole number from 1 to 34, else nil (an
  unknown day, `0`, `35`, `2.5`, a word or a list).
  """
  def day_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n in 1..34 -> n
      _other -> nil
    end
  end

  def day_number(_value), do: nil

  @doc "The phase a day belongs to."
  def phase(%__MODULE__{phases: phases}, %{phase_id: id}), do: Enum.find(phases, &(&1.id == id))

  @doc "The phase holding day `n`."
  def phase_of(%__MODULE__{phases: phases}, n),
    do: Enum.find(phases, &(n >= &1.first_day and n <= &1.last_day))

  @doc "A phase by its id, or nil."
  def phase_by_id(%__MODULE__{phases: phases}, id), do: Enum.find(phases, &(&1.id == id))

  @doc "The prayers a phase says, in its order; one the document lacks is skipped."
  def prayers(%__MODULE__{prayers: prayers}, phase),
    do: phase.prayer_ids |> Enum.map(&prayers[&1]) |> Enum.reject(&is_nil/1)

  @doc "A day's readings in their order."
  def readings(day), do: Enum.sort_by(day.readings, & &1.order)

  @doc """
  A day's steps as its flow walks them: each prayer of its phase, then
  each of its readings, `{:prayer, prayer}` or `{:reading, reading}`.
  """
  def steps(doc, day) do
    phase = phase(doc, day)
    Enum.map(prayers(doc, phase), &{:prayer, &1}) ++ Enum.map(readings(day), &{:reading, &1})
  end

  @doc """
  The step a link names, from 1: a whole number held to the day's steps,
  the first for anything else.
  """
  def step(param, count) when is_binary(param) do
    case Integer.parse(param) do
      {n, ""} -> n |> max(1) |> min(max(count, 1))
      _other -> 1
    end
  end

  def step(_param, _count), do: 1

  @doc "The chant a prayer is sung to on its page, or nil."
  def chant(%__MODULE__{chants: chants}, %{id: id}), do: Map.get(chants, id)

  # ---- Words

  @doc "\"DAY 5 OF 33\", or \"CONSECRATION DAY\"."
  def badge(34), do: "Consecration Day"
  def badge(n), do: "Day #{n} of 33"

  @doc "\"DAY 5\", or \"CONSECRATION DAY\": the flow's head."
  def short_badge(34), do: "Consecration Day"
  def short_badge(n), do: "Day #{n}"

  @doc "\"Fifth Day\"."
  def ordinal(n) when n in 1..34, do: "#{Enum.at(@ordinals, n - 1)} Day"

  @doc """
  The line under a day's title: its stage, "Days 1–12 · Letting Go of the
  World", or the ordinal where the day's title is its stage's own focus.
  """
  def subtitle(phase, day) do
    stage =
      if phase.id == "consecration_day",
        do: phase.subtitle,
        else: "#{phase.name} · #{phase.subtitle}"

    if String.downcase(day.title) == String.downcase(phase.subtitle),
      do: ordinal(day.number),
      else: stage
  end

  @doc "A phase's span: \"1–12\", or \"Consecration Day\" (the introduction's journey)."
  def range_label(%{id: "consecration_day"}), do: "Consecration Day"
  def range_label(%{first_day: d, last_day: d}), do: "Day #{d}"
  def range_label(%{first_day: a, last_day: b}), do: "#{a}–#{b}"

  @doc "A phase's span on the journey card: \"Days 13–19\"."
  def span_label(%{id: "consecration_day"}), do: "Consecration Day"
  def span_label(%{first_day: d, last_day: d}), do: "Day #{d}"
  def span_label(%{first_day: a, last_day: b}), do: "Days #{a}–#{b}"

  @doc "A phase's days."
  def phase_days(%{first_day: a, last_day: b}), do: Enum.to_list(a..b)

  @doc "A prayer's Latin name where it is not its English one, else nil."
  def latin_title(%{latin_title: latin, title: title}) when is_binary(latin) do
    if String.downcase(latin) == String.downcase(title), do: nil, else: latin
  end

  def latin_title(_prayer), do: nil

  @doc "\"1 prayer\", \"4 prayers\"."
  def prayer_count(1), do: "1 prayer"
  def prayer_count(n), do: "#{n} prayers"

  @doc "A reading's paragraphs."
  def paragraphs(text) do
    text
    |> String.split(~r/\n\s*\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  A reading's paragraphs as the page sets them, as the app's
  `ReadingText`: `{:rule}` for a paragraph of rule characters (an
  ornament between sections), `{:heading, text}` for one opening `# `
  (the reading's own title, as the book prints it), else `{:text, text,
  versal?}`, the first prose paragraph opening on the versal.
  """
  def blocks(text) do
    {blocks, _versal_taken?} =
      text
      |> paragraphs()
      |> Enum.map_reduce(false, fn paragraph, taken? ->
        cond do
          rule?(paragraph) -> {{:rule}, taken?}
          String.starts_with?(paragraph, "# ") -> {{:heading, heading(paragraph)}, taken?}
          true -> {{:text, paragraph, not taken?}, true}
        end
      end)

    blocks
  end

  defp rule?(paragraph),
    do: String.length(paragraph) >= 3 and String.match?(paragraph, ~r/^[─—–\-*_ ]+$/u)

  defp heading(paragraph), do: paragraph |> String.replace_prefix("# ", "") |> String.trim()

  @doc "A reading's opening: its first two prose paragraphs, run together, as the card shows it."
  def preview(reading) do
    reading.text
    |> blocks()
    |> Enum.flat_map(fn
      {:text, text, _versal?} -> [text]
      _other -> []
    end)
    |> Enum.take(2)
    |> Enum.join(" ")
  end

  # ---- Looks

  @doc "A phase's painting, `{name, focal x, focal y}`."
  def painting(%{painting: name}), do: {name, 0.5, 0.3}

  @doc "The style a phase tints the page with: its two colours as custom properties."
  def tint_style(%{id: id}) do
    {top, foot} = Map.get(@tints, id, {"#0A0A15", "#050509"})
    "--phase-top: #{top}; --phase-foot: #{foot};"
  end

  @doc "A phase's accent on the journey: the gold at its opacity, or gold-light on the last."
  def accent_style(%{id: id}) do
    case Map.get(@accents, id, 1.0) do
      :light -> "background: var(--color-gilt-light);"
      opacity -> "background: rgba(227, 188, 91, #{opacity});"
    end
  end
end
