defmodule LumenViae.Rosary.Meditation.SetTranslation do
  @moduledoc """
  A meditation set's own words in the language a read asked for, as its
  `set_translation` serves them with `lang=es`. See
  `LumenViae.Rosary.Meditation.SetSpanish`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :description, :string,
      description: "The set's description in this language, or null: show the English."

    field :source, :string,
      description:
        "The set's source in this language (the Spanish edition's title where the Spanish was copied from one), or null: show the English."

    field :artwork_alt, :string,
      description:
        "The alt text of the set's artwork in this language, or null: show the English."

    field :ai_translated, :boolean,
      description:
        "`true` when the text is the team's own AI translation: show the app's AI notice. Absent otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :meditation_set_translation
end
