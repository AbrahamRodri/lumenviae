defmodule LumenViae.Rosary.PrayerBook.NovenaTranslations do
  @moduledoc """
  The `novena_translations` section of `LumenViae.Rosary.PrayerBook`: in
  Spanish, every novena that has Spanish
  (`LumenViae.Rosary.PrayerBook.Spanish.novenas/0`); in English, none.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Content
  alias LumenViae.Rosary.PrayerBook.Spanish

  # As for `translations`: GraphQL selects only the fields a query names.
  @impl true
  def load(_query, _opts, _context), do: [:lang]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      case Content.language(record.lang) do
        "es" -> Spanish.novenas()
        _english -> []
      end
    end)
  end
end
