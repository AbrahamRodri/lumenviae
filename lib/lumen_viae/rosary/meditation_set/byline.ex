defmodule LumenViae.Rosary.MeditationSet.Byline do
  @moduledoc """
  The byline a set is shown with: its own `author` (or `source`) when it has
  one, otherwise the derivation from its meditations.

  An explicit value on the set always wins; the derivation only fills a
  gap. This is the value both APIs print, so a client never has to know
  which of the two it was handed.

  Takes `field: :author` or `field: :source`.
  """
  use Ash.Resource.Calculation

  @derived %{author: :derived_author, source: :derived_source}

  @impl true
  def init(opts) do
    if Map.has_key?(@derived, opts[:field]) do
      {:ok, opts}
    else
      {:error, "field must be :author or :source"}
    end
  end

  @impl true
  def load(_query, opts, _context), do: [opts[:field], Map.fetch!(@derived, opts[:field])]

  @impl true
  def calculate(sets, opts, _context) do
    derived = Map.fetch!(@derived, opts[:field])

    Enum.map(sets, fn set ->
      case Map.fetch!(set, opts[:field]) do
        blank when blank in [nil, ""] -> Map.fetch!(set, derived)
        explicit -> explicit
      end
    end)
  end
end
