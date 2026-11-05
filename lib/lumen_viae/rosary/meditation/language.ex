defmodule LumenViae.Rosary.Meditation.Language do
  @moduledoc """
  Puts the language a meditation-set read asked for (`lang`, read by
  `LumenViae.Rosary.Content.language/1`) in the query's context, for the
  set's `translations` calculation
  (`LumenViae.Rosary.Meditation.SetTranslations`). A read that names a
  `lang` also loads each set's `set_translation`, so a list of sets
  carries their own words in that language as one set does. It changes
  nothing else: the read returns the same sets in the same order in every
  language, and a read without `lang` loads nothing more.
  """
  use Ash.Resource.Preparation

  alias LumenViae.Rosary.Content

  @impl true
  def prepare(query, _opts, _context) do
    asked = Ash.Query.get_argument(query, :lang)
    query = Ash.Query.set_context(query, %{meditation_lang: Content.language(asked)})

    if is_nil(asked), do: query, else: Ash.Query.load(query, :set_translation)
  end
end
