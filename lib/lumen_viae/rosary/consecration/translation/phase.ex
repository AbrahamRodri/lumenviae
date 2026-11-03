defmodule LumenViae.Rosary.Consecration.Translation.Phase do
  @moduledoc "One Consecration phase's words in another language. See `LumenViae.Rosary.Consecration.Translation`."
  use Ash.TypedStruct

  typed_struct do
    field :id, :string, allow_nil?: false, description: "The phase's id, the same as in `phases`."

    field :name, :string,
      allow_nil?: false,
      description: "Its name in this language (`Días 1–12`)."

    field :subtitle, :string, allow_nil?: false, description: "Its subtitle in this language."

    field :ai_translated, :boolean,
      description:
        "`true` when the words are the team's own AI translation, not a published text: show the app's AI notice. Absent otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_phase_translation
end
