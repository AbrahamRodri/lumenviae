defmodule LumenViae.Rosary.Meditation.Language do
  @moduledoc """
  Puts the language a meditation-set read asked for (`lang`, read by
  `LumenViae.Rosary.Content.language/1`) in the query's context, for the
  set's `translations` calculation
  (`LumenViae.Rosary.Meditation.SetTranslations`). It changes nothing
  else: the read returns the same sets in the same order in every
  language.
  """
  use Ash.Resource.Preparation

  alias LumenViae.Rosary.Content

  @impl true
  def prepare(query, _opts, _context) do
    lang = query |> Ash.Query.get_argument(:lang) |> Content.language()
    Ash.Query.set_context(query, %{meditation_lang: lang})
  end
end
