defmodule LumenViae.Rosary.Consecration.Translation.Feast do
  @moduledoc "One feast of Mary's words in another language. See `LumenViae.Rosary.Consecration.Translation`."
  use Ash.TypedStruct

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The feast's id, the same as in `feasts`."
    field :name, :string, allow_nil?: false, description: "Its name in this language."

    field :description, :string,
      allow_nil?: false,
      description: "Its description in this language."

    field :ai_translated, :boolean,
      description:
        "`true` when the words are the team's own AI translation, not a published text: show the app's AI notice. Absent otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_feast_translation
end
