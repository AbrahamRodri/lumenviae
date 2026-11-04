defmodule LumenViae.Rosary.Meditation.Translation do
  @moduledoc """
  One meditation in the language a read asked for, as a meditation set's
  `translations` section serves it with `lang=es`. See
  `LumenViae.Rosary.Meditation.Spanish`.
  """
  use Ash.TypedStruct

  typed_struct do
    field :id, :integer,
      allow_nil?: false,
      description: "The meditation's id, the same as in the set's meditations."

    field :title, :string, description: "Its title in this language, or null where the English has none."

    field :content, :string,
      allow_nil?: false,
      description:
        "Its text in this language, paragraphs parted as the English's. The recording, if any, still says the English."

    field :ai_translated, :boolean,
      description:
        "`true` when the text is the team's own AI translation, not a published text: show the app's AI notice under it. Absent otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :meditation_translation
end
