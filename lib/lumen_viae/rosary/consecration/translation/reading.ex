defmodule LumenViae.Rosary.Consecration.Translation.Reading do
  @moduledoc "One Consecration reading in another language. See `LumenViae.Rosary.Consecration.Translation`."
  use Ash.TypedStruct

  typed_struct do
    field :order, :integer,
      allow_nil?: false,
      description: "Its place in the day, the same as in `days`."

    field :title, :string,
      allow_nil?: false,
      description: "Its citation in this language (`Mateo 5, 1-19`)."

    field :text, :string,
      allow_nil?: false,
      description: "The reading in this language, in the same ReadingText grammar as the English."

    field :source, :string,
      allow_nil?: false,
      description:
        "The edition it is from (`Biblia de Torres Amat`), or the work it translates when `ai_translated`."

    field :ai_translated, :boolean,
      description:
        "`true` when the reading is the team's own AI translation, not a published text: show the app's AI notice under it. Absent otherwise."
  end

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :consecration_reading_translation
end
