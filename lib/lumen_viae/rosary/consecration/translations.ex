defmodule LumenViae.Rosary.Consecration.Translations do
  @moduledoc """
  The `translations` section of `LumenViae.Rosary.Consecration`: in
  Spanish, `LumenViae.Rosary.Consecration.Spanish.translation/0`; in
  English, the same four lists, empty.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Consecration.Spanish
  alias LumenViae.Rosary.Content

  @empty %{phases: [], days: [], prayers: [], feasts: []}

  # GraphQL selects only the fields a query names, so the language is
  # asked for here or it would arrive empty.
  @impl true
  def load(_query, _opts, _context), do: [:lang]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      case Content.language(record.lang) do
        "es" -> Spanish.translation()
        _english -> @empty
      end
    end)
  end
end
