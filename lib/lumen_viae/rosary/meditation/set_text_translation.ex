defmodule LumenViae.Rosary.Meditation.SetTextTranslation do
  @moduledoc """
  A meditation set's `set_translation`: with `lang=es`, the Spanish of
  its description, source and image alt
  (`LumenViae.Rosary.Meditation.SetSpanish.translation/2`), each checked
  against the English a client is shown; otherwise null. The language
  comes from the read's context, put there by
  `LumenViae.Rosary.Meditation.Language`.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Meditation.SetSpanish

  @impl true
  def load(_query, _opts, _context), do: [:description, :byline_source, :artwork]

  @impl true
  def calculate(sets, _opts, context) do
    case context.source_context[:meditation_lang] do
      "es" ->
        Enum.map(sets, fn set ->
          SetSpanish.translation(set.id, %{
            description: set.description,
            source: set.byline_source,
            artwork_alt: set.artwork && set.artwork.alt
          })
        end)

      _english ->
        Enum.map(sets, fn _set -> nil end)
    end
  end
end
