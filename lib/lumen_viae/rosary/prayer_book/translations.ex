defmodule LumenViae.Rosary.PrayerBook.Translations do
  @moduledoc """
  The `translations` section of `LumenViae.Rosary.PrayerBook`: in Spanish,
  every prayer the book prints that has Spanish
  (`LumenViae.Rosary.PrayerBook.Spanish.prayers/0`); in English, none.

  Each is a plain map, so `ai_translated` is there only when true.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.PrayerBook.Spanish

  # GraphQL selects only the fields a query names, so the language is
  # asked for here or it would arrive empty.
  @impl true
  def load(_query, _opts, _context), do: [:lang]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      case Content.language(record.lang) do
        "es" -> Spanish.prayers()
        _english -> []
      end
    end)
  end
end
