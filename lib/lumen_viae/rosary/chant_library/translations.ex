defmodule LumenViae.Rosary.ChantLibrary.Translations do
  @moduledoc """
  The `translations` section of `LumenViae.Rosary.ChantLibrary`: in
  Spanish, `LumenViae.Rosary.ChantLibrary.Spanish.translation/0`; in
  English, the same two lists, empty.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.ChantLibrary.Spanish
  alias LumenViae.Rosary.Content

  @empty %{chants: [], groups: []}

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
