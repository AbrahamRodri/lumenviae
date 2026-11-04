defmodule LumenViae.Rosary.Meditation.SetTranslations do
  @moduledoc """
  A meditation set's `translations` section: with `lang=es`, its
  meditations' Spanish in prayer order
  (`LumenViae.Rosary.Meditation.Spanish.translations/1`); otherwise none.
  The language comes from the read's context, put there by
  `LumenViae.Rosary.Meditation.Language`.
  """
  use Ash.Resource.Calculation

  alias LumenViae.Rosary.Meditation.Spanish

  @impl true
  def load(_query, _opts, _context), do: [set_memberships: [meditation: [:title, :content]]]

  @impl true
  def calculate(sets, _opts, context) do
    case context.source_context[:meditation_lang] do
      "es" ->
        Enum.map(sets, fn set ->
          set.set_memberships
          |> Enum.map(& &1.meditation)
          |> Enum.reject(&is_nil/1)
          |> Spanish.translations()
        end)

      _english ->
        Enum.map(sets, fn _set -> [] end)
    end
  end
end
