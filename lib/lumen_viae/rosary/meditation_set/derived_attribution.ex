defmodule LumenViae.Rosary.MeditationSet.DerivedAttribution do
  @moduledoc """
  A set's byline as its meditations give it: the author (or the source)
  every one of them carries, or nil.

  Derived only when every meditation agrees. A set of four Emmerich
  passages and one Liguori gets nil rather than a name that is true of most
  of it, and so does a set where one meditation names nobody.

  This is a calculation, never a stored value. Writing the derivation into
  the set's own `author` and `source` columns would mean any later save
  promoted a guess to an explicit override, which then went stale the
  moment a meditation's attribution was fixed.

  Takes `field: :author` or `field: :source`, and reads the matching list
  aggregate, so it costs no query of its own.
  """
  use Ash.Resource.Calculation

  @aggregates %{author: :meditation_authors, source: :meditation_sources}

  @impl true
  def init(opts) do
    if Map.has_key?(@aggregates, opts[:field]) do
      {:ok, opts}
    else
      {:error, "field must be :author or :source"}
    end
  end

  @impl true
  def load(_query, opts, _context), do: [Map.fetch!(@aggregates, opts[:field])]

  @impl true
  def calculate(sets, opts, _context) do
    aggregate = Map.fetch!(@aggregates, opts[:field])
    Enum.map(sets, &unanimous(Map.fetch!(&1, aggregate)))
  end

  @doc """
  The one value every entry shares once blanks are read as nothing, or nil
  when the list is empty, disagrees, or is unanimous about nothing.
  """
  def unanimous(values) do
    case values |> List.wrap() |> Enum.map(&blank_to_nil/1) |> Enum.uniq() do
      [value] when is_binary(value) -> value
      _disagreement_or_nothing -> nil
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
